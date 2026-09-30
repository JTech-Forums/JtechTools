# frozen_string_literal: true

require "rails_helper"
require "rotp"

# Dumbcourse end to end, driven the way a flip phone drives it: arrow keys,
# OK (Enter), the soft keys (F1/F2 stand in for SoftLeft/SoftRight) and the
# keypad digits, on a 240×320 screen. Set JTECH_SCREENSHOT_GALLERY=1 to also
# save screenshots (tmp/capybara/dumbcourse_*.png).
RSpec.describe "Dumbcourse" do
  fab!(:category) { Fabricate(:category, name: "Flip Phones", color: "E45735") }
  fab!(:alice) do
    Fabricate(
      :user,
      username: "alice_k",
      name: "Alice Klein",
      trust_level: TrustLevel[2],
      password: "supersecretpassword1",
      active: true,
    )
  end
  fab!(:bob) do
    Fabricate(
      :user,
      username: "bob_m",
      name: "Bob Mizrachi",
      trust_level: TrustLevel[2],
      password: "anothersecretpass22",
      active: true,
    )
  end
  fab!(:topic) do
    Fabricate(
      :topic,
      user: alice,
      category: category,
      title: "Looking for a good kosher flip phone",
    )
  end
  fab!(:op) do
    Fabricate(
      :post,
      topic: topic,
      user: alice,
      raw: "Which one has the best battery? I tried the **Nokia 2780**.",
    )
  end
  fab!(:reply) do
    Fabricate(
      :post,
      topic: topic,
      user: bob,
      raw: "The Kyocera DuraXV lasts days. See https://example.com/duraxv for specs.",
    )
  end

  before do
    # Signing in also needs a confirmed email.
    alice.activate
    bob.activate
    SiteSetting.dumbcourse_enabled = true
    SiteSetting.reqpm_enabled = true
    SiteSetting.hide_new_user_profiles = false
  end

  def shot(name)
    return unless ENV["JTECH_SCREENSHOT_GALLERY"]
    page.save_screenshot("dumbcourse_#{name}.png")
  end

  def focused_key
    page.evaluate_script(
      "document.activeElement && document.activeElement.getAttribute('data-key')",
    )
  end

  def press(*keys)
    keys.each do |k|
      page.send_keys(k)
      sleep 0.05
    end
  end

  def phone(&block)
    resize_window(width: 240, height: 320, &block)
  end

  describe "signing in" do
    it "with a password, typed on the keypad" do
      phone do
        visit "/dumb/"
        expect(page).to have_css("#login")
        shot("01_sign_in")
        find("#login").send_keys("alice_k")
        press(:down)
        page.send_keys("supersecretpassword1", :enter)
        expect(page).to have_css(".row.topic", text: "Looking for a good kosher flip phone")
        expect(page).to have_css("#tbTitle", text: SiteSetting.title)
      end
    end

    it "asks for the two-factor code when the account has one" do
      totp = Fabricate(:user_second_factor_totp, user: alice)
      phone do
        visit "/dumb/login"
        find("#login").fill_in(with: "alice_k")
        find("#password").fill_in(with: "supersecretpassword1")
        find("[data-login-btn]").click
        expect(page).to have_css("#tfaCode")
        shot("02_two_factor")
        find("#tfaCode").fill_in(with: ROTP::TOTP.new(totp.data).now)
        find("[data-login-btn]").click
        expect(page).to have_css(".row.topic")
      end
    end

    it "says so when the password is wrong" do
      phone do
        visit "/dumb/login"
        find("#login").fill_in(with: "alice_k")
        find("#password").fill_in(with: "wrong password here")
        find("[data-login-btn]").click
        expect(page).to have_css("#authError", text: /incorrect/i)
      end
    end

    # The phone and the approving device run in one browser here (a second
    # browser can't be launched in every CI sandbox); the request spec
    # covers the two-session flow.
    it "by approving the phone from another device — the phone's side" do
      phone do
        visit "/dumb/login"
        click_link "Sign in with another device"
        expect(page).to have_css(".pair-code")
        shot("03_pair_code")
        code = find(".pair-code").text.delete("-")
        DiscourseDumbcourse::Pairing.approve!(code, alice)
        expect(page).to have_css(".row.topic", wait: 15)
        expect(page).to have_no_css("#login")
      end
    end

    it "by approving the phone from another device — the approver's side" do
      code, _secret =
        DiscourseDumbcourse::Pairing.start!(user_agent: "KAIOS/3.1 Firefox/84.0", ip: "10.0.0.8")
      sign_in(alice)
      visit "/dumb/link"
      find("#pairCode").fill_in(with: code.downcase.insert(4, "-"))
      find("[data-link] button[type=submit]").click
      expect(page).to have_css(".dialog-text", text: /Sign in this device as @alice_k/)
      expect(page).to have_css(".dialog-text", text: /KaiOS phone/)
      find(".dialog [data-ok]").click
      expect(page).to have_css(".dialog-title", text: "Approved")
      expect(DiscourseDumbcourse::Pairing.find(code)[:status]).to eq("approved")
    end

    it "from an emailed sign-in link" do
      token = Fabricate(:email_token, user: alice, scope: EmailToken.scopes[:email_login])
      phone do
        visit "/dumb/email-login/#{token.token}"
        expect(page).to have_css("[data-confirm] button[type=submit]")
        find("[data-confirm] button[type=submit]").click
        expect(page).to have_css(".row.topic")
      end
    end

    it "after setting a new password from an emailed reset link" do
      token = Fabricate(:email_token, user: alice, scope: EmailToken.scopes[:password_reset])
      phone do
        visit "/dumb/password-reset/#{token.token}"
        find("#newPass").fill_in(with: "a brand new long password")
        find("[data-reset] button[type=submit]").click
        expect(page).to have_css(".row.topic")
      end
      expect(alice.reload.confirm_password?("a brand new long password")).to eq(true)
    end
  end

  describe "reading and writing with the D-pad" do
    before { sign_in(bob) }

    it "opens a topic, moves post to post, and likes from the post's actions" do
      phone do
        visit "/dumb/"
        expect(page).to have_css(".row.topic")
        expect(focused_key).to eq("t#{topic.id}")
        shot("04_latest")
        press(:enter)
        expect(page).to have_css(".post[data-n='1']")
        press(:right)
        expect(focused_key).to eq("p1")
        press(:enter)
        expect(page).to have_css(".sheet-title", text: "#1")
        shot("05_post_sheet")
        find(".sheet-item", text: "Like").click
        expect(page).to have_css(".toast", text: "Liked")
        expect(
          PostAction.exists?(post_id: op.id, user_id: bob.id) ||
            DiscourseReactions::ReactionUser.exists?(post_id: op.id, user_id: bob.id),
        ).to eq(true)
      end
    end

    it "lists a post's links in its action sheet" do
      phone do
        visit "/dumb/t/#{topic.slug}/#{topic.id}"
        find(".post[data-n='2']").click
        press(:enter)
        expect(page).to have_css(".sheet-heading", text: /1 link in this post/i)
        expect(page).to have_css(".sheet-item[href='https://example.com/duraxv']")
      end
    end

    it "replies with the keypad and the soft keys" do
      phone do
        visit "/dumb/t/#{topic.slug}/#{topic.id}"
        expect(page).to have_css(".post[data-n='2']")
        find(".post[data-n='2']").click
        press("3")
        expect(page).to have_css("#cText")
        expect(page).to have_css(".c-context", text: "@bob_m")
        find("#cText").send_keys("Thanks, that is really useful to know!")
        shot("06_composer")
        press(:f2)
        expect(page).to have_css(".toast", text: "Reply posted")
        expect(page).to have_css(".post", text: "Thanks, that is really useful to know!")
      end
      expect(topic.posts.last.raw).to eq("Thanks, that is really useful to know!")
      expect(topic.posts.last.reply_to_post_number).to eq(2)
    end

    it "keeps a draft when the composer is closed, and discards it on request" do
      phone do
        visit "/dumb/t/#{topic.slug}/#{topic.id}"
        find("[data-act=reply-topic]").click
        find("#cText").send_keys("Half a thought")
        sleep 0.8
        press(:escape)
        expect(page).to have_no_css("#cText")
        visit "/dumb/drafts"
        expect(page).to have_css(".row", text: "Reply: Looking for a good kosher flip phone")
        find(".row", text: "Reply:").click
        find(".sheet-item", text: "Continue writing").click
        expect(page).to have_field("cText", with: "Half a thought")
      end
    end

    it "bookmarks a post" do
      phone do
        visit "/dumb/t/#{topic.slug}/#{topic.id}"
        find(".post[data-n='1']").click
        press(:enter)
        find(".sheet-item", text: "Bookmark").click
        expect(page).to have_css(".toast", text: "Bookmarked")
        expect(
          Bookmark.exists?(user_id: bob.id, bookmarkable_id: op.id, bookmarkable_type: "Post"),
        ).to eq(true)
        visit "/dumb/bookmarks"
        expect(page).to have_css(".row", text: "Looking for a good kosher flip phone")
      end
    end

    it "starts a new topic in a category" do
      phone do
        visit "/dumb/"
        press("3")
        expect(page).to have_css("#cTitle")
        find("#cTitle").fill_in(with: "Best case for the TCL Flip Pro")
        find("#cCat").select("Flip Phones")
        find("#cText").fill_in(with: "Mine keeps getting scratched. Any recommendations?")
        find("[data-c=send]").click
        expect(page).to have_css(".topic-title", text: "Best case for the TCL Flip Pro")
      end
      expect(Topic.last.category).to eq(category)
    end

    it "shows notifications and marks them read when opened" do
      notification =
        Notification.create!(
          notification_type: Notification.types[:mentioned],
          user_id: bob.id,
          topic_id: topic.id,
          post_number: 1,
          data: { topic_title: topic.title, display_username: "alice_k" }.to_json,
        )
      phone do
        visit "/dumb/"
        expect(page).to have_css("#tbBadge", text: "1")
        visit "/dumb/notifications"
        expect(page).to have_css(".row.notif.unread", text: "alice_k mentioned you in")
        shot("07_notifications")
        find(".row.notif").click
        expect(page).to have_css(".post[data-n='1']")
      end
      expect(notification.reload.read).to eq(true)
    end

    it "opens the menu with the left soft key" do
      phone do
        visit "/dumb/"
        press(:f1)
        expect(page).to have_css(".layer-drawer .menu-item", text: "Notifications")
        shot("08_menu")
        press(:escape)
        expect(page).to have_no_css(".layer-drawer")
      end
    end

    it "repeats the screen's soft-key actions in the menu" do
      phone do
        visit "/dumb/"
        expect(page).to have_css("#softkeys .sk-right", text: "Options")
        press("*")
        find(".layer-drawer .menu-item[data-menu=screen]", text: "Options").click
        expect(page).to have_css(".sheet-item", text: "New topic")
      end
    end

    it "learns a soft key the phone sends under another name" do
      phone do
        visit "/dumb/phone-keys"
        find(".row[data-which=softleft]").click
        expect(page).to have_css("#pk-softleft", text: "Press it now")
        press(:f9)
        expect(page).to have_css("#pk-softleft", text: "F9")
        expect(page).to have_css("#pkLast", text: "Left soft key")
        visit "/dumb/"
        press(:f9)
        expect(page).to have_css(".layer-drawer .menu-item", text: "Notifications")
      end
    end

    it "takes soft keys that some Android browsers only name on keyup" do
      phone do
        visit "/dumb/"
        expect(page).to have_css("#softkeys .sk-left")
        page.execute_script(<<~JS)
          function fire(type, key, keyCode) {
            var e = new KeyboardEvent(type, { key: key, bubbles: true, cancelable: true });
            Object.defineProperty(e, "keyCode", { get: function () { return keyCode; } });
            document.body.dispatchEvent(e);
          }
          fire("keydown", "Unidentified", 229);
          fire("keyup", "SoftLeft", 0);
        JS
        expect(page).to have_css(".layer-drawer .menu-item", text: "Notifications")
      end
    end

    it "remembers the theme and text size" do
      phone do
        visit "/dumb/preferences"
        find(".row[data-pref=theme]").click
        find(".sheet-item", text: "Light").click
        expect(page).to have_css("html.light")
        find(".row[data-pref=textSize]").click
        find(".sheet-item", text: "125%").click
        visit "/dumb/"
        expect(page).to have_css("html.light")
        expect(page.evaluate_script("document.documentElement.style.fontSize")).to eq("18.75px")
      end
    end
  end

  describe "REQ-PM" do
    it "asks someone for their contact details from their profile" do
      sign_in(bob)
      phone do
        visit "/dumb/u/alice_k"
        find("a", text: "Contact details").click
        expect(page).to have_css("[data-act=ask]")
        find("[data-act=ask]").click
        expect(page).to have_css(".toast", text: "Request sent.")
        expect(page).to have_css(".notice", text: "Requested")
      end
      expect(DiscourseReqpm::Request.where(requester_id: bob.id, target_id: alice.id)).to exist
    end
  end

  describe "moderation" do
    fab!(:moderator) { Fabricate(:moderator, username: "mod_m") }

    it "closes a topic from the topic menu" do
      sign_in(moderator)
      phone do
        visit "/dumb/t/#{topic.slug}/#{topic.id}"
        expect(page).to have_css(".topic-head")
        press(:f2)
        find(".sheet-item", text: "Close topic").click
        expect(page).to have_css(".toast", text: "Done")
      end
      expect(topic.reload.closed).to eq(true)
    end
  end

  it "signs out and forgets the account's drafts" do
    sign_in(bob)
    phone do
      visit "/dumb/t/#{topic.slug}/#{topic.id}"
      find("[data-act=reply-topic]").click
      find("#cText").send_keys("Private draft")
      sleep 0.8
      press(:escape)
      visit "/dumb/logout"
      find(".dialog [data-ok]").click
      expect(page).to have_css("#login")
      stored = page.evaluate_script("JSON.stringify(Object.keys(localStorage))")
      expect(stored).not_to include("dc:user:")
    end
  end
end
