# frozen_string_literal: true

# Routes for the Jtech bundle. Each sub-plugin's engine is mounted at its
# own prefix so existing URLs (and the inherited specs that hit them) keep
# working post-merge.
#
# Sub-plugins that don't register routes — Dislike, Another SMTP, Mini-mod —
# rely on Discourse's existing routes via Guardian overrides and event hooks,
# so they have no entries here.

# ── Mod-categories (lifted from discourse-mod/config/routes.rb) ─────────────
DiscourseModCategories::Engine.routes.draw do
  put "/topic/:topic_id" => "messages#update_topic"
  put "/category/:category_id" => "messages#update_category"
  post "/topic/:topic_id/note-reply" => "messages#add_note_reply"
  put "/topic/:topic_id/note-reply" => "messages#update_note_reply"
  delete "/topic/:topic_id/note-reply" => "messages#delete_note_reply"
  delete "/topic/:topic_id/note" => "messages#delete_note"
  post "/topic/:topic_id/whisper-participant" => "messages#add_whisper_participant"
  get "/notes-feed" => "messages#notes_feed"
  post "/notes-feed/seen" => "messages#notes_feed_seen"
  get "/checklist" => "checklist#show"
  get "/checklist/owed" => "checklist#owed"
  put "/checklist" => "checklist#update"
  post "/checklist/accept" => "checklist#accept"
  post "/checklist/require-reaccept" => "checklist#require_reaccept"
  post "/checklist/targeted" => "checklist#create_targeted"
  put "/checklist/targeted/:id" => "checklist#update_targeted"
  delete "/checklist/targeted/:id" => "checklist#delete_targeted"
  get "/topic/:topic_id/prompt-checklist" => "checklist#show_topic"
  put "/topic/:topic_id/prompt-checklist" => "checklist#update_topic"
  delete "/topic/:topic_id/prompt-checklist" => "checklist#delete_topic"
end

# ── Dumbcourse (lifted from dumbcourse/config/routes.rb) ────────────────────
DiscourseDumbcourse::Engine.routes.draw do
  post "/hcaptcha" => "app#hcaptcha"

  # Push notification endpoints (must be before catch-all)
  scope "/push", defaults: { format: :json } do
    get "/info" => "push#server_info"
    post "/register" => "push#register"
    delete "/unregister" => "push#unregister"
    get "/status" => "push#status"
    get "/preferences" => "push#preferences"
    put "/preferences" => "push#update_preferences"
    post "/test" => "push#test_push"
  end

  # SSE / ntfy endpoints — permanently gone (see sse_controller.rb)
  # Must be before the catch-all so stale clients don't get redirected to /login.
  get "/push/sse/:topic" => "sse#stream"
  get "/ntfy/:topic/sse" => "sse#stream"
  get "/ntfy/*path" => "sse#stream"

  # LanguageTool proxy endpoint
  post "/languagetool/check" => "languagetool#check"

  # Main app routes (catch-all) - exclude push and ntfy paths
  get "/" => "app#show"
  get "/*path" => "app#show",
      :constraints => ->(req) do
        base = DiscourseDumbcourse.base_path_with_slash
        !req.path.start_with?("#{base}/push") && !req.path.start_with?("#{base}/ntfy")
      end
end

class DiscourseDumbcourseBasePathConstraint
  def matches?(req)
    req.params[:dumbcourse_base_path].to_s == DiscourseDumbcourse.base_path
  end
end

# ── Mount points ────────────────────────────────────────────────────────────
Discourse::Application.routes.draw do
  # Keep the original mount paths so existing URLs and specs continue to work.
  mount ::DiscourseModCategories::Engine, at: "discourse-mod-categories"

  constraints DiscourseDumbcourseBasePathConstraint.new do
    scope "/:dumbcourse_base_path",
          defaults: {
            dumbcourse_base_path: DiscourseDumbcourse.base_path,
          } do
      mount ::DiscourseDumbcourse::Engine, at: "/"
    end
  end
end
