# frozen_string_literal: true

module DiscourseMiniMod
  # mini_mod_manage_tags lets mini-mods into the tag admin screens, but a few
  # of those actions reach past the tags they can see: the CSV upload creates
  # tag groups (which stay staff-only), and "unused tags" lists and deletes
  # hidden tags too. Those stay with staff. (Deleting a single tag is
  # already limited to tags they can see by core's fetch_tag.)
  module TagsControllerExtension
    extend ActiveSupport::Concern

    included do
      before_action :mini_mod_forbid_tag_admin, only: %i[upload list_unused destroy_unused]
    end

    private

    def mini_mod_forbid_tag_admin
      raise Discourse::InvalidAccess if current_user && guardian.mini_mod_acting?
    end
  end
end
