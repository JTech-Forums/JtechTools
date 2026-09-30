# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseReqpm::Crypto do
  fab!(:user)
  fab!(:other, :user)

  it "round-trips a value for its owner and field" do
    cipher = described_class.encrypt("+1 555 0100", user_id: user.id, field: :value)
    expect(cipher).to start_with(described_class::PREFIX)
    expect(cipher).not_to include("555")
    expect(described_class.decrypt(cipher, user_id: user.id, field: :value)).to eq("+1 555 0100")
  end

  it "refuses a ciphertext moved to another user or field" do
    cipher = described_class.encrypt("secret", user_id: user.id, field: :value)
    expect(described_class.decrypt(cipher, user_id: other.id, field: :value)).to be_nil
    expect(described_class.decrypt(cipher, user_id: user.id, field: :note)).to be_nil
  end

  it "refuses tampered or foreign data" do
    cipher = described_class.encrypt("secret", user_id: user.id, field: :value)
    expect(
      described_class.decrypt(cipher.sub(/.\z/, "A"), user_id: user.id, field: :value),
    ).to be_nil
    expect(described_class.decrypt("plaintext", user_id: user.id, field: :value)).to be_nil
  end

  it "never stores plaintext in the contact methods table" do
    method = DiscourseReqpm::ContactMethod.new(user_id: user.id, kind: "email")
    method.value = "hidden@example.com"
    method.note = "after 6pm"
    method.save!

    row =
      DB.query_single(
        "SELECT value_ciphertext || coalesce(note_ciphertext, '') FROM reqpm_contact_methods WHERE id = ?",
        method.id,
      ).first
    expect(row).not_to include("hidden@example.com")
    expect(row).not_to include("after 6pm")
    expect(method.reload.value).to eq("hidden@example.com")
    expect(method.note).to eq("after 6pm")
  end

  it "reports a row it can no longer read instead of showing garbage" do
    method = DiscourseReqpm::ContactMethod.new(user_id: user.id, kind: "email")
    method.value = "x@example.com"
    method.save!
    method.update_columns(value_ciphertext: "#{described_class::PREFIX}garbage")
    expect(method.reload.unreadable?).to eq(true)
  end
end
