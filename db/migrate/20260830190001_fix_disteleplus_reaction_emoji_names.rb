# frozen_string_literal: true

# The Telegram emoji map stored three inbound reaction names Discourse's
# emoji set doesn't contain (salute, whisper, shrug), so those chips rendered
# as literal ":salute:" text. Rename stored rows to the real names; the
# NOT EXISTS guard skips rows where the same user already reacted to the same
# message with the correct name (unique index message_id/user_id/emoji), and
# the DELETE clears those now-redundant duplicates. Idempotent by shape.
class FixDisteleplusReactionEmojiNames < ActiveRecord::Migration[7.2]
  RENAMES = {
    "salute" => "saluting_face",
    "whisper" => "shushing_face",
    "shrug" => "person_shrugging",
  }

  def up
    RENAMES.each do |from, to|
      execute(<<~SQL)
        UPDATE disteleplus_reactions r
        SET emoji = '#{to}'
        WHERE emoji = '#{from}'
          AND NOT EXISTS (
            SELECT 1
            FROM disteleplus_reactions d
            WHERE d.message_id = r.message_id
              AND d.user_id = r.user_id
              AND d.emoji = '#{to}'
          )
      SQL
      execute("DELETE FROM disteleplus_reactions WHERE emoji = '#{from}'")
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
