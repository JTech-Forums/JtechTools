# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseDisteleplus::ForumUploadPolicy do
  let(:topic) do
    instance_double(
      Topic,
      deleted_at: nil,
      visible?: true,
      archetype: Archetype.default,
      category_id: 12,
      read_restricted_category?: false,
    )
  end
  let(:post) do
    instance_double(
      Post,
      deleted_at: nil,
      hidden?: false,
      post_type: Post.types[:regular],
      topic: topic,
    )
  end

  before do
    SiteSetting.disteleplus_forum_upload_category_ids = ""
    SiteSetting.disteleplus_forum_upload_include_restricted_categories = false
  end

  it "accepts a visible regular post by default" do
    expect(described_class.eligible?(post)).to eq(true)
  end

  it "always excludes private messages" do
    allow(topic).to receive(:archetype).and_return(Archetype.private_message)
    expect(described_class.eligible?(post)).to eq(false)
  end

  it "excludes restricted categories unless the admin explicitly includes them" do
    allow(topic).to receive(:read_restricted_category?).and_return(true)
    expect(described_class.eligible?(post)).to eq(false)

    SiteSetting.disteleplus_forum_upload_include_restricted_categories = true
    expect(described_class.eligible?(post)).to eq(true)
  end

  it "honors the category allowlist" do
    SiteSetting.disteleplus_forum_upload_category_ids = "13"
    expect(described_class.eligible?(post)).to eq(false)

    SiteSetting.disteleplus_forum_upload_category_ids = "12"
    expect(described_class.eligible?(post)).to eq(true)
  end
end
