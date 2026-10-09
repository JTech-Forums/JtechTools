import type { DSL } from "@ember/routing/lib/dsl";

export default function (this: DSL) {
  this.route("mod-elections", { path: "/elections" });
}
