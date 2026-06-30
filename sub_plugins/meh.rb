# frozen_string_literal: true
# Jtech sub-plugin: meh — repaints the "man_shrugging" 🤷 emoji with a custom MEH glyph.
#
# Why this approach: rather than add a brand-new reaction (which the dumbcourse
# SPA and other surfaces don't know about), we override the image of an EXISTING
# emoji. discourse-reactions renders each reaction via buildEmojiUrl(name), which
# checks custom emoji BEFORE the emoji set — so registering a custom emoji under
# the name "man_shrugging" makes every man_shrugging render as MEH: the "don't
# know" reaction AND :man_shrugging: typed in posts. Nothing structural changes,
# so it can't break the reaction plumbing.
#
# Gated by meh_enabled so it can be switched off (takes effect on the next
# rebuild/restart, since emoji are registered at boot). Wrapped in rescue so a
# missing image can never break boot. The dumbcourse SPA is handled separately
# (it renders reactions as native unicode, so app_controller injects mehEnabled
# and dumbcourse.js swaps in an <img> for that slot).
#
# Bundled image: public/images/meh.png, served at /plugins/jtech-tools/images/meh.png.

after_initialize do
  next unless SiteSetting.meh_enabled

  begin
    register_emoji("man_shrugging", "/plugins/jtech-tools/images/meh.png")
  rescue StandardError => e
    Rails.logger.warn("[jtech-meh] could not repaint man_shrugging emoji: #{e.message}")
  end
end
