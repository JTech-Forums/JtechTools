# frozen_string_literal: true

require "rails_helper"

# The installed app's icon: the web manifest lists the plugin's opaque app icon
# instead of the see-through manifest_icon upload, unless switched off.
RSpec.describe "JTech app icon" do
  let(:upload) { Fabricate(:upload) }

  before do
    SiteSetting.jtech_enabled = true
    SiteSetting.manifest_icon = upload
  end

  def icons
    get "/manifest.webmanifest"
    expect(response.status).to eq(200)
    # served as application/manifest+json, which parsed_body leaves as a string
    JSON.parse(response.body)["icons"]
  end

  it "serves the plugin's icon, plain and maskable" do
    expect(icons).to contain_exactly(
      a_hash_including("src" => end_with("/plugins/jtech-tools/jtech-app-icon.png")).and(
        satisfy { |icon| !icon.key?("purpose") },
      ),
      a_hash_including(
        "src" => end_with("/plugins/jtech-tools/jtech-app-icon.png"),
        "purpose" => "maskable",
      ),
    )
  end

  it "leaves core's icon when the setting is off" do
    SiteSetting.jtech_app_icon = false
    srcs = icons.map { |icon| icon["src"] }
    expect(srcs).to be_present
    expect(srcs.grep(/jtech-app-icon/)).to be_empty
  end

  it "leaves core's icon when the plugin is off" do
    SiteSetting.jtech_enabled = false
    srcs = icons.map { |icon| icon["src"] }
    expect(srcs).to be_present
    expect(srcs.grep(/jtech-app-icon/)).to be_empty
  end
end
