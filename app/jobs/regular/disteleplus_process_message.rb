# frozen_string_literal: true

module Jobs
  # Link previews, the way Chat's ProcessMessage does it: fetch oneboxes for
  # the links in a message (populating the onebox cache), re-cook, and
  # publish the edit so open clients repaint.
  class DisteleplusProcessMessage < ::Jobs::Base
    MAX_LINKS = 5

    def execute(args)
      message = DiscourseDisteleplus::Message.find_by(id: args[:message_id])
      return if message.nil? || message.deleted? || message.raw.blank?

      urls = PrettyText.extract_links(message.cooked).map(&:url).uniq.first(MAX_LINKS)
      return if urls.empty?

      urls.each do |url|
        Oneboxer.onebox(url, invalidate_oneboxes: false, user_id: message.user_id)
      rescue StandardError => e
        Rails.logger.warn("#{DiscourseDisteleplus::LOG_TAG} onebox failed for #{url}: #{e.message}")
      end

      cooked =
        DiscourseDisteleplus::MessageService.cook_with_oneboxes(
          message.raw,
          user_id: message.user_id,
        )
      return if cooked == message.cooked

      message.update!(cooked: cooked)
      DiscourseDisteleplus::Publisher.publish(:edited, message, actor: message.user)
    end
  end
end
