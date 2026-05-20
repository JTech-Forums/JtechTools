import { apiInitializer } from "discourse/lib/api";

const ENABLE_SETTING = "dumbcourse_languagetool_enabled";
const MODE_SETTING = "dumbcourse_languagetool_mode";

const SELF_HOSTED_SETTINGS = [
  "dumbcourse_languagetool_url",
  "dumbcourse_languagetool_secret",
];

const OFFICIAL_API_SETTINGS = [
  "dumbcourse_languagetool_api_url",
  "dumbcourse_languagetool_api_username",
  "dumbcourse_languagetool_api_key",
];

const SETTING_SELECTOR = (name) => `.setting[data-setting="${name}"]`;

const isAdminSettingsPage = () => {
  const path = window.location.pathname || "";
  return (
    path.startsWith("/admin/site_settings") ||
    path.startsWith("/admin/config/settings")
  );
};

const findSettingRow = (name) => document.querySelector(SETTING_SELECTOR(name));

const getSettingValue = (name) => {
  const row = findSettingRow(name);
  if (!row) {
    return null;
  }

  const checkbox = row.querySelector("input[type='checkbox']");
  if (checkbox) {
    return checkbox.checked;
  }

  const select = row.querySelector("select");
  if (select) {
    return select.value;
  }

  const input = row.querySelector("input, textarea");
  if (input) {
    return input.value;
  }

  return null;
};

const setRowVisible = (name, visible) => {
  const row = findSettingRow(name);
  if (!row) {
    return;
  }

  row.style.display = visible ? "" : "none";
};

const applyVisibility = () => {
  if (!isAdminSettingsPage()) {
    return;
  }

  const enabledValue = getSettingValue(ENABLE_SETTING);
  const enabled = enabledValue === true || enabledValue === "true";
  const mode = getSettingValue(MODE_SETTING) || "";

  setRowVisible(MODE_SETTING, enabled);

  const showSelfHosted = enabled && mode === "self_hosted";
  const showOfficial = enabled && mode === "official_api";

  SELF_HOSTED_SETTINGS.forEach((setting) => {
    setRowVisible(setting, showSelfHosted);
  });

  OFFICIAL_API_SETTINGS.forEach((setting) => {
    setRowVisible(setting, showOfficial);
  });
};

export default apiInitializer((api) => {
  let scheduled = false;

  const scheduleApply = () => {
    if (scheduled) {
      return;
    }
    scheduled = true;
    requestAnimationFrame(() => {
      scheduled = false;
      applyVisibility();
    });
  };

  const bindListeners = () => {
    if (!isAdminSettingsPage()) {
      return;
    }

    const container = document.querySelector(".admin-site-settings");
    if (!container || container.dataset.dumbcourseLtBound === "true") {
      return;
    }

    container.dataset.dumbcourseLtBound = "true";

    const handler = (event) => {
      if (!event.target.closest(".setting")) {
        return;
      }
      scheduleApply();
    };

    container.addEventListener("input", handler);
    container.addEventListener("change", handler);

    scheduleApply();
  };

  const observer = new MutationObserver(() => {
    bindListeners();
    scheduleApply();
  });

  observer.observe(document.body, { childList: true, subtree: true });

  api.onPageChange(() => {
    bindListeners();
    scheduleApply();
  });
});
