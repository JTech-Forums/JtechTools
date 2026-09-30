# frozen_string_literal: true

module DiscourseReqpm
  # Builds every JSON payload REQ-PM sends. Decrypted values leave the
  # server from exactly two methods: `own_method` (a user's own card, to
  # that user) and `shared_method` (a method someone shared, to the person
  # it was shared with). Everything else is metadata.
  module Presenter
    def self.user(user)
      BasicUserSerializer.new(user, root: false).as_json
    end

    def self.own_method(method)
      {
        id: method.id,
        kind: method.kind,
        label: method.label,
        emoji: method.emoji,
        value: method.value,
        note: method.note,
        share_by_default: method.share_by_default,
        position: method.position,
        unreadable: method.unreadable?,
      }
    end

    def self.shared_method(method)
      {
        id: method.id,
        kind: method.kind,
        label: method.label,
        emoji: method.emoji,
        value: method.value,
        note: method.note,
      }
    end

    def self.card(user)
      {
        methods: ContactMethod.where(user_id: user.id).ordered.map { |m| own_method(m) },
        allow_requests: Policy.allows_requests?(user),
        max_methods: SiteSetting.reqpm_max_methods,
      }
    end

    def self.current_user_summary(user)
      # An admin impersonating someone gets no REQ-PM UI (the endpoints
      # refuse them anyway).
      return { available: false } if user.is_impersonating
      return { available: false } unless Policy.can_use?(user)
      {
        available: true,
        setup_prompt: Setup.prompt_for(user),
        incoming_count: incoming_count(user),
      }
    end

    def self.incoming_count(user)
      Request.open_requests.where(target_id: user.id).count
    end

    # Details `owner` has shared with `viewer`, in the owner's order.
    # Rows that no longer decrypt are dropped rather than shown blank.
    def self.shared_methods(owner_id:, viewer_id:)
      ContactMethod
        .joins(:shares)
        .where(user_id: owner_id, reqpm_shares: { recipient_id: viewer_id })
        .ordered
        .reject(&:unreadable?)
        .map { |m| shared_method(m) }
    end

    def self.outgoing_state(request)
      return "answered" if request.fulfilled?
      request.created_at > Request.expiry_cutoff ? "waiting" : "expired"
    end

    def self.cooldown_until(actor, target)
      last =
        Request
          .where(requester_id: actor.id, target_id: target.id)
          .where("created_at > ?", SiteSetting.reqpm_request_cooldown_days.days.ago)
          .order(created_at: :desc)
          .first
      last && (last.created_at + SiteSetting.reqpm_request_cooldown_days.days)
    end

    def self.inbox(actor)
      received =
        Share
          .where(recipient_id: actor.id)
          .includes(:owner, :contact_method)
          .group_by(&:owner_id)
          .filter_map do |_owner_id, shares|
            methods =
              shares
                .map(&:contact_method)
                .compact
                .sort_by { |m| [m.position, m.id] }
                .reject(&:unreadable?)
                .map { |m| shared_method(m) }
            next if methods.empty?
            {
              user: user(shares.first.owner),
              methods: methods,
              shared_at: shares.map(&:updated_at).max,
            }
          end
          .sort_by { |row| -row[:shared_at].to_f }

      sent =
        Share
          .where(owner_id: actor.id)
          .includes(:recipient)
          .group_by(&:recipient)
          .map do |recipient, shares|
            {
              user: user(recipient),
              method_ids: shares.map(&:contact_method_id).sort,
              shared_at: shares.map(&:updated_at).max,
            }
          end
          .sort_by { |row| -row[:shared_at].to_f }

      incoming =
        Request
          .open_requests
          .where(target_id: actor.id)
          .includes(:requester)
          .order(created_at: :desc)
          .map do |r|
            {
              id: r.id,
              user: user(r.requester),
              wanted_kinds: r.wanted_kinds,
              created_at: r.created_at,
            }
          end

      # Declined requests read as "waiting" until they expire: the requester
      # is never told they were turned down.
      outgoing =
        Request
          .where(requester_id: actor.id)
          .where.not(status: :cancelled)
          .where("created_at > ?", 60.days.ago)
          .includes(:target)
          .order(created_at: :desc)
          .limit(50)
          .map do |r|
            state = outgoing_state(r)
            {
              id: r.id,
              user: user(r.target),
              wanted_kinds: r.wanted_kinds,
              state: state,
              created_at: r.created_at,
              can_cancel: state == "waiting",
            }
          end

      { received: received, sent: sent, incoming: incoming, outgoing: outgoing }
    end

    # Everything the per-user REQ-PM window needs about `actor` ⇄ `target`.
    def self.relationship(actor, target)
      incoming = Request.open_requests.find_by(requester_id: target.id, target_id: actor.id)
      outgoing =
        Request
          .where(requester_id: actor.id, target_id: target.id)
          .where.not(status: :cancelled)
          .order(created_at: :desc)
          .first

      request_blocked = Policy.blocked_reason(actor, target, for_request: true)
      share_blocked = Policy.blocked_reason(actor, target, for_request: false)
      retry_at = nil
      if request_blocked.nil?
        if outgoing&.open?
          request_blocked = :pending
        elsif (retry_at = cooldown_until(actor, target))
          request_blocked = :cooldown
        end
      end

      {
        user: user(target),
        their_methods: shared_methods(owner_id: target.id, viewer_id: actor.id),
        my_methods: ContactMethod.where(user_id: actor.id).ordered.map { |m| own_method(m) },
        my_shared_method_ids:
          Share.where(owner_id: actor.id, recipient_id: target.id).pluck(:contact_method_id).sort,
        incoming_request:
          incoming &&
            {
              id: incoming.id,
              wanted_kinds: incoming.wanted_kinds,
              created_at: incoming.created_at,
            },
        outgoing_request:
          outgoing &&
            {
              id: outgoing.id,
              state: outgoing_state(outgoing),
              wanted_kinds: outgoing.wanted_kinds,
              created_at: outgoing.created_at,
            }.tap { |h| h[:can_cancel] = h[:state] == "waiting" },
        can_request: request_blocked.nil?,
        request_blocked: request_blocked,
        retry_at: retry_at,
        can_share: share_blocked.nil?,
        share_blocked: share_blocked,
      }
    end
  end
end
