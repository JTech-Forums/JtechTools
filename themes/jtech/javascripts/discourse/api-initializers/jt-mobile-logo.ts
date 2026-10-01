import { settings } from "virtual:theme";
import { apiInitializer } from "discourse/lib/api";
import type Session from "discourse/models/session";
import type Site from "discourse/models/site";
import type SiteSettingsService from "discourse/services/site-settings";

interface LogoSiteSettings {
  site_logo_url: string;
  site_logo_small_url: string;
  site_logo_small_dark_url: string;
  site_mobile_logo_url: string;
}

// What core's header/home-logo passes to the transformer
interface HomeLogoContext {
  name: string;
  dark?: boolean;
}

// Phones: the small square logo instead of the wide one, by answering core's
// "mobile logo" lookup with the small logo. A mobile logo the admin uploaded
// still wins (with none, core's mobile logo URL is the main logo's), and
// without a small logo nothing changes. site.mobileView is read when the
// header asks, not here: reading it during initialization is deprecated.
export default apiInitializer((api) => {
  if (!settings.mobile_small_logo) {
    return;
  }

  const site = api.container.lookup("service:site") as Site;
  const session = api.container.lookup("service:session") as Session & {
    defaultColorSchemeIsDark?: boolean;
  };
  const siteSettings = api.container.lookup(
    "service:site-settings"
  ) as SiteSettingsService & LogoSiteSettings;

  api.registerValueTransformer(
    "home-logo-image-url",
    ({ value, context }: { value: string; context: HomeLogoContext }) => {
      const light = siteSettings.site_logo_small_url || "";
      const ownMobileLogo =
        siteSettings.site_mobile_logo_url &&
        siteSettings.site_mobile_logo_url !== siteSettings.site_logo_url;
      if (
        context.name !== "mobile_logo" ||
        !site.mobileView ||
        !light ||
        ownMobileLogo
      ) {
        return value;
      }
      const dark = siteSettings.site_logo_small_dark_url || "";
      if (context.dark) {
        return dark;
      }
      return session.defaultColorSchemeIsDark ? dark || light : light;
    }
  );
});
