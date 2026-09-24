# frozen_string_literal: true
# Jtech sub-plugin body, lifted from `discourse-username-avatar/plugin.rb` of the original plugin.
# This file is instance_eval'd by Jtech/plugin.rb in the Plugin::Instance context,
# so DSL methods (after_initialize, register_asset, on, …) work unchanged.

after_initialize do
  module ::DiscourseUsernameAvatar
    module UserEmailHashPatch
      # Discourse's only avatar-relevant caller of this method is
      # UserAvatar#update_gravatar!, which builds the Gravatar request URL as:
      #   https://.../avatar/#{user.email_hash}.png?...&d=404
      #
      # Because that request is always made with d=404, a username-derived hash
      # will not match a real Gravatar account for virtually any user. The
      # request 404s, UserAvatar#update_gravatar! rescues it and leaves the
      # gravatar_upload/uploaded_avatar_id association untouched, and Discourse
      # falls through to its built-in "letter avatar" -- which is already keyed
      # off username, not email. Net effect: default avatars stop varying by
      # email and become consistently username-driven.
      #
      # System/bot accounts (e.g. discobot) are unaffected: UserAvatar looks
      # those up via @@custom_user_gravatar_email_hash *before* ever calling
      # user.email_hash, so this override never runs for them.
      #
      # Users with a manually uploaded custom avatar are unaffected: this
      # method only feeds the Gravatar lookup, which avatar_template never
      # consults once uploaded_avatar_id points at a real custom upload.
      def email_hash
        unless SiteSetting.jtech_enabled && SiteSetting.discourse_username_avatar_enabled
          return super
        end
        return super if username.blank?

        Digest::MD5.hexdigest(username.downcase.strip)
      end
    end
  end

  reloadable_patch { ::User.prepend(DiscourseUsernameAvatar::UserEmailHashPatch) }
end
