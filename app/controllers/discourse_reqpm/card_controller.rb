# frozen_string_literal: true

module DiscourseReqpm
  # The signed-in user's own contact card: the ways they can be reached,
  # whether others may request them, and the setup prompt.
  class CardController < BaseController
    # Server-rendered shell so a hard load or a link to /reqpm boots Ember.
    def page
      render "default/empty"
    end

    def show
      render_json_dump(Presenter.card(current_user))
    end

    def create
      method = exchange.add_method!(contact_params)
      render_json_dump({ method: Presenter.own_method(method) }, status: :created)
    end

    def update
      method = exchange.update_method!(find_own_method, contact_params)
      render_json_dump({ method: Presenter.own_method(method) })
    end

    def destroy
      exchange.remove_method!(find_own_method)
      render json: success_json
    end

    def reorder
      exchange.reorder!(params.require(:ids))
      render_json_dump(Presenter.card(current_user))
    end

    def preferences
      unless params[:allow_requests].nil?
        current_user.custom_fields[
          DiscourseReqpm::ALLOW_REQUESTS_FIELD
        ] = ActiveModel::Type::Boolean.new.cast(params[:allow_requests])
        current_user.save_custom_fields(true)
      end
      render_json_dump(Presenter.card(current_user))
    end

    def snooze_setup
      Setup.snooze!(current_user)
      render json: success_json
    end

    def decline_setup
      Setup.decline!(current_user)
      render json: success_json
    end

    private

    def find_own_method
      ContactMethod.find_by(id: params[:id], user_id: current_user.id) || raise(Discourse::NotFound)
    end

    # Nested under a key the parameter filter masks (see sub_plugins/reqpm.rb),
    # so contact details never reach the request log.
    def contact_params
      params
        .require(:reqpm_contact)
        .permit(:kind, :value, :label, :emoji, :note, :share_by_default)
        .to_h
        .symbolize_keys
    end
  end
end
