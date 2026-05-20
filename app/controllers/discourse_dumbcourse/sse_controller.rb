# frozen_string_literal: true

module DiscourseDumbcourse
  class SseController < ::ActionController::Base
    requires_plugin DiscourseDumbcourse::PLUGIN_NAME

    skip_before_action :verify_authenticity_token

    # GET /<base>/push/sse/:topic and /<base>/ntfy/:topic/sse
    #
    # SSE is permanently disabled.  Returning 410 Gone (not 503) so stale
    # cached SPA bundles stop reconnecting — EventSource spec treats 410
    # as a terminal error and stops retrying.
    #
    # Push notifications are still delivered via Redis PUBLISH → a future
    # lightweight listener (standalone Puma / thin SSE proxy) can subscribe
    # without tying up Discourse Pitchfork workers.
    def stream
      response.headers["Cache-Control"] = "no-store"
      render plain: "SSE permanently disabled — use polling", status: :gone
    end
  end
end
