import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import type Post from "discourse/models/post";
import { i18n } from "discourse-i18n";

type ListingPost = Post & {
  id: number;
  user_id: number;
  listing_sold?: boolean;
};

interface ListingCurrentUser {
  id: number;
  staff?: boolean;
}

interface ListingFormatStatusSignature {
  Args: { data: { post: ListingPost } };
}

// The foot of a listing card: whether it's still available, and for the
// seller and staff, the button that switches it.
export default class ListingFormatStatus extends Component<ListingFormatStatusSignature> {
  @service declare currentUser: ListingCurrentUser | null;

  @tracked sold = this.args.data.post.listing_sold ?? false;
  @tracked saving = false;

  get canSwitch(): boolean {
    const user = this.currentUser;
    const post = this.args.data.post;
    return !!user && (user.id === post.user_id || !!user.staff);
  }

  @action
  async toggle() {
    const post = this.args.data.post;
    this.saving = true;
    try {
      const result = (await ajax(
        `/jtech-listing-format/posts/${post.id}/sold`,
        { type: "PUT", data: { sold: !this.sold } }
      )) as { sold: boolean };
      this.sold = result.sold;
      post.set("listing_sold", result.sold);
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.saving = false;
    }
  }

  <template>
    <div
      class="listing-status {{if this.sold 'listing-status--sold'}}"
      data-listing-sold={{if this.sold "true" "false"}}
    >
      <span class="listing-status__label">
        {{if
          this.sold
          (i18n "listing_format.status.sold")
          (i18n "listing_format.status.available")
        }}
      </span>
      {{#if this.canSwitch}}
        <DButton
          class="btn-default btn-small listing-status__toggle"
          @action={{this.toggle}}
          @disabled={{this.saving}}
          @label={{if
            this.sold
            "listing_format.status.mark_available"
            "listing_format.status.mark_sold"
          }}
        />
      {{/if}}
    </div>
  </template>
}
