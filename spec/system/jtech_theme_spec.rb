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

  # Core's about page: stats on a ruled strip, staff as avatar + name, the
  # right column as plain text. The theme: tiles, cards, one ruled card.
  it "shows the about page's counts as tiles, its staff as cards" do
    sign_in(member)
    visit("/about")
    # members and "created" always; admins / moderators only when core lists
    # someone, which it doesn't in this database
    expect(page).to have_css(".about__stats-item", minimum: 2)
    expect(page).to have_css(".about__right-side .about__activities-item")

    borders, tile_tops, staff_border = page.evaluate_script(<<~JS)
      [
        [".about__stats-item", ".about__right-side"]
          .map((selector) => getComputedStyle(document.querySelector(selector)).borderTopWidth),
        [...document.querySelectorAll(".about__stats-item")]
          .slice(0, 2)
          .map((tile) => Math.round(tile.getBoundingClientRect().top)),
        [...document.querySelectorAll(".about-page-users-list .user-info")]
          .map((card) => getComputedStyle(card).borderTopWidth),
      ]
    JS
    expect(borders).to eq(%w[1px 1px])
    expect(tile_tops[0]).to eq(tile_tops[1]) # a row of tiles, not a column
    expect(staff_border.uniq).to eq(["1px"]).or eq([]) # cards, when there are staff to show
    expect_no_theme_errors
  end

  describe "the avatar's menu" do
    it "opens on the profile tab, and the bell on notifications" do
      sign_in(member)
      visit("/latest")
      find("#toggle-current-user").click
      expect(page).to have_css("#user-menu-button-profile.active")

      find(".jt-header-notifications > .icon").click
      expect(page).to have_css("#user-menu-button-all-notifications.active")
      expect_no_theme_errors
    end

    it "opens on the review queue while the avatar's badge says something is waiting" do
      Fabricate(:reviewable)
      sign_in(admin)
      visit("/latest")
      expect(page).to have_css("#toggle-current-user .badge-notification.new-reviewables")
      find("#toggle-current-user").click
      expect(page).to have_css("#user-menu-button-review-queue.active")
      expect_no_theme_errors
    end
  end

  # Core's log in page: a bare form beside the other ways in. The theme puts
  # both on one card and makes the fields its own 44px controls.
  it "puts the log in page's form and other ways in on one card" do
    visit("/login")
    expect(page).to have_css(".login-fullpage #login-account-name")
    border, field_height = page.evaluate_script(<<~JS)
      [
        getComputedStyle(document.querySelector(".login-fullpage .login-body")).borderTopWidth,
        Math.round(document.querySelector("#login-account-name").getBoundingClientRect().height),
      ]
    JS
    expect(border).to eq("1px")
    expect(field_height).to eq(44)
    expect(page).to have_no_css(".jt-footer")
    expect_no_theme_errors
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

  # Core's /badges: boxes with a faint border under grey group headings. The
  # theme: cards under small labels, and a badge's own page on its big card.
  it "shows badges as cards under group labels" do
    sign_in(member)
    visit("/badges")
    expect(page).to have_css(".badge-groups .badge-card .badge-link", minimum: 1)
    border, label_case = page.evaluate_script(<<~JS)
      [
        getComputedStyle(document.querySelector(".badge-card")).borderTopWidth,
        getComputedStyle(document.querySelector(".badge-grouping .title h2")).textTransform,
      ]
    JS
    expect(border).to eq("1px")
    expect(label_case).to eq("uppercase")

    find(".badge-card .badge-link", match: :first).click
    expect(page).to have_css(".show-badge .badge-card.--badge-large")
    expect_no_theme_errors
  end

  it "shows each command's keyboard shortcut, and binds the theme's own" do
    SiteSetting.chat_enabled = false
    sign_in(member)
    visit("/latest")
    send_keys([:control, "k"])
    expect(page).to have_css(".jt-cmdk__item", text: "Latest")
    keys = page.evaluate_script(<<~JS)
      Object.fromEntries(
        [...document.querySelectorAll(".jt-cmdk__item")].map((row) => [
          row.querySelector(".jt-cmdk__label").textContent.trim(),
          [...row.querySelectorAll(".jt-cmdk__keys kbd")].map((k) => k.textContent).join(" "),
        ])
      )
    JS
    expect(keys).to include(
      "Latest" => "g l",
      "Notifications" => "g i",
      "Preferences" => "g e",
      "Keyboard shortcuts" => "?",
    )
    shot("cmdk-shortcuts")

    send_keys(:escape)
    expect(page).to have_no_css(".jt-cmdk")
    send_keys("g", "i")
    expect(page).to have_current_path("/u/#{member.username}/notifications")
    expect_no_theme_errors
  end

  # Core's /g: boxes with a faint border under a loose row of filters, and a
  # group's members table bare. The theme: cards under a toolbar of equal
  # controls, and the users directory's table card for the members.
  # A grid item is as wide as its longest unbreakable word, so a long group
  # handle pushed every group card past a phone's edge.
  it "fits group cards with long handles on a phone", mobile: true do
    Fabricate(:group, name: "filtering_specialist", full_name: "Filteringspecialistsandhelpers")
    sign_in(member)
    visit("/g")
    expect(page).to have_css(".groups-boxes .group-box")
    widths = page.evaluate_script(<<~JS)
      ({ page: document.documentElement.scrollWidth, window: document.documentElement.clientWidth })
    JS
    expect(widths["page"]).to eq(widths["window"])
    expect_no_theme_errors
  end

  # Core turns the outline off on buttons (.btn:focus-visible, and on desktop
  # .discourse-no-touch nav.post-controls .actions button:focus-visible) and
  # marks focus with the hover fill, which the theme's quiet buttons barely
  # have: keyboard focus vanished on most of them.
  it "rings a button that has keyboard focus, inside the post menu too" do
    sign_in(member)
    visit("/t/#{topic.slug}/#{topic.id}")
    expect(page).to have_css("#post_1 nav.post-controls .actions button.reply")
    send_keys(:tab) # keyboard first, so the focus() calls below count as keyboard focus
    rings = page.evaluate_script(<<~JS)
      ["#toggle-current-user", "#post_1 nav.post-controls .actions button.reply"].map((selector) => {
        const button = document.querySelector(selector);
        button.focus();
        const style = getComputedStyle(button);
        return [
          button.matches(":focus-visible"),
          style.outlineStyle,
          Math.sign(parseFloat(style.outlineOffset)),
        ];
      })
    JS
    expect(rings[0]).to eq([true, "solid", 1])
    # the post menu scrolls sideways, so the ring is drawn inside the button
    expect(rings[1]).to eq([true, "solid", -1])
    expect_no_theme_errors
  end

  it "shows groups as cards, and a group's members in the directory's table card" do
    sign_in(admin)
    visit("/g")
    expect(page).to have_css(".groups-boxes .group-box", minimum: 2)
    box_border, filter_height = page.evaluate_script(<<~JS)
      [
        getComputedStyle(document.querySelector(".group-box")).borderTopWidth,
        Math.round(document.querySelector(".groups-header-filters-name").getBoundingClientRect().height),
      ]
    JS
    expect(box_border).to eq("1px")
    expect(filter_height).to eq(38) # 2.4rem, like the other controls

    visit("/g/staff")
    expect(page).to have_css(".group-members .directory-table__row", text: admin.username)
    card_border = page.evaluate_script(<<~JS)
      getComputedStyle(document.querySelector(".container.group .horizontal-scroll-sync__content")).borderTopWidth
    JS
    expect(card_border).to eq("1px")
    expect_no_theme_errors
  end

  # On phones the command menu showed keyboard hints beside its tap targets:
  # an "esc" keycap next to the x (the keycap rule outweighed the touch one)
  # and a return-key glyph on the active row.
  it "drops the command menu's keyboard hints on phones", mobile: true do
    SiteSetting.chat_enabled = false
    sign_in(member)
    visit("/latest")
    expect(page).to have_css(".jt-card")
    find(".jt-header-search__button").click
    expect(page).to have_css(".jt-cmdk .jt-cmdk__item.--active")
    hints = page.evaluate_script(<<~JS)
      (() => {
        const close = document.querySelector(".jt-cmdk__esc");
        const shown = (el) => getComputedStyle(el).display !== "none";
        return {
          esc: shown(close.querySelector("kbd")),
          x: shown(close.querySelector(".d-icon")),
          enter: shown(document.querySelector(".jt-cmdk__item.--active .jt-cmdk__enter")),
        };
      })()
    JS
    expect(hints).to eq("esc" => false, "x" => true, "enter" => false)
    expect_no_theme_errors
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

  # Core's text-only empty states are a heading and a paragraph at the top
  # left of a blank page; the theme puts them on a centred card with a glyph.
  # Core's error page was ":(" in huge type over the reason; the theme draws
  # it as the empty states' card with a glyph chip. Reached the way core's own
  # spec does: a hidden profile, visited logged out.
  it "shows the error page on the empty states' card" do
    SiteSetting.hide_user_profiles_from_public = true
    visit("/u/#{member.username}")
    expect(page).to have_css(".error-page .reason")
    looks = page.evaluate_script(<<~JS)
      (() => {
        const card = getComputedStyle(document.querySelector(".error-page"));
        const face = document.querySelector(".error-page .face");
        return {
          card: card.borderTopWidth,
          face: getComputedStyle(face).fontSize,
          glyph: getComputedStyle(face, "::after").content,
        };
      })()
    JS
    expect(looks).to eq("card" => "1px", "face" => "0px", "glyph" => '""')
    shot("error-page")
    expect_no_theme_errors
  end

  it "shows an empty page's message on a centred card" do
    sign_in(member)
    visit("/u/#{member.username}/activity/bookmarks")
    expect(page).to have_css(".empty-state__container.--text-only .empty-state__title")
    border, centred = page.evaluate_script(<<~JS)
      (() => {
        const card = document.querySelector(".empty-state__container.--text-only");
        const outlet = document.querySelector("#main-outlet").getBoundingClientRect();
        const r = card.getBoundingClientRect();
        return [
          getComputedStyle(card).borderTopWidth,
          Math.abs((r.left - outlet.left) - (outlet.right - r.right)) <= 1,
        ];
      })()
    JS
    expect(border).to eq("1px")
    expect(centred).to eq(true)
    expect_no_theme_errors
  end

  it "centres the search field on the header bar on wide screens" do
    sign_in(member)
    visit("/latest")
    expect(page).to have_css(".jt-header-search--centered .jt-header-search__button")
    expect(page).to have_no_css(".d-header-icons .jt-header-search__button")
    bar_centre, field_centre = page.evaluate_script(<<~JS)
      [".d-header > .wrap > .contents", ".jt-header-search--centered .jt-header-search__button"]
        .map((selector) => document.querySelector(selector).getBoundingClientRect())
        .map((r) => r.left + r.width / 2)
    JS
    expect(field_centre).to be_within(1).of(bar_centre)
    expect_no_theme_errors
  end

  # Core's notifications page: a bare list under two filters; unread type
  # badges in the accent colour. The theme: a toolbar, a card, black / white.
  it "lists notifications on a card, with unread type badges in the text colour" do
    Fabricate(
      :notification,
      user: member,
      topic: topic,
      post_number: first_post.post_number,
      notification_type: Notification.types[:mentioned],
      read: false,
      data: {
        topic_title: topic.title,
        original_post_id: first_post.id,
        original_username: admin.username,
        display_username: admin.username,
      }.to_json,
    )
    SiteSetting.show_user_menu_avatars = true # the badge sits on the avatar
    sign_in(member)
    visit("/u/#{member.username}/notifications")
    expect(page).to have_css(
      ".user-notifications-list li.notification.unread .icon-avatar__icon-wrapper",
    )

    card_border, filter_height, badge_bg, label_color = page.evaluate_script(<<~JS)
      (() => {
        const row = document.querySelector(".user-notifications-list li.notification.unread");
        return [
          getComputedStyle(document.querySelector(".user-notifications-list")).borderTopWidth,
          Math.round(document.querySelector(".user-notifications-filter .select-kit-header").getBoundingClientRect().height),
          getComputedStyle(row.querySelector(".icon-avatar__icon-wrapper")).backgroundColor,
          getComputedStyle(row.querySelector(".item-label")).color,
        ];
      })()
    JS
    expect(card_border).to eq("1px")
    expect(filter_height).to eq(35) # 2.2rem, like the other toolbars
    expect(badge_bg).to eq(label_color) # the text colour, not the accent
    expect_no_theme_errors
  end

  # Core opens each review item with a bar in the inverted text colour (solid
  # black, or white in dark mode) and says "no items" in bare text; the
  # avatar's review badge is red. The theme: a quiet title row, an outlined
  # Pending, the empty-page card, and the header's inverse pill.
  it "keeps the review queue in the theme's quiet cards" do
    Fabricate(:reviewable_flagged_post, topic: topic, target: first_post)
    sign_in(admin)
    visit("/latest")
    expect(page).to have_css(".d-header .badge-notification.new-reviewables")
    badge = page.evaluate_script(<<~JS)
      (() => {
        const badge = getComputedStyle(document.querySelector(".d-header .new-reviewables"));
        return badge.backgroundColor === getComputedStyle(document.body).color;
      })()
    JS
    expect(badge).to eq(true)

    visit("/review")
    expect(page).to have_css(".review-item__header")
    looks = page.evaluate_script(<<~JS)
      (() => {
        const header = getComputedStyle(document.querySelector(".review-item__header"));
        const pending = getComputedStyle(document.querySelector(".review-item__status.--pending"));
        const text = getComputedStyle(document.body).color;
        return {
          headerInText: header.color === text,
          headerFilled: header.backgroundColor === text,
          pending: pending.backgroundColor,
        };
      })()
    JS
    expect(looks).to eq(
      "headerInText" => true,
      "headerFilled" => false,
      "pending" => "rgba(0, 0, 0, 0)",
    )
    shot("review-queue")

    visit("/review?type=ReviewableUser")
    expect(page).to have_css(".reviewable-list .no-review")
    empty =
      page.evaluate_script(
        "getComputedStyle(document.querySelector('.reviewable-list .no-review')).borderTopWidth",
      )
    expect(empty).to eq("1px")
    expect_no_theme_errors
  end

  it "keeps New Topic on the row of tabs when the window narrows" do
    sign_in(member)
    resize_window(width: 900) do
      visit("/latest")
      expect(page).to have_css("#create-topic")
      tops = page.evaluate_script(<<~JS)
        ["#navigation-bar", "#create-topic"]
          .map((selector) => document.querySelector(selector).getBoundingClientRect().top)
          .map(Math.round)
      JS
      expect(tops.uniq.size).to eq(1)
      expect_no_theme_errors
    end
  end

  it "moves the filters up a line rather than squeezing the tabs" do
    Fabricate(:category, name: "Filter apps", parent_category: category)
    sign_in(admin)
    resize_window(width: 900) do
      visit(category.url)
      expect(page).to have_css(".list-controls #create-topic")
      filters, tabs, new_topic, tabs_fit, scrolls_sideways = page.evaluate_script(<<~JS)
        (() => {
          const row = document.querySelector(".list-controls .navigation-container");
          const tabs = row.querySelector(":scope > #navigation-bar");
          const top = (e) => Math.round(e.getBoundingClientRect().top);
          return [
            top(row.querySelector(":scope > .category-breadcrumb")),
            top(tabs),
            top(row.querySelector("#create-topic")),
            tabs.scrollWidth <= tabs.clientWidth + 1,
            document.documentElement.scrollWidth > window.innerWidth,
          ];
        })()
      JS
      expect(filters).to be < tabs
      expect(new_topic).to eq(tabs)
      expect(tabs_fit).to eq(true)
      expect(scrolls_sideways).to eq(false)
      expect_no_theme_errors
    end
  end

  # Core's [details] is a grey bar with ► / ▼, a quote a grey title bar over a
  # barred blockquote, a onebox a 1px + 4px ring. The theme: one hairline card
  # for each, the section's chevron turning when it opens.
  # The composer's rich editor (core's default) drew [details] as a grey bar
  # with a triangle and a blockquote as a grey box; in the post both are the
  # theme's (jt-post-blocks). Now the editor shows them as the post will.
  it "draws sections and blockquotes in the rich editor as they'll look in the post" do
    # tests start in Markdown; core's rich editor specs set the mode the same way
    member.user_option.update!(composition_mode: UserOption.composition_mode_types[:rich])
    sign_in(member)
    visit(topic.relative_url)
    find(".topic-footer-main-buttons .create").click
    composer = PageObjects::Components::Composer.new
    expect(composer).to be_opened
    expect(page).to have_css("#reply-control .ProseMirror")
    composer.toggle_rich_editor
    composer.fill_content("[details=\"Steps\"]\nHold power.\n[/details]\n\n> A plain blockquote")
    composer.toggle_rich_editor
    expect(page).to have_css("#reply-control .ProseMirror details summary")
    looks = page.evaluate_script(<<~JS)
      (() => {
        const editor = document.querySelector("#reply-control .ProseMirror");
        const details = editor.querySelector("details");
        const quote = editor.querySelector(":scope > blockquote");
        return {
          details: getComputedStyle(details).borderTopWidth,
          marker: getComputedStyle(details.querySelector("summary"), "::before").content,
          bar: getComputedStyle(quote).borderLeftWidth,
          fill: getComputedStyle(quote).backgroundColor,
        };
      })()
    JS
    expect(looks).to eq(
      "details" => "1px",
      "marker" => '""',
      "bar" => "2px",
      "fill" => "rgba(0, 0, 0, 0)",
    )
    expect_no_theme_errors
  end

  # A Hebrew quote runs right to left, but its bar sat on the far left, away
  # from where its text starts
  it "puts a Hebrew blockquote's bar where its text starts" do
    SiteSetting.support_mixed_text_direction = true
    post =
      Fabricate(
        :post,
        topic: topic,
        user: admin,
        raw: "> שלום, זה ציטוט בעברית\n\n> And this one is in English",
      )
    sign_in(member)
    visit(post.url)
    expect(page).to have_css("#post_#{post.post_number} .cooked > blockquote[dir]", count: 2)
    bars = page.evaluate_script(<<~JS)
      [...document.querySelectorAll("#post_#{post.post_number} .cooked > blockquote")].map((quote) => {
        const style = getComputedStyle(quote);
        return [style.direction, style.borderLeftWidth, style.borderRightWidth];
      })
    JS
    expect(bars).to eq([%w[rtl 0px 2px], %w[ltr 2px 0px]])
    expect_no_theme_errors
  end

  it "draws collapsible sections, quotes and link previews as hairline cards" do
    post =
      Fabricate(
        :post,
        topic: topic,
        user: admin,
        raw:
          "[quote=\"#{member.username}, post:1, topic:#{topic.id}\"]\nI'm setting up a flip phone.\n[/quote]",
      )
    # written out rather than cooked, so the spec doesn't lean on the details
    # plugin or a onebox fetch
    post.update_column(:cooked, post.cooked + <<~HTML)
      <details><summary>Steps</summary><p>Turn it off and on.</p></details>
      <aside class="onebox allowlistedgeneric" data-onebox-src="https://example.com/">
        <header class="source"><a href="https://example.com/">example.com</a></header>
        <article class="onebox-body"><h3><a href="https://example.com/">Example</a></h3></article>
      </aside>
    HTML
    sign_in(member)
    visit("#{topic.relative_url}/#{post.post_number}")
    selector = "#post_#{post.post_number} .cooked"
    expect(page).to have_css("#{selector} details summary")
    expect(page).to have_css("#{selector} aside.onebox")
    looks = page.evaluate_script(<<~JS)
      (() => {
        const post = document.querySelector("#{selector}");
        const details = post.querySelector("details");
        const quote = post.querySelector("aside.quote blockquote");
        const onebox = post.querySelector("aside.onebox");
        return {
          marker: getComputedStyle(details.querySelector("summary"), "::before").content,
          details: getComputedStyle(details).borderTopWidth,
          quoteBar: getComputedStyle(quote).borderLeftWidth,
          ring: getComputedStyle(onebox).boxShadow,
          onebox: getComputedStyle(onebox).borderTopWidth,
        };
      })()
    JS
    expect(looks).to eq(
      "marker" => '""',
      "details" => "1px",
      "quoteBar" => "0px",
      "ring" => "none",
      "onebox" => "1px",
    )

    find("#{selector} details summary").click
    expect(page).to have_css("#{selector} details[open]")
    turned =
      page.evaluate_script(
        "getComputedStyle(document.querySelector('#{selector} details summary'), '::before').transform",
      )
    expect(turned).not_to eq("none")
    shot("post-blocks")
    expect_no_theme_errors
  end

  it "leaves a gap between New's All / Topics / Replies and the first card" do
    sign_in(member)
    visit("/new")
    expect(page).to have_css(".topic-replies-toggle-wrapper")
    expect(page).to have_css(".topic-list.jt-cards .topic-list-item")
    gap = page.evaluate_script(<<~JS)
      document.querySelector(".topic-list.jt-cards .topic-list-item").getBoundingClientRect().top -
        document.querySelector(".topic-replies-toggle-wrapper").getBoundingClientRect().bottom
    JS
    expect(gap).to be >= 8
    expect_no_theme_errors
  end

  # Core's static pages: a 700px column at the interface size. The theme: a
  # reading column at the post's size, with a post's heading and list rhythm.
  it "sets the guidelines page in a reading column" do
    guidelines = Fabricate(:topic, user: admin, title: "Community guidelines for the forum")
    Fabricate(
      :post,
      topic: guidelines,
      user: admin,
      raw: "Be kind.\n\n## No ads\n\n- One\n- Two\n\nThat's all.",
    )
    SiteSetting.guidelines_topic_id = guidelines.id

    visit("/guidelines")
    expect(page).to have_css(".body-page h2", text: "No ads")
    width, size, indent = page.evaluate_script(<<~JS)
      [
        Math.round(document.querySelector(".body-page").getBoundingClientRect().width),
        getComputedStyle(document.querySelector(".body-page h2").parentElement).fontSize,
        getComputedStyle(document.querySelector(".body-page ul:not(.nav-pills)")).marginLeft,
      ]
    JS
    expect(width).to eq(704) # 44rem
    expect(size).to eq("17.0672px") # the post's reading size, not core's 16px
    expect(indent).to eq("0px") # a post's indent, not core's 40px
    expect_no_theme_errors
  end

  # Core's polls: square corners, flat grey bars with no track (a 0% option
  # shows nothing), the voter count in grey and the settings gear a bare
  # button (a grey box in dark mode). The theme: its radius, a track under
  # every result with your vote in the text colour, the count in the text
  # colour, a flat gear.
  it "draws a poll's results on tracks, with the voter's choice in the text colour" do
    post = PostCreator.create!(admin, topic_id: topic.id, raw: <<~MD)
      Which day?

      [poll]
      * Monday
      * Tuesday
      [/poll]
    MD
    monday = post.polls.first.poll_options.find_by(html: "Monday").digest
    # staff, so the gear has something to offer (close, export)
    DiscoursePoll::Poll.vote(admin, post.id, "poll", [monday])
    sign_in(admin)
    visit("#{topic.relative_url}/#{post.post_number}")
    poll = "#post_#{post.post_number} .poll"
    expect(page).to have_css("#{poll} .results li.chosen")
    looks = page.evaluate_script(<<~JS)
      (() => {
        const poll = document.querySelector("#{poll}");
        const text = getComputedStyle(document.body).color;
        const tracks = [...poll.querySelectorAll(".results .bar-back")];
        return {
          rounded: getComputedStyle(poll).borderTopLeftRadius !== "0px",
          tracks: tracks.length,
          tracksShown: tracks.every((t) => getComputedStyle(t).backgroundColor !== "rgba(0, 0, 0, 0)"),
          chosen: getComputedStyle(poll.querySelector(".chosen .bar")).backgroundColor === text,
          count: getComputedStyle(poll.querySelector(".info-number")).color === text,
          gear: getComputedStyle(poll.querySelector(".poll-buttons .widget-dropdown-header")).backgroundColor,
        };
      })()
    JS
    expect(looks).to eq(
      "rounded" => true,
      "tracks" => 2,
      "tracksShown" => true,
      "chosen" => true,
      "count" => true,
      "gear" => "rgba(0, 0, 0, 0)",
    )
    shot("poll")
    expect_no_theme_errors
  end

  it "puts Me too on the post menu's line, next to the like count" do
    skip("needs discourse-solved") unless defined?(::DiscourseSolved)
    SiteSetting.solved_enabled = true
    SiteSetting.enable_solved_shared_issues = true
    category.upsert_custom_fields(DiscourseSolved::ENABLE_ACCEPTED_ANSWERS_CUSTOM_FIELD => "true")
    DiscourseSolved::AcceptedAnswerCache.reset_accepted_answer_cache
    sign_in(admin)
    visit(topic.relative_url)
    expect(page).to have_css("#post_1 .post-action-menu__solved-shared-issue")
    me_too, menu, post = page.evaluate_script(<<~JS)
      [
        "#post_1 .post-action-menu__solved-shared-issue",
        "#post_1 nav.post-controls .actions",
        "#post_1 .post__contents",
      ]
        .map((selector) => document.querySelector(selector).getBoundingClientRect())
        .map((r) => [Math.round(r.top + r.height / 2), Math.round(r.right)])
    JS
    expect(me_too[0]).to be_within(1).of(menu[0])
    expect(menu[1]).to be <= post[1]
    shot("me-too")
    expect_no_theme_errors
  end

  # Core's preferences: bold labels over small pills in a loose stack. The
  # theme: each group a card, the controls 2.4rem, Save on a ruled bar.
  it "shows each preferences group as a card with the theme's controls" do
    sign_in(member)
    visit("/u/#{member.username}/preferences/emails")
    expect(page).to have_css(".user-preferences .control-group .select-kit-header")
    card_border, control_height, save_height = page.evaluate_script(<<~JS)
      [
        getComputedStyle(document.querySelector(".user-preferences .form-vertical > .control-group")).borderTopWidth,
        Math.round(document.querySelector(".user-preferences .control-group .select-kit-header").getBoundingClientRect().height),
        Math.round(document.querySelector(".user-preferences .save-button .btn").getBoundingClientRect().height),
      ]
    JS
    expect(card_border).to eq("1px")
    expect(control_height).to eq(38) # 2.4rem
    expect(save_height).to eq(38)
    expect_no_theme_errors
  end

  # Core sets a table as bare text: a grey header, 3px cells and a faint line
  # between rows. The theme: a hairline card with a sunken header strip,
  # roomy cells and a rule between rows.
  it "sets a table in a post as a card with a header strip" do
    post =
      Fabricate(
        :post,
        topic: topic,
        user: admin,
        raw: "| Phone | Filter |\n|---|---|\n| Qin F21 | eGate |\n| Flip 3 | Mitzuyan |",
      )
    sign_in(member)
    visit("#{topic.relative_url}/#{post.post_number}")
    table = "#post_#{post.post_number} .cooked table"
    expect(page).to have_css("#{table} tbody tr", count: 2)
    looks = page.evaluate_script(<<~JS)
      (() => {
        const table = document.querySelector("#{table}");
        const th = getComputedStyle(table.querySelector("th"));
        const rows = table.querySelectorAll("tbody tr");
        return {
          frame: getComputedStyle(table).borderTopWidth,
          strip: th.backgroundColor !== "rgba(0, 0, 0, 0)",
          rule: getComputedStyle(rows[1].querySelector("td")).borderTopWidth,
          roomy: parseFloat(getComputedStyle(rows[0].querySelector("td")).paddingLeft) >= 8,
        };
      })()
    JS
    expect(looks).to eq("frame" => "1px", "strip" => true, "rule" => "1px", "roomy" => true)
    shot("table")
    expect_no_theme_errors
  end

  it "keeps a user title's pill to the size of its text on phones", mobile: true do
    admin.update!(title: "Forum Administrator")
    visit(topic.relative_url)
    expect(page).to have_css("#post_2 .names .user-title", text: "Forum Administrator")
    pill, text, names = page.evaluate_script(<<~JS)
      (() => {
        const title = document.querySelector("#post_2 .names .user-title");
        const text = document.createRange();
        text.selectNodeContents(title);
        return [title, text, title.closest(".names")]
          .map((e) => Math.round(e.getBoundingClientRect().width));
      })()
    JS
    expect(pill).to be < text + 30
    expect(pill).to be < names
    expect_no_theme_errors
  end

  # Core's suggested list is a bare table under a bold "want to read more?";
  # the theme: a divided card and a sentence.
  # Core lifts a user card's big avatar 3.3em above the card; on the theme's
  # hairline card it slipped out of place and covered the post behind it.
  it "keeps the avatar inside the user card" do
    sign_in(member)
    visit(topic.relative_url)
    find("#post_1 .topic-avatar a").click
    expect(page).to have_css(".user-card.show img.avatar")
    inside = page.evaluate_script(<<~JS)
      (() => {
        const card = document.querySelector(".user-card.show");
        return (
          card.querySelector("img.avatar").getBoundingClientRect().top >=
          card.getBoundingClientRect().top
        );
      })()
    JS
    expect(inside).to eq(true)
    expect_no_theme_errors
  end

  it "puts the suggested topics under a topic on a card" do
    sign_in(member)
    visit(topic.relative_url)
    expect(page).to have_css(".more-topics__container .topic-list .topic-list-item")
    border, weight = page.evaluate_script(<<~JS)
      [
        getComputedStyle(document.querySelector(".more-topics__list .topic-list")).borderTopWidth,
        getComputedStyle(document.querySelector(".more-topics__browse-more")).fontWeight,
      ]
    JS
    expect(border).to eq("1px")
    expect(weight).to eq("400")
    expect_no_theme_errors
  end

  # On phones core makes every footer button an icon, Reply included
  it "keeps the word on the phone's Reply button", mobile: true do
    sign_in(member)
    visit(topic.relative_url)
    expect(page).to have_css(
      "#topic-footer-buttons .create .d-button-label",
      text: "Reply",
      visible: true,
    )
    expect_no_theme_errors
  end

  # Core mixes radii: square composer controls and Discard, 10px rows and
  # menus, 14px fields beside 12px buttons, circular avatars among rounded
  # boxes. The theme: one radius for controls, avatars as rounded boxes.
  it "gives every control one radius and draws avatars as rounded boxes" do
    sign_in(member)
    visit(topic.relative_url)
    find(".topic-footer-main-buttons .create").click
    expect(page).to have_css("#reply-control.open .save-or-cancel .discard-button")
    looks = page.evaluate_script(<<~JS)
      (() => {
        const radius = (s) => getComputedStyle(document.querySelector(s)).borderTopLeftRadius;
        const control = radius("#reply-control .save-or-cancel .btn-primary");
        const avatar = getComputedStyle(document.querySelector(".topic-avatar img.avatar"));
        return {
          odd: [
            "#reply-control .composer-controls .toggle-minimize",
            "#reply-control .save-or-cancel .discard-button",
            "#reply-control .d-editor-textarea-wrapper",
            "#reply-control .d-editor-button-bar .btn:not(.composer-toggle-switch)",
            ".post-controls .actions .btn",
          ].filter((s) => radius(s) !== control),
          circle:
            avatar.borderTopLeftRadius === "50%" &&
            (!avatar.cornerShape || /round|[(]1[)]/.test(avatar.cornerShape)),
        };
      })()
    JS
    expect(looks).to eq("odd" => [], "circle" => false)
    shot("one-radius")
    expect_no_theme_errors
  end

  # "view 1 hidden reply" was core's bold uppercase grey line; the theme draws
  # it like the list's "last visit" divider. Core only renders it around
  # filtered posts, so the spec adds the same markup and checks its look.
  it "draws the hidden replies link as a centred divider" do
    sign_in(member)
    visit(topic.relative_url)
    expect(page).to have_css(".post-stream")
    gap = page.evaluate_script(<<~JS)
      (() => {
        const gap = document.createElement("div");
        gap.className = "gap";
        gap.textContent = "view 1 hidden reply";
        document.querySelector(".post-stream").appendChild(gap);
        const style = getComputedStyle(gap);
        const look = {
          display: style.display,
          case: style.textTransform,
          rule: getComputedStyle(gap, "::before").height,
        };
        gap.remove();
        return look;
      })()
    JS
    expect(gap).to eq("display" => "flex", "case" => "none", "rule" => "1px")
    expect_no_theme_errors
  end

  it "puts the tracking menu in the topic's row of buttons, without the explanation" do
    sign_in(member)
    visit(topic.relative_url)
    expect(page).to have_css("#topic-footer-buttons .notifications-tracking-trigger")
    expect(page).to have_no_css("#topic-footer-buttons .reason .text")
    tracking, reply = page.evaluate_script(<<~JS)
      ["#topic-footer-buttons .notifications-tracking-trigger", "#topic-footer-buttons .create"]
        .map((selector) => document.querySelector(selector).getBoundingClientRect())
        .map((r) => [Math.round(r.top), Math.round(r.left)])
    JS
    expect(tracking[0]).to eq(reply[0])
    expect(tracking[1]).to be < reply[1]
    expect_no_theme_errors
  end

  # On sidebar pages core placed the composer at the sidebar plus its gap,
  # without the page's gutter, so it started left of everything above it.
  it "starts the composer at the content's left edge on sidebar pages" do
    # the rich editor has no preview, so the composer takes core's previewless
    # layout (tests otherwise start in Markdown with the preview open)
    member.user_option.update!(composition_mode: UserOption.composition_mode_types[:rich])
    sign_in(member)
    visit(topic.relative_url)
    expect(page).to have_css("body.has-sidebar-page")
    find(".topic-footer-main-buttons .create").click
    expect(page).to have_css("#reply-control.open.hide-preview")
    offset = page.evaluate_script(<<~JS)
      Math.round(
        document.querySelector("#reply-control").getBoundingClientRect().left -
          document.querySelector("#main-outlet").getBoundingClientRect().left
      )
    JS
    expect(offset).to eq(0)
    expect_no_theme_errors
  end

  it "lines the footer up with the page above it" do
    sign_in(member)
    visit(topic.relative_url)
    expect(page).to have_css(".jt-footer__inner")
    page_edges, footer_edges = page.evaluate_script(<<~JS)
      [[".sidebar-wrapper", "#main-outlet"], [".jt-footer__inner", ".jt-footer__inner"]]
        .map(([left, right]) => [
          document.querySelector(left).getBoundingClientRect().left,
          document.querySelector(right).getBoundingClientRect().right,
        ])
    JS
    expect(footer_edges[0]).to be_within(1).of(page_edges[0])
    expect(footer_edges[1]).to be_within(1).of(page_edges[1])
  end

  # Core lists tags as "name x 190" in floated columns; the theme makes each
  # a chip with the number alone in a pill, and the lists wrap.
  it "shows the tags page as chips, with the count alone in its pill" do
    Fabricate(:topic, category: category, user: admin, tags: [Fabricate(:tag, name: "ios")])
    Tag.ensure_consistency! # the counts the page shows
    sign_in(member)
    visit("/tags")
    expect(page).to have_css(".tags-index .tag-box", minimum: 2)
    expect(find(".tag-box", text: tag.name).find(".tag-count")).to have_text(/\A1\z/)

    display, android_top, ios_top = page.evaluate_script(<<~JS)
      [
        getComputedStyle(document.querySelector(".tags-index .tags-list")).display,
        ...[...document.querySelectorAll(".tags-index .tag-box")]
          .slice(0, 2)
          .map((box) => Math.round(box.getBoundingClientRect().top)),
      ]
    JS
    expect(display).to eq("flex")
    expect(android_top).to eq(ios_top) # side by side, not stacked
    expect_no_theme_errors
  end

  def horizontal_edges(*selectors)
    page.evaluate_script(<<~JS)
      #{selectors.to_json}
        .map((selector) => document.querySelector(selector).getBoundingClientRect())
        .map((r) => [Math.round(r.left), Math.round(r.right)])
    JS
  end

  # Gives each element keyboard focus and reports its focus ring: [outline
  # style, whether the ring reaches past the element, whether a box that clips
  # its overflow cuts it]. A pair [selector, ancestor] reads the ring off the
  # ancestor, for a link whose box takes the ring.
  def focus_rings(*targets)
    send_keys(:tab) # keyboard first, so focus() below counts as keyboard focus
    page.evaluate_script(<<~JS)
      #{targets.to_json}.map((target) => {
        const [selector, ringOn] = [].concat(target);
        const link = document.querySelector(selector);
        link.focus();
        const ringed = ringOn ? link.closest(ringOn) : link;
        const style = getComputedStyle(ringed);
        const reach = parseFloat(style.outlineWidth) + parseFloat(style.outlineOffset);
        const box = ringed.getBoundingClientRect();
        let cut = false;
        for (let el = ringed.parentElement; el !== document.documentElement; el = el.parentElement) {
          const s = getComputedStyle(el);
          if (s.overflowX === "visible" && s.overflowY === "visible") continue;
          const clip = el.getBoundingClientRect();
          cut ||=
            box.left - reach < clip.left - 0.5 ||
            box.top - reach < clip.top - 0.5 ||
            box.right + reach > clip.right + 0.5 ||
            box.bottom + reach > clip.bottom + 0.5;
        }
        return [style.outlineStyle, reach > 0, cut];
      })
    JS
  end

  # Core clips a post's names, the header's logo and the topic map's avatars
  # (overflow: hidden) right at the link's edge, which cut a keyboard focus
  # ring away, and takes the ring off suggested topics' titles.
  it "shows the whole focus ring on links in boxes that clip" do
    sign_in(member)
    visit(topic.relative_url)
    expect(page).to have_css("#post_1 .names .first a")
    expect(page).to have_css(".more-topics__container .topic-list a.title")
    rings =
      focus_rings(
        "#post_1 .names .first a",
        [".d-header .home-logo-wrapper-outlet a", ".home-logo-wrapper-outlet"],
        ".more-topics__container .topic-list a.title",
      )
    expect(rings).to all(eq(["solid", true, false]))
    expect_no_theme_errors
  end

  # On phones the name link is taller, for a bigger tap area
  it "shows the whole focus ring on a post's names on a phone", mobile: true do
    sign_in(member)
    visit(topic.relative_url)
    expect(page).to have_css("#post_1 .names .first a")
    expect(focus_rings("#post_1 .names .first a")).to eq([["solid", true, false]])
    expect_no_theme_errors
  end

  # Suggested topics and the search page used to stop short of the right
  # edge the header, content and footer share
  it "runs suggested topics and the search page to the page's edges" do
    sign_in(member)

    visit(topic.relative_url)
    expect(page).to have_css(".more-topics__container .topic-list")
    wall, suggested = horizontal_edges("#main-outlet", ".more-topics__container")
    expect(suggested[1]).to be_within(1).of(wall[1])

    visit("/search?q=filter")
    expect(page).to have_css(".search-header .search-bar")
    wall, bar = horizontal_edges("#main-outlet", ".search-header .search-bar")
    expect(bar).to eq(wall)
    expect_no_theme_errors
  end

  # Core puts the bulk-select / sort row above the count, insets the count by
  # a different rule than the results (so it sat further in), and separates
  # results with margins. The theme makes the count the title, the row a
  # toolbar under it, and the results one divided card.
  it "lays the search page out as a count, a toolbar and a card of results" do
    SearchIndexer.enable
    SearchIndexer.index(topic, force: true)
    SearchIndexer.index(first_post, force: true)
    sign_in(member)
    visit("/search?q=filter")
    expect(page).to have_css(".fps-result-entries .fps-result", text: "Which filter works best")

    count, info, entries = page.evaluate_script(<<~JS)
        [".result-count", ".search-info", ".fps-result-entries"]
          .map((selector) => document.querySelector(selector).getBoundingClientRect())
          .map((r) => [Math.round(r.top), Math.round(r.bottom)])
      JS
    expect(count[1]).to be <= info[0]
    expect(info[1]).to be <= entries[0]

    wall, counted, card = horizontal_edges("#main-outlet", ".result-count", ".fps-result-entries")
    expect(counted).to eq(wall)
    expect(card).to eq(wall)
    border = page.evaluate_script(<<~JS)
      getComputedStyle(document.querySelector(".fps-result-entries")).borderTopWidth
    JS
    expect(border).to eq("1px")
    expect_no_theme_errors
  end

  # Core fills a deleted post with bright pink and turns its name and buttons
  # red. The theme: a dashed outline over a faint hatch, everything in greys.
  it "shows staff a deleted post in greys, not pink and red" do
    # staff see a deleted reply only after "show deleted"; a deleted first
    # post is always in the stream (core keeps post 1), as on the live forum
    first_post.update_columns(deleted_at: Time.zone.now, deleted_by_id: admin.id)
    sign_in(admin)
    visit(topic.relative_url)
    expect(page).to have_css(".topic-post.deleted .regular > .cooked")
    looks = page.evaluate_script(<<~JS)
      (() => {
        const post = document.querySelector(".topic-post.deleted");
        const cooked = getComputedStyle(post.querySelector(".regular > .cooked"));
        const grey = (c) => {
          const [r, g, b] = c.match(/[0-9.]+/g).map(Number);
          return Math.max(r, g, b) - Math.min(r, g, b) < 12;
        };
        return {
          outline: cooked.borderTopStyle,
          fill: cooked.backgroundColor,
          name: grey(getComputedStyle(post.querySelector(".topic-meta-data")).color),
          buttons: grey(getComputedStyle(post.querySelector("nav.post-controls")).color),
        };
      })()
    JS
    expect(looks).to eq(
      "outline" => "dashed",
      "fill" => "rgba(0, 0, 0, 0)",
      "name" => true,
      "buttons" => true,
    )
    shot("deleted-post")
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

  # Core's row of post buttons scrolled sideways on phones: eight or nine
  # 38px buttons are wider than the column. The theme's row wraps instead.
  it "fits a post's buttons in the phone's column without scrolling", mobile: true do
    sign_in(member)
    visit(topic.relative_url)
    expect(page).to have_css(".topic-post .post-controls .actions .btn")
    overflowing = page.evaluate_script(<<~JS)
      [...document.querySelectorAll(".topic-post .post-controls")]
        .filter((row) => row.scrollWidth > row.clientWidth + 1).length
    JS
    expect(overflowing).to eq(0)
    expect_no_theme_errors
  end

  it "doesn't offer Quick look to visitors, so it can't get round a login gate" do
    visit("/latest")
    expect(page).to have_css(".jt-card")
    expect(page).to have_no_css(".jt-card__peek")
  end

  # Core's bookmarks are a bare table, the activity stream posts stacked with
  # hairlines, the inbox a plain topic list. The theme: a card, cards, cards.
  it "puts a member's bookmarks, activity and inbox on cards" do
    Fabricate(:bookmark, user: member, bookmarkable: first_post, name: "Read again")
    Fabricate(:topic_user, user: member, topic: topic) # the bookmarks query joins it
    # the activity stream reads user actions, which specs don't log by default
    UserActionManager.enable
    UserActionManager.topic_created(topic)
    UserActionManager.post_created(first_post)
    pm = Fabricate(:private_message_topic, user: admin, recipient: member)
    Fabricate(:post, topic: pm, user: admin, raw: "A note for the inbox layout.")
    sign_in(member)
    visit("/latest") # the theme compiles on the first request; don't time that
    expect(page).to have_css(".jt-card")

    visit("/u/#{member.username}/activity/bookmarks")
    expect(page).to have_css(".bookmark-list .bookmark-list-item", text: "Read again", wait: 15)
    bookmarks_border = page.evaluate_script(<<~JS)
      getComputedStyle(document.querySelector(".topic-list.bookmark-list")).borderTopWidth
    JS
    expect(bookmarks_border).to eq("1px")

    visit("/u/#{member.username}/activity")
    expect(page).to have_css(".user-stream .post-list-item", text: "blocks the browser")
    stream_border = page.evaluate_script(<<~JS)
      getComputedStyle(document.querySelector(".user-stream .post-list-item")).borderTopWidth
    JS
    expect(stream_border).to eq("1px")

    visit("/u/#{member.username}/messages")
    expect(page).to have_css(".topic-list.jt-cards .jt-card", text: pm.title)
    expect_no_theme_errors
  end

  # Core floats "See 1 new or updated topic" over the list's header row on
  # wide screens; card lists have none, so it sat on the first card.
  it "keeps the new topics button above the first card, not on it" do
    sign_in(member)
    visit("/latest")
    expect(page).to have_css(".topic-list.jt-cards .topic-list-item")
    PostCreator.create!(
      admin,
      title: "A topic posted while the list is open",
      raw: "Posted while someone had the list open.",
      category: category.id,
    )
    expect(page).to have_css(".show-more.has-topics .alert")
    gap = page.evaluate_script(<<~JS)
      document.querySelector(".topic-list.jt-cards .topic-list-item").getBoundingClientRect().top -
        document.querySelector(".show-more .alert").getBoundingClientRect().bottom
    JS
    expect(gap).to be >= 0
    shot("new-topics-button")
    expect_no_theme_errors
  end

  it "starts a topic in the tag being viewed from the header's +" do
    sign_in(member)
    visit("/tag/#{tag.name}")
    find(".jt-header-new-topic button").click
    expect(page).to have_css("#reply-control.open")
    expect(page).to have_css("#reply-control .mini-tag-chooser", text: tag.name)
    expect_no_theme_errors
  end

  # Core's progress widget on phones is a row of boxes with the accent on its
  # numbers; the theme makes it one hairline capsule with tabular numbers.
  it "shows the phone's progress widget as one capsule", mobile: true do
    sign_in(member)
    visit(topic.relative_url)
    expect(page).to have_css("#topic-progress .nums")
    border, radius, numerals = page.evaluate_script(<<~JS)
      [
        getComputedStyle(document.querySelector("#topic-progress-wrapper")).borderTopWidth,
        parseFloat(getComputedStyle(document.querySelector("#topic-progress-wrapper")).borderTopLeftRadius),
        getComputedStyle(document.querySelector("#topic-progress .nums")).fontVariantNumeric,
      ]
    JS
    expect(border).to eq("1px")
    expect(radius).to be > 4
    expect(numerals).to eq("tabular-nums")
    expect_no_theme_errors
  end

  # Core marks the selected tab with a solid 2px bar. The theme: a 1px line
  # that glows, with a faint light behind the label.
  it "marks the selected tab with a thin glowing line" do
    sign_in(member)
    visit("/latest")
    expect(page).to have_css(".navigation-container .nav-pills > li > a.active")
    tab = page.evaluate_script(<<~JS)
      (() => {
        const tab = document.querySelector(".navigation-container .nav-pills > li > a.active");
        const line = getComputedStyle(tab, "::after");
        return {
          line: line.height,
          glow: line.boxShadow !== "none",
          light: getComputedStyle(tab).backgroundImage.startsWith("radial-gradient"),
        };
      })()
    JS
    expect(tab).to eq("line" => "1px", "glow" => true, "light" => true)
    expect_no_theme_errors
  end

  # "Back" floats above the phone's progress capsule; matched with the
  # capsule's own buttons it lost its fill and showed as bare grey text over
  # the post below. Core only shows it after some jumps, so the spec adds the
  # same markup core renders and checks its look.
  it "draws the phone's Back button as a pill of its own", mobile: true do
    sign_in(member)
    visit(topic.relative_url)
    expect(page).to have_css("#topic-progress-wrapper")
    back = page.evaluate_script(<<~JS)
      (() => {
        const container = document.createElement("div");
        container.className = "progress-back-container";
        container.innerHTML = '<button class="btn btn-icon-text btn-primary btn-small progress-back" type="button"><span class="d-button-label">Back</span></button>';
        document.querySelector("#topic-progress-wrapper").appendChild(container);
        const style = getComputedStyle(container.querySelector(".btn"));
        const look = { fill: style.backgroundColor, height: parseFloat(style.height), border: style.borderTopWidth };
        container.remove();
        return look;
      })()
    JS
    expect(back["fill"]).not_to eq("rgba(0, 0, 0, 0)")
    expect(back["height"]).to be >= 30
    expect(back["border"]).to eq("1px")
    expect_no_theme_errors
  end

  it "sends links that aren't forum pages to the browser" do
    visit("/latest")
    expect(page).to have_css(".jt-header-home a[href='/home'][data-auto-route='true']")
    expect(page).to have_css(".jt-footer a[href='/latest']:not([data-auto-route])")
  end

  it "draws the theme's own shortcuts in the ? help like core's" do
    sign_in(member)
    visit("/latest")
    expect(page).to have_css(".jt-card")
    find("body").send_keys("?")
    expect(page).to have_css(".keyboard-shortcuts-modal .delimiter-space kbd.d-shortcut")
    spacing = page.evaluate_script(<<~JS)
      (() => {
        const rows = [...document.querySelectorAll(".keyboard-shortcuts-modal tr")];
        const gap = (name) => {
          const row = rows.find((r) => r.querySelector(".shortcut-description")?.textContent.trim() === name);
          const [a, b] = row.querySelectorAll(".d-shortcut__key");
          return Math.round(b.getBoundingClientRect().left - a.getBoundingClientRect().right);
        };
        return { core: gap("Home"), theme: gap("Tags") };
      })()
    JS
    expect(spacing["theme"]).to eq(spacing["core"])
    expect_no_theme_errors
  end

  it "gives the header and sidebar room: core's 16px text, 40px header controls, 36px rows" do
    sign_in(member)
    visit("/latest")
    expect(page).to have_css(".sidebar-section-link")
    root, header, control, glyph, row, label = page.evaluate_script(<<~JS)
      (() => {
        const size = (s) => document.querySelector(s).getBoundingClientRect();
        return [
          parseFloat(getComputedStyle(document.documentElement).fontSize),
          size(".d-header").height,
          size(".d-header-icons .jt-header-notifications > .icon").height,
          size(".d-header-icons .jt-header-notifications .d-icon").width,
          size(".sidebar-section-link").height,
          parseFloat(getComputedStyle(document.querySelector(".sidebar-section-link")).fontSize),
        ].map(Math.round);
      })()
    JS
    expect(root).to eq(16)
    expect(header).to be >= 60
    expect(control).to eq(40)
    expect(glyph).to eq(18)
    expect(row).to eq(36)
    expect(label).to eq(16)
    expect_no_theme_errors
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

  # The theme keeps thin scrollbars visible on touch screens, except under a
  # post's row of buttons, which scrolls sideways by a few pixels on phones.
  # Small controls on phones get a hit area of at least 32px without growing
  # (they were 16-22px): measured as how far above and below a control's
  # centre a tap still lands on it.
  it "gives small controls on phones a finger-sized hit area", mobile: true do
    reach = <<~JS
      ((selector) => {
        const el = document.querySelector(selector);
        el.scrollIntoView({ block: "center" });
        const r = el.getBoundingClientRect();
        const x = r.left + r.width / 2;
        const y = r.top + r.height / 2;
        const on = (dy) => {
          const hit = document.elementFromPoint(x, y + dy);
          return hit === el || el.contains(hit);
        };
        let up = 0;
        let down = 0;
        while (up < 40 && on(-(up + 1))) up++;
        while (down < 40 && on(down + 1)) down++;
        return Math.round(up + down + 1);
      })
    JS
    sign_in(member)
    visit("/latest")
    expect(page).to have_css(".jt-card .jt-card__peek")
    expect(page.evaluate_script("#{reach}('.jt-card__peek')")).to be >= 30
    expect(page.evaluate_script("#{reach}('.jt-card .badge-category__wrapper')")).to be >= 30

    visit(topic.relative_url)
    expect(page).to have_css(".topic-post .post-info.post-date a.post-date")
    expect(
      page.evaluate_script("#{reach}('.topic-post .post-info.post-date a.post-date')"),
    ).to be >= 30
    expect_no_theme_errors
  end

  it "draws no scrollbar under a post's buttons on phones", mobile: true do
    sign_in(member)
    visit(topic.relative_url)
    expect(page).to have_css(".topic-post .post-controls")
    scrollbar = page.evaluate_script(<<~JS)
      getComputedStyle(document.querySelector(".topic-post .post-controls")).scrollbarWidth
    JS
    expect(scrollbar).to eq("none")
    expect_no_theme_errors
  end

  it "draws trust-level and staff flair in black and white, with its own marks" do
    Group.refresh_automatic_groups!
    Group.find(Group::AUTO_GROUPS[:trust_level_2]).update!(
      flair_icon: "thumbs-up",
      flair_bg_color: "9CA3AF",
      flair_color: "FFFFFF",
    )
    Group.find(Group::AUTO_GROUPS[:admins]).update!(
      flair_icon: "shield-halved",
      flair_bg_color: "5A29E4",
      flair_color: "FFFFFF",
    )
    member.update!(flair_group_id: Group::AUTO_GROUPS[:trust_level_2])
    admin.update!(flair_group_id: Group::AUTO_GROUPS[:admins])

    visit(topic.relative_url)
    expect(page).to have_css("#post_1 .avatar-flair-trust_level_2")
    expect(page).to have_css("#post_2 .avatar-flair-admins")
    backgrounds, icons, glyphs = page.evaluate_script(<<~JS)
      (() => {
        const flairs = ["#post_1", "#post_2"].map((post) =>
          document.querySelector(`${post} .topic-avatar .avatar-flair`)
        );
        return [
          flairs.map((flair) => getComputedStyle(flair).backgroundColor),
          flairs.map((flair) => getComputedStyle(flair.querySelector("svg")).display),
          flairs.map((flair) => {
            const glyph = getComputedStyle(flair, "::before");
            return (glyph.maskImage || glyph.webkitMaskImage).startsWith('url("data:image/svg+xml');
          }),
        ];
      })()
    JS
    expect(backgrounds).not_to include("rgb(156, 163, 175)", "rgb(90, 41, 228)")
    expect(backgrounds.uniq.size).to eq(2) # staff are inverted
    expect(icons).to eq(%w[none none])
    expect(glyphs).to eq([true, true])
    shot("flair")
    expect_no_theme_errors
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

    it "shows jump buttons under the timeline, a 2×2 block with core's buttons" do
      sign_in(member)
      visit(topic.relative_url)
      expect(page).to have_css(".timeline-container .jt-jump .jt-jump__bottom")
      # reply · notifications over first post · last post, all one size
      reply, bell, top, bottom = page.evaluate_script(<<~JS)
        [".reply-to-post", ".notifications-tracking-trigger", ".jt-jump__top", ".jt-jump__bottom"]
          .map((selector) => document.querySelector(`.timeline-footer-controls ${selector}`))
          .map((b) => b.getBoundingClientRect())
          .map((r) => [Math.round(r.left), Math.round(r.top), Math.round(r.width), Math.round(r.height)])
      JS
      expect([reply, bell, top, bottom].map { |b| b[2..] }.uniq.size).to eq(1)
      expect(bell[1]).to eq(reply[1])
      expect([top[0], top[1] > reply[1]]).to eq([reply[0], true])
      expect([bottom[0], bottom[1]]).to eq([bell[0], top[1]])
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

  describe "login gate" do
    def gate(categories: "", tags: "")
      jtech_theme.update_setting(:gated_categories, categories)
      jtech_theme.update_setting(:gated_tags, tags)
      jtech_theme.save!
    end

    it "fades a gated category's topic into a prompt to log in or sign up" do
      gate(categories: category.id.to_s)
      visit(topic.relative_url)
      expect(page).to have_css("body.jt-gated")
      expect(page).to have_css(".jt-gate__title", text: "Log in to keep reading")
      expect(page).to have_css(
        ".jt-gate__text",
        text: "Topics in #{category.name} are for members.",
      )
      expect(page).to have_css(".jt-gate__sign-up")
      shot("gate")
      expect_no_theme_errors

      find(".jt-gate__log-in").click
      expect(page).to have_current_path("/login")
    end

    it "fits a phone", mobile: true do
      gate(categories: category.id.to_s)
      visit(topic.relative_url)
      expect(page).to have_css(".jt-gate .jt-gate__sign-up")
      shot("gate")
      expect_no_theme_errors
    end

    it "gates topics with a gated tag" do
      gate(tags: tag.name)
      visit(topic.relative_url)
      expect(page).to have_css(".jt-gate")
    end

    it "only offers Log in when sign-ups are closed" do
      SiteSetting.invite_only = true
      gate(categories: category.id.to_s)
      visit(topic.relative_url)
      expect(page).to have_css(".jt-gate__log-in.btn-primary")
      expect(page).to have_no_css(".jt-gate__sign-up")
    end

    it "leaves members and other categories alone" do
      gate(categories: Fabricate(:category).id.to_s)
      visit(topic.relative_url)
      expect(page).to have_css(".topic-post")
      expect(page).to have_no_css(".jt-gate")

      gate(categories: category.id.to_s)
      sign_in(member)
      visit(topic.relative_url)
      expect(page).to have_css(".topic-post")
      expect(page).to have_no_css(".jt-gate")
      expect(page).to have_no_css("body.jt-gated")
    end
  end

  it "draws Discourse's icons with Lucide's outline set" do
    sign_in(member)
    visit("/latest")
    expect(page).to have_css(".jt-header-notifications .d-icon-bell")
    icon, drawn = page.evaluate_script(<<~JS)
      (() => {
        const id = document
          .querySelector(".jt-header-notifications .d-icon-bell use")
          .getAttribute("href")
          .slice(1);
        return [id, !!document.querySelector(`symbol#${id}`)];
      })()
    JS
    expect(icon).to eq("jt-bell")
    expect(drawn).to eq(true)
    expect_no_theme_errors
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

  # Core's secondary text (timeline dates, "1 Reply", "view 1 hidden reply",
  # the topic's category in the header) used greys that read at 2.5:1 to
  # 3.4:1. Every grey core and the theme put text in reaches WCAG AA, on the
  # page and on the sunken surface, in light and dark.
  it "keeps secondary text at 4.5:1 or better in light and dark" do
    contrast = <<~JS
      (() => {
        const rgb = (c) => c.match(/[0-9.]+/g).slice(0, 3).map(Number);
        const lum = ([r, g, b]) => {
          const f = (v) => ((v /= 255) <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4);
          return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b);
        };
        const probe = document.createElement("div");
        document.body.appendChild(probe);
        const resolve = (prop, value) => {
          probe.style[prop] = value;
          return rgb(getComputedStyle(probe)[prop]);
        };
        const surfaces = ["var(--secondary)", "var(--jt-surface-sunken)"].map((v) =>
          resolve("backgroundColor", v)
        );
        const worst = {};
        for (const grey of [
          "--primary-medium",
          "--primary-med-or-secondary-high",
          "--header_primary-high",
          "--jt-text-subtle",
        ]) {
          const fg = lum(resolve("color", `var(${grey})`));
          worst[grey] = Math.min(
            ...surfaces.map((bg) => {
              const b = lum(bg);
              return (Math.max(fg, b) + 0.05) / (Math.min(fg, b) + 0.05);
            })
          );
        }
        probe.remove();
        return Object.fromEntries(Object.entries(worst).filter(([, ratio]) => ratio < 4.5));
      })()
    JS

    sign_in(member)
    visit("/latest")
    expect(page).to have_css(".jt-card")
    expect(page.evaluate_script(contrast)).to eq({})

    page.driver.with_playwright_page { |pw| pw.emulate_media(colorScheme: "dark") }
    visit("/latest")
    expect(page).to have_css(".jt-card")
    expect(page.evaluate_script(contrast)).to eq({})
    expect_no_theme_errors
  end

  it "lets people pick JTech Dim instead of OLED black" do
    page.driver.with_playwright_page { |pw| pw.emulate_media(colorScheme: "dark") }
    sign_in(member)
    preferences = PageObjects::Pages::UserPreferencesInterface.new.visit(member)
    dark = PageObjects::Components::SelectKit.new(".dark-color-scheme .select-kit")
    # the theme's own default, by name rather than core's "-1"
    expect(dark).to have_selected_name("JTech Dark")
    dark.expand
    expect(dark).to have_option_name("JTech Dim")
    dark.select_row_by_name("JTech Dim")
    preferences.save_changes

    visit("/latest")
    expect(page).to have_css(".jt-card")
    background = page.evaluate_script("getComputedStyle(document.body).backgroundColor")
    expect(background).to eq("rgb(22, 22, 22)")
    shot("dim-latest")
    expect_no_theme_errors
  end
end
