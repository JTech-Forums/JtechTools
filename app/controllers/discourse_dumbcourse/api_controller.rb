# frozen_string_literal: true

module DiscourseDumbcourse
  # Small helpers the app needs that core has no endpoint for.
  class ApiController < ::ApplicationController
    requires_plugin "jtech-tools"

    before_action :ensure_enabled
    before_action :ensure_logged_in

    # POST /<base>/api/preview — the composer's Preview, cooked exactly as
    # the post would be (Discourse's own renderer, which also sanitises).
    def preview
      RateLimiter.new(current_user, "dumbcourse-preview", 30, 1.minute).performed!
      raw = params.require(:raw).to_s
      raise Discourse::InvalidParameters.new(:raw) if raw.length > SiteSetting.max_post_length
      render json: { cooked: PrettyText.cook(raw, user_id: current_user.id) }
    end

    private

    def ensure_enabled
      raise Discourse::NotFound unless DiscourseDumbcourse.enabled?
    end
  end
end
