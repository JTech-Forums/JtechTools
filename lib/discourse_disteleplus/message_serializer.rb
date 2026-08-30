# frozen_string_literal: true

module DiscourseDisteleplus
  module MessageSerializer
    def self.serialize(message, viewer: nil, include_reply: true)
      user = message.user
      {
        id: message.id,
        raw: message.deleted? ? "" : message.raw,
        cooked: message.deleted? ? "" : message.cooked,
        source: message.source,
        external_sender_name: message.external_sender_name,
        deleted: message.deleted?,
        edited_at: message.edited_at&.iso8601,
        created_at: message.created_at.iso8601,
        updated_at: message.updated_at.iso8601,
        user: serialize_user(user),
        uploads: message.deleted? ? [] : message.uploads.map { |upload| serialize_upload(upload) },
        reactions: message.deleted? ? [] : serialize_reactions(message, viewer),
        reply_to:
          include_reply && message.reply_to ? serialize_reply_preview(message.reply_to) : nil,
        can_edit: viewer ? Access.can_edit?(viewer, message) : false,
        can_delete: viewer ? Access.can_delete?(viewer, message) : false,
        can_react: viewer ? Access.allowed?(viewer) && !message.deleted? : false,
      }
    end

    def self.serialize_user(user)
      return nil if user.nil?

      {
        id: user.id,
        username: user.username,
        name: user.name,
        avatar_template: user.avatar_template,
        admin: user.admin?,
        moderator: user.moderator?,
      }
    end

    def self.serialize_upload(upload)
      {
        id: upload.id,
        url: upload.url,
        short_url: upload.short_url,
        original_filename: upload.original_filename,
        extension: upload.extension,
        filesize: upload.filesize,
        width: upload.width,
        height: upload.height,
        thumbnail_width: upload.thumbnail_width,
        thumbnail_height: upload.thumbnail_height,
      }
    end

    def self.serialize_reactions(message, viewer)
      message
        .reactions
        .includes(:user)
        .group_by(&:emoji)
        .map do |emoji, reactions|
          {
            emoji: emoji,
            count: reactions.length,
            reacted: viewer ? reactions.any? { |reaction| reaction.user_id == viewer.id } : false,
            users: reactions.map { |reaction| serialize_user(reaction.user) },
          }
        end
        .sort_by { |reaction| reaction[:emoji] }
    end

    IMAGE_EXTENSIONS = %w[png jpg jpeg gif webp].freeze

    def self.serialize_reply_preview(message)
      uploads = message.deleted? ? [] : message.uploads.to_a
      image = uploads.find { |upload| IMAGE_EXTENSIONS.include?(upload.extension.to_s.downcase) }
      {
        id: message.id,
        deleted: message.deleted?,
        cooked: message.deleted? ? "" : message.cooked,
        external_sender_name: message.external_sender_name,
        user: serialize_user(message.user),
        upload_count: uploads.length,
        thumbnail_url: image&.url,
        attachment_name: uploads.first&.original_filename,
      }
    end
  end
end
