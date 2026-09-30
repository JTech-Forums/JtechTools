# frozen_string_literal: true

# translator_tweaks_hide_untranslatable is gone: hiding the translate globe
# on posts without a detected language left those posts untranslatable,
# while upstream detects the language on demand when the globe is clicked.
class DropTranslatorTweaksHideUntranslatable < ActiveRecord::Migration[7.2]
  def up
    execute "DELETE FROM site_settings WHERE name = 'translator_tweaks_hide_untranslatable'"
  end

  def down
  end
end
