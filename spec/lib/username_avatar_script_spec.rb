# frozen_string_literal: true

require "rails_helper"

RSpec.describe "scripts/username_avatar_recalculate.rb" do # rubocop:disable RSpec/DescribeClass
  let(:script) { File.expand_path("../../scripts/username_avatar_recalculate.rb", __dir__) }

  fab!(:gravatar_user, :user)
  fab!(:custom_user, :user)
  fab!(:letter_user, :user)
  fab!(:gravatar_upload, :upload)
  fab!(:custom_upload, :upload)

  before do
    SiteSetting.automatically_download_gravatars = false

    gravatar_user.user_avatar.update!(gravatar_upload_id: gravatar_upload.id)
    gravatar_user.update!(uploaded_avatar_id: gravatar_upload.id)

    custom_user.user_avatar.update!(custom_upload_id: custom_upload.id)
    custom_user.update!(uploaded_avatar_id: custom_upload.id)
  end

  def run_script
    # A rails-runner script, so it is run as a file, not required.
    expect { load(script) }.to output(/Switched 1 user/).to_stdout # rubocop:disable Discourse/Plugins/UseRequireRelative
  end

  it "resets only people showing a Gravatar picture" do
    run_script

    expect(gravatar_user.reload.uploaded_avatar_id).to be_nil
    expect(custom_user.reload.uploaded_avatar_id).to eq(custom_upload.id)
    expect(letter_user.reload.uploaded_avatar_id).to be_nil
  end

  it "leaves the system user alone" do
    system = Discourse.system_user
    system.user_avatar.update!(gravatar_upload_id: gravatar_upload.id)
    system.update!(uploaded_avatar_id: gravatar_upload.id)

    run_script
    expect(system.reload.uploaded_avatar_id).to eq(gravatar_upload.id)
  end
end
