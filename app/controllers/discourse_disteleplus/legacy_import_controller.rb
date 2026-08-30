# frozen_string_literal: true

module DiscourseDisteleplus
  class LegacyImportController < ::ApplicationController
    requires_login
    before_action :ensure_admin

    def show
      render_json_dump(LegacyChatImporter.status)
    end

    def create
      status = LegacyChatImporter.status
      raise Discourse::InvalidAccess unless status[:available]

      unless params[:dry_run].to_s == "true"
        Jobs.enqueue(
          :disteleplus_import_legacy_chat,
          after_id: params[:after_id].to_i,
          batch_size: params.fetch(:batch_size, LegacyChatImporter::BATCH_SIZE).to_i.clamp(1, 500),
        )
      end
      render_json_dump(status.merge(queued: params[:dry_run].to_s != "true"))
    end

    private

    def ensure_admin
      raise Discourse::InvalidAccess unless current_user&.admin?
    end
  end
end
