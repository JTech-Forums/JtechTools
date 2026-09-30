# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseTranslatorTweaks do
  let(:google) do
    Class.new do
      const_set(:TRANSLATE_URI, "https://translation.googleapis.com/language/translate/v2")
      const_set(:DETECT_URI, "https://translation.googleapis.com/language/translate/v2/detect")
      const_set(:SUPPORT_URI, "https://translation.googleapis.com/language/translate/v2/languages")
    end
  end

  it "points all three endpoints at the proxy" do
    described_class.apply_proxy!(google, "https://proxy.example.com/language/translate/v2/")

    expect(google::TRANSLATE_URI).to eq("https://proxy.example.com/language/translate/v2")
    expect(google::DETECT_URI).to eq("https://proxy.example.com/language/translate/v2/detect")
    expect(google::SUPPORT_URI).to eq("https://proxy.example.com/language/translate/v2/languages")
  end

  it "leaves Google alone when no proxy is set" do
    described_class.apply_proxy!(google, "  ")
    expect(google::TRANSLATE_URI).to start_with("https://translation.googleapis.com")
  end
end
