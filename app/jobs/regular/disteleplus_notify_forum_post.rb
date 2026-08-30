# frozen_string_literal: true

module Jobs
  # Delivers one forum post summary to Telegram and mirrors it into the native
  # conversation as the bridge bot. Idempotent per post via the link table.
  class DisteleplusNotifyForumPost < ::Jobs::Base
    def execute(args)
      post = Post.find_by(id: args[:post_id])
      return unless DiscourseDisteleplus::ForumPostNotifier.eligible?(post)

      chat_id = SiteSetting.disteleplus_telegram_chat_id.to_s.strip
      return if chat_id.blank?

      bot = DiscourseDisteleplus.bot_user
      return if bot.nil?

      marker = "forum-post:#{post.id}"
      return if DiscourseDisteleplus::Message.where(external_sender_name: marker).exists?

      api = DiscourseDisteleplus::TelegramApi.new
      payload = {
        chat_id: chat_id,
        text: DiscourseDisteleplus::ForumPostNotifier.telegram_html(post),
        parse_mode: "HTML",
        disable_web_page_preview: !SiteSetting.disteleplus_forum_post_link_preview,
      }
      thread_id = DiscourseDisteleplus.telegram_thread_id(SiteSetting.disteleplus_chat_topic_id)
      payload[:message_thread_id] = thread_id if thread_id
      result = api.call("sendMessage", payload)
      unless result.ok
        DiscourseDisteleplus::Health.record_error(result.description, context: "forum post #{post.id}")
        Rails.logger.warn("#{DiscourseDisteleplus::LOG_TAG} forum post notify failed: #{result.description}")
        return
      end

      message =
        DiscourseDisteleplus::MessageService
          .new(actor: bot, bypass_access: true)
          .create!(
            raw: DiscourseDisteleplus::ForumPostNotifier.native_markdown(post),
            source: :discourse,
            external_sender_name: marker,
            bridge: false,
            notify: false,
          )
      DiscourseDisteleplus::MessageLink.create!(
        telegram_chat_id: chat_id,
        telegram_message_id: result.result["message_id"],
        disteleplus_message_id: message.id,
        direction: :discourse_to_tg,
        kind: :text,
      )
    rescue DiscourseDisteleplus::TelegramApi::RateLimited => e
      Jobs.enqueue_in(e.retry_after.seconds, :disteleplus_notify_forum_post, post_id: args[:post_id])
    end
  end
end
