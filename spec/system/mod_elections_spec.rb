# frozen_string_literal: true

require "rails_helper"

# Mod elections in the browser: running, ranking candidates on a ballot,
# reading the results, and an admin publishing them. Set
# JTECH_SCREENSHOT_GALLERY=1 to also save screenshots
# (tmp/capybara/mod_elections_*.png).
RSpec.describe "Mod elections" do
  fab!(:admin)
  fab!(:moderator) do
    Fabricate(:moderator, username: "shalom_k", trust_level: TrustLevel[3], created_at: 1.year.ago)
  end
  fab!(:chaim) do
    Fabricate(:user, username: "chaim_w", trust_level: TrustLevel[2], created_at: 1.year.ago)
  end
  fab!(:dovid) do
    Fabricate(:user, username: "dovid_l", trust_level: TrustLevel[3], created_at: 1.year.ago)
  end
  fab!(:voter) do
    Fabricate(:user, username: "rivka_s", trust_level: TrustLevel[3], created_at: 1.year.ago)
  end

  let(:election) do
    DiscourseModElections::Lifecycle.create!(
      admin,
      seats: 2,
      nominations_open_at: 1.minute.ago,
      voting_open_at: 3.days.from_now,
      voting_close_at: 6.days.from_now,
    )
  end

  before do
    SiteSetting.jtech_enabled = true
    SiteSetting.mod_elections_enabled = true
  end

  def shot(name)
    return unless ENV["JTECH_SCREENSHOT_GALLERY"]
    page.save_screenshot("mod_elections_#{name}.png")
  end

  def candidate_for(user)
    election.candidates.find_by(user: user)
  end

  def open_voting
    DiscourseModElections::Nominations.run!(
      chaim,
      election,
      "I answer most of the Android questions.",
    )
    DiscourseModElections::Nominations.run!(dovid, election, "")
    DiscourseModElections::Lifecycle.end_phase!(election, admin)
  end

  it "lets a member run for mod with a statement" do
    election
    sign_in(chaim)
    visit "/elections"

    expect(page).to have_css(".mod-elections-candidate", text: moderator.username)
    find(".mod-elections-run__start").click
    find(".mod-elections-run__statement").fill_in(with: "Fair and fast.")
    shot("01_run_form")
    find(".mod-elections-run__submit").click

    expect(page).to have_css(".mod-elections-run__status", text: "You're running.")
    expect(page).to have_css(".mod-elections-candidate", text: "Fair and fast.")
    expect(candidate_for(chaim).statement).to eq("Fair and fast.")
    shot("02_running")
  end

  it "builds a ranking with the buttons and saves it" do
    open_voting
    sign_in(voter)
    visit "/elections"

    expect(page).to have_css(".global-notice", text: "Vote Week is open")
    ballot = find(".mod-elections-ballot")
    [chaim, dovid].each do |user|
      ballot.find(
        ".mod-elections-ballot__pool [data-candidate-id='#{candidate_for(user).id}'] .mod-elections-ballot__add",
      ).click
    end
    ballot.find(
      ".mod-elections-ballot__ranking [data-candidate-id='#{candidate_for(dovid).id}'] .mod-elections-ballot__up",
    ).click
    shot("03_ballot_ranked")
    ballot.find(".mod-elections-ballot__save").click

    expect(page).to have_css(".mod-elections-ballot__state", text: "Saved")
    saved = DiscourseModElections::Ballot.find_by(election: election, user: voter)
    expect(saved.ranking).to eq([candidate_for(dovid).id, candidate_for(chaim).id])
    expect(saved.weight).to eq(3)

    visit "/elections"
    expect(page).to have_no_css(".global-notice", text: "Vote Week is open")
    places = all(".mod-elections-ballot__ranking .mod-elections-ballot__name").map(&:text)
    expect(places).to eq([dovid.username, chaim.username])
    shot("04_ballot_saved")
  end

  it "doesn't offer a candidate their own name" do
    open_voting
    sign_in(chaim)
    visit "/elections"

    row = find(".mod-elections-ballot__pool [data-candidate-id='#{candidate_for(chaim).id}']")
    expect(row).to have_no_css(".mod-elections-ballot__add")
    expect(row).to have_text("You")
  end

  it "lets an admin check the count before publishing it, then shows the results" do
    open_voting
    DiscourseModElections::Voting.cast!(voter, election, [candidate_for(chaim).id])
    DiscourseModElections::Voting.cast!(dovid, election, [candidate_for(chaim).id])
    DiscourseModElections::Lifecycle.end_phase!(election, admin)

    sign_in(admin)
    visit "/admin/plugins/jtech-tools/mod-elections"
    find(".mod-elections-admin__preview").click
    expect(page).to have_css(".mod-elections-results__winner", text: chaim.username)
    shot("05_admin_preview")
    find(".mod-elections-admin__publish").click
    find(".dialog-footer .btn-primary").click

    expect(page).to have_css(".mod-elections-admin__seats-list", text: chaim.username)
    expect(chaim.reload).to be_moderator

    sign_in(voter)
    visit "/elections"
    expect(page).to have_css(".mod-elections-status", text: "Results")
    expect(page).to have_css(".mod-elections-results__row--elected", text: chaim.username)
    expect(page).to have_css(".mod-elections-results__table th", text: "First choices")
    shot("06_results")
  end
end
