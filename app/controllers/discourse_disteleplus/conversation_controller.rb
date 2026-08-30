# frozen_string_literal: true

module DiscourseDisteleplus
  class ConversationController < ::ApplicationController
    requires_plugin "jtech-tools"
    requires_login
    before_action :ensure_enabled
    before_action :ensure_allowed

    PAGE_SIZE = 40
    MAX_PAGE_SIZE = 100

    # Ember entry point: /disteleplus renders the application shell; the
    # route then fetches the conversation JSON.
    def page
      render "default/empty"
    end

    def show
      messages = page_scope.limit(PAGE_SIZE).to_a.reverse
      render_json_dump(
        { messages: serialize_messages(messages), meta: conversation_meta(messages) },
      )
    end

    def index
      limit = params.fetch(:limit, PAGE_SIZE).to_i.clamp(1, MAX_PAGE_SIZE)
      return render_around(params[:around_id].to_i, limit) if params[:around_id].present?
      messages = page_scope.limit(limit).to_a.reverse
      render_json_dump(
        {
          messages: serialize_messages(messages),
          meta: {
            has_more: messages.any? && Message.where("id < ?", messages.first.id).exists?,
          },
        },
      )
    end

    def create
      rate_limit!("create", 30, 1.minute)
      message =
        service.create!(
          raw: params[:raw],
          upload_ids: params[:upload_ids],
          reply_to_id: params[:reply_to_id],
        )
      render_message(message, status: :created)
    rescue MessageService::Error, ActiveRecord::RecordInvalid => e
      render_error(e)
    end

    def update
      rate_limit!("update", 30, 1.minute)
      message = Message.find(params[:id])
      render_message(service.update!(message, raw: params[:raw]))
    rescue MessageService::Error, ActiveRecord::RecordInvalid => e
      render_error(e)
    end

    def destroy
      rate_limit!("delete", 20, 1.minute)
      message = Message.find(params[:id])
      render_message(service.delete!(message))
    rescue MessageService::Error, ActiveRecord::RecordInvalid => e
      render_error(e)
    end

    def add_reaction
      rate_limit!("reaction", 60, 1.minute)
      message = Message.find(params[:id])
      render_message(service.react!(message, emoji: params[:emoji], action: :add))
    rescue MessageService::Error, ActiveRecord::RecordInvalid => e
      render_error(e)
    end

    def remove_reaction
      rate_limit!("reaction", 60, 1.minute)
      message = Message.find(params[:id])
      render_message(service.react!(message, emoji: params[:emoji], action: :remove))
    rescue MessageService::Error, ActiveRecord::RecordInvalid => e
      render_error(e)
    end

    # Text is encrypted at rest, so search decrypts and filters in Ruby over a
    # bounded window — fine for one room.
    SEARCH_WINDOW = 3000
    SEARCH_LIMIT = 50

    def search
      rate_limit!("search", 30, 1.minute)
      term = params[:q].to_s.strip.downcase
      raise Discourse::InvalidParameters.new(:q) if term.length < 2

      results = []
      Message
        .not_deleted
        .includes(:user, :uploads)
        .order(id: :desc)
        .limit(SEARCH_WINDOW)
        .find_each(batch_size: 200) do |message|
          haystack = [
            message.raw,
            message.external_sender_name,
            message.user&.username,
            message.user&.name,
          ]
          next unless haystack.compact.any? { |field| field.downcase.include?(term) }
          results << message
          break if results.length >= SEARCH_LIMIT
        end
      render_json_dump(
        {
          results:
            results.map do |m|
              MessageSerializer.serialize(m, viewer: current_user, include_reply: false)
            end,
          count: results.length,
        },
      )
    end

    def typing
      rate_limit!("typing", 60, 1.minute)
      Publisher.publish_typing(current_user)
      if SiteSetting.disteleplus_typing_to_telegram &&
           Discourse.redis.set("disteleplus:typing-sent", "1", ex: 4, nx: true)
        Jobs.enqueue(:disteleplus_telegram_typing)
      end
      render json: success_json
    end

    def read
      rate_limit!("read", 120, 1.minute)
      state = service.mark_read!(params.require(:message_id))
      render_json_dump(
        {
          success: true,
          last_read_message_id: state&.last_read_message_id,
          unread_count: unread_count(state&.last_read_message_id),
        },
      )
    end

    private

    def ensure_enabled
      raise Discourse::NotFound unless SiteSetting.disteleplus_enabled
    end

    def ensure_allowed
      raise Discourse::InvalidAccess unless Access.allowed?(current_user)
    end

    def render_around(id, limit)
      half = [limit / 2, 1].max
      before =
        Message
          .includes(:user, :uploads, reply_to: :user, reactions: :user)
          .where("id < ?", id)
          .order(id: :desc)
          .limit(half)
          .to_a
          .reverse
      target =
        Message.includes(:user, :uploads, reply_to: :user, reactions: :user).where(id: id).to_a
      after =
        Message
          .includes(:user, :uploads, reply_to: :user, reactions: :user)
          .where("id > ?", id)
          .order(id: :asc)
          .limit(half)
          .to_a
      messages = before + target + after
      render_json_dump(
        {
          messages: serialize_messages(messages),
          meta: {
            has_more: messages.any? && Message.where("id < ?", messages.first.id).exists?,
            has_newer: messages.any? && Message.where("id > ?", messages.last.id).exists?,
          },
        },
      )
    end

    def page_scope
      scope = Message.includes(:user, :uploads, reply_to: :user, reactions: :user).order(id: :desc)
      before_id = params[:before_id].to_i
      scope = scope.where("disteleplus_messages.id < ?", before_id) if before_id.positive?
      scope
    end

    def serialize_messages(messages)
      messages.map { |message| MessageSerializer.serialize(message, viewer: current_user) }
    end

    def conversation_meta(messages)
      state = UserState.find_by(user: current_user)
      latest_id = Message.maximum(:id)
      {
        allowed: true,
        current_user_id: current_user.id,
        latest_message_id: latest_id,
        last_read_message_id: state&.last_read_message_id,
        unread_count: unread_count(state&.last_read_message_id),
        has_more: messages.any? && Message.where("id < ?", messages.first.id).exists?,
        message_bus_channel: Publisher::CHANNEL,
        can_upload: true,
        voice_notes_enabled: SiteSetting.disteleplus_voice_notes_enabled,
      }
    end

    def unread_count(last_read_id)
      Message
        .not_deleted
        .where("id > ?", last_read_id.to_i)
        .where.not(user_id: current_user.id)
        .count
    end

    def service
      @service ||= MessageService.new(actor: current_user)
    end

    def render_message(message, status: :ok)
      render_json_dump(
        { message: MessageSerializer.serialize(message.reload, viewer: current_user) },
        status: status,
      )
    end

    def render_error(error)
      render json: { errors: [error.message] }, status: :unprocessable_entity
    end

    def rate_limit!(action, limit, interval)
      RateLimiter.new(current_user, "disteleplus-#{action}", limit, interval).performed!
    end
  end
end
