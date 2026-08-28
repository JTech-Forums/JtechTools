# frozen_string_literal: true

require "rails_helper"

# Contract for the Telegram webhook receiver: the secret header is the only
# authentication, authenticated requests always get a 200 (Telegram retries
# non-2xx in a loop), and the controller does nothing but enqueue.
RSpec.describe "Disteleplus Telegram webhook" do
  let(:secret) { "s3cret-token" }
  let(:path) { "/jtech-disteleplus/telegram/webhook" }
  let(:update) { { update_id: 1, message: { message_id: 7, chat: { id: -100_123 }, text: "hi" } } }

  before do
    SiteSetting.jtech_enabled = true
    SiteSetting.disteleplus_enabled = true
    SiteSetting.disteleplus_webhook_secret = secret
  end

  def post_update(body: update.to_json, header: secret)
    headers = { "CONTENT_TYPE" => "application/json" }
    headers["X-Telegram-Bot-Api-Secret-Token"] = header if header
    post path, params: body, headers: headers
  end

  it "404s when the module is disabled" do
    SiteSetting.disteleplus_enabled = false
    post_update
    expect(response.status).to eq(404)
  end

  it "403s on a wrong secret without enqueueing" do
    expect { post_update(header: "wrong") }.not_to change {
      Jobs::DisteleplusProcessTelegramUpdate.jobs.size
    }
    expect(response.status).to eq(403)
  end

  it "403s on a missing secret header" do
    post_update(header: nil)
    expect(response.status).to eq(403)
  end

  it "403s when no secret is configured (never open by accident)" do
    SiteSetting.disteleplus_webhook_secret = ""
    post_update(header: "")
    expect(response.status).to eq(403)
  end

  it "enqueues the processing job for a valid update and answers 200" do
    expect_enqueued_with(
      job: :disteleplus_process_telegram_update,
      args: {
        update: JSON.parse(update.to_json),
      },
    ) { post_update }
    expect(response.status).to eq(200)
    expect(response.parsed_body["ok"]).to eq(true)
  end

  it "tolerates junk bodies with a 200 and no enqueue" do
    expect { post_update(body: "not json{{") }.not_to change {
      Jobs::DisteleplusProcessTelegramUpdate.jobs.size
    }
    expect(response.status).to eq(200)
  end

  it "ignores bodies without an update_id" do
    expect { post_update(body: { foo: "bar" }.to_json) }.not_to change {
      Jobs::DisteleplusProcessTelegramUpdate.jobs.size
    }
    expect(response.status).to eq(200)
  end
end
