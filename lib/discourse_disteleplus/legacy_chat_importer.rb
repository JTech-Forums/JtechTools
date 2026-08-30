# frozen_string_literal: true

module DiscourseDisteleplus
  # The sole optional dependency boundary for old Discourse Chat data. It is
  # administrator-triggered, read-only with respect to Chat, resumable, and
  # safe to leave installed after Chat is disabled.
  class LegacyChatImporter
    BATCH_SIZE = 100
    PREFIX = /\A\*\*(.+?)\s+\(TG\):\*\*\s*/m

    def self.available?
      defined?(::Chat::Message) && SiteSetting.disteleplus_chat_channel_id.to_i.positive?
    end

    def self.status
      native = Message.where.not(legacy_chat_message_id: nil)
      result = {
        available: available? ? true : false,
        channel_id: SiteSetting.disteleplus_chat_channel_id.to_i,
        imported: native.count,
        imported_uploads:
          MessageUpload.where(message_id: native.select(:id)).count,
        imported_reactions:
          Reaction.where(message_id: native.select(:id)).count,
        linked_telegram:
          MessageLink.where.not(disteleplus_message_id: nil).where.not(chat_message_id: nil).count,
      }
      if available?
        source = source_scope
        result[:source] = source.count
        result[:remaining] = [result[:source] - result[:imported], 0].max
        result[:complete] = result[:remaining].zero?
      else
        result[:source] = nil
        result[:remaining] = nil
        result[:complete] = false
      end
      result
    end

    def self.import_batch(after_id: 0, batch_size: BATCH_SIZE)
      raise "Discourse Chat or legacy channel unavailable" unless available?

      source = source_scope.where("chat_messages.id > ?", after_id.to_i).limit(batch_size)
      imported = 0
      last_id = after_id.to_i
      source.each do |legacy|
        last_id = legacy.id
        imported += 1 if import_one(legacy)
      end
      { imported: imported, last_id: last_id, more: source_scope.where("chat_messages.id > ?", last_id).exists? }
    end

    def self.import_one(legacy)
      existing = Message.find_by(legacy_chat_message_id: legacy.id)
      if existing
        relink(existing, legacy.id)
        return false
      end

      links = MessageLink.where(chat_message_id: legacy.id)
      telegram_origin = links.tg_to_discourse.exists?
      raw = legacy.message.to_s
      external_sender_name = nil
      if telegram_origin && (match = raw.match(PREFIX))
        external_sender_name = match[1]
        raw = raw.sub(PREFIX, "")
      end
      reply_to =
        if legacy.respond_to?(:in_reply_to_id) && legacy.in_reply_to_id.present?
          Message.find_by(legacy_chat_message_id: legacy.in_reply_to_id)
        end

      native = nil
      Message.transaction do
        native =
          Message.create!(
            user_id: legacy.user_id,
            raw: raw,
            cooked: raw.blank? ? "" : PrettyText.cook(raw, user_id: legacy.user_id),
            source: telegram_origin ? :telegram : :discourse,
            external_sender_name: external_sender_name,
            reply_to: reply_to,
            edited_at: legacy.try(:edited_at),
            deleted_at: legacy.try(:deleted_at),
            legacy_chat_message_id: legacy.id,
            created_at: legacy.created_at,
            updated_at: legacy.updated_at,
          )
        Array(legacy.try(:uploads)).each do |upload|
          native.message_uploads.create!(upload: upload)
        end
        Array(legacy.try(:reactions)).each do |reaction|
          next unless reaction.try(:user_id).present? && reaction.try(:emoji).present?
          native.reactions.find_or_create_by!(user_id: reaction.user_id, emoji: reaction.emoji)
        end
        links.update_all(disteleplus_message_id: native.id)
      end
      true
    rescue ActiveRecord::RecordNotUnique
      false
    rescue StandardError => e
      Rails.logger.warn(
        "#{DiscourseDisteleplus::LOG_TAG} legacy Chat import failed for message " \
          "#{legacy.id}: #{e.class}: #{e.message}",
      )
      false
    end

    def self.source_scope
      ::Chat::Message
        .where(chat_channel_id: SiteSetting.disteleplus_chat_channel_id)
        .order(:id)
    end

    def self.relink(native, legacy_id)
      MessageLink.where(chat_message_id: legacy_id).update_all(disteleplus_message_id: native.id)
    end

    private_class_method :source_scope, :relink
  end
end
