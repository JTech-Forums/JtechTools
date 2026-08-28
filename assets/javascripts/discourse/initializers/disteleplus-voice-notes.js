// Disteleplus voice notes — composer mic button + custom audio player.
//
// BUTTON: registered through the chat plugin's composer-button API so it sits
// with the native attach controls (inline, next to the upload button). Opens
// DisteleplusVoiceRecorder for the channel the composer belongs to; hidden
// outside the bridge channel unless disteleplus_voice_notes_bridge_channel_only
// is off. The recorder posts the note itself, so nothing here touches the
// composer's draft.
//
// PLAYER: chat renders uploads OUTSIDE the cooked message text (a sibling
// `.chat-uploads` block), which api.decorateChatMessage never sees. A single
// MutationObserver on the chat container therefore wraps every <audio> as it
// appears — including ones streamed in later by MessageBus, the drawer, and
// thread panes — and the page-change hook catches anything already present.
import { withPluginApi } from "discourse/lib/plugin-api";
import DisteleplusVoiceRecorder from "../components/disteleplus-voice-recorder";
import { enhanceWithin, pruneDetached } from "../lib/disteleplus-voice-player";

const CHANNEL_URL = /^\/chat\/c\/[^/]+\/(\d+)(?:\/t\/(\d+))?/;

function channelFromContext(context) {
  // The chat plugin calls displayed()/action() with the composer component
  // as `this`; which property holds the channel has moved between versions,
  // so try each known home before giving up to the URL.
  const model =
    context?.model ??
    context?.channel ??
    context?.args?.channel ??
    context?.args?.thread ??
    context?.chat?.activeChannel;
  if (!model) {
    return { channelId: null, threadId: null };
  }
  // A thread's composer exposes the thread as the model; its channel hangs
  // off it. A channel composer exposes the channel directly.
  if (model.channel?.id) {
    return { channelId: model.channel.id, threadId: model.id ?? null };
  }
  return { channelId: model.id ?? null, threadId: null };
}

function channelFromUrl() {
  const match = window.location.pathname.match(CHANNEL_URL);
  if (!match) {
    return { channelId: null, threadId: null };
  }
  return {
    channelId: parseInt(match[1], 10),
    threadId: match[2] ? parseInt(match[2], 10) : null,
  };
}

export default {
  name: "disteleplus-voice-notes",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    if (
      !siteSettings.disteleplus_enabled ||
      !siteSettings.disteleplus_voice_notes_enabled
    ) {
      return;
    }

    const bridgeChannelId = parseInt(
      siteSettings.disteleplus_chat_channel_id,
      10
    );
    const bridgeOnly = siteSettings.disteleplus_voice_notes_bridge_channel_only;
    const allAudio = siteSettings.disteleplus_voice_player_all_audio;
    const modal = container.lookup("service:modal");

    const allowedChannel = (channelId) =>
      !bridgeOnly || (bridgeChannelId > 0 && channelId === bridgeChannelId);

    withPluginApi((api) => {
      if (!api.registerChatComposerButton) {
        return;
      }

      api.registerChatComposerButton({
        id: "disteleplus-voice-note",
        icon: "microphone",
        label: "disteleplus.voice.button",
        title: "disteleplus.voice.button",
        position: "inline",
        classNames: ["disteleplus-voice-note-btn"],
        displayed() {
          if (!window.MediaRecorder || !navigator.mediaDevices?.getUserMedia) {
            return false;
          }
          const fromContext = channelFromContext(this);
          const channelId = fromContext.channelId ?? channelFromUrl().channelId;
          return allowedChannel(channelId);
        },
        action() {
          const fromContext = channelFromContext(this);
          const target = fromContext.channelId ? fromContext : channelFromUrl();
          if (!target.channelId || !allowedChannel(target.channelId)) {
            return;
          }
          modal.show(DisteleplusVoiceRecorder, { model: target });
        },
      });

      // ── player ──────────────────────────────────────────────────────────
      const options = { allAudio };
      let observer = null;

      const observe = () => {
        if (observer) {
          return;
        }
        observer = new MutationObserver((mutations) => {
          let removed = false;
          for (const mutation of mutations) {
            if (mutation.removedNodes.length) {
              removed = true;
            }
            for (const node of mutation.addedNodes) {
              if (node.nodeType !== Node.ELEMENT_NODE) {
                continue;
              }
              enhanceWithin(node, options);
            }
          }
          // Glimmer re-rendered a message: drop players whose <audio> is
          // gone so nothing stacks or lingers.
          if (removed) {
            pruneDetached();
          }
        });
        observer.observe(document.body, { childList: true, subtree: true });
      };

      api.onPageChange(() => {
        // Only bother watching once the user has been near chat at all —
        // the observer is cheap, but there is no point running it on the
        // topic list forever for someone who never opens chat.
        if (
          document.querySelector(
            ".chat-message, .chat-drawer, .c-routes, #chat-progress-bar-container"
          ) ||
          window.location.pathname.startsWith("/chat")
        ) {
          observe();
          enhanceWithin(document.body, options);
        }
      });

      // The drawer can open on any page without a route change.
      document.addEventListener(
        "click",
        (event) => {
          if (event.target?.closest?.(".chat-header-icon, .chat-drawer")) {
            observe();
          }
        },
        { capture: true, passive: true }
      );
    });
  },
};
