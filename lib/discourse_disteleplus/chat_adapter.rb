# frozen_string_literal: true

module DiscourseDisteleplus
  # The ONLY place in the bridge that touches the chat plugin's Ruby API.
  #
  # The chat plugin ships with Discourse core but is a moving target and is
  # not vendored here, so every call is defensive: `defined?` feature checks,
  # an ArgumentError fallback between the `params:` envelope and legacy
  # kwargs signatures of the service objects, and an accessor chain for the
  # service result. Targets Discourse 3.2+ (Chat::CreateMessage et al.
  # service objects). If the chat plugin is absent everything no-ops via
  # `available?` — the translator_tweaks `defined?` precedent.
  #
  # Echo suppression, layer 1: DiscourseEvent.trigger is synchronous and
  # in-process, so any :chat_message_* events fired while we write under
  # `with_bridge_flag` run on this same thread and are skipped by the event
  # handlers. The disteleplus_message_links table is the durable layer 2.
  class ChatAdapter
    class BridgeError < StandardError
    end

    def self.available?
      defined?(::Chat) && defined?(::Chat::Message) && defined?(::Chat::CreateMessage)
    end

    def self.bridging?
      Thread.current[:disteleplus_bridging] == true
    end

    def self.with_bridge_flag
      Thread.current[:disteleplus_bridging] = true
      yield
    ensure
      Thread.current[:disteleplus_bridging] = nil
    end

    def self.find_message(id)
      return nil unless available?
      ::Chat::Message.find_by(id: id)
    end

    # Creates a chat message as `user` and returns the Chat::Message.
    def self.create_message(channel_id:, user:, text:, upload_ids: nil, in_reply_to_id: nil)
      with_bridge_flag do
        params = { chat_channel_id: channel_id, message: text }
        params[:upload_ids] = upload_ids if upload_ids.present?
        params[:in_reply_to_id] = in_reply_to_id if in_reply_to_id.present?

        result = call_service(::Chat::CreateMessage, params, user)
        raise BridgeError, failure_reason(result) unless result_success?(result)

        message =
          result.try(:message_instance) || result.try(:message) ||
            result.try(:[], :message_instance) || result.try(:[], :message)
        raise BridgeError, "chat message missing from service result" if message.nil?
        message
      end
    end

    def self.update_message(message_id:, user:, text:)
      with_bridge_flag do
        result =
          call_service(::Chat::UpdateMessage, { message_id: message_id, message: text }, user)
        raise BridgeError, failure_reason(result) unless result_success?(result)
        result
      end
    end

    def self.trash_message(message_id:, channel_id:, user:)
      with_bridge_flag do
        params = { message_id: message_id, channel_id: channel_id }
        result = call_service(::Chat::TrashMessage, params, user)
        raise BridgeError, failure_reason(result) unless result_success?(result)
        result
      end
    end

    # Adds/removes a reaction as `user`. action is :add or :remove.
    def self.react(message_id:, user:, emoji:, action:)
      with_bridge_flag do
        message = find_message(message_id)
        return if message.nil?

        if defined?(::Chat::MessageReactor)
          ::Chat::MessageReactor.new(user, message.chat_channel).react!(
            message_id: message.id,
            react_action: action,
            emoji: emoji,
          )
        elsif defined?(::Chat::CreateMessageReaction)
          call_service(
            ::Chat::CreateMessageReaction,
            { message_id: message.id, emoji: emoji, react_action: action },
            user,
          )
        end
      end
    rescue StandardError => e
      Rails.logger.warn("#{DiscourseDisteleplus::LOG_TAG} react failed: #{e.class}: #{e.message}")
      nil
    end

    # Emoji names currently reacted onto the message, oldest first — the last
    # entry is the "most recent" one the outbound bridge mirrors to Telegram.
    def self.current_reaction_emojis(message_id)
      message = find_message(message_id)
      return [] if message.nil? || !message.respond_to?(:reactions)
      message.reactions.order(:created_at).map(&:emoji)
    rescue StandardError => e
      Rails.logger.warn("#{DiscourseDisteleplus::LOG_TAG} reactions read failed: #{e.message}")
      []
    end

    def self.message_uploads(message)
      message.respond_to?(:uploads) ? message.uploads.to_a : []
    end

    # Makes sure the posting user is following the channel — CreateMessage
    # policies can reject non-members. Best-effort, API surface permitting.
    def self.ensure_membership(channel_id:, user:)
      return unless available? && defined?(::Chat::ChannelMembershipManager)
      channel = ::Chat::Channel.find_by(id: channel_id)
      return if channel.nil?
      ::Chat::ChannelMembershipManager.new(channel).follow(user)
    rescue StandardError => e
      Rails.logger.warn("#{DiscourseDisteleplus::LOG_TAG} membership failed: #{e.message}")
      nil
    end

    # ── service-call plumbing ────────────────────────────────────────────────

    # Tries the modern `.call(params:, guardian:)` envelope first, then the
    # legacy flat-kwargs signature.
    def self.call_service(service, params, user)
      guardian = user.guardian
      begin
        service.call(params: params, guardian: guardian)
      rescue ArgumentError
        service.call(guardian: guardian, **params)
      end
    end

    def self.result_success?(result)
      return result.success? if result.respond_to?(:success?)
      true
    end

    def self.failure_reason(result)
      %i[inspect_steps error message].each do |accessor|
        value = result.try(accessor)
        return value.to_s if value.present? && !value.is_a?(Proc)
      end
      "chat service failed"
    end
  end
end
