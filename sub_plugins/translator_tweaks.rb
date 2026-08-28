# frozen_string_literal: true
# Jtech sub-plugin: apply alltechdev's tweaks on top of the upstream
# discourse/discourse-translator plugin.
#
# This file is instance_eval'd by Jtech/plugin.rb in the Plugin::Instance
# context, so DSL methods work just like in any other plugin.rb.
#
# Settings live in the `jtech_translator:` block of config/settings.yml:
#   translator_tweaks_enabled              module master switch
#   translator_tweaks_worker_url           Google proxy base ('' = call Google direct)
#   translator_tweaks_hide_untranslatable  the globe-hiding Guardian patch
#
# The two tweaks are unrelated and have independent toggles; only the master
# switch ties them together.

after_initialize do
  # If the translator plugin isn't installed, skip everything below. There is
  # nothing to patch, so every setting in the jtech_translator block is inert
  # on such a site — the descriptions say so.
  next unless defined?(::DiscourseTranslator)

  # ── 1. Google provider → private Cloudflare Worker proxy ────────────────
  # Upstream Google provider hits googleapis.com directly. Redirect all three
  # endpoints (translate / detect / languages) at a self-hosted worker. This
  # bypasses per-IP quota throttling and keeps the Google API key out of the
  # forum host's outbound traffic. Blank setting = leave upstream alone.
  #
  # BOOT-TIME ONLY, deliberately. The endpoints are Ruby constants on the
  # upstream provider class, so the swap can only happen once — here. Editing
  # translator_tweaks_worker_url, or flipping either enable switch, changes
  # nothing until the app is restarted; a live const rewrite would leave
  # sibling Unicorn/Sidekiq processes disagreeing about the endpoint. The
  # restart caveat is stated in the setting description and confirmed in a
  # dialog when the URL is edited.
  if SiteSetting.jtech_enabled && SiteSetting.translator_tweaks_enabled &&
       SiteSetting.translator_tweaks_worker_url.present? &&
       defined?(::DiscourseTranslator::Provider::Google)
    base = SiteSetting.translator_tweaks_worker_url.strip.sub(%r{/+\z}, "")
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
  # jtech-tools alphabetically — but upstream `can_translate?` only ever
  # returns false early or falls through to `super`. Our prepend sits in the
  # super-chain and blocks the "fall through to true" path for blank-locale
  # posts. Order works regardless of which plugin prepended first.
  #
  # Unlike tweak 1, the settings are read per call, so these toggles take
  # effect immediately — no restart. When any switch is off we fall straight
  # through to upstream's own can_translate? and behave like stock Discourse.
  # The module is always prepended (never conditionally), so toggling on and
  # off is symmetric and needs no reload.
  reloadable_patch do
    ::Guardian.prepend(
      Module.new do
        def can_translate?(post)
          unless SiteSetting.jtech_enabled && SiteSetting.translator_tweaks_enabled &&
                   SiteSetting.translator_tweaks_hide_untranslatable
            return super
          end

          return false if post&.detected_locale.blank?
          super
        end
      end,
    )
  end
end
