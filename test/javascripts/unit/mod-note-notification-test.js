import { module, test } from "qunit";
import modNoteNotificationRenderer from "discourse/plugins/discourse-mod/discourse/lib/mod-note-notification";

// Unit tests for the moderator-note notification-type renderer. The renderer
// is a factory that receives a NotificationTypeBase class and returns a
// subclass. A minimal fake base stands in for core's NotificationTypeBase so
// the mod-note branch can be exercised in isolation; end-to-end behaviour is
// covered in spec/system.

class FakeBase {
  constructor({ notification }) {
    this.notification = notification;
  }

  get linkHref() {
    return "base-link";
  }

  get linkTitle() {
    return "base-title";
  }

  get icon() {
    return "base-icon";
  }

  get label() {
    return "base-label";
  }

  get description() {
    return "base-description";
  }

  get username() {
    return this.notification.data.display_username;
  }
}

function renderer(data) {
  const Renderer = modNoteNotificationRenderer(FakeBase);
  return new Renderer({ notification: { data } });
}

module("Unit | discourse-mod | mod-note-notification", function () {
  test("links straight to the note url for a mod-note notification", function (assert) {
    const r = renderer({
      mod_note: true,
      url: "/t/some-topic/12/4",
      display_username: "molly",
      topic_title: "Some topic",
    });
    assert.strictEqual(r.linkHref, "/t/some-topic/12/4");
  });

  test("uses the shield icon for a mod-note notification", function (assert) {
    const r = renderer({ mod_note: true, display_username: "molly" });
    assert.strictEqual(r.icon, "shield-halved");
  });

  test("describes the note with the topic title", function (assert) {
    const r = renderer({
      mod_note: true,
      display_username: "molly",
      topic_title: "Share your app build here",
    });
    assert.strictEqual(r.description, "Share your app build here");
  });

  test("defers to the base class for non-mod-note custom notifications", function (assert) {
    const r = renderer({ message: "some.other.notification" });
    assert.strictEqual(r.linkHref, "base-link");
    assert.strictEqual(r.label, "base-label");
    assert.strictEqual(r.description, "base-description");
  });

  test("mirrors core custom.js icon for non-mod-note notifications", function (assert) {
    const r = renderer({ message: "discourse_mod_categories.whisper" });
    assert.strictEqual(r.icon, "notification.discourse_mod_categories.whisper");
  });

  test("treats a missing mod_note marker as not a mod note", function (assert) {
    const r = renderer({ url: "/t/x/1" });
    assert.strictEqual(r.linkHref, "base-link");
  });
});
