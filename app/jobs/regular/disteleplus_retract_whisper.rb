# frozen_string_literal: true

module Jobs
  # A post that became a whisper after the bridge had already mirrored it:
  # take back the forum-post announcement (native message + its Telegram
  # copy) and every attachment copied to the uploads topic. Best effort —
  # Telegram only lets bots delete their messages for a limited time, so
  # failures are logged, never raised.
  class DisteleplusRetractWhisper < ::Jobs::Base
    def execute(args)
      post = ::Post.with_deleted.find_by(id: args[:post_id])
      return unless post && DiscourseModCategories::Whisper.whisper?(post)

      bot = DiscourseDisteleplus.bot_user
      if bot
        DiscourseDisteleplus::Message
          .not_deleted
          .where(external_sender_name: "forum-post:#{post.id}")
          .find_each do |message|
            DiscourseDisteleplus::MessageService.new(actor: bot, bypass_access: true).delete!(
              message,
            )
          end
      end

      links = DiscourseDisteleplus::ForumUploadLink.where(post_id: post.id).to_a
      return if links.empty?

      api = DiscourseDisteleplus::TelegramApi.new
      links.each do |link|
        begin
          api.call(
            "deleteMessage",
            chat_id: link.telegram_chat_id,
            message_id: link.telegram_message_id,
          )
        rescue StandardError => e
          Rails.logger.warn(
            "#{DiscourseDisteleplus::LOG_TAG} whisper upload retract failed: #{e.class}: #{e.message}",
          )
        end
        link.destroy
      end
    end
  end
end
