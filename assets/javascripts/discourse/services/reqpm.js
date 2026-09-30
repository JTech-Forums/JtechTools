import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import ReqpmSetupModal from "../components/reqpm-setup-modal";
import ReqpmUserModal from "../components/reqpm-user-modal";

const BASE = "/jtech-reqpm";

// Client side of REQ-PM: the endpoints, the unanswered-requests badge, and
// opening the per-user window and the setup prompt. Contact values only ever
// pass through here on their way to the component showing them; nothing is
// cached or stored in the browser.
export default class ReqpmService extends Service {
  @service currentUser;
  @service siteSettings;
  @service messageBus;
  @service modal;

  @tracked incomingCount = 0;
  // Bumped whenever the server says something changed for this user; open
  // REQ-PM views watch it and reload.
  @tracked refreshToken = 0;

  subscribed = false;

  constructor() {
    super(...arguments);
    this.incomingCount = this.currentUser?.reqpm?.incoming_count || 0;
    if (this.available) {
      this.messageBus.subscribe("/reqpm/state", this.onState);
      this.messageBus.subscribe("/reqpm/refresh", this.onRefresh);
      this.subscribed = true;
    }
  }

  willDestroy() {
    super.willDestroy(...arguments);
    if (this.subscribed) {
      this.messageBus.unsubscribe("/reqpm/state", this.onState);
      this.messageBus.unsubscribe("/reqpm/refresh", this.onRefresh);
    }
  }

  get available() {
    return !!(
      this.siteSettings.reqpm_enabled && this.currentUser?.reqpm?.available
    );
  }

  get setupPrompt() {
    return this.currentUser?.reqpm?.setup_prompt || null;
  }

  onState = (data) => {
    if (typeof data?.incoming_count === "number") {
      this.incomingCount = data.incoming_count;
    }
    this.refreshToken++;
  };

  onRefresh = () => {
    this.refreshToken++;
  };

  // Called after the user adds their first method, snoozes or declines, so
  // the prompt does not come back before the next page load recomputes it.
  clearSetupPrompt() {
    if (this.currentUser?.reqpm) {
      this.currentUser.set("reqpm", {
        ...this.currentUser.reqpm,
        setup_prompt: null,
      });
    }
  }

  // ── Own card ──────────────────────────────────────────────────────────

  card() {
    return ajax(`${BASE}/card.json`);
  }

  addMethod(attrs) {
    return ajax(`${BASE}/card/methods.json`, {
      type: "POST",
      data: { reqpm_contact: attrs },
    });
  }

  updateMethod(id, attrs) {
    return ajax(`${BASE}/card/methods/${id}.json`, {
      type: "PUT",
      data: { reqpm_contact: attrs },
    });
  }

  deleteMethod(id) {
    return ajax(`${BASE}/card/methods/${id}.json`, { type: "DELETE" });
  }

  reorder(ids) {
    return ajax(`${BASE}/card/methods/order.json`, {
      type: "PUT",
      data: { ids },
    });
  }

  setAllowRequests(allow) {
    return ajax(`${BASE}/card/preferences.json`, {
      type: "PUT",
      data: { allow_requests: allow },
    });
  }

  snoozeSetup() {
    return ajax(`${BASE}/card/setup/snooze.json`, { type: "POST" });
  }

  declineSetup() {
    return ajax(`${BASE}/card/setup/decline.json`, { type: "POST" });
  }

  // ── Between users ─────────────────────────────────────────────────────

  inbox() {
    return ajax(`${BASE}/inbox.json`);
  }

  relationship(username) {
    return ajax(`${BASE}/users/${encodeURIComponent(username)}.json`);
  }

  request(username, wantedKinds = []) {
    return ajax(`${BASE}/requests.json`, {
      type: "POST",
      data: { username, wanted_kinds: wantedKinds },
    });
  }

  declineRequest(id) {
    return ajax(`${BASE}/requests/${id}/decline.json`, { type: "POST" });
  }

  cancelRequest(id) {
    return ajax(`${BASE}/requests/${id}.json`, { type: "DELETE" });
  }

  share(username, methodIds) {
    return ajax(`${BASE}/shares.json`, {
      type: "POST",
      data: { username, method_ids: methodIds },
    });
  }

  revoke(username) {
    return ajax(`${BASE}/shares/${encodeURIComponent(username)}.json`, {
      type: "DELETE",
    });
  }

  forget(username) {
    return ajax(`${BASE}/received/${encodeURIComponent(username)}.json`, {
      type: "DELETE",
    });
  }

  // ── Windows ───────────────────────────────────────────────────────────

  openUser(user) {
    return this.modal.show(ReqpmUserModal, { model: { user } });
  }

  openSetup(mode) {
    return this.modal.show(ReqpmSetupModal, { model: { mode } });
  }
}

// Server errors with a known reason (e.g. "cooldown") come back as
// { errors: [message], extras: { reason, field, retry_at } }.
export function reqpmError(error) {
  const json = error?.jqXHR?.responseJSON;
  return {
    message: json?.errors?.[0] || null,
    reason: json?.extras?.reason || null,
    field: json?.extras?.field || null,
  };
}
