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

  # The default sections, in the sale thread's own layout.
  let(:listing) { <<~MD }
      ### ITEM
      Qin F21 Pro

      ### QUANTITY
      1

      ### CONDITION
      Like new

      ### SPECS
      4GB RAM, 64GB storage

      ### IMAGES
      ![phone](/uploads/default/original/1X/abc.png)

      ### PICKUP LOCATION OR SHIPPING AVAILABLE
      Pickup in Brooklyn
    MD

  before { SiteSetting.listing_format_topics = sale_topic.id.to_s }

  def reply(raw, topic: sale_topic)
    post "/posts.json", params: { raw: raw, topic_id: topic.id }
  end

  describe "replying" do
    before { sign_in(seller) }

    it "takes a reply in the format" do
      expect { reply(listing) }.to change { sale_topic.posts.count }.by(1)
      expect(response.status).to eq(200)
    end

    it "turns away a reply with an empty section, saying which" do
      expect { reply(listing.sub("Like new\n", "")) }.not_to change { sale_topic.posts.count }
      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"].join).to include("missing: CONDITION")
    end

    it "turns away a comment" do
      expect { reply("Is this still available?") }.not_to change { sale_topic.posts.count }
      expect(response.status).to eq(422)
    end

    it "turns away a reply with a link to another site" do
      expect { reply("#{listing}\nhttps://www.ebay.com/itm/123") }.not_to change {
        sale_topic.posts.count
      }
      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"].join).to include("www.ebay.com")
    end

    it "takes email and phone links" do
      raw = "#{listing}[call](tel:+16465550134) or [email](mailto:a@b.com)"
      expect { reply(raw) }.to change { sale_topic.posts.count }.by(1)
    end

    it "leaves other topics alone" do
      expect {
        reply("Anyone have one? https://www.ebay.com/itm/123", topic: other_topic)
      }.to change { other_topic.posts.count }.by(1)
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

    it "lets them be edited without adding the sections" do
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

  it "doesn't let an edit empty a section of a listing" do
    sign_in(seller)
    reply(listing)
    listed = Post.find(response.parsed_body["id"])

    put "/posts/#{listed.id}.json", params: { post: { raw: listing.sub("Like new\n", "") } }
    expect(response.status).to eq(422)
    expect(listed.reload.raw).to include("Like new")
  end

  describe "the reply form" do
    it "gets the sections, options and editor section for someone who has to follow them" do
      sign_in(seller)
      get "/t/#{sale_topic.id}.json"
      body = response.parsed_body
      expect(body["listing_format_fields"]).to eq(
        [
          "ITEM",
          "QUANTITY",
          "CONDITION",
          "SPECS",
          "IMAGES",
          "PICKUP LOCATION OR SHIPPING AVAILABLE",
        ],
      )
      expect(body["listing_format_choices"]["CONDITION"]).to eq(
        "multiple" => false,
        "options" => ["New", "Like new", "Used", "For parts"],
        "details" => [],
      )
      expect(body["listing_format_choices"]["PICKUP LOCATION OR SHIPPING AVAILABLE"]).to eq(
        "multiple" => true,
        "options" => ["Pickup", "Shipping available"],
        "details" => ["Pickup"],
      )
      expect(body["listing_format_optional_fields"]).to eq(["IMAGES"])
      expect(body["listing_format_editor_field"]).to eq("IMAGES")
    end

    it "is left out for staff, visitors and other topics" do
      sign_in(moderator)
      get "/t/#{sale_topic.id}.json"
      expect(response.parsed_body.keys).not_to include(
        "listing_format_fields",
        "listing_format_choices",
        "listing_format_editor_field",
      )

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

    it "tells everyone the card layout" do
      get "/t/#{sale_topic.id}.json"
      expect(response.parsed_body["listing_format_card"]).to eq(
        "sections" => [
          "ITEM",
          "QUANTITY",
          "CONDITION",
          "SPECS",
          "IMAGES",
          "PICKUP LOCATION OR SHIPPING AVAILABLE",
        ],
        "images" => "IMAGES",
      )
    end

    it "leaves other topics unmarked" do
      get "/t/#{other_topic.id}.json"
      expect(response.parsed_body).not_to have_key("listing_format_topic")
    end
  end

  describe "marking a listing sold" do
    fab!(:buyer) { Fabricate(:user, trust_level: TrustLevel[2], refresh_auto_groups: true) }
    fab!(:admin)
    fab!(:sold_listing) { Fabricate(:post, topic: sale_topic, user: seller) }

    def mark(post, sold)
      put "/jtech-listing-format/posts/#{post.id}/sold.json", params: { sold: sold }
    end

    def sold?(post)
      post.reload.custom_fields[DiscourseListingFormat::SOLD_FIELD] == true
    end

    it "lets the seller mark it sold and available again" do
      sign_in(seller)
      mark(sold_listing, true)
      expect(response.status).to eq(200)
      expect(response.parsed_body["sold"]).to eq(true)
      expect(sold?(sold_listing)).to eq(true)

      mark(sold_listing, false)
      expect(response.status).to eq(200)
      expect(sold?(sold_listing)).to eq(false)
    end

    it "lets moderators and admins mark it" do
      sign_in(moderator)
      mark(sold_listing, true)
      expect(response.status).to eq(200)

      sign_in(admin)
      mark(sold_listing, false)
      expect(response.status).to eq(200)
      expect(sold?(sold_listing)).to eq(false)
    end

    it "doesn't let anyone else mark it" do
      sign_in(buyer)
      mark(sold_listing, true)
      expect(response.status).to eq(403)
      expect(sold?(sold_listing)).to eq(false)

      sign_out
      mark(sold_listing, true)
      expect(response.status).to eq(403)
    end

    it "only marks listings: not the opening post, not other topics" do
      sign_in(moderator)
      mark(opening_post, true)
      expect(response.status).to eq(404)
      mark(other_opening_post, true)
      expect(response.status).to eq(404)
    end

    it "doesn't reach a post the person can't see" do
      private_category = Fabricate(:private_category, group: Fabricate(:group))
      sale_topic.update!(category: private_category)
      sign_in(seller)
      mark(sold_listing, true)
      expect(response.status).to eq(403)
      expect(sold?(sold_listing)).to eq(false)
    end

    it "is gone once the module is off" do
      SiteSetting.listing_format_enabled = false
      sign_in(seller)
      mark(sold_listing, true)
      expect(response.status).to eq(404)
    end

    it "shows everyone whether each listing is sold" do
      sold_listing.custom_fields[DiscourseListingFormat::SOLD_FIELD] = true
      sold_listing.save_custom_fields

      get "/t/#{sale_topic.id}.json"
      posts = response.parsed_body["post_stream"]["posts"].index_by { |p| p["id"] }
      expect(posts[sold_listing.id]["listing_sold"]).to eq(true)
      expect(posts[older_post.id]["listing_sold"]).to eq(false)
      expect(posts[opening_post.id]).not_to have_key("listing_sold")

      get "/t/#{other_topic.id}.json"
      expect(response.parsed_body["post_stream"]["posts"].first).not_to have_key("listing_sold")
    end
  end
end
