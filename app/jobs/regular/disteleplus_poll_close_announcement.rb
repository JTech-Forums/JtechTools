# frozen_string_literal: true

module Jobs
  # Runs shortly after a conversation poll's close time: makes sure the poll
  # really closed (core's own close job owns that; this is a belt-and-braces
  # race guard), then posts a results summary into the conversation, which
  # bridges to Telegram like any other message.
  class DisteleplusPollCloseAnnouncement < ::Jobs::Base
    def execute(args)
      return unless DiscourseDisteleplus::Polls.enabled?

      message = DiscourseDisteleplus::Message.find_by(id: args[:message_id])
      return if message.nil? || message.deleted? || message.poll_post_id.blank?

      post = ::Post.find_by(id: message.poll_post_id)
      poll = post && ::Poll.find_by(post: post)
      return unless poll

      if poll.open? && poll.close_at&.past?
        begin
          ::DiscoursePoll::Poll.toggle_status(
            Discourse.system_user,
            post.id,
            poll.name,
            "closed",
            false,
          )
        rescue StandardError
          # Core's close job may win the race — announcing is what matters.
        end
        poll.reload
      end
      return if poll.open?

      raw = DiscourseDisteleplus::Polls.results_markdown(message)
      return if raw.blank?

      DiscourseDisteleplus::MessageService.new(actor: Discourse.system_user).create!(
        raw: raw,
        reply_to_id: message.id,
        notify: false,
      )
    rescue StandardError => e
      Rails.logger.warn(
        "#{DiscourseDisteleplus::LOG_TAG} poll close announcement failed: #{e.message}",
      )
    end
  end
end
