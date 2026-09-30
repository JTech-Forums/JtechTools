# frozen_string_literal: true
# Jtech sub-plugin: Translator tweaks — points the upstream
# discourse/discourse-translator plugin's Google provider at a proxy.
# Instance_eval'd by plugin.rb in the Plugin::Instance context.
#
# Settings (config/settings.yml, jtech_translator):
#   translator_tweaks_enabled     module switch
#   translator_tweaks_worker_url  Google proxy base ('' = call Google direct)
#
# (The old "hide the translate globe on posts with no detected language"
# tweak is gone: upstream detects the language when the globe is clicked, so
# hiding it only made older posts impossible to translate.)

module ::DiscourseTranslatorTweaks
  # Points the provider class's three endpoint constants at `base`.
  def self.apply_proxy!(google, base)
    base = base.to_s.strip.sub(%r{/+\z}, "")
    return if base.empty?

    silence_warnings do
      {
        TRANSLATE_URI: base,
        DETECT_URI: "#{base}/detect",
        SUPPORT_URI: "#{base}/languages",
      }.each do |name, value|
        google.send(:remove_const, name) if google.const_defined?(name, false)
        google.const_set(name, value.freeze)
      end
    end
  end
end

after_initialize do
  # Nothing to patch without the translator plugin; every setting in the
  # jtech_translator block is inert on such a site.
  next unless defined?(::DiscourseTranslator::Provider::Google)

  # Upstream's Google provider calls googleapis.com directly. Redirect its
  # three endpoints (translate / detect / languages) at the configured proxy,
  # e.g. to spread Google's per-IP quota. The provider still sends the
  # site's Google API key in each request body, so the proxy sees the key
  # and every post it translates — use only one you control.
  #
  # Boot-time only: the endpoints are Ruby constants on the provider class,
  # so the swap happens once per process. Editing the URL or either switch
  # needs an app restart (the setting description and its confirmation
  # dialog say so); a live rewrite would leave sibling web and Sidekiq
  # processes disagreeing about the endpoint.
  reloadable_patch do
    if SiteSetting.jtech_enabled && SiteSetting.translator_tweaks_enabled
      DiscourseTranslatorTweaks.apply_proxy!(
        ::DiscourseTranslator::Provider::Google,
        SiteSetting.translator_tweaks_worker_url,
      )
    end
  end
end
