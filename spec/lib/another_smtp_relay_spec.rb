# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseAnotherSmtp::Relay do
  let(:global_settings) do
    {
      address: "localhost",
      port: 1025,
      domain: "localhost.localdomain",
      user_name: nil,
      password: nil,
      authentication: nil,
      enable_starttls: nil,
      enable_starttls_auto: true,
      openssl_verify_mode: nil,
      ssl: nil,
      tls: nil,
      open_timeout: 5,
      read_timeout: 5,
    }
  end

  def build_message(from: "Forum <noreply@forum.example>")
    message = Mail::Message.new
    message.from = from
    message.to = "someone@example.com"
    message.subject = "hi"
    message.delivery_method(Mail::SMTP, global_settings)
    message
  end

  def send_hook(message, type = :digest)
    DiscourseEvent.trigger(:before_email_send, message, type)
    message.delivery_method.settings
  end

  before do
    SiteSetting.discourse_another_email_enabled = true
    SiteSetting.discourse_another_email_smtp_address = "smtp.relay.example"
    SiteSetting.discourse_another_email_smtp_port = 2525
    SiteSetting.discourse_another_email_smtp_username = "apikey"
    SiteSetting.discourse_another_email_smtp_password = "s3cret"
  end

  it "points the message at the relay and logs in" do
    settings = send_hook(build_message)

    expect(settings).to include(
      address: "smtp.relay.example",
      port: 2525,
      authentication: "plain",
      user_name: "apikey",
      password: "s3cret",
      enable_starttls_auto: true,
      openssl_verify_mode: "peer",
    )
    expect(settings[:tls]).to be_nil
    expect(settings[:domain]).to eq("localhost.localdomain")
  end

  it "leaves the server's relay alone while switched off" do
    SiteSetting.discourse_another_email_enabled = false
    expect(send_hook(build_message)).to include(address: "localhost", port: 1025)
  end

  it "leaves the server's relay alone while the master switch is off" do
    SiteSetting.jtech_enabled = false
    expect(send_hook(build_message)).to include(address: "localhost")
  end

  it "does nothing without a relay address" do
    SiteSetting.discourse_another_email_smtp_address = ""
    expect(send_hook(build_message)).to include(address: "localhost")
  end

  it "keeps group inbox mail on the group's own mail server" do
    expect(send_hook(build_message, :group_smtp)).to include(address: "localhost")

    Fabricate(
      :group,
      smtp_enabled: true,
      smtp_server: "smtp.gmail.com",
      smtp_port: 587,
      email_username: "support@forum.example",
      email_password: "pw",
    )
    message = build_message(from: "Support <support@forum.example>")
    expect(send_hook(message, :user_private_message)).to include(address: "localhost")
    expect(message.from).to eq(["support@forum.example"])
  end

  describe "transport security" do
    it "uses implicit TLS without STARTTLS" do
      SiteSetting.discourse_another_email_smtp_security = "tls"
      settings = send_hook(build_message)
      expect(settings).to include(
        tls: true,
        ssl: true,
        enable_starttls: false,
        enable_starttls_auto: false,
      )
    end

    it "requires STARTTLS" do
      SiteSetting.discourse_another_email_smtp_security = "starttls_always"
      settings = send_hook(build_message)
      expect(settings).to include(enable_starttls: :always, enable_starttls_auto: nil, tls: nil)
    end

    it "can send in the clear" do
      SiteSetting.discourse_another_email_smtp_security = "none"
      settings = send_hook(build_message)
      expect(settings).to include(enable_starttls: false, enable_starttls_auto: false, tls: nil)
    end

    it "produces settings Mail::SMTP accepts" do
      %w[tls starttls_always starttls_auto none].each do |mode|
        SiteSetting.discourse_another_email_smtp_security = mode
        message = build_message
        send_hook(message)
        smtp = Mail::SMTP.new(message.delivery_method.settings)
        expect { smtp.send(:build_smtp_session) }.not_to raise_error
      end
    end
  end

  describe "authentication" do
    it "skips AUTH when the mode is none" do
      SiteSetting.discourse_another_email_smtp_authentication_mode = "none"
      expect(send_hook(build_message)).to include(
        authentication: nil,
        user_name: nil,
        password: nil,
      )
    end

    it "skips AUTH rather than sending empty credentials" do
      SiteSetting.discourse_another_email_smtp_username = ""
      SiteSetting.discourse_another_email_smtp_password = ""
      expect(send_hook(build_message)).to include(authentication: nil, user_name: nil)
    end
  end

  it "announces the configured HELO domain" do
    SiteSetting.discourse_another_email_smtp_domain = "forum.example"
    expect(send_hook(build_message)[:domain]).to eq("forum.example")
  end

  describe "from rewriting" do
    it "swaps the From domain and keeps the display name" do
      SiteSetting.discourse_another_email_force_from_domain = "example.com"
      message = build_message
      send_hook(message)
      expect(message[:from].to_s).to eq("Forum <noreply@example.com>")
    end

    it "logs in as the sender without its +tag" do
      SiteSetting.discourse_another_email_force_from_domain = "example.com"
      SiteSetting.discourse_another_email_force_smtp_username_to_sender = true
      settings = send_hook(build_message(from: "noreply+digest@forum.example"))
      expect(settings[:user_name]).to eq("noreply@example.com")
    end

    it "does not turn AUTH back on for the sender" do
      SiteSetting.discourse_another_email_smtp_authentication_mode = "none"
      SiteSetting.discourse_another_email_force_smtp_username_to_sender = true
      expect(send_hook(build_message)[:user_name]).to be_nil
    end
  end

  it "never lets a broken setting stop the email" do
    SiteSetting.stubs(:discourse_another_email_force_from_domain).raises(StandardError, "boom")
    Rails.logger.expects(:error).with(regexp_matches(/boom/))
    expect { send_hook(build_message) }.not_to raise_error
  end

  it "reroutes real mail sent through Email::Sender" do
    user = Fabricate(:user)
    message = TestMailer.send_test(user.email)
    Email::Sender.new(message, :test_message).send
    expect(message.delivery_method.settings[:address]).to eq("smtp.relay.example")
  end

  describe ProblemCheck::AnotherSmtpUnconfigured do
    subject(:check) { described_class.new }

    it "warns when the relay is on without an address" do
      SiteSetting.discourse_another_email_smtp_address = ""
      expect(check.call).to be_present
    end

    it "is quiet once an address is set, or the relay is off" do
      expect(check.call).to be_blank
      SiteSetting.discourse_another_email_smtp_address = ""
      SiteSetting.discourse_another_email_enabled = false
      expect(check.call).to be_blank
    end
  end
end
