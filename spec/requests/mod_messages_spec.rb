# frozen_string_literal: true

require "rails_helper"

# Verifies that only moderators and admins can set the plugin's
# moderator messages, and that regular/anonymous users are forbidden.
RSpec.describe "Moderator messages endpoints" do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:first_post) { Fabricate(:post, topic: topic) }

  before { SiteSetting.mod_categories_enabled = true }

  describe "PUT /discourse-mod-categories/topic/:topic_id" do
    it "lets a moderator set the footer message and reply prompt" do
      sign_in(moderator)

      put "/discourse-mod-categories/topic/#{topic.id}.json",
          params: {
            footer_message: "Read the pinned guidelines.",
            reply_prompt: "Is your reply on-topic?",
          }

      expect(response.status).to eq(200)
      expect(topic.reload.custom_fields["mod_topic_footer_message"]).to eq(
        "Read the pinned guidelines.",
      )
      expect(topic.custom_fields["mod_topic_reply_prompt"]).to eq(
        "Is your reply on-topic?",
      )
    end

    it "lets an admin set the messages" do
      sign_in(admin)

      put "/discourse-mod-categories/topic/#{topic.id}.json",
          params: {
            footer_message: "Set by an admin",
          }

      expect(response.status).to eq(200)
      expect(topic.reload.custom_fields["mod_topic_footer_message"]).to eq(
        "Set by an admin",
      )
    end

    it "forbids a regular user (only mods/admins may set it)" do
      sign_in(user)

      put "/discourse-mod-categories/topic/#{topic.id}.json",
          params: {
            footer_message: "should not be saved",
          }

      expect(response.status).to eq(403)
      expect(topic.reload.custom_fields["mod_topic_footer_message"]).to be_blank
    end

    it "forbids an anonymous user" do
      put "/discourse-mod-categories/topic/#{topic.id}.json",
          params: {
            footer_message: "should not be saved",
          }

      expect(response.status).to eq(403)
      expect(topic.reload.custom_fields["mod_topic_footer_message"]).to be_blank
    end

    it "returns 404 for a missing topic" do
      sign_in(moderator)

      put "/discourse-mod-categories/topic/0.json",
          params: {
            footer_message: "x",
          }

      expect(response.status).to eq(404)
    end

    it "updates only the fields that are provided" do
      topic.custom_fields["mod_topic_reply_prompt"] = "existing prompt"
      topic.save_custom_fields(true)
      sign_in(moderator)

      put "/discourse-mod-categories/topic/#{topic.id}.json",
          params: {
            footer_message: "new footer",
          }

      expect(response.status).to eq(200)
      expect(topic.reload.custom_fields["mod_topic_reply_prompt"]).to eq(
        "existing prompt",
      )
    end

    it "lets a moderator pin a post to the bottom" do
      sign_in(moderator)

      put "/discourse-mod-categories/topic/#{topic.id}.json",
          params: {
            pinned_post_id: first_post.id,
          }

      expect(response.status).to eq(200)
      expect(topic.reload.custom_fields["mod_topic_pinned_post_id"]).to eq(
        first_post.id,
      )
    end

    it "lets a moderator unpin by sending a blank pinned_post_id" do
      topic.custom_fields["mod_topic_pinned_post_id"] = first_post.id
      topic.save_custom_fields(true)
      sign_in(moderator)

      put "/discourse-mod-categories/topic/#{topic.id}.json",
          params: {
            pinned_post_id: "",
          }

      expect(response.status).to eq(200)
      expect(
        topic.reload.custom_fields["mod_topic_pinned_post_id"],
      ).to be_blank
    end

    it "rejects a pinned_post_id that is not a post in this topic" do
      other_post = Fabricate(:post)
      sign_in(moderator)

      put "/discourse-mod-categories/topic/#{topic.id}.json",
          params: {
            pinned_post_id: other_post.id,
          }

      expect(response.status).to eq(400)
      expect(
        topic.reload.custom_fields["mod_topic_pinned_post_id"],
      ).to be_blank
    end

    it "forbids a regular user from pinning a post" do
      sign_in(user)

      put "/discourse-mod-categories/topic/#{topic.id}.json",
          params: {
            pinned_post_id: first_post.id,
          }

      expect(response.status).to eq(403)
      expect(
        topic.reload.custom_fields["mod_topic_pinned_post_id"],
      ).to be_blank
    end

    it "accepts a long, unicode footer message" do
      sign_in(moderator)
      long_message = "проверка 🚀 wide content " * 200

      put "/discourse-mod-categories/topic/#{topic.id}.json",
          params: {
            footer_message: long_message,
          }

      expect(response.status).to eq(200)
      expect(topic.reload.custom_fields["mod_topic_footer_message"]).to eq(
        long_message,
      )
    end

    it "clears the reply prompt when sent an empty string" do
      topic.custom_fields["mod_topic_reply_prompt"] = "An old prompt"
      topic.save_custom_fields(true)
      sign_in(moderator)

      put "/discourse-mod-categories/topic/#{topic.id}.json",
          params: {
            reply_prompt: "",
          }

      expect(response.status).to eq(200)
      expect(topic.reload.custom_fields["mod_topic_reply_prompt"]).to eq("")
    end

    it "is a no-op when no recognised params are sent" do
      topic.custom_fields["mod_topic_footer_message"] = "Keep me"
      topic.save_custom_fields(true)
      sign_in(moderator)

      put "/discourse-mod-categories/topic/#{topic.id}.json", params: {}

      expect(response.status).to eq(200)
      expect(topic.reload.custom_fields["mod_topic_footer_message"]).to eq(
        "Keep me",
      )
    end

    it "pins, then unpins, leaving no pinned post" do
      sign_in(moderator)

      put "/discourse-mod-categories/topic/#{topic.id}.json",
          params: {
            pinned_post_id: first_post.id,
          }
      expect(topic.reload.custom_fields["mod_topic_pinned_post_id"]).to eq(
        first_post.id,
      )

      put "/discourse-mod-categories/topic/#{topic.id}.json",
          params: {
            pinned_post_id: "",
          }
      expect(
        topic.reload.custom_fields["mod_topic_pinned_post_id"],
      ).to be_blank
    end

    it "treats pinned_post_id 0 as unpin" do
      topic.custom_fields["mod_topic_pinned_post_id"] = first_post.id
      topic.save_custom_fields(true)
      sign_in(moderator)

      put "/discourse-mod-categories/topic/#{topic.id}.json",
          params: {
            pinned_post_id: "0",
          }

      expect(response.status).to eq(200)
      expect(
        topic.reload.custom_fields["mod_topic_pinned_post_id"],
      ).to be_blank
    end

    it "lets a moderator require reply approval for the topic" do
      sign_in(moderator)

      put "/discourse-mod-categories/topic/#{topic.id}.json",
          params: {
            require_reply_approval: true,
          }

      expect(response.status).to eq(200)
      expect(
        topic.reload.custom_fields["mod_topic_require_reply_approval"],
      ).to eq(true)
    end

    it "lets a moderator turn reply approval back off" do
      topic.custom_fields["mod_topic_require_reply_approval"] = true
      topic.save_custom_fields(true)
      sign_in(moderator)

      put "/discourse-mod-categories/topic/#{topic.id}.json",
          params: {
            require_reply_approval: false,
          }

      expect(response.status).to eq(200)
      expect(
        topic.reload.custom_fields["mod_topic_require_reply_approval"],
      ).to eq(false)
    end

    it "forbids a regular user from changing reply approval" do
      sign_in(user)

      put "/discourse-mod-categories/topic/#{topic.id}.json",
          params: {
            require_reply_approval: true,
          }

      expect(response.status).to eq(403)
    end

    it "lets a moderator set a private note and its position" do
      sign_in(moderator)

      put "/discourse-mod-categories/topic/#{topic.id}.json",
          params: {
            private_note: "For staff only",
            private_note_position: "top",
          }

      expect(response.status).to eq(200)
      expect(topic.reload.custom_fields["mod_topic_private_note"]).to eq(
        "For staff only",
      )
      expect(
        topic.custom_fields["mod_topic_private_note_position"],
      ).to eq("top")
      # The moderator who set the note is recorded as its author.
      expect(
        topic.custom_fields["mod_topic_private_note_user_id"],
      ).to eq(moderator.id)
      expect(response.parsed_body["private_note_author"]["username"]).to eq(
        moderator.username,
      )
    end

    it "falls back to bottom for an invalid note position" do
      sign_in(moderator)

      put "/discourse-mod-categories/topic/#{topic.id}.json",
          params: {
            private_note: "note",
            private_note_position: "sideways",
          }

      expect(response.status).to eq(200)
      expect(
        topic.reload.custom_fields["mod_topic_private_note_position"],
      ).to eq("bottom")
    end

    it "forbids a regular user from setting a private note" do
      sign_in(user)

      put "/discourse-mod-categories/topic/#{topic.id}.json",
          params: {
            private_note: "should not be saved",
          }

      expect(response.status).to eq(403)
      expect(
        topic.reload.custom_fields["mod_topic_private_note"],
      ).to be_blank
    end
  end

  describe "PUT /discourse-mod-categories/category/:category_id" do
    it "lets a moderator set the per-category new-topic prompt" do
      sign_in(moderator)

      put "/discourse-mod-categories/category/#{category.id}.json",
          params: {
            new_topic_prompt: "Have you searched for an existing topic?",
          }

      expect(response.status).to eq(200)
      expect(
        category.reload.custom_fields["mod_category_new_topic_prompt"],
      ).to eq("Have you searched for an existing topic?")
    end

    it "lets an admin set the per-category new-topic prompt" do
      sign_in(admin)

      put "/discourse-mod-categories/category/#{category.id}.json",
          params: {
            new_topic_prompt: "Set by an admin",
          }

      expect(response.status).to eq(200)
      expect(
        category.reload.custom_fields["mod_category_new_topic_prompt"],
      ).to eq("Set by an admin")
    end

    it "forbids a regular user (only mods/admins may set it)" do
      sign_in(user)

      put "/discourse-mod-categories/category/#{category.id}.json",
          params: {
            new_topic_prompt: "should not be saved",
          }

      expect(response.status).to eq(403)
      expect(
        category.reload.custom_fields["mod_category_new_topic_prompt"],
      ).to be_blank
    end

    it "forbids an anonymous user" do
      put "/discourse-mod-categories/category/#{category.id}.json",
          params: {
            new_topic_prompt: "should not be saved",
          }

      expect(response.status).to eq(403)
    end

    it "returns 404 for a missing category" do
      sign_in(moderator)

      put "/discourse-mod-categories/category/0.json",
          params: {
            new_topic_prompt: "x",
          }

      expect(response.status).to eq(404)
    end

    it "clears the new-topic prompt when sent an empty string" do
      category.custom_fields["mod_category_new_topic_prompt"] = "An old prompt"
      category.save_custom_fields(true)
      sign_in(moderator)

      put "/discourse-mod-categories/category/#{category.id}.json",
          params: {
            new_topic_prompt: "",
          }

      expect(response.status).to eq(200)
      expect(
        category.reload.custom_fields["mod_category_new_topic_prompt"],
      ).to eq("")
    end

    it "stores the new-topic prompt trust-level cap" do
      sign_in(moderator)

      put "/discourse-mod-categories/category/#{category.id}.json",
          params: {
            new_topic_prompt: "Read the guidelines",
            new_topic_prompt_max_tl: 1,
          }

      expect(response.status).to eq(200)
      expect(response.parsed_body["new_topic_prompt_max_tl"]).to eq(1)
      expect(
        category.reload.custom_fields["mod_category_new_topic_prompt_max_tl"],
      ).to eq(1)
    end

    it "clamps an out-of-range new-topic trust-level cap to 0-4" do
      sign_in(moderator)

      put "/discourse-mod-categories/category/#{category.id}.json",
          params: {
            new_topic_prompt: "x",
            new_topic_prompt_max_tl: 9,
          }
      expect(response.parsed_body["new_topic_prompt_max_tl"]).to eq(4)

      put "/discourse-mod-categories/category/#{category.id}.json",
          params: {
            new_topic_prompt: "x",
            new_topic_prompt_max_tl: -3,
          }
      expect(response.parsed_body["new_topic_prompt_max_tl"]).to eq(0)
    end
  end

  describe "reply-prompt trust-level cap" do
    it "stores the reply-prompt trust-level cap on the topic" do
      sign_in(moderator)

      put "/discourse-mod-categories/topic/#{topic.id}.json",
          params: {
            reply_prompt: "Is your reply on-topic?",
            reply_prompt_max_tl: 1,
          }

      expect(response.status).to eq(200)
      expect(response.parsed_body["reply_prompt_max_tl"]).to eq(1)
      expect(
        topic.reload.custom_fields["mod_topic_reply_prompt_max_tl"],
      ).to eq(1)
    end

    it "clamps an out-of-range reply trust-level cap to 0-4" do
      sign_in(moderator)

      put "/discourse-mod-categories/topic/#{topic.id}.json",
          params: {
            reply_prompt: "x",
            reply_prompt_max_tl: 99,
          }
      expect(response.parsed_body["reply_prompt_max_tl"]).to eq(4)
    end

    it "leaves the cap untouched when the param is absent" do
      topic.custom_fields["mod_topic_reply_prompt_max_tl"] = 2
      topic.save_custom_fields(true)
      sign_in(moderator)

      put "/discourse-mod-categories/topic/#{topic.id}.json",
          params: {
            reply_prompt: "changed",
          }

      expect(
        topic.reload.custom_fields["mod_topic_reply_prompt_max_tl"],
      ).to eq(2)
    end
  end

  describe "POST /discourse-mod-categories/topic/:topic_id/note-reply" do
    it "lets a moderator add a reply to the note thread" do
      sign_in(moderator)

      post "/discourse-mod-categories/topic/#{topic.id}/note-reply.json",
           params: {
             raw: "Following up on this note.",
           }

      expect(response.status).to eq(200)
      replies =
        topic.reload.custom_fields["mod_topic_private_note_replies"]
      expect(replies.last["raw"]).to eq("Following up on this note.")
      expect(replies.last["user_id"]).to eq(moderator.id)
      expect(replies.last["created_at"]).to be_present
    end

    it "appends multiple replies in order" do
      sign_in(moderator)

      post "/discourse-mod-categories/topic/#{topic.id}/note-reply.json",
           params: {
             raw: "First reply.",
           }
      post "/discourse-mod-categories/topic/#{topic.id}/note-reply.json",
           params: {
             raw: "Second reply.",
           }

      replies =
        topic.reload.custom_fields["mod_topic_private_note_replies"]
      expect(replies.map { |r| r["raw"] }).to eq(
        ["First reply.", "Second reply."],
      )
    end

    it "returns the serialized replies with author info" do
      sign_in(moderator)

      post "/discourse-mod-categories/topic/#{topic.id}/note-reply.json",
           params: {
             raw: "Hello team.",
           }

      reply = response.parsed_body["replies"].last
      expect(reply["raw"]).to eq("Hello team.")
      expect(reply["author"]["username"]).to eq(moderator.username)
    end

    it "rejects a blank reply" do
      sign_in(moderator)

      post "/discourse-mod-categories/topic/#{topic.id}/note-reply.json",
           params: {
             raw: "   ",
           }

      expect(response.status).to eq(400)
    end

    it "forbids a regular user from replying to the note" do
      sign_in(user)

      post "/discourse-mod-categories/topic/#{topic.id}/note-reply.json",
           params: {
             raw: "should not be saved",
           }

      expect(response.status).to eq(403)
      expect(
        topic.reload.custom_fields["mod_topic_private_note_replies"],
      ).to be_blank
    end
  end

  describe "editing and deleting note-thread entries" do
    # Seeds the topic with a note plus two staff replies and returns their ids.
    def seed_thread
      put "/discourse-mod-categories/topic/#{topic.id}.json",
          params: {
            private_note: "The note body.",
          }
      post "/discourse-mod-categories/topic/#{topic.id}/note-reply.json",
           params: {
             raw: "First reply.",
           }
      post "/discourse-mod-categories/topic/#{topic.id}/note-reply.json",
           params: {
             raw: "Second reply.",
           }
      topic.reload.custom_fields["mod_topic_private_note_replies"].map do |r|
        r["id"]
      end
    end

    describe "PUT /discourse-mod-categories/topic/:topic_id/note-reply" do
      it "lets a moderator edit a reply's raw" do
        sign_in(moderator)
        ids = seed_thread

        put "/discourse-mod-categories/topic/#{topic.id}/note-reply.json",
            params: {
              reply_id: ids.first,
              raw: "Edited first reply.",
            }

        expect(response.status).to eq(200)
        replies = topic.reload.custom_fields["mod_topic_private_note_replies"]
        edited = replies.find { |r| r["id"] == ids.first }
        expect(edited["raw"]).to eq("Edited first reply.")
        # The other reply is untouched.
        other = replies.find { |r| r["id"] == ids.last }
        expect(other["raw"]).to eq("Second reply.")
        body = response.parsed_body
        expect(body["replies"].first["raw"]).to eq("Edited first reply.")
        expect(body["replies"].first["id"]).to eq(ids.first)
      end

      it "rejects an edit with a blank raw" do
        sign_in(moderator)
        ids = seed_thread

        put "/discourse-mod-categories/topic/#{topic.id}/note-reply.json",
            params: {
              reply_id: ids.first,
              raw: "   ",
            }

        expect(response.status).to eq(400)
      end

      it "rejects an edit for an unknown reply_id" do
        sign_in(moderator)
        seed_thread

        put "/discourse-mod-categories/topic/#{topic.id}/note-reply.json",
            params: {
              reply_id: "deadbeefdeadbeef",
              raw: "Nope.",
            }

        expect(response.status).to eq(400)
      end

      it "forbids a regular user from editing a reply" do
        sign_in(moderator)
        ids = seed_thread

        sign_in(user)
        put "/discourse-mod-categories/topic/#{topic.id}/note-reply.json",
            params: {
              reply_id: ids.first,
              raw: "should not save",
            }

        expect(response.status).to eq(403)
        replies = topic.reload.custom_fields["mod_topic_private_note_replies"]
        expect(replies.find { |r| r["id"] == ids.first }["raw"]).to eq(
          "First reply.",
        )
      end

      it "forbids an anonymous user from editing a reply" do
        sign_in(moderator)
        ids = seed_thread

        delete "/session/#{moderator.username}.json"
        put "/discourse-mod-categories/topic/#{topic.id}/note-reply.json",
            params: {
              reply_id: ids.first,
              raw: "should not save",
            }

        expect(response.status).to eq(403)
      end
    end

    describe "DELETE /discourse-mod-categories/topic/:topic_id/note-reply" do
      it "lets a moderator delete a single reply, leaving the rest intact" do
        sign_in(moderator)
        ids = seed_thread

        delete "/discourse-mod-categories/topic/#{topic.id}/note-reply.json",
               params: {
                 reply_id: ids.first,
               }

        expect(response.status).to eq(200)
        replies = topic.reload.custom_fields["mod_topic_private_note_replies"]
        expect(replies.map { |r| r["id"] }).to eq([ids.last])
        expect(replies.first["raw"]).to eq("Second reply.")
      end

      it "handles an unknown reply_id" do
        sign_in(moderator)
        seed_thread

        delete "/discourse-mod-categories/topic/#{topic.id}/note-reply.json",
               params: {
                 reply_id: "deadbeefdeadbeef",
               }

        expect(response.status).to eq(400)
      end

      it "forbids a regular user from deleting a reply" do
        sign_in(moderator)
        ids = seed_thread

        sign_in(user)
        delete "/discourse-mod-categories/topic/#{topic.id}/note-reply.json",
               params: {
                 reply_id: ids.first,
               }

        expect(response.status).to eq(403)
        expect(
          topic.reload.custom_fields["mod_topic_private_note_replies"].size,
        ).to eq(2)
      end
    end

    describe "DELETE /discourse-mod-categories/topic/:topic_id/note" do
      it "lets a moderator delete the note and its replies" do
        sign_in(moderator)
        seed_thread

        delete "/discourse-mod-categories/topic/#{topic.id}/note.json"

        expect(response.status).to eq(200)
        topic.reload
        expect(topic.custom_fields["mod_topic_private_note"]).to be_blank
        expect(
          topic.custom_fields["mod_topic_private_note_replies"],
        ).to be_blank
        expect(response.parsed_body["private_note"]).to eq("")
        expect(response.parsed_body["replies"]).to eq([])
      end

      it "forbids a regular user from deleting the note" do
        sign_in(moderator)
        seed_thread

        sign_in(user)
        delete "/discourse-mod-categories/topic/#{topic.id}/note.json"

        expect(response.status).to eq(403)
        expect(
          topic.reload.custom_fields["mod_topic_private_note"],
        ).to eq("The note body.")
      end

      it "forbids an anonymous user from deleting the note" do
        sign_in(moderator)
        seed_thread

        delete "/session/#{moderator.username}.json"
        delete "/discourse-mod-categories/topic/#{topic.id}/note.json"

        expect(response.status).to eq(403)
      end
    end
  end

  describe "GET /discourse-mod-categories/notes-feed" do
    before do
      topic.custom_fields["mod_topic_private_note"] = "A note to review."
      topic.custom_fields["mod_topic_private_note_activity_at"] = Time
        .zone
        .now
        .iso8601
      topic.save_custom_fields(true)
    end

    it "lists topics that have a moderator note, for staff" do
      sign_in(moderator)

      get "/discourse-mod-categories/notes-feed.json"

      expect(response.status).to eq(200)
      notes = response.parsed_body["notes"]
      expect(notes.map { |n| n["topic_id"] }).to include(topic.id)
      expect(notes.first["note"]).to eq("A note to review.")
    end

    it "forbids a regular user" do
      sign_in(user)

      get "/discourse-mod-categories/notes-feed.json"

      expect(response.status).to eq(403)
    end
  end

  describe "POST /discourse-mod-categories/notes-feed/seen" do
    it "records the staff member's seen timestamp" do
      sign_in(moderator)

      post "/discourse-mod-categories/notes-feed/seen.json"

      expect(response.status).to eq(200)
      expect(
        moderator.reload.custom_fields["mod_notes_seen_at"],
      ).to be_present
    end

    it "forbids a regular user" do
      sign_in(user)

      post "/discourse-mod-categories/notes-feed/seen.json"

      expect(response.status).to eq(403)
    end

    it "links each note to the topic's last post" do
      topic.custom_fields["mod_topic_private_note"] = "Review me."
      topic.save_custom_fields(true)
      sign_in(moderator)

      get "/discourse-mod-categories/notes-feed.json"

      url = response.parsed_body["notes"].first["url"]
      expect(url).to match(%r{/#{topic.id}/\d+\z})
    end
  end

  describe "moderator-note notifications" do
    def custom_notifications(user)
      Notification.where(
        user_id: user.id,
        notification_type: Notification.types[:custom],
        topic_id: topic.id,
      )
    end

    it "notifies other staff when a moderator sets a note" do
      sign_in(moderator)

      expect {
        put "/discourse-mod-categories/topic/#{topic.id}.json",
            params: {
              private_note: "Heads up, staff.",
            }
      }.to change { custom_notifications(admin).count }.by(1)
    end

    it "does not notify the moderator who set the note" do
      sign_in(moderator)

      put "/discourse-mod-categories/topic/#{topic.id}.json",
          params: {
            private_note: "A note.",
          }

      expect(custom_notifications(moderator).count).to eq(0)
    end

    it "does not notify regular users" do
      sign_in(moderator)

      put "/discourse-mod-categories/topic/#{topic.id}.json",
          params: {
            private_note: "A note.",
          }

      expect(custom_notifications(user).count).to eq(0)
    end

    it "notifies staff when a reply is added to the note" do
      sign_in(moderator)

      expect {
        post "/discourse-mod-categories/topic/#{topic.id}/note-reply.json",
             params: {
               raw: "Following up.",
             }
      }.to change { custom_notifications(admin).count }.by(1)
    end
  end
end
