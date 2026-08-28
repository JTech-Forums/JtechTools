# frozen_string_literal: true
# Jtech sub-plugin: Disteleplus — Telegram ⇄ Discourse Chat bridge.
#
# Bridges exactly ONE Telegram group with exactly ONE Discourse Chat channel,
# two-way. Use case: the admin team chats in a Telegram group; an admin
# without Telegram participates through a TL4-restricted chat channel and
# both sides see a single conversation.
#
# Inbound (Telegram → Discourse): Telegram pushes updates to a secret-guarded
# webhook (see routes.rb / WebhookController); a Sidekiq job feeds them to
# UpdateProcessor, which posts into the channel — AS the matching Discourse
# user when the Telegram username maps to one (manual mapping setting wins
# over the automatic same-username match), otherwise as the bridge-bot user
# with a "**Name (TG):**" prefix. Media within the size cap is re-uploaded;
# replies, edits, polls (rendered as markdown) and reactions are mirrored.
#
# Outbound (Discourse → Telegram): the chat plugin's DiscourseEvents enqueue
# a send job; the bot posts with a "<b>username:</b>" prefix (bots cannot
# impersonate), edits/deletes its linked messages, and mirrors at most ONE
# reaction per message (a Bot API hard limit).
#
# Echo suppression is two-layered: a thread-local flag while the bridge
# itself writes to chat (DiscourseEvent.trigger is synchronous, so our own
# writes' events are skipped on the spot), plus the persistent
# disteleplus_message_links table.
#
# Known-impossible by Bot API design, documented rather than faked: Telegram
# never reports message deletions to bots, so TG-side deletions leave the
# Discourse copy in place.
#
# The optional "chat lock" mode points the chat button straight at the
# bridge channel and blocks creating channels/DMs — UI hidden client-side,
# enforced by a Guardian prepend server-side.
#
# All chat-plugin API touchpoints live in ChatAdapter so the whole module
# no-ops gracefully when the chat plugin is absent (translator_tweaks
# precedent).

register_asset "stylesheets/disteleplus.scss"

module ::DiscourseDisteleplus
  LOG_TAG = "[jtech-tools disteleplus]"

  def self.chat_available?
    ChatAdapter.available?
  end

  # The user that posts unmatched Telegram messages and owns nothing else.
  # Looked up per call (multisite-safe, and cheap); lazily created on first
  # use. Point the setting at an existing username to reuse a user instead.
  def self.bot_user
    username = SiteSetting.disteleplus_bridge_bot_username.to_s.strip
    return nil if username.blank?
    User.find_by_username(username) || create_bot_user!(username)
  end

  def self.create_bot_user!(username)
    user =
      User.create!(
        username: username,
        name: "Telegram Bridge",
        email: "no-reply.disteleplus@#{Discourse.current_hostname}",
        password: SecureRandom.hex(32),
        active: true,
        approved: true,
        # The bridge channel is TL4-restricted on this forum; TL4 lets the
        # bot post there without also granting staff powers.
        trust_level: TrustLevel[4],
      )
    user.activate
    user
  rescue StandardError => e
    Rails.logger.warn("#{LOG_TAG} bot user create failed: #{e.class}: #{e.message}")
    nil
  end

  # Shared handler for :chat_message_created/_edited/_trashed. Splat args —
  # the chat plugin's event arity is not vendored here, but the message is
  # always the first argument.
  def self.handle_chat_event(event, args)
    return unless SiteSetting.disteleplus_enabled
    return unless chat_available?
    return if ChatAdapter.bridging?

    message = args[0]
    return if message.nil? || !message.respond_to?(:id)

    channel_id = message.try(:chat_channel_id) || args[1].try(:id)
    return unless channel_id == SiteSetting.disteleplus_chat_channel_id

    bot = bot_user
    return if bot && message.user_id == bot.id

    links = MessageLink.for_chat_message(message.id)
    if event == :chat_message_created
      # Already linked → it came FROM Telegram; never echo it back.
      return if links.exists?
    else
      # Edits/trashes of Telegram-originated messages cannot be pushed back —
      # those are the humans' own Telegram messages, untouchable by the bot.
      return if links.tg_to_discourse.exists?
      return if links.empty?
    end

    action =
      {
        chat_message_created: "create",
        chat_message_edited: "edit",
        chat_message_trashed: "delete",
      }[
        event
      ]
    return if action.nil?
    return if action == "edit" && !SiteSetting.disteleplus_bridge_edits
    return if action == "delete" && !SiteSetting.disteleplus_bridge_deletes

    Jobs.enqueue(:disteleplus_send_to_telegram, action: action, chat_message_id: message.id)
  rescue StandardError => e
    Rails.logger.warn("#{LOG_TAG} chat event #{event} failed: #{e.class}: #{e.message}")
  end

  # Handler for a chat reaction event, whatever its exact payload shape —
  # the chat message is found among the args, the reacting user (if present)
  # is used only to skip the bot's own reactions.
  def self.handle_reaction_event(args)
    return unless SiteSetting.disteleplus_enabled && SiteSetting.disteleplus_bridge_reactions
    return unless chat_available?
    return if ChatAdapter.bridging?

    message =
      args.find { |a| a.respond_to?(:chat_channel_id) } ||
        args.filter_map { |a| a.try(:chat_message) || a.try(:message) }.first
    return if message.nil?
    return unless message.try(:chat_channel_id) == SiteSetting.disteleplus_chat_channel_id

    actor = args.find { |a| a.is_a?(::User) }
    bot = bot_user
    return if actor && bot && actor.id == bot.id

    return unless MessageLink.for_chat_message(message.id).exists?

    Jobs.enqueue(:disteleplus_send_to_telegram, action: "react", chat_message_id: message.id)
  rescue StandardError => e
    Rails.logger.warn("#{LOG_TAG} reaction event failed: #{e.class}: #{e.message}")
  end

  def self.lock_active_for?(user)
    return false unless SiteSetting.disteleplus_enabled && SiteSetting.disteleplus_lock_chat_ui
    return false if SiteSetting.disteleplus_lock_chat_exempt_admins && user&.admin?
    true
  end
