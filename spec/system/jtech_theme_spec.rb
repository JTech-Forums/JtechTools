# frozen_string_literal: true

require "rails_helper"

# Installs the bundled JTech theme, makes it the default and walks the main
# pages on desktop and mobile. Fails when the theme throws, logs a theme error,
# trips a deprecation (system specs raise on those), or a JTech surface that
# should render doesn't. This is the CI guard for "a Discourse update broke the
# theme": CI runs against Discourse `latest`.
#
# Screenshots land in tmp/capybara/jtech_theme/ (uploaded by the Feature
# Screenshots workflow).
RSpec.describe "JTech theme" do
  fab!(:jtech_theme) do
    DiscourseJtechTheme::Installer.sync_now
    DiscourseJtechTheme::Installer.theme
  end
  fab!(:admin) { Fabricate(:admin, username: "jt_admin", name: "Jay Admin") }
  fab!(:member) do
    Fabricate(:user, username: "jt_member", name: "Morgan Member", trust_level: TrustLevel[2])
  end
  fab!(:category) { Fabricate(:category, name: "Filtering", description: "Filters and setups.") }
  fab!(:tag) { Fabricate(:tag, name: "android") }
  fab!(:topic) do
    Fabricate(
      :topic,
      category: category,
      user: member,
      tags: [tag],
      title: "Which filter works best on a flip phone?",
    )
  end
  fab!(:first_post) do
    Fabricate(
      :post,
      topic: topic,
      user: member,
      raw:
        "I'm setting up a flip phone and want something that blocks the browser.\n\n```ruby\nputs 1\n```\n\n[Read more](https://example.com/guide)",
    )
  end
  fab!(:replies) do
    Array.new(3) { |i| Fabricate(:post, topic: topic, user: admin, raw: "Reply number #{i + 1}.") }
  end
  fab!(:more_topics) do
    Array.new(4) do |i|
      t = Fabricate(:topic, category: category, user: admin, title: "Another useful topic #{i + 1}")
      Fabricate(:post, topic: t, user: admin, raw: "Body of topic #{i + 1}.")
      t
    end
  end

  before do
    SiteSetting.jtech_enabled = true
    jtech_theme.set_default!
    DirectoryItem.refresh!
  end

  def shot(name)
    dir = Rails.root.join("tmp/capybara/jtech_theme")
    FileUtils.mkdir_p(dir)
    page.save_screenshot(dir.join("#{name}-#{is_mobile? ? "mobile" : "desktop"}.png").to_s)
  end

  # Theme errors are reported as "[THEME <id> 'JTech'] …" on the console and,
  # for admins, as a banner. Page errors (uncaught exceptions) count as well.
  def expect_no_theme_errors
    expect(page).to have_no_css(".broken-theme-alert-banner")
    errors =
      $playwright_logger.logs.select do |log|
        log[:level] == "error" &&
          (log[:source] == "pageerror-api" || log[:message].include?("THEME #{jtech_theme.id}"))
      end
    expect(errors.map { |e| e[:message] }).to eq([])
  end

  def visit_and_check(path, *selectors, name:)
    visit(path)
    expect(page).to have_css("#main-outlet")
    selectors.each { |selector| expect(page).to have_css(selector) }
    shot(name)
    expect_no_theme_errors
  end

  shared_examples "renders the main pages" do
    it "renders without theme errors" do
      sign_in(user) if user

      visit_and_check("/latest", ".jt-hero", ".jt-card", ".jt-footer", name: "#{role}-latest")
      visit_and_check("/categories", ".jt-footer", name: "#{role}-categories")
      visit_and_check(
        "/c/#{category.slug}/#{category.id}",
        ".jt-banner",
        ".jt-card",
        name: "#{role}-category",
      )
      visit_and_check("/tag/#{tag.name}", ".jt-banner", name: "#{role}-tag")
      visit_and_check(topic.relative_url, ".topic-post", name: "#{role}-topic")
      visit_and_check("/u", ".directory-table", name: "#{role}-users")
      visit_and_check("/u/#{member.username}/summary", ".user-main", name: "#{role}-profile")
      visit_and_check("/search?q=filter", ".search-container", name: "#{role}-search")
    end
  end

  context "when anonymous" do
    let(:user) { nil }
    let(:role) { "anon" }

    include_examples "renders the main pages"
    context "on mobile", mobile: true do
      include_examples "renders the main pages"
    end
  end

  context "when signed in" do
    let(:user) { member }
    let(:role) { "member" }

    include_examples "renders the main pages"
    context "on mobile", mobile: true do
      include_examples "renders the main pages"
    end
  end

  context "when signed in as an admin" do
    let(:user) { admin }
    let(:role) { "admin" }

    include_examples "renders the main pages"
  end

  it "opens the command menu with Ctrl+K and finds a topic" do
    SiteSetting.chat_enabled = false
    SearchIndexer.enable
    SearchIndexer.index(topic, force: true)
    SearchIndexer.index(first_post, force: true)
    sign_in(member)
    visit("/latest")
    expect(page).to have_css(".jt-header-search__keys")

    send_keys([:control, "k"])
    expect(page).to have_css(".jt-cmdk")
    shot("cmdk-open")

    find(".jt-cmdk__input").fill_in(with: "flip phone")
    expect(page).to have_css(".jt-cmdk__item", text: topic.title)
    shot("cmdk-results")
    expect_no_theme_errors

    send_keys(:escape)
    expect(page).to have_no_css(".jt-cmdk")
  end

  it "leaves Ctrl+K to chat for people who can chat" do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
    sign_in(member)
    visit("/latest")
    expect(page).to have_css(".jt-header-search__button")
    expect(page).to have_no_css(".jt-header-search__keys")

    find(".jt-header-search__button").click
    expect(page).to have_css(".jt-cmdk")
    expect_no_theme_errors
  end

  it "previews a topic's first post in Quick look" do
    sign_in(member)
    visit("/latest")
    card = find(".topic-list-item[data-topic-id='#{topic.id}']")
    card.hover # the button shows on hover where there is one
    card.find(".jt-card__peek").click
    expect(page).to have_css(".jt-quick-look .cooked", text: "blocks the browser")
    shot("quick-look")
    expect_no_theme_errors
  end

  it "doesn't offer Quick look to visitors, so it can't get round a login gate" do
    visit("/latest")
    expect(page).to have_css(".jt-card")
    expect(page).to have_no_css(".jt-card__peek")
  end

  it "starts a topic in the tag being viewed from the header's +" do
    sign_in(member)
    visit("/tag/#{tag.name}")
    find(".jt-header-new-topic button").click
    expect(page).to have_css("#reply-control.open")
    expect(page).to have_css("#reply-control .mini-tag-chooser", text: tag.name)
    expect_no_theme_errors
  end

  it "sends links that aren't forum pages to the browser" do
    visit("/latest")
    expect(page).to have_css(".jt-header-home a[href='/home'][data-auto-route='true']")
    expect(page).to have_css(".jt-footer a[href='/latest']:not([data-auto-route])")
  end

  describe "header icons" do
    # Every visible icon in the header row, the theme's and core's and chat's:
    # one glyph size, one vertical centre. The desktop search field has its
    # own, smaller magnifier.
    def header_glyphs(skip: ".current-user")
      page.evaluate_script(<<~JS)
        [...document.querySelectorAll(".d-header-icons > li:not(#{skip}) svg.d-icon")]
          .map((svg) => svg.getBoundingClientRect())
          .filter((r) => r.width > 0)
          .map((r) => [Math.round(r.width), Math.round(r.top + r.height / 2)])
      JS
    end

    before do
      SiteSetting.chat_enabled = true
      SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
      sign_in(member)
    end

    it "are all one size" do
      visit("/latest")
      expect(page).to have_css(".chat-header-icon .d-icon")
      glyphs = header_glyphs(skip: ".current-user, .jt-header-search")
      expect(glyphs.size).to be >= 5
      expect(glyphs.uniq.size).to eq(1)
    end

    it "are all one size on phones", mobile: true do
      visit("/latest")
      expect(page).to have_css(".hamburger-dropdown .d-icon")
      glyphs = header_glyphs
      expect(glyphs.size).to be >= 4
      expect(glyphs.uniq.size).to eq(1)
    end
  end

  describe "what used to be separate components" do
    fab!(:lonely_topic) do
      Fabricate(:topic, category: category, user: admin, title: "A topic nobody answered yet")
    end
    fab!(:lonely_post) do
      Fabricate(
        :post,
        topic: lonely_topic,
        user: admin,
        raw:
          "Line one of the guide.\n\n```bash\necho one\necho two\necho three\n```\n\nSee [the homepage](/home) or [latest](/latest).",
      )
    end

    it "prompts for the first reply and numbers code lines" do
      sign_in(member)
      visit(lonely_topic.relative_url)
      expect(page).to have_css(".jt-first-reply", text: "Be the first to reply")
      expect(page).to have_css("pre.jt-numbered .jt-lines", text: "1\n2\n3")
      shot("first-reply")
      expect_no_theme_errors
    end

    it "doesn't prompt once someone has replied" do
      sign_in(member)
      visit(topic.relative_url)
      expect(page).to have_css(".topic-post")
      expect(page).to have_no_css(".jt-first-reply")
    end

    it "opens links to non-forum pages in posts as a page load" do
      visit(lonely_topic.relative_url)
      expect(page).to have_css(".cooked a[href='/home'][data-auto-route='true']")
      expect(page).to have_css(".cooked a[href='/latest']:not([data-auto-route])")
    end

    it "shows jump buttons under the timeline" do
      sign_in(member)
      visit(topic.relative_url)
      expect(page).to have_css(".timeline-container .jt-jump .jt-jump__bottom")
      expect_no_theme_errors
    end

    it "shows when someone was last seen on their user card" do
      member.update!(last_seen_at: 2.hours.ago)
      sign_in(admin)
      visit(topic.relative_url)
      find("#post_1 .main-avatar[data-user-card='#{member.username}']").click
      expect(page).to have_css(".user-card .jt-last-seen")
      expect_no_theme_errors
    end

    it "shows the small logo on phones", mobile: true do
      SiteSetting.logo_small = Fabricate(:image_upload)
      visit("/latest")
      expect(page).to have_css("#site-logo.logo-mobile[src*='#{SiteSetting.logo_small.url}']")
    end

    it "keeps a mobile logo the admin uploaded", mobile: true do
      SiteSetting.logo_small = Fabricate(:image_upload)
      SiteSetting.mobile_logo = Fabricate(:image_upload)
      visit("/latest")
      expect(page).to have_css("#site-logo.logo-mobile[src*='#{SiteSetting.mobile_logo.url}']")
    end

    it "styles core's category boxes" do
      SiteSetting.desktop_category_page_style = "categories_boxes"
      visit("/categories")
      expect(page).to have_css(".category-boxes .category-box")
      shot("category-boxes")
      expect_no_theme_errors
    end
  end

  it "shows the dark palette when the browser prefers dark" do
    page.driver.with_playwright_page { |pw| pw.emulate_media(colorScheme: "dark") }
    sign_in(member)
    visit("/latest")
    expect(page).to have_css(".jt-card")
    background = page.evaluate_script("getComputedStyle(document.body).backgroundColor")
    expect(background).to eq("rgb(0, 0, 0)")
    shot("dark-latest")
    visit(topic.relative_url)
    expect(page).to have_css(".topic-post")
    shot("dark-topic")
    expect_no_theme_errors
  end
end
