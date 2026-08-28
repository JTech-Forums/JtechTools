# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseDisteleplus::ForumUploadFormatter do
  let(:category) { Struct.new(:slug).new("Android Apps") }
  let(:topic) { Struct.new(:title, :category).new("Useful <Apps>", category) }
  let(:user) { Struct.new(:username).new("uploader") }
  let(:post) do
    instance_double(
      Post,
      topic: topic,
      user: user,
      post_number: 7,
      created_at: Time.utc(2026, 8, 28, 12, 30),
      full_url: "https://forums.jtechforums.org/t/useful/12/7",
      excerpt: "The author's <comment> & notes",
    )
  end
  let(:upload) do
    instance_double(
      Upload,
      original_filename: "tool <final>.apk",
      filesize: 1_572_864,
      extension: "apk",
      sha1: "a123456789b123456789c123456789d123456789",
    )
  end

  it "builds a compact expandable caption with escaped metadata and a post link" do
    caption = described_class.caption(post, upload)

    expect(caption).to include("<b>tool &lt;final&gt;.apk</b>")
    expect(caption).to include("<blockquote expandable>")
    expect(caption).to include("The author's")
    expect(caption).to include("#jtechupload #file_apk #cat_android_apps #jtu_a123456789")
    expect(caption).to include("SHA-1 <code>a123456789b123456789c123456789d123456789</code>")
    expect(caption).to include("1.5 MB")
    expect(caption).to include("2026-08-28 12:30:00 UTC")
    expect(caption).to include('href="https://forums.jtechforums.org/t/useful/12/7"')
    expect(caption).to include("Useful &lt;Apps&gt; · post #7")
  end
end
