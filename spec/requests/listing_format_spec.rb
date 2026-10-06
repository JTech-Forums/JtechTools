# frozen_string_literal: true

require "rails_helper"

# The listing format through the endpoints people actually use: replying,
# editing, and the topic page that tells the composer what to fill in.
RSpec.describe "Listing format" do
  # Trust level 2 so core's new-user limits on links don't answer first.
  fab!(:seller) { Fabricate(:user, trust_level: TrustLevel[2], refresh_auto_groups: true) }
  fab!(:moderator) { Fabricate(:moderator, refresh_auto_groups: true) }
  fab!(:sale_topic, :topic)
  fab!(:other_topic, :topic)
  fab!(:opening_post) { Fabricate(:post, topic: sale_topic) }
  fab!(:other_opening_post) { Fabricate(:post, topic: other_topic) }
  # Written before the topic was added to the setting, in no format at all.
  fab!(:older_post) do
    Fabricate(
      :post,
      topic: sale_topic,
      user: seller,
      raw: "Selling my old flip phone, see https://www.ebay.com/itm/123",
    )
  end

  let(:listing) { "Item: Qin F21 Pro\nCondition: Like new\nPrice: $80\nContact: 646-555-0134" }

  before do
    SiteSetting.listing_format_fields = "Item|Condition|Price|Contact"
    SiteSetting.listing_format_topics = sale_topic.id.to_s
  end

  def reply(raw, topic: sale_topic)
    post "/posts.json", params: { raw: raw, topic_id: topic.id }
  end

  describe "replying" do
    before { sign_in(seller) }

    it "takes a reply in the format" do
      expect { reply(listing) }.to change { sale_topic.posts.count }.by(1)
      expect(response.status).to eq(200)
    end

    it "turns away a reply missing a field, saying which" do
      expect { reply(listing.sub("Price: $80\n", "")) }.not_to change { sale_topic.posts.count }
      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"].join).to include("missing: Price")
    end

    it "turns away a reply with a link to another site" do
      expect { reply("#{listing}\nhttps://www.ebay.com/itm/123") }.not_to change {
        sale_topic.posts.count
      }
      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"].join).to include("www.ebay.com")
    end

    it "takes email and phone links" do
      raw = "#{listing.sub("646-555-0134", "[call](tel:+16465550134)")}\n[email](mailto:a@b.com)"
      expect { reply(raw) }.to change { sale_topic.posts.count }.by(1)
    end

    it "leaves other topics alone" do
      expect { reply("Anyone have one? https://www.ebay.com/itm/123", topic: other_topic) }.to change {
        other_topic.posts.count
      }.by(1)
    end

    it "leaves the topic alone once the module is off" do
      SiteSetting.listing_format_enabled = false
      expect { reply("Is this still available?") }.to change { sale_topic.posts.count }.by(1)
    end

    it "leaves the topic alone once the master switch is off" do
      SiteSetting.jtech_enabled = false
      expect { reply("Is this still available?") }.to change { sale_topic.posts.count }.by(1)
    end
  end

  it "lets staff post without the format" do
    sign_in(moderator)
    expect { reply("Reminder: use the format.") }.to change { sale_topic.posts.count }.by(1)
  end

  describe "posts from before" do
    before { sign_in(seller) }

    it "keeps them" do
      expect(older_post.reload.deleted_at).to be_nil
      expect(older_post.hidden).to eq(false)
    end

    it "lets them be edited without adding the fields" do
      put "/posts/#{older_post.id}.json",
          params: {
            post: {
              raw: "SOLD — selling my old flip phone, see https://www.ebay.com/itm/123",
            },
          }
      expect(response.status).to eq(200)
      expect(older_post.reload.raw).to start_with("SOLD")
    end

    it "doesn't let an edit add a link to another site" do
      put "/posts/#{older_post.id}.json",
          params: {
            post: {
              raw: "#{older_post.raw}\nAlso https://www.amazon.com/dp/1",
            },
          }
      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"].join).to include("www.amazon.com")
      expect(older_post.reload.raw).not_to include("amazon")
    end
  end

  it "doesn't let an edit take a field out of a listing" do
    sign_in(seller)
    reply(listing)
    listed = Post.find(response.parsed_body["id"])

    put "/posts/#{listed.id}.json", params: { post: { raw: listing.sub("Price: $80\n", "") } }
    expect(response.status).to eq(422)
    expect(listed.reload.raw).to include("Price: $80")
  end

  describe "the composer's starting text" do
    it "lists the fields for someone who has to follow them" do
      sign_in(seller)
      get "/t/#{sale_topic.id}.json"
      expect(response.parsed_body["listing_format_fields"]).to eq(%w[Item Condition Price Contact])
    end

    it "is left out for staff, visitors and other topics" do
      sign_in(moderator)
      get "/t/#{sale_topic.id}.json"
      expect(response.parsed_body).not_to have_key("listing_format_fields")

      sign_in(seller)
      get "/t/#{other_topic.id}.json"
      expect(response.parsed_body).not_to have_key("listing_format_fields")
    end

    it "is left out for visitors" do
      get "/t/#{sale_topic.id}.json"
      expect(response.parsed_body).not_to have_key("listing_format_fields")
    end
  end

  describe "marking the topic for the REQ-PM button" do
    it "marks a listing topic for everyone, staff and visitors included" do
      get "/t/#{sale_topic.id}.json"
      expect(response.parsed_body["listing_format_topic"]).to eq(true)

      sign_in(moderator)
      get "/t/#{sale_topic.id}.json"
      expect(response.parsed_body["listing_format_topic"]).to eq(true)
    end

    it "leaves other topics unmarked" do
      get "/t/#{other_topic.id}.json"
      expect(response.parsed_body).not_to have_key("listing_format_topic")
    end
  end
end
