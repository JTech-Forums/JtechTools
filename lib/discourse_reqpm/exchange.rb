# frozen_string_literal: true

module DiscourseReqpm
  # Everything one user can do to another in REQ-PM: ask for their details,
  # send their own, take back what they sent, forget what they received,
  # and answer or withdraw requests. Also the owner's edits to their own
  # card. Controllers stay thin and call in here.
  class Exchange
    class Error < StandardError
      attr_reader :reason, :details

      def initialize(reason, details = {})
        @reason = reason
        @details = details
        super(reason.to_s)
      end
    end

    attr_reader :actor

    def initialize(actor)
      @actor = actor
    end

    # ── Own card ──────────────────────────────────────────────────────────

    def add_method!(attrs)
      if ContactMethod.where(user_id: actor.id).count >= SiteSetting.reqpm_max_methods
        raise Error.new(:too_many_methods, max: SiteSetting.reqpm_max_methods)
      end
      RateLimiter.new(actor, "reqpm-card-edit", 60, 1.hour).performed!

      cleaned = normalize!(attrs)
      method = ContactMethod.new(user_id: actor.id)
      assign(method, cleaned, attrs)
      method.position = (ContactMethod.where(user_id: actor.id).maximum(:position) || -1) + 1
      method.save!
      method
    end

    def update_method!(method, attrs)
      ensure_own!(method)
      RateLimiter.new(actor, "reqpm-card-edit", 60, 1.hour).performed!
      # Fields left out keep their current value, so a single toggle can be
      # saved on its own.
      current = {
        kind: method.kind,
        value: method.value,
        label: method.label,
        emoji: method.emoji,
        note: method.note,
      }
      given = attrs.slice(*current.keys).reject { |_, v| v.nil? }
      cleaned = normalize!(current.merge(given))
      assign(method, cleaned, attrs)
      method.save!
      publish_refresh(method.shares.pluck(:recipient_id))
      method
    end

    def remove_method!(method)
      ensure_own!(method)
      recipient_ids = method.shares.pluck(:recipient_id)
      method.destroy!
      publish_refresh(recipient_ids)
    end

    def reorder!(ids)
      ids = Array(ids).map(&:to_i)
      methods = ContactMethod.where(user_id: actor.id).index_by(&:id)
      raise Error.new(:invalid_methods) if ids.sort != methods.keys.sort
      ContactMethod.transaction do
        ids.each_with_index { |id, index| methods[id].update_columns(position: index) }
      end
    end

    # ── Requests ──────────────────────────────────────────────────────────

    def request!(target, wanted_kinds: [])
      ensure_reachable!(target, for_request: true)
      wanted = Array(wanted_kinds).map(&:to_s).uniq.select { |k| Kinds.valid?(k) }

      Request.transaction do
        expire_stale!(requester_id: actor.id, target_id: target.id)
        if Request.pending.exists?(requester_id: actor.id, target_id: target.id)
          raise Error.new(:pending)
        end
        if (retry_at = Presenter.cooldown_until(actor, target))
          raise Error.new(:cooldown, retry_at: retry_at)
        end

        RateLimiter.new(
          actor,
          "reqpm-request",
          SiteSetting.reqpm_max_requests_per_day,
          1.day,
        ).performed!

        @request =
          Request.create!(
            requester_id: actor.id,
            target_id: target.id,
            wanted_kinds: wanted,
            status: :pending,
          )
      end

      Notifier.request_created(@request)
      publish_state(target)
      @request
    rescue ActiveRecord::RecordNotUnique
      raise Error.new(:pending)
    end

    def decline!(request)
      raise Error.new(:not_found) unless request.target_id == actor.id && request.open?
      request.update!(status: :declined, responded_at: Time.zone.now)
      Notifier.mark_read(user: actor, actor_id: request.requester_id, kind: "request")
      publish_state(actor)
      request
    end

    def cancel!(request)
      raise Error.new(:not_found) unless request.requester_id == actor.id && request.pending?
      request.update!(status: :cancelled, responded_at: Time.zone.now)
      target = request.target
      Notifier.remove(user: target, actor_id: actor.id, kind: "request")
      publish_state(target)
      request
    end

    # ── Sharing ───────────────────────────────────────────────────────────

    # Makes `method_ids` exactly what `recipient` can see of actor's card:
    # newly ticked methods are shared, unticked ones are taken back. Only
    # additions notify the recipient.
    def share!(recipient, method_ids:)
      ensure_reachable!(recipient, for_request: false)
      ids = Array(method_ids).map(&:to_i).uniq
      raise Error.new(:nothing_selected) if ids.empty?

      methods = ContactMethod.where(user_id: actor.id, id: ids).to_a
      raise Error.new(:invalid_methods) if methods.size != ids.size
      raise Error.new(:unreadable) if methods.any?(&:unreadable?)

      current =
        Share.where(owner_id: actor.id, recipient_id: recipient.id).pluck(:contact_method_id)
      added = ids - current
      removed = current - ids

      if added.any?
        RateLimiter.new(
          actor,
          "reqpm-share",
          SiteSetting.reqpm_max_shares_per_day,
          1.day,
        ).performed!
      end

      answered = 0
      Share.transaction do
        if removed.any?
          Share.where(
            owner_id: actor.id,
            recipient_id: recipient.id,
            contact_method_id: removed,
          ).delete_all
        end
        if added.any?
          # Two quick clicks may race; the unique index keeps one row.
          Share.insert_all(
            added.map do |id|
              { owner_id: actor.id, recipient_id: recipient.id, contact_method_id: id }
            end,
            unique_by: %i[contact_method_id recipient_id],
          )
        end
        answered =
          Request
            .open_requests
            .where(requester_id: recipient.id, target_id: actor.id)
            .update_all(status: Request.statuses[:fulfilled], responded_at: Time.zone.now)
      end

      Notifier.shared(owner: actor, recipient: recipient) if added.any?
      if answered > 0
        Notifier.mark_read(user: actor, actor_id: recipient.id, kind: "request")
        publish_state(actor)
      end
      publish_refresh([recipient.id])
      { added: added, removed: removed }
    end

    # Takes back everything actor shared with `recipient`. Always allowed,
    # whoever the recipient is now; the recipient is not told.
    def revoke!(recipient)
      Share.where(owner_id: actor.id, recipient_id: recipient.id).delete_all
      Notifier.remove(user: recipient, actor_id: actor.id, kind: "shared")
      publish_refresh([recipient.id])
    end

    # Drops `owner`'s details from actor's own list. The owner is not told.
    def forget!(owner)
      Share.where(owner_id: owner.id, recipient_id: actor.id).delete_all
      Notifier.mark_read(user: actor, actor_id: owner.id, kind: "shared")
    end

    private

    def normalize!(attrs)
      Kinds.normalize!(
        kind: attrs[:kind],
        value: attrs[:value],
        label: attrs[:label],
        emoji: attrs[:emoji],
        note: attrs[:note],
      )
    rescue Kinds::Invalid => e
      raise Error.new(:invalid_field, field: e.field, problem: e.reason)
    end

    def assign(method, cleaned, attrs)
      method.kind = cleaned[:kind]
      method.value = cleaned[:value]
      method.label = cleaned[:label]
      method.note = cleaned[:note]
      method.emoji = cleaned[:emoji]
      unless attrs[:share_by_default].nil?
        method.share_by_default = ActiveModel::Type::Boolean.new.cast(attrs[:share_by_default])
      end
    end

    def ensure_own!(method)
      raise Error.new(:not_found) if method.nil? || method.user_id != actor.id
    end

    def ensure_reachable!(target, for_request:)
      reason = Policy.blocked_reason(actor, target, for_request: for_request)
      raise Error.new(reason) if reason
    end

    def expire_stale!(requester_id:, target_id:)
      Request
        .pending
        .where(requester_id: requester_id, target_id: target_id)
        .where("created_at <= ?", Request.expiry_cutoff)
        .update_all(status: Request.statuses[:expired])
    end

    # Pending-request badge for `user`. Counts only, never content.
    def publish_state(user)
      MessageBus.publish(
        "/reqpm/state",
        { incoming_count: Presenter.incoming_count(user) },
        user_ids: [user.id],
      )
    end

    # Tells open REQ-PM pages to reload; carries no data.
    def publish_refresh(user_ids)
      ids = Array(user_ids).compact
      return if ids.empty?
      MessageBus.publish("/reqpm/refresh", { at: Time.zone.now.to_i }, user_ids: ids)
    end
  end
end
