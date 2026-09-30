import type { DSL } from "@ember/routing/lib/dsl";

export default {
  resource: "user.preferences",

  map(this: DSL) {
    this.route("reqpm");
  },
};
