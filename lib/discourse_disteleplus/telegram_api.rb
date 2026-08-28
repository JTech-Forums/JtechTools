# frozen_string_literal: true

require "net/http"

module DiscourseDisteleplus
  # Thin Net::HTTP wrapper over the Telegram Bot API.
  #
  # Same posture as the Dumbcourse LanguageTool proxy: short timeouts, no
  # retries here (the jobs re-enqueue on 429 via RateLimited), and failures
  # surface as Result(ok: false) for callers to log-and-swallow — a Telegram
  # outage must never take a Sidekiq queue down with it.
  class TelegramApi
    BASE = "https://api.telegram.org"
    OPEN_TIMEOUT = 3
    READ_TIMEOUT = 15
    # Hard Bot API limit on getFile downloads, independent of our setting.
    MAX_DOWNLOAD_BYTES = 20 * 1024 * 1024

    class RateLimited < StandardError
      attr_reader :retry_after

      def initialize(retry_after)
        @retry_after = [retry_after.to_i, 5].max
        super("Telegram API rate limited, retry after #{@retry_after}s")
      end
    end

    Result = Struct.new(:ok, :description, :result, keyword_init: true)

    def initialize(token: nil)
      @token = token || SiteSetting.disteleplus_bot_token
    end

    # JSON-body Bot API call. Returns a Result; raises RateLimited on 429 so
    # jobs can re-enqueue with Telegram's suggested delay.
    def call(method, payload = {})
      uri = URI("#{BASE}/bot#{@token}/#{method}")
      request = Net::HTTP::Post.new(uri.request_uri, "Content-Type" => "application/json")
      request.body = payload.to_json
      parse_response(perform(uri, request))
    end

    # Multipart call for file sends (sendPhoto/sendDocument/…). `io` is
    # streamed by Net::HTTP's form encoding, so large files don't balloon RAM.
    def call_multipart(
      method,
      fields,
      file_field:,
      io:,
      filename:,
      mime: "application/octet-stream"
    )
      uri = URI("#{BASE}/bot#{@token}/#{method}")
      request = Net::HTTP::Post.new(uri.request_uri)
      form = fields.map { |k, v| [k.to_s, v.to_s] }
      form << [file_field.to_s, io, { filename: filename, content_type: mime }]
      request.set_form(form, "multipart/form-data")
      parse_response(perform(uri, request))
    end

    # getFile + download. Returns a binmode Tempfile (caller closes/unlinks)
    # or nil when the file is over `max_bytes`/the 20 MB Bot API cap or any
    # step fails. Aborts mid-stream if the body outgrows the declared size.
    def download_file(file_id, max_bytes:)
      limit = [max_bytes.to_i, MAX_DOWNLOAD_BYTES].min
      meta = call("getFile", file_id: file_id)
      file_path = meta.result&.dig("file_path")
      declared = meta.result&.dig("file_size").to_i
      return nil if !meta.ok || file_path.blank? || declared > limit

      uri = URI("#{BASE}/file/bot#{@token}/#{file_path}")
      tempfile = Tempfile.new(["disteleplus", File.extname(file_path)], binmode: true)

      Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        http.open_timeout = OPEN_TIMEOUT
        http.read_timeout = READ_TIMEOUT
        http.request(Net::HTTP::Get.new(uri.request_uri)) do |response|
          raise "unexpected #{response.code}" unless response.code.to_i == 200
          response.read_body do |chunk|
            tempfile.write(chunk)
            raise "download exceeded #{limit} bytes" if tempfile.size > limit
          end
        end
      end

      tempfile.rewind
      tempfile
    rescue StandardError => e
      Rails.logger.warn(
        "#{DiscourseDisteleplus::LOG_TAG} download failed: #{e.class}: #{e.message}",
      )
      tempfile&.close!
      nil
    end

    private

    def perform(uri, request)
      Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        http.open_timeout = OPEN_TIMEOUT
        http.read_timeout = READ_TIMEOUT
        http.request(request)
      end
    end

    def parse_response(response)
      data =
        begin
          JSON.parse(response.body)
        rescue JSON::ParserError, TypeError
          {}
        end

      raise RateLimited, (data.dig("parameters", "retry_after") || 30) if response.code.to_i == 429

      Result.new(ok: data["ok"] == true, description: data["description"], result: data["result"])
    end
  end
end
