import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";
import ModWhisperTargetModal from "../components/mod-whisper-target-modal";
import { computeReplyAudience } from "../lib/mod-whisper-reply-audience";

// Inline eye SVG so no icon needs registering.
const EYE_PATH =
  "M12 5c-7 0-10 7-10 7s3 7 10 7 10-7 10-7-3-7-10-7zm0 11a4 4 0 110-8 4 4 0 010 8z";

function whisperParticipantIds(topic) {
  const ids = topic?.mod_whisper_participant_ids;
  return Array.isArray(ids) ? ids : [];
}

export default {
  name: "discourse-mod-whisper",

  initialize() {
    withPluginApi((api) => {
      const siteSettings = api.container.lookup("service:site-settings");
      if (!siteSettings?.mod_whisper_enabled) {
        return;
      }

      const currentUser = api.getCurrentUser();

      api.modifyClass("model:composer", {
        pluginId: "discourse-mod-whisper",
      });

      api.onToolbarCreate((toolbar) => {
        toolbar.addButton({
          id: "mod-whisper-target",
          className: "mod-whisper-target",
          group: "extras",
          icon: "far-eye",
          title: "discourse_mod_categories.whisper.toolbar_title",
          perform: () => {
            const composerService = api.container.lookup("service:composer");
            const model = composerService?.model;
            if (!model || !currentUser) {
              return;
            }

            if (currentUser.staff) {
              const modal = api.container.lookup("service:modal");
              modal?.show(ModWhisperTargetModal, {
                model: { composer: model },
              });
              return;
            }

            // Non-staff: only an existing topic whisper participant may
            // whisper, and only ever staff-only. Arm it directly.
            const participantIds = whisperParticipantIds(model.topic);
            if (participantIds.includes(currentUser.id)) {
              model.set("modWhisperArmed", true);
              model.set("modWhisperTargetUserIds", []);
              model.set("modWhisperTargetUsernames", []);
              model.set("modWhisperTargets", []);
              model.set("modWhisperTargetGroupIds", []);
              model.set("modWhisperTargetGroupNames", []);
              model.set("modWhisperTargetGroups", []);
              model.set("modWhisperTargetBadgeIds", []);
              model.set("modWhisperTargetBadges", []);
            }
            // Non-participant: no-op.
          },
        });
      });

      api.serializeOnCreate(
        "mod_whisper_target_user_ids",
        "modWhisperTargetUserIds"
      );

      api.serializeOnCreate(
        "mod_whisper_target_group_ids",
        "modWhisperTargetGroupIds"
      );

      api.serializeOnCreate(
        "mod_whisper_target_badge_ids",
        "modWhisperTargetBadgeIds"
      );

      // A boolean armed flag survives form-encoding even when the target id
      // array is empty (a staff-only whisper, or a non-staff whisper-back).
      // It is the server's single signal that a whisper is intended.
      api.serializeOnCreate("mod_whisper", "modWhisperArmed");

      // `addTrackedPostProperties` is the modern replacement for the
      // deprecated `includePostAttributes` — it surfaces the serializer
      // attributes on the post model, which the cooked-element decorator
      // below relies on.
      if (api.addTrackedPostProperties) {
        api.addTrackedPostProperties(
          "mod_is_whisper",
          "mod_whisper_target_user_ids",
          "mod_whisper_targets",
          "mod_whisper_target_group_ids",
          "mod_whisper_target_groups",
          "mod_whisper_target_badge_ids",
          "mod_whisper_target_badges",
          "mod_whisper_is_staff_only",
          "mod_whisper_author_is_staff"
        );
      } else {
        api.includePostAttributes(
          "mod_is_whisper",
          "mod_whisper_target_user_ids",
          "mod_whisper_targets",
          "mod_whisper_target_group_ids",
          "mod_whisper_target_groups",
          "mod_whisper_target_badge_ids",
          "mod_whisper_target_badges",
          "mod_whisper_is_staff_only",
          "mod_whisper_author_is_staff"
        );
      }

      api.decorateCookedElement(
        (cookedEl, helper) => {
          const post = helper?.getModel?.() || helper?.model;
          if (!post?.mod_is_whisper) {
            return;
          }

          const targets = Array.isArray(post.mod_whisper_targets)
            ? post.mod_whisper_targets
            : [];
          const targetGroups = Array.isArray(post.mod_whisper_target_groups)
            ? post.mod_whisper_target_groups
            : [];
          const targetBadges = Array.isArray(post.mod_whisper_target_badges)
            ? post.mod_whisper_target_badges
            : [];
          const staffOnly =
            !targets.length && !targetGroups.length && !targetBadges.length;

          // Mark the cooked element itself — a marker on the post <article>
          // does not survive Glimmer post-stream reconciliation. SCSS tints
          // and borders it via these classes.
          cookedEl.classList.add("mod-whisper");
          cookedEl.classList.remove("mod-whisper--staff", "mod-whisper--user");
          cookedEl.classList.add(
            staffOnly ? "mod-whisper--user" : "mod-whisper--staff"
          );

          // Insert the banner as the FIRST CHILD of the cooked element — NOT
          // a sibling. The Glimmer post stream owns the elements around
          // `.cooked`; a foreign sibling gets reconciled away. A child of
          // `.cooked` is re-decorated whenever the cooked HTML re-renders.
          if (cookedEl.querySelector(":scope > .mod-whisper-banner")) {
            return;
          }

          const banner = document.createElement("div");
          banner.className = "mod-whisper-banner";

          const svgNS = "http://www.w3.org/2000/svg";
          const icon = document.createElementNS(svgNS, "svg");
          icon.setAttribute("viewBox", "0 0 24 24");
          icon.setAttribute("width", "14");
          icon.setAttribute("height", "14");
          icon.setAttribute("aria-hidden", "true");
          icon.classList.add("mod-whisper-eye");
          const path = document.createElementNS(svgNS, "path");
          path.setAttribute("fill", "currentColor");
          path.setAttribute("d", EYE_PATH);
          icon.appendChild(path);
          banner.appendChild(icon);

          const label = document.createElement("span");
          label.className = "mod-whisper-banner__label";

          if (staffOnly) {
            label.textContent = ` ${i18n(
              "discourse_mod_categories.whisper.banner_to_staff"
            )}`;
            banner.appendChild(label);
          } else {
            label.textContent = ` ${i18n(
              "discourse_mod_categories.whisper.banner_to"
            )} `;
            banner.appendChild(label);

            let entryIndex = 0;
            const addSep = () => {
              if (entryIndex > 0) {
                const sep = document.createElement("span");
                sep.className = "mod-whisper-banner__sep";
                sep.textContent = ", ";
                banner.appendChild(sep);
              }
              entryIndex++;
            };

            targets.forEach((t) => {
              addSep();
              const link = document.createElement("a");
              link.className = "mod-whisper-banner__user";
              link.href = `/u/${t.username}`;
              link.textContent = `@${t.username}`;
              banner.appendChild(link);
            });

            targetGroups.forEach((g) => {
              addSep();
              const link = document.createElement("a");
              link.className = "mod-whisper-banner__group";
              link.href = `/g/${g.name}`;
              link.textContent = g.name;
              banner.appendChild(link);
            });

            targetBadges.forEach((b) => {
              addSep();
              const link = document.createElement("a");
              link.className = "mod-whisper-banner__badge";
              link.href = `/badges/${b.id}`;
              link.textContent = b.name;
              banner.appendChild(link);
            });
          }

          cookedEl.insertBefore(banner, cookedEl.firstChild);
        },
        { id: "discourse-mod-whisper-decorator", onlyStream: true }
      );

      // Auto-arm a whisper-back when replying to a whisper, for any user who
      // is part of that whisper's audience. This covers the default reply
      // flow; quote-reply behaviour is intentionally unchanged and not
      // special-cased here.
      api.onAppEvent("composer:opened", () => {
        const composerService = api.container.lookup("service:composer");
        const model = composerService?.model;
        if (!model || !currentUser) {
          return;
        }
        const post = model.post;
        if (!post?.mod_is_whisper) {
          return;
        }

        if (currentUser.staff) {
          // Carry forward the original whisper's group AND badge targets so
          // a staff reply stays visible to the same audience.
          const replyGroups = Array.isArray(post.mod_whisper_target_groups)
            ? post.mod_whisper_target_groups
            : [];
          const replyBadges = Array.isArray(post.mod_whisper_target_badges)
            ? post.mod_whisper_target_badges
            : [];
          model.set("modWhisperArmed", true);
          model.set(
            "modWhisperTargetGroupIds",
            replyGroups.map((g) => g.id)
          );
          model.set(
            "modWhisperTargetGroupNames",
            replyGroups.map((g) => g.name)
          );
          model.set("modWhisperTargetGroups", replyGroups);
          model.set(
            "modWhisperTargetBadgeIds",
            replyBadges.map((b) => b.id)
          );
          model.set("modWhisperTargetBadges", replyBadges);

          const replyAudience = computeReplyAudience(post, currentUser.id);
          if (replyAudience.length) {
            model.set(
              "modWhisperTargetUserIds",
              replyAudience.map((u) => u.id)
            );
            model.set(
              "modWhisperTargetUsernames",
              replyAudience.map((u) => u.username)
            );
            model.set("modWhisperTargets", replyAudience);
          } else {
            model.set("modWhisperTargetUserIds", []);
            model.set("modWhisperTargetUsernames", []);
            model.set("modWhisperTargets", []);
          }
        } else {
          // Non-staff replying to a whisper they can see — force staff-only.
          model.set("modWhisperArmed", true);
          model.set("modWhisperTargetUserIds", []);
          model.set("modWhisperTargetUsernames", []);
          model.set("modWhisperTargets", []);
          model.set("modWhisperTargetGroupIds", []);
          model.set("modWhisperTargetGroupNames", []);
          model.set("modWhisperTargetGroups", []);
          model.set("modWhisperTargetBadgeIds", []);
          model.set("modWhisperTargetBadges", []);
        }
      });
    });
  },
};