end

require_relative "../lib/discourse_disteleplus/emoji_map"
require_relative "../lib/discourse_disteleplus/formatter"
require_relative "../lib/discourse_disteleplus/telegram_api"
require_relative "../lib/discourse_disteleplus/user_matcher"
require_relative "../lib/discourse_disteleplus/chat_adapter"
require_relative "../lib/discourse_disteleplus/update_processor"

after_initialize do
  # ── "Register webhook" settings button ────────────────────────────────────
  # Flipping disteleplus_register_webhook_now on auto-generates the webhook
  # secret (if blank), enqueues the setWebhook call, and resets itself —
  # same pattern as dislike's purge_phantom_likes_now.
  on(:site_setting_changed) do |name, _old_val, new_val|
    if name.to_s == "disteleplus_register_webhook_now" && new_val == true
      if SiteSetting.disteleplus_webhook_secret.blank?
        SiteSetting.disteleplus_webhook_secret = SecureRandom.hex(32)
      end
      Jobs.enqueue(:disteleplus_register_webhook)
      SiteSetting.disteleplus_register_webhook_now = false
    end
  end

  # ── Discourse → Telegram event hooks ──────────────────────────────────────
  %i[chat_message_created chat_message_edited chat_message_trashed].each do |event|
    on(event) { |*args| DiscourseDisteleplus.handle_chat_event(event, args) }
  end

  # Chat fires NO DiscourseEvent for reactions (verified against core:
  # plugins/chat triggers only created/edited/trashed/restored/processed),
  # so Discourse → Telegram reaction bridging observes MessageReactor#react!
  # directly. Fires only after a successful reaction; TG-originated reactions
  # applied through this same reactor are skipped by the bridging? guard in
  # handle_reaction_event. The listener below stays as a freebie in case a
  # future chat version adds the event — double delivery is harmless because
  # the "react" job just re-asserts the current reaction state.
  on(:chat_message_reacted) { |*args| DiscourseDisteleplus.handle_reaction_event(args) }

  reloadable_patch do
    if defined?(::Chat::MessageReactor) && ::Chat::MessageReactor.method_defined?(:react!)
      ::Chat::MessageReactor.prepend(
        Module.new do
          def react!(message_id:, react_action:, emoji:)
            result = super
            begin
              message = ::Chat::Message.find_by(id: message_id)
              user = instance_variable_get(:@user)
              ::DiscourseDisteleplus.handle_reaction_event([message, user].compact) if message
            rescue StandardError => e
              Rails.logger.warn(
                "#{::DiscourseDisteleplus::LOG_TAG} reaction observe failed: #{e.message}",
              )
            end
            result
          end
        end,
      )
    end
  end

  # ── Chat lock: server-side enforcement ────────────────────────────────────
  # The client initializer hides the UI; this makes the restriction real.
  # Only methods the installed chat version actually defines are patched, so
  # an upstream rename degrades to "not enforced for that action" instead of
  # a boot error.
  reloadable_patch do
    lock_methods =
      %i[can_create_direct_message? can_create_chat_channel? can_create_channel?].select do |m|
        ::Guardian.method_defined?(m)
      end

    if defined?(::Chat) && lock_methods.any?
      ::Guardian.prepend(
        Module.new do
          lock_methods.each do |m|
            define_method(m) do |*args, **kwargs|
              return false if ::DiscourseDisteleplus.lock_active_for?(@user)
              super(*args, **kwargs)
            end
          end
        end,
      )
    end
  end
end
