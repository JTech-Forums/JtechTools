# frozen_string_literal: true
# Jtech sub-plugin: apply alltechdev's tweaks on top of the upstream
# discourse/discourse-translator plugin.
#
# This file is instance_eval'd by Jtech/plugin.rb in the Plugin::Instance
# context, so DSL methods work just like in any other plugin.rb.

after_initialize do
  # If the translator plugin isn't installed, skip everything below.
  next unless defined?(::DiscourseTranslator)

  # ── 1. Google provider → private Cloudflare Worker proxy ────────────────
  # Upstream Google provider hits googleapis.com directly. Redirect all three
  # endpoints (translate / detect / languages) at a self-hosted worker. This
  # bypasses per-IP quota throttling and keeps the Google API key out of the
  # forum host's outbound traffic.
  if defined?(::DiscourseTranslator::Provider::Google)
    base = "https://google-translate-worker.abesternheim.workers.dev/language/translate/v2"
    overrides = {
      TRANSLATE_URI: base,
      DETECT_URI: "#{base}/detect",
      SUPPORT_URI: "#{base}/languages",
    }
    google = ::DiscourseTranslator::Provider::Google
    silence_warnings do
      overrides.each do |name, value|
        google.send(:remove_const, name) if google.const_defined?(name, false)
        google.const_set(name, value.freeze)
      end
    end
  end

  # ── 2. Hide the translate globe on posts with no detected_locale row ────
  # Upstream `can_translate?` only suppresses the globe inside a short post-
  # detection buffer window. For posts that predate the plugin install and
  # never had detection run, the buffer check always fails, the globe shows,
  # and clicking it produces a no-op API call. Returning false the moment
  # detected_locale is blank fixes both cases — brand-new posts simply get
  # the globe ~5s later when the detect job lands.
  #
  # Method-resolution note: we prepend onto Guardian. Upstream's prepend wins
  # the outermost position because the translator plugin loads after
  # JtechTools alphabetically — but upstream `can_translate?` only ever
  # returns false early or falls through to `super`. Our prepend sits in the
  # super-chain and blocks the "fall through to true" path for blank-locale
  # posts. Order works regardless of which plugin prepended first.
  reloadable_patch do
    ::Guardian.prepend(
      Module.new do
        def can_translate?(post)
          return false if post&.detected_locale.blank?
          super
        end
      end,
    )
  end
end
