# frozen_string_literal: true

module Jobs
  class DisteleplusImportLegacyChat < ::Jobs::Base
    def execute(args)
      result =
        DiscourseDisteleplus::LegacyChatImporter.import_batch(
          after_id: args[:after_id].to_i,
          batch_size: args[:batch_size].to_i.clamp(1, 500),
        )
      if result[:more]
        Jobs.enqueue(
          :disteleplus_import_legacy_chat,
          after_id: result[:last_id],
          batch_size: args[:batch_size],
        )
      else
        Rails.logger.info(
          "#{DiscourseDisteleplus::LOG_TAG} legacy Chat import complete: " \
            "#{DiscourseDisteleplus::LegacyChatImporter.status.to_json}",
        )
      end
    end
  end
end
