# frozen_string_literal: true

module DiscourseListingFormat
  # Marks a listing sold or available again. The seller can, and so can
  # staff, who could already edit the post to say the same thing.
  class ListingsController < ::ApplicationController
    requires_plugin "jtech-tools"
    requires_login

    def sold
      raise Discourse::NotFound unless DiscourseListingFormat.enabled?

      post = Post.find_by(id: params[:id])
      raise Discourse::NotFound unless post
      guardian.ensure_can_see!(post)
      raise Discourse::NotFound unless DiscourseListingFormat.listing?(post)
      raise Discourse::InvalidAccess unless DiscourseListingFormat.can_mark_sold?(post, guardian)

      sold = params.require(:sold).to_s == "true"
      post.custom_fields[DiscourseListingFormat::SOLD_FIELD] = sold
      post.save_custom_fields(true)

      render json: { sold: sold }
    end
  end
end
