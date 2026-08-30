# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseDisteleplus::Crypto do
  fab!(:user)

  before do
    SiteSetting.jtech_enabled = true
    SiteSetting.disteleplus_enabled = true
    SiteSetting.disteleplus_encrypt_at_rest = true
  end

  it "round-trips and marks ciphertext" do
    enc = described_class.encrypt("secret plan")
    expect(enc).to start_with(described_class::PREFIX)
    expect(enc).not_to include("secret plan")
    expect(described_class.decrypt(enc)).to eq("secret plan")
    expect(described_class.decrypt("plain")).to eq("plain")
  end

  it "stores messages encrypted and reads them back transparently" do
    message =
      DiscourseDisteleplus::Message.create!(
        user: user,
        raw: "top secret",
        cooked: "<p>top secret</p>",
      )
    stored =
      DiscourseDisteleplus::Message.connection.select_one(
        "SELECT raw, cooked FROM disteleplus_messages WHERE id = #{message.id}",
      )
    expect(stored["raw"]).to start_with("enc:v1:")
    expect(stored["cooked"]).not_to include("top secret")
    expect(message.reload.raw).to eq("top secret")
    expect(message.cooked).to eq("<p>top secret</p>")
  end

  it "leaves plaintext alone when disabled and migrates it with the onceoff job" do
    SiteSetting.disteleplus_encrypt_at_rest = false
    message = DiscourseDisteleplus::Message.create!(user: user, raw: "old", cooked: "<p>old</p>")
    expect(message[:raw]).to eq("old")

    SiteSetting.disteleplus_encrypt_at_rest = true
    Jobs::DisteleplusEncryptMessages.new.execute_onceoff({})
    expect(message.reload[:raw]).to start_with("enc:v1:")
    expect(message.raw).to eq("old")
  end
end
