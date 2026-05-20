# frozen_string_literal: true

# Routes for the Jtech bundle. Each sub-plugin's URLs are appended directly
# under Discourse::Application — we don't mount the sub-plugins' Rails
# engines.
#
# Why: mounting `DiscourseModCategories::Engine` reliably raised
#   ArgumentError: Invalid route name, already in use: 'discourse_mod_categories'
# at boot, no matter what `as:` we passed or whether the mount was inside
# `routes.draw` or `routes.append`. Something earlier in the boot pipeline
# (Discourse's plugin loader, presumably, since this engine module is also
# referenced from sub_plugins/mod_categories.rb's PluginStore namespace and
# locale tree) registers the helper name first, so a second mount collides.
# Bypassing the engine mount avoids the collision and the route table is
# functionally identical — the controllers under
# `app/controllers/<namespace>/` are autoloaded by Rails regardless of
# whether their parent module is mounted as an engine.
#
# Sub-plugins that don't register routes — Dislike, Another SMTP, Mini-mod —
# rely on Discourse's existing routes via Guardian overrides and event hooks,
# so they have no entries here.

# ── Mod-categories ─────────────────────────────────────────────────────────
Discourse::Application.routes.append do
  scope "/discourse-mod-categories",
        module: "discourse_mod_categories",
        as: :discourse_mod_categories do
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
end

# ── Dumbcourse ─────────────────────────────────────────────────────────────
class DiscourseDumbcourseBasePathConstraint
  def matches?(req)
    req.params[:dumbcourse_base_path].to_s == DiscourseDumbcourse.base_path
  end
end

Discourse::Application.routes.append do
  constraints DiscourseDumbcourseBasePathConstraint.new do
    scope "/:dumbcourse_base_path",
          module: "discourse_dumbcourse",
          as: :discourse_dumbcourse,
          defaults: {
            dumbcourse_base_path: DiscourseDumbcourse.base_path,
          } do
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

      # SSE / ntfy endpoints — must be before the catch-all so stale clients
      # don't get redirected to /login.
      get "/push/sse/:topic" => "sse#stream"
      get "/ntfy/:topic/sse" => "sse#stream"
      get "/ntfy/*path" => "sse#stream"

      # LanguageTool proxy endpoint
      post "/languagetool/check" => "languagetool#check"

      # Main app routes (catch-all) — exclude push and ntfy paths
      get "/" => "app#show"
      get "/*path" => "app#show",
          :constraints => ->(req) do
            base = DiscourseDumbcourse.base_path_with_slash
            !req.path.start_with?("#{base}/push") && !req.path.start_with?("#{base}/ntfy")
          end
    end
  end
end
