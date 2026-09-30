# frozen_string_literal: true

# REQ-PM's setup prompt opens a window over the first page for every member
# with an empty contact card — which is every fabricated user. Keep it out of
# other features' browser specs; the REQ-PM specs opt back in.
#
# Registered from before(:suite) so it runs after core's per-example
# TestSetup (which resets site settings) rather than before it.
RSpec.configure do |config|
  config.before(:suite) do
    RSpec.configure do |late|
      late.before(:each, type: :system) do |example|
        next if example.metadata[:reqpm_prompt]
        SiteSetting.reqpm_setup_prompt = "off" if SiteSetting.respond_to?(:reqpm_setup_prompt)
      end
    end
  end
end
