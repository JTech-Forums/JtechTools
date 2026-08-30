# frozen_string_literal: true

module DiscourseDisteleplus
  class ConversationController < ::ApplicationController
    requires_login
    before_action :ensure_enabled
    before_action :ensure_allowed

    PAGE_SIZE = 40
    MAX_PAGE_SIZE = 100

    def show
      messages = page_scope.limit(PAGE_SIZE).to_a.reverse
      render_json_dump(
        {
          messages: serialize_messages(messages),
          meta: conversation_meta(messages),
        },
      )
    end

    def index
      limit = params.fetch(:limit, PAGE_SIZE).to_i.clamp(1, MAX_PAGE_SIZE)
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

    def page_scope
      scope =
        Message
          .includes(:user, :uploads, reply_to: :user, reactions: :user)
          .order(id: :desc)
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
