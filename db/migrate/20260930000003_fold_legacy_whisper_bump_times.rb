# frozen_string_literal: true

# Topics bumped by a whisper before whispers stopped bumping topics kept the
# last public bump time in the mod_non_whisper_bumped_at custom field, and
# every non-staff topic list was re-sorted by it (which also overrode /top,
# /hot and every other list order). Write that time back into bumped_at once
# and drop the field.
class FoldLegacyWhisperBumpTimes < ActiveRecord::Migration[7.2]
  def up
    rows = DB.query(<<~SQL)
      SELECT topic_id, value FROM topic_custom_fields WHERE name = 'mod_non_whisper_bumped_at'
    SQL

    rows.each do |row|
      time =
        begin
          Time.zone.parse(row.value.to_s)
        rescue ArgumentError
          nil
        end
      next if time.nil?

      DB.exec(<<~SQL, id: row.topic_id, time: time)
        UPDATE topics SET bumped_at = LEAST(:time, bumped_at) WHERE id = :id
      SQL
    end

    execute "DELETE FROM topic_custom_fields WHERE name = 'mod_non_whisper_bumped_at'"
  end

  def down
  end
end
