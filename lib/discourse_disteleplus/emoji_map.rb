# frozen_string_literal: true

module DiscourseDisteleplus
  # Discourse emoji names ⇄ Telegram reaction emoji characters.
  #
  # Telegram bots may only react with characters from the Bot API's fixed
  # reaction set (ReactionTypeEmoji, ~73 chars, no premium/custom emoji), so
  # both directions funnel through this table. Unmapped Discourse emoji fall
  # back to 👍; unmapped Telegram chars fall back to :+1:.
  module EmojiMap
    FALLBACK_TG = "👍"
    FALLBACK_DISCOURSE = "+1"

    # Discourse emoji name (no colons) → Telegram reaction char. Every value
    # must be in Telegram's allowed reaction set. Aliases share a value; the
    # first name per char is the canonical inbound mapping (see
    # TG_TO_DISCOURSE below).
    DISCOURSE_TO_TG = {
      "+1" => "👍",
      "thumbsup" => "👍",
      "-1" => "👎",
      "thumbsdown" => "👎",
      "heart" => "❤",
      "heartpulse" => "💓",
      "fire" => "🔥",
      "tada" => "🎉",
      "clap" => "👏",
      "grin" => "😁",
      "grinning" => "😁",
      "smile" => "😁",
      "thinking" => "🤔",
      "exploding_head" => "🤯",
      "scream" => "😱",
      "rage" => "🤬",
      "angry" => "🤬",
      "cry" => "😢",
      "sob" => "😭",
      "joy" => "🤣",
      "rofl" => "🤣",
      "laughing" => "🤣",
      "100" => "💯",
      "pray" => "🙏",
      "ok_hand" => "👌",
      "eyes" => "👀",
      "heart_eyes" => "😍",
      "kissing_heart" => "😘",
      "trophy" => "🏆",
      "zap" => "⚡",
      "handshake" => "🤝",
      "hugs" => "🤗",
      "wave" => "👋",
      "star_struck" => "🤩",
      "partying_face" => "🥳",
      "smiling_face_with_three_hearts" => "🥰",
      "neutral_face" => "😐",
      "sunglasses" => "😎",
      "salute" => "🫡",
      "saluting_face" => "🫡",
      "broken_heart" => "💔",
      "poop" => "💩",
      "hankey" => "💩",
      "dove" => "🕊",
      "strawberry" => "🍓",
      "banana" => "🍌",
      "champagne" => "🍾",
      "beers" => "🍻",
      "pill" => "💊",
      "ghost" => "👻",
      "jack_o_lantern" => "🎃",
      "christmas_tree" => "🎄",
      "snowman" => "☃",
      "santa" => "🎅",
      "unicorn" => "🦄",
      "whale" => "🐳",
      "see_no_evil" => "🙈",
      "monkey" => "🐒",
      "alien" => "👾",
      "robot" => "🤖",
      "new_moon_with_face" => "🌚",
      "hot_face" => "🥵",
      "cold_face" => "🥶",
      "clown_face" => "🤡",
      "nauseated_face" => "🤮",
      "sleeping" => "😴",
      "zany_face" => "🤪",
      "face_with_raised_eyebrow" => "🤨",
      "face_with_monocle" => "🧐",
      "yawning_face" => "🥱",
      "woozy_face" => "🥴",
      "smiling_imp" => "😈",
      "innocent" => "😇",
      "whisper" => "🤫",
      "shushing_face" => "🤫",
      "writing_hand" => "✍",
      "man_shrugging" => "🤷‍♂",
      "woman_shrugging" => "🤷‍♀",
      "shrug" => "🤷",
      "electric_plug" => "🔌",
      "kiss" => "💋",
    }.freeze

    # Telegram char → canonical Discourse emoji name. Built by inversion —
    # for aliased names the FIRST entry above wins, which is why canonical
    # names are listed before their aliases.
    TG_TO_DISCOURSE =
      DISCOURSE_TO_TG.each_with_object({}) { |(name, char), memo| memo[char] ||= name }.freeze

    def self.discourse_to_tg(name)
      DISCOURSE_TO_TG[name.to_s.delete(":")] || FALLBACK_TG
    end

    def self.tg_to_discourse(char)
      TG_TO_DISCOURSE[char.to_s] || FALLBACK_DISCOURSE
    end
  end
end
