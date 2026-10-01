import Component from "@glimmer/component";
import { service } from "@ember/service";
import { settings, themePrefix } from "virtual:theme";
import { i18n } from "discourse-i18n";
import { needsFullPageLoad } from "../lib/jt-links";
import JtechMark from "./jtech-mark";

// Site footer: mark + tagline, link columns grouped by `section` (in the order
// sections first appear in the footer_links setting), small print.
export default class JtFooter extends Component {
  @service router;

  get columns() {
    const bySection = new Map();
    for (const link of settings.footer_links || []) {
      if (!bySection.has(link.section)) {
        bySection.set(link.section, []);
      }
      bySection.get(link.section).push({
        ...link,
        fullPage: needsFullPageLoad(this.router, link.url),
      });
    }
    return [...bySection].map(([title, links]) => ({ title, links }));
  }

  get year() {
    return new Date().getFullYear();
  }

  <template>
    <footer class="jt-footer">
      <div class="jt-footer__inner">
        <div class="jt-footer__brand">
          <span class="jt-footer__mark"><JtechMark /></span>
          <span class="jt-footer__name">JTech Forums</span>
          {{#if settings.footer_tagline}}
            <p class="jt-footer__tagline">{{settings.footer_tagline}}</p>
          {{/if}}
        </div>

        <nav
          aria-label={{i18n (themePrefix "jt.footer.label")}}
          class="jt-footer__columns"
        >
          {{#each this.columns as |column|}}
            <div class="jt-footer__column">
              <h2 class="jt-footer__heading">{{column.title}}</h2>
              <ul>
                {{#each column.links as |link|}}
                  <li><a
                      data-auto-route={{if link.fullPage "true"}}
                      href={{link.url}}
                    >{{link.title}}</a></li>
                {{/each}}
              </ul>
            </div>
          {{/each}}
        </nav>
      </div>

      <div class="jt-footer__base">
        <span>© {{this.year}} JTech Forums</span>
      </div>
    </footer>
  </template>
}
