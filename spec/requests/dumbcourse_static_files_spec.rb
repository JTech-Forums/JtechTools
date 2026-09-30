# frozen_string_literal: true

require "rails_helper"

# The Dumbcourse catch-all serves its static files straight from the
# plugin's public/ directory. Nothing outside that directory may ever be
# served, however the path is spelled.
RSpec.describe "Dumbcourse static files" do
  fab!(:user)

  let(:base) { "/#{SiteSetting.dumbcourse_base_path}" }
  let(:plugin_rb_marker) { "# name: jtech-tools" }

  before do
    SiteSetting.dumbcourse_enabled = true
    sign_in(user)
  end

  it "serves its own assets" do
    get "#{base}/dumbcourse.js"
    expect(response.status).to eq(200)
    expect(response.media_type).to eq("text/javascript")
  end

  %w[
    ../plugin.rb
    ../../jtech-tools/plugin.rb
    ../../../plugins/jtech-tools/plugin.rb
    %2e%2e/plugin.rb
    %2e%2e%2fplugin.rb
    ..%2f..%2fplugin.rb
    a/../../plugin.rb
    ./../plugin.rb
  ].each do |evil|
    it "never serves a file outside public/ for #{evil.inspect}" do
      get "#{base}/#{evil}"
      expect(response.body).not_to include(plugin_rb_marker)
    end
  end
end
