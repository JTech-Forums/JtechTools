# frozen_string_literal: true

module DiscourseDisteleplus
  # Moderation reports → Telegram. Every new Reviewable (flagged post, queued
  # post awaiting approval, user needing review) is announced in a dedicated
  # Telegram topic with Approve / Deny / More buttons under the message. A
  # button press performs the matching reviewable action as the mapped
  # Discourse staff member; when a reviewable is resolved — from Telegram or
  # from the Discourse review queue — the Telegram message is edited to show
  # who resolved it and how, and the action buttons disappear.
  #
  # Authorization model for button presses (this drives real moderation):
  #   1. the callback must originate in the configured reports chat, and
  #   2. the presser must be Discourse staff, proven either by an explicit
  #      disteleplus_user_map row matched on permanent numeric telegram_id, or
  #      by being an administrator of the reports chat AND resolving to a
  #      staff account by username (see Reports.acting_staff).
  # Everyone else gets a "not authorized" alert that names their Telegram id
  # so an admin can map them, and nothing happens.
  #
  # Reports always live in their own forum topic (auto-created, see
  # ensure_topic!) — never in the group's General.
  module Reports
    CALLBACK_PREFIX = "dtp"
    INTENTS = %w[approve deny more].freeze

    # Preferred action ids per intent, most specific first. At perform time
    # the first id available on the reviewable (per actions_for) is used, so
    # the same two buttons work across reviewable types.
    APPROVE_ACTIONS = %i[
      approve_post
      agree_and_hide
      agree_and_keep_hidden
      agree_and_keep
      approve_user
      approve
    ].freeze
    DENY_ACTIONS = %i[reject_post disagree_and_restore disagree delete_user reject ignore].freeze

    def self.enabled?
      DiscourseDisteleplus.enabled? && SiteSetting.disteleplus_reports_enabled &&
        SiteSetting.disteleplus_bot_token.present?
    end

    def self.admin_notices?
      enabled? && SiteSetting.disteleplus_reports_admin_notices
    end

    def self.chat_id
      SiteSetting.disteleplus_reports_chat_id.to_s.strip.presence ||
        SiteSetting.disteleplus_telegram_chat_id.to_s.strip
    end

    def self.thread_id
      DiscourseDisteleplus.telegram_thread_id(SiteSetting.disteleplus_reports_topic_id)
    end

    # Reports live in their own Telegram forum topic, never in General. When
    # no (valid) topic id is stored, create one named
    # disteleplus_reports_topic_name in the reports chat and remember it —
    # so a fresh deploy migrates itself without anyone binding anything.
    # Returns the message_thread_id, or nil when Telegram refused (chat is
    # not a forum, bot lacks manage-topics) — callers then DROP the message.
    def self.ensure_topic!(api: TelegramApi.new)
      return nil if chat_id.blank?
      return thread_id if thread_id

      DistributedMutex.synchronize("disteleplus-reports-topic", validity: 30) do
        # Another process may have created it while we waited for the lock.
        return thread_id if thread_id

        name = SiteSetting.disteleplus_reports_topic_name.to_s.squish.presence || "Reports"
        result = api.call("createForumTopic", chat_id: chat_id, name: name.first(128))
        created = result.result&.dig("message_thread_id").to_i
        if result.ok && created > 1
          SiteSetting.set_and_log(:disteleplus_reports_topic_id, created, Discourse.system_user)
          Rails.logger.info("#{LOG_TAG} created reports topic #{created} in chat #{chat_id}")
          created
        else
          Health.record_error(
            result.description.presence || "createForumTopic returned no thread id",
            context: "create reports topic",
          )
          Rails.logger.warn("#{LOG_TAG} could not create the reports topic: #{result.description}")
          nil
        end
      end
    end

    def self.reports_chat?(candidate)
      configured = chat_id
      configured.present? && candidate.to_s == configured
    end

    # True when the reports topic lives inside the bridged conversation group,
    # so the chat bridge can exclude it (moderation traffic must never leak
    # into the member-facing conversation).
    def self.reports_thread_in_bridge_chat?(actual_topic_id)
      return false unless SiteSetting.disteleplus_reports_enabled
      return false if chat_id != SiteSetting.disteleplus_telegram_chat_id.to_s.strip
      topic = SiteSetting.disteleplus_reports_topic_id.to_i
      topic.positive? && actual_topic_id.to_i == topic
    end

    # ── outbound: announce a reviewable ─────────────────────────────────────

    def self.notify_reviewable(reviewable)
      return if reviewable.nil? || chat_id.blank?
      return if ReportLink.for_reviewable(reviewable.id).exists?

      # A reviewable can already be resolved by the time the (delayed) job
      # runs — e.g. an admin flagging with "Take Action" agrees immediately.
      # Announce it anyway, pre-resolved and without action buttons, so the
      # reports topic stays a complete log (and admin self-tests show up).
      pending = reviewable.pending?
      text = reviewable_html(reviewable)
      text = "#{text}\n\n✅ <b>#{escape(resolution_line(reviewable))}</b>" unless pending

      payload = {
        chat_id: chat_id,
        text: text,
        parse_mode: "HTML",
        link_preview_options: {
          is_disabled: true,
        },
        reply_markup: {
          inline_keyboard:
            pending ? action_keyboard(reviewable) : [[review_url_button(reviewable)]],
        },
      }
      result = send_report_message(payload, context: "report #{reviewable.id}")
      return unless result.ok

      ReportLink.create!(
        reviewable_id: reviewable.id,
        telegram_chat_id: chat_id,
        telegram_message_id: result.result["message_id"],
        status: pending ? :open : :resolved,
      )
    end

    # sendMessage into the reports topic, creating the topic first when
    # needed and recreating it when Telegram says the stored one is gone.
    # Never falls back to General: with no topic available the message is
    # dropped and the failure recorded for the admin dashboard.
    def self.send_report_message(payload, context:)
      api = TelegramApi.new
      topic = ensure_topic!(api: api)
      if topic.nil?
        # No topic and none could be created: drop rather than leak into
        # General. The dashboard problem check shows why.
        Rails.logger.warn("#{LOG_TAG} #{context} dropped: no reports topic available")
        return TelegramApi::Result.new(ok: false, description: "no reports topic")
      end
      payload = payload.merge(message_thread_id: topic)

      result = api.call("sendMessage", payload)
      return result if result.ok

      # The stored topic was deleted in Telegram: forget it, create a fresh
      # one and retry once.
      if result.description.to_s.match?(/thread not found|topic/i)
        Rails.logger.warn(
          "#{LOG_TAG} reports topic #{topic} is gone (#{result.description}); recreating",
        )
        SiteSetting.set_and_log(:disteleplus_reports_topic_id, 0, Discourse.system_user)
        fresh = ensure_topic!(api: api)
        result = api.call("sendMessage", payload.merge(message_thread_id: fresh)) if fresh
        return result if result.ok
      end

      Health.record_error(result.description, context: context)
      Rails.logger.warn("#{LOG_TAG} #{context} send failed: #{result.description}")
      result
    end

    # ── outbound: reflect resolution back onto the Telegram message ─────────

    def self.mark_resolved(reviewable, status:)
      link = ReportLink.for_reviewable(reviewable.id).first
      return if link.nil? || link.status_resolved?

      line = resolution_line(reviewable, status: status)
      text = "#{reviewable_html(reviewable)}\n\n✅ <b>#{Formatter.escape_html(line)}</b>"
      TelegramApi.new.call(
        "editMessageText",
        chat_id: link.telegram_chat_id,
        message_id: link.telegram_message_id,
        text: text,
        parse_mode: "HTML",
        link_preview_options: {
          is_disabled: true,
        },
        reply_markup: {
          inline_keyboard: [[review_url_button(reviewable)]],
        },
      )
      link.update!(status: :resolved)
    end

    # ── outbound: plain admin notices (problems, what's new, warnings) ──────

    # Deduped by key so the per-admin notification fan-out (one Notification
    # row per admin) produces exactly one Telegram message.
    def self.notify_admin_notice(html, dedupe_key:, dedupe_seconds: 2.days.to_i)
      return unless admin_notices?
      return if chat_id.blank?
      redis_key = "disteleplus:admin-notice:#{Digest::SHA1.hexdigest(dedupe_key.to_s)}"
      return unless Discourse.redis.set(redis_key, "1", ex: dedupe_seconds, nx: true)

      Jobs.enqueue(:disteleplus_send_report_notice, html: html)
    end

    def self.deliver_notice(html)
      return if html.blank? || chat_id.blank?
      payload = {
        chat_id: chat_id,
        text: html,
        parse_mode: "HTML",
        link_preview_options: {
          is_disabled: true,
        },
      }
      send_report_message(payload, context: "admin notice")
    end

    # Called from the notification_created hook. Bridges the two admin-facing
    # notification types every admin receives (so the reports topic carries
    # the same signals as the bell): new-features announcements and dashboard
    # problem alerts.
    def self.maybe_bridge_admin_notification(notification)
      return unless admin_notices?
      types = ::Notification.types
      base = Discourse.base_url

      case notification.notification_type
      when types[:new_features]
        notify_admin_notice(
          "🆕 <b>#{escape(I18n.t("disteleplus.reports.new_features"))}</b>\n" \
            "<a href=\"#{base}/admin/whats-new\">#{escape(I18n.t("disteleplus.reports.new_features_link"))}</a>",
          dedupe_key: "new_features:#{notification.data.to_s.first(200)}",
        )
      when types[:admin_problems]
        notify_admin_notice(
          "⚠️ <b>#{escape(I18n.t("disteleplus.reports.admin_problems"))}</b>\n" \
            "<a href=\"#{base}/admin\">#{escape(I18n.t("disteleplus.reports.admin_problems_link"))}</a>",
          dedupe_key: "admin_problems:#{Time.zone.now.to_date}",
          dedupe_seconds: 12.hours.to_i,
        )
      end
    rescue StandardError => e
      Rails.logger.warn("#{LOG_TAG} admin notification bridge failed: #{e.message}")
    end

    # Official warnings: meta-only (who warned whom) — the warning PM's text
    # stays private.
    def self.maybe_bridge_official_warning(topic)
      return unless admin_notices?
      return unless topic&.subtype == TopicSubtype.moderator_warning

      target =
        topic.topic_allowed_users.joins(:user).where.not(users: { id: topic.user_id }).first&.user
      notify_admin_notice(
        "⚠️ <b>#{escape(I18n.t("disteleplus.reports.official_warning"))}</b>\n" \
          "#{escape(topic.user&.username.to_s)} → #{escape(target&.username.to_s)}",
        dedupe_key: "warning:#{topic.id}",
      )
    rescue StandardError => e
      Rails.logger.warn("#{LOG_TAG} warning bridge failed: #{e.message}")
    end

    # ── inbound: button presses ──────────────────────────────────────────────

    def self.handle_callback(callback)
      api = TelegramApi.new
      answer = ->(text, alert: false) do
        api.call(
          "answerCallbackQuery",
          callback_query_id: callback["id"],
          text: text,
          show_alert: alert,
        )
      end

      data = callback["data"].to_s
      prefix, intent, reviewable_id = data.split(":", 3)
      return if prefix != CALLBACK_PREFIX
      # Always answer — an unanswered callback leaves the button spinning on
      # the presser's screen until Telegram times it out.
      return answer.call(I18n.t("disteleplus.reports.disabled")) unless enabled?
      return answer.call(I18n.t("disteleplus.reports.unknown_action")) if INTENTS.exclude?(intent)

      message = callback["message"] || {}
      unless reports_chat?(message.dig("chat", "id"))
        Rails.logger.warn(
          "#{LOG_TAG} report callback from foreign chat #{message.dig("chat", "id").inspect} ignored",
        )
        return answer.call(I18n.t("disteleplus.reports.not_authorized"), alert: true)
      end

      actor = acting_staff(callback["from"], message.dig("chat", "id"), api: api)
      unless actor&.staff?
        Rails.logger.warn(
          "#{LOG_TAG} unauthorized report action by tg user " \
            "#{callback.dig("from", "id")} (@#{callback.dig("from", "username")})",
        )
        return(
          answer.call(
            I18n.t(
              "disteleplus.reports.not_authorized",
              telegram_id: callback.dig("from", "id").to_s,
              username: callback.dig("from", "username").to_s.presence || "-",
            ),
            alert: true,
          )
        )
      end

      begin
        RateLimiter.new(actor, "disteleplus-report-action", 30, 1.minute).performed!
      rescue RateLimiter::LimitExceeded
        return answer.call(I18n.t("disteleplus.reports.rate_limited"), alert: true)
      end

      reviewable = Reviewable.find_by(id: reviewable_id.to_i)
      return answer.call(I18n.t("disteleplus.reports.gone")) if reviewable.nil?

      case intent
      when "more"
        send_details(reviewable, reply_to: message["message_id"])
        answer.call(I18n.t("disteleplus.reports.details_sent"))
      else
        unless reviewable.pending?
          mark_resolved(reviewable, status: reviewable.status)
          return answer.call(I18n.t("disteleplus.reports.already_resolved"))
        end
        action_id = action_for(reviewable, actor, intent)
        return answer.call(I18n.t("disteleplus.reports.no_action"), alert: true) if action_id.nil?
        result = reviewable.perform(actor, action_id)
        if result.success?
          # The transition hook edits the message; the toast confirms fast.
          answer.call(
            I18n.t("disteleplus.reports.action_done", action: action_id.to_s.humanize.downcase),
          )
        else
          answer.call(I18n.t("disteleplus.reports.action_failed"), alert: true)
        end
      end
    rescue Reviewable::InvalidAction, Discourse::InvalidAccess
      answer.call(I18n.t("disteleplus.reports.no_action"), alert: true)
    rescue TelegramApi::RateLimited
      raise
    rescue StandardError => e
      Rails.logger.warn("#{LOG_TAG} report callback failed: #{e.class}: #{e.message}")
      answer.call(I18n.t("disteleplus.reports.action_failed"), alert: true)
    end

    # Who is pressing the button, as a Discourse staff user — or nil.
    # Two independent ways in:
    #   1. an explicit disteleplus_user_map row matched by permanent numeric
    #      telegram_id (the recommended setup), or
    #   2. the presser is an administrator/creator of the reports chat AND
    #      resolves to a Discourse staff account by username (map row or the
    #      same username). Renaming a Telegram account alone cannot pass this:
    #      the attacker would also have to be made admin of the staff group.
    def self.acting_staff(from, chat, api:)
      by_id = UserMatcher.privileged_match(from)
      return by_id if by_id&.staff?

      by_name = UserMatcher.staff_by_username(from)
      return nil unless by_name&.staff?

      member = api.call("getChatMember", chat_id: chat, user_id: from["id"])
      status = member.result&.dig("status") if member.ok
      %w[creator administrator].include?(status) ? by_name : nil
    rescue StandardError => e
      Rails.logger.warn("#{LOG_TAG} acting_staff lookup failed: #{e.message}")
      nil
    end

    # First preferred action id actually available to this user on this
    # reviewable.
    def self.action_for(reviewable, actor, intent)
      candidates = intent == "approve" ? APPROVE_ACTIONS : DENY_ACTIONS
      actions = reviewable.actions_for(Guardian.new(actor))
      candidates.find { |id| actions.has?(id) }
    rescue StandardError => e
      Rails.logger.warn("#{LOG_TAG} actions_for failed: #{e.message}")
      nil
    end

    def self.send_details(reviewable, reply_to: nil)
      payload = {
        chat_id: chat_id,
        text: details_html(reviewable),
        parse_mode: "HTML",
        link_preview_options: {
          is_disabled: true,
        },
        reply_markup: {
          inline_keyboard: [[review_url_button(reviewable)]],
        },
      }
      payload[:reply_to_message_id] = reply_to if reply_to
      send_report_message(payload, context: "report details #{reviewable.id}")
    end

    # ── formatting ───────────────────────────────────────────────────────────

    def self.reviewable_html(reviewable)
      lines = ["🚩 <b>#{escape(type_label(reviewable))}</b>"]

      if (title = topic_title(reviewable)).present?
        url = topic_url(reviewable)
        lines << (url ? "<a href=\"#{escape(url)}\">#{escape(title)}</a>" : escape(title))
      end

      if (target = reviewable.target_created_by || target_user(reviewable))
        lines << "#{escape(I18n.t("disteleplus.reports.about"))}: @#{escape(target.username)}"
      end
      if reviewable.created_by && reviewable.created_by.id > 0
        lines << "#{escape(I18n.t("disteleplus.reports.reported_by"))}: @#{escape(reviewable.created_by.username)}"
      end
      if (reasons = score_reasons(reviewable)).present?
        lines << "#{escape(I18n.t("disteleplus.reports.reason"))}: #{escape(reasons)}"
      end

      excerpt = excerpt_for(reviewable)
      lines << "<blockquote>#{escape(excerpt)}</blockquote>" if excerpt.present?
      lines.join("\n")
    end

    def self.details_html(reviewable)
      long_excerpt = excerpt_for(reviewable, length: 1500)
      lines = ["🔎 <b>#{escape(type_label(reviewable))} ##{reviewable.id}</b>"]
      lines << "#{escape(I18n.t("disteleplus.reports.status"))}: #{escape(reviewable.status.to_s)}"
      reviewable.reviewable_scores.each do |score|
        parts = ["@#{escape(score.user&.username.to_s)}", escape(score_type_label(score))]
        parts << escape(score.reason.to_s.first(200)) if score.reason.present?
        lines << "• #{parts.compact_blank.join(" — ")}"
      end
      lines << "<blockquote>#{escape(long_excerpt)}</blockquote>" if long_excerpt.present?
      lines.join("\n")
    end

    def self.action_keyboard(reviewable)
      [
        [
          {
            text: "✅ #{I18n.t("disteleplus.reports.approve")}",
            callback_data: "#{CALLBACK_PREFIX}:approve:#{reviewable.id}",
          },
          {
            text: "❌ #{I18n.t("disteleplus.reports.deny")}",
            callback_data: "#{CALLBACK_PREFIX}:deny:#{reviewable.id}",
          },
          {
            text: "⋯ #{I18n.t("disteleplus.reports.more")}",
            callback_data: "#{CALLBACK_PREFIX}:more:#{reviewable.id}",
          },
        ],
      ]
    end

    def self.review_url_button(reviewable)
      {
        text: I18n.t("disteleplus.reports.open_in_discourse"),
        url: "#{Discourse.base_url}/review/#{reviewable.id}",
      }
    end

    def self.type_label(reviewable)
      key = reviewable.type.to_s.sub("Reviewable", "").underscore
      I18n.t("disteleplus.reports.types.#{key}", default: key.humanize)
    end

    def self.topic_title(reviewable)
      reviewable.topic&.title.presence || payload_value(reviewable, "title")
    end

    def self.topic_url(reviewable)
      topic = reviewable.topic
      return nil if topic.nil?
      post_number = reviewable.try(:post)&.post_number
      url = "#{Discourse.base_url}/t/#{topic.slug}/#{topic.id}"
      post_number ? "#{url}/#{post_number}" : url
    end

    def self.target_user(reviewable)
      reviewable.target.is_a?(::User) ? reviewable.target : nil
    end

    def self.excerpt_for(reviewable, length: nil)
      length ||= SiteSetting.disteleplus_reports_excerpt_length
      return "" if length.to_i <= 0
      raw =
        if reviewable.target.is_a?(::Post)
          reviewable.target.raw
        elsif reviewable.target.is_a?(::User)
          nil
        else
          payload_value(reviewable, "raw")
        end
      raw.to_s.squish.truncate(length.to_i)
    end

    def self.payload_value(reviewable, key)
      payload = reviewable.payload
      payload.is_a?(Hash) ? payload[key].to_s.presence : nil
    end

    def self.score_reasons(reviewable)
      reviewable.reviewable_scores.filter_map { |score| score_type_label(score) }.uniq.join(", ")
    rescue StandardError
      nil
    end

    def self.score_type_label(score)
      type = ReviewableScore.types.key(score.reviewable_score_type)
      type ? type.to_s.humanize : nil
    rescue StandardError
      nil
    end

    def self.resolution_line(reviewable, status: nil)
      status_label = (status.presence || reviewable.status).to_s.humanize.downcase
      resolver = last_resolver(reviewable)
      if resolver
        I18n.t("disteleplus.reports.resolved_by", status: status_label, username: resolver.username)
      else
        I18n.t("disteleplus.reports.resolved", status: status_label)
      end
    end

    # Latest transition's author, straight from the reviewable history.
    def self.last_resolver(reviewable)
      reviewable
        .reviewable_histories
        .where(reviewable_history_type: ReviewableHistory.types[:transitioned])
        .order(created_at: :desc)
        .first
        &.created_by
    rescue StandardError
      nil
    end

    def self.escape(value)
      Formatter.escape_html(value.to_s)
    end
  end
end
