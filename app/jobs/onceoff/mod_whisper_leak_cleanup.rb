# frozen_string_literal: true

module Jobs
  # One-off repair of whisper side effects written before the whisper
  # visibility hardening (every existing whisper, once, on deploy):
  #
  #   * search-index rows, and links extracted into the public topic map
  #   * pins that rendered a whisper's cooked HTML for everyone
  #   * link previews (oneboxes) of a whisper baked into OTHER posts — those
  #     posts are rebaked so the excerpt disappears
  #   * topic counters (posts_count, last poster / last posted at) and the
  #     parent posts' reply_count that counted whispers as public replies
  class ModWhisperLeakCleanup < ::Jobs::Onceoff
    def execute_onceoff(_args)
      field = DiscourseModCategories::POST_WHISPER_TARGETS_FIELD
      whisper_ids = ::PostCustomField.where(name: field).distinct.pluck(:post_id)
      return if whisper_ids.empty?

      whisper_ids.each_slice(500) do |ids|
        ::PostSearchData.where(post_id: ids).delete_all
        ::TopicLink.where(post_id: ids).delete_all
        ::TopicCustomField.where(
          name: DiscourseModCategories::TOPIC_PINNED_POST_FIELD,
          value: ids.map(&:to_s),
        ).delete_all

        parent_ids = ::PostReply.where(reply_post_id: ids).distinct.pluck(:post_id)
        DiscourseModCategories::Whisper.refresh_reply_counts(parent_ids)

        ::Post
          .where(id: ::TopicLink.where(link_post_id: ids).select(:post_id))
          .where.not(id: ids)
          .find_each { |p| p.rebake!(priority: :low) }
      end

      ::Post
        .where(id: whisper_ids)
        .distinct
        .pluck(:topic_id)
        .each { |topic_id| DiscourseModCategories::Whisper.refresh_topic_counters(topic_id) }
    end
  end
end
