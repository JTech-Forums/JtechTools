# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::DiscourseJtechTheme::Installer do
  before do
    SiteSetting.jtech_enabled = true
    SiteSetting.jtech_theme_install = true
  end

  def installed
    described_class.theme
  end

  describe ".sync_now" do
    it "installs the bundled theme without making it the default or user-selectable" do
      result = nil
      expect { result = described_class.sync_now }.to change { Theme.count }.by(1)
      expect(result).to eq(:installed)

      theme = installed
      expect(theme.name).to eq("JTech")
      expect(theme.component).to eq(false)
      expect(theme.id).to be > 0
      expect(theme.user_selectable).to eq(false)
      expect(SiteSetting.default_theme_id).not_to eq(theme.id)
      expect(theme.color_schemes.pluck(:name)).to contain_exactly("JTech Light", "JTech Dark")
      expect(described_class.state["digest"]).to eq(described_class.digest)
    end

    it "does nothing when the bundled theme hasn't changed" do
      described_class.sync_now
      theme = installed

      result = nil
      expect { result = described_class.sync_now }.not_to change { Theme.count }
      expect(result).to eq(:unchanged)
      expect(installed.updated_at).to eq_time(theme.updated_at)
    end

    it "updates the same theme when the bundled theme changes" do
      described_class.sync_now
      id = installed.id
      described_class.save_state(described_class.state.merge("digest" => "older"))

      result = nil
      expect { result = described_class.sync_now }.not_to change { Theme.count }
      expect(result).to eq(:updated)
      expect(installed.id).to eq(id)
      expect(described_class.state["digest"]).to eq(described_class.digest)
    end

    it "keeps admin choices when it updates" do
      described_class.sync_now
      theme = installed
      theme.update!(user_selectable: true)
      SiteSetting.default_theme_id = theme.id
      described_class.save_state(described_class.state.merge("digest" => "older"))

      described_class.sync_now

      expect(installed.user_selectable).to eq(true)
      expect(SiteSetting.default_theme_id).to eq(theme.id)
    end

    it "leaves a theme an admin deleted deleted" do
      described_class.sync_now
      installed.destroy!

      result = nil
      expect { result = described_class.sync_now }.not_to change { Theme.count }
      expect(result).to eq(:removed)
      expect(described_class.state["removed_at"]).to be_present
      expect(described_class.sync_now).to eq(:removed)
    end
  end

  describe ".reinstall!" do
    it "brings back a theme an admin deleted" do
      described_class.sync_now
      installed.destroy!
      described_class.sync_now

      expect { described_class.reinstall! }.to change { Theme.count }.by(1)
      expect(installed).to be_present
      expect(described_class.state["removed_at"]).to be_nil
    end
  end

  describe ".sync!" do
    it "stays out of test databases unless asked" do
      expect(described_class.sync!).to eq(:skipped_test)
      expect(installed).to be_nil
    end

    context "when asked to run" do
      around do |example|
        ENV["JTECH_THEME_SEED"] = "1"
        example.run
      ensure
        ENV.delete("JTECH_THEME_SEED")
      end

      it "does nothing when the module is switched off" do
        SiteSetting.jtech_theme_install = false
        expect(described_class.sync!).to eq(:disabled)
        expect(installed).to be_nil
      end

      it "does nothing when the bundle is switched off" do
        SiteSetting.jtech_enabled = false
        expect(described_class.sync!).to eq(:disabled)
        expect(installed).to be_nil
      end

      it "never raises, so a failed import can't stop a migration" do
        allow(RemoteTheme).to receive(:import_theme_from_directory).and_raise(
          StandardError,
          "broken theme",
        )
        expect(described_class.sync!).to eq(:failed)
      end
    end
  end
end
