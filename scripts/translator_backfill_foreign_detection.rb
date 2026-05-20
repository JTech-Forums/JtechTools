# frozen_string_literal: true

# Run via: docker exec app rails runner /var/www/discourse/plugins/JtechTools/scripts/translator_backfill_foreign_detection.rb
#
# Requires the upstream discourse/discourse-translator plugin to be installed
# alongside JtechTools — this script enqueues its DetectTranslatableLanguage
# job. The script lives here because the rest of alltechdev's tweaks to that
# plugin are applied at boot from sub_plugins/translator_tweaks.rb, so it
# made sense to bundle the one-shot script with them.
#
# Finds posts written in non-Latin script that have never had language detection
# run on them (no row in discourse_translator_post_locales), and enqueues the
# existing Jobs::DetectTranslatableLanguage for each, throttled to 1 per second.
# Idempotent — running it again skips posts that already have a locale row.

unless SiteSetting.translator_enabled
  warn "translator_enabled is OFF — aborting"
  exit 1
end

# Hebrew/Yiddish (U+0590-U+05FF), Arabic (U+0600-U+06FF), Cyrillic (U+0400-U+04FF),
# CJK (U+3000-U+9FFF). 20+ consecutive matches signal "this post is foreign-script".
FOREIGN_PATTERN = "[\u0590-\u05FF\u0600-\u06FF\u0400-\u04FF\u3000-\u9FFF]{20,}"

scope =
  Post
    .joins(:topic)
    .where("posts.deleted_at IS NULL")
    .where("topics.deleted_at IS NULL")
    .where(post_type: Post.types[:regular])
    .where("NOT EXISTS (SELECT 1 FROM discourse_translator_post_locales WHERE post_id = posts.id)")
    .where("posts.raw ~ ?", FOREIGN_PATTERN)

total = scope.count
puts "Found #{total} foreign-script posts with no detected_locale row."
exit 0 if total.zero?

count = 0
scope.find_each do |post|
  Jobs.enqueue(:detect_translatable_language, type: "Post", translatable_id: post.id)
  count += 1
  print "."
  sleep 1.0
end
puts ""
puts "Enqueued #{count} detection jobs. Watch /sidekiq for completion."
