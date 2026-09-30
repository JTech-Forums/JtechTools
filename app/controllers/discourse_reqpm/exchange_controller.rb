# frozen_string_literal: true

module DiscourseReqpm
  # Requests and shares between two users.
  class ExchangeController < BaseController
    def inbox
      render_json_dump(Presenter.inbox(current_user))
    end

    # Everything the REQ-PM window on someone's user card needs.
    def relationship
      render_json_dump(Presenter.relationship(current_user, find_user!(params[:username])))
    end

    def create_request
      target = find_user!(params.require(:username))
      exchange.request!(target, wanted_kinds: params[:wanted_kinds])
      render_json_dump(Presenter.relationship(current_user, target), status: :created)
    end

    def decline_request
      request = Request.find_by(id: params[:id], target_id: current_user.id)
      raise Discourse::NotFound if request.nil?
      exchange.decline!(request)
      render json: success_json
    end

    def cancel_request
      request = Request.find_by(id: params[:id], requester_id: current_user.id)
      raise Discourse::NotFound if request.nil?
      exchange.cancel!(request)
      render json: success_json
    end

    def share
      recipient = find_user!(params.require(:username))
      exchange.share!(recipient, method_ids: params.require(:method_ids))
      render_json_dump(Presenter.relationship(current_user, recipient))
    end

    def revoke
      recipient = find_user!(params[:username])
      exchange.revoke!(recipient)
      render_json_dump(Presenter.relationship(current_user, recipient))
    end

    def forget
      owner = find_user!(params[:username])
      exchange.forget!(owner)
      render json: success_json
    end
  end
end
