// The picture viewer's sizes and its Save links.
import assert from "node:assert/strict";
import { before, test } from "node:test";
import {
  centring,
  fitSize,
  keepCentre,
  nextZoom,
  panStep,
} from "../src/ui/picture-math.ts";

type Cooked = typeof import("../src/content/cooked.ts");
let cooked: Cooked;

before(async () => {
  await import("./stub-dom.ts");
  cooked = await import("../src/content/cooked.ts");
});

test("OK steps fit, 2x, 3x and back to fit", () => {
  assert.equal(nextZoom(1), 2);
  assert.equal(nextZoom(2), 3);
  assert.equal(nextZoom(3), 1);
});

test("a picture fits the screen, keeping its shape", () => {
  // A wide screenshot on a 240x290 stage.
  assert.deepEqual(fitSize(1333, 964, 240, 290), { w: 240, h: 174 });
  // A tall phone photo: the height decides.
  assert.deepEqual(fitSize(3000, 4000, 240, 290), { w: 217, h: 290 });
});

test("a small picture isn't blown up to fit", () => {
  assert.deepEqual(fitSize(100, 50, 240, 290), { w: 100, h: 50 });
});

test("nothing to size before the picture has loaded", () => {
  assert.deepEqual(fitSize(0, 0, 240, 290), { w: 0, h: 0 });
  assert.deepEqual(fitSize(100, 50, 0, 0), { w: 0, h: 0 });
});

test("a picture smaller than the screen is centred", () => {
  assert.equal(centring(174, 290), 58);
  assert.equal(centring(480, 240), 0);
});

test("zooming keeps the middle of the screen in the middle", () => {
  // Fit (240 wide, no scroll) to 2x (480 wide): the middle stays at 120 of
  // 240, i.e. scrolled 120 into the 480.
  assert.equal(keepCentre(0, 240, 240, 0, 480, 0), 120);
  // 2x scrolled to its right edge, then 3x: still on the right edge's middle.
  assert.equal(keepCentre(240, 240, 480, 0, 720, 0), 420);
  // Back to fit: no scrolling left.
  assert.equal(keepCentre(420, 240, 720, 0, 240, 0), 0);
  // A short picture centred vertically (offset 58) zoomed: stays in range.
  assert.equal(keepCentre(0, 290, 174, 58, 348, 0), 29);
});

test("the D-pad moves a zoomed picture by part of the screen", () => {
  assert.equal(panStep(240), 96);
  assert.equal(panStep(10), 16);
});

test("Save downloads a forum upload from the forum the reader is on", () => {
  // Discourse writes its own hostname; the path alone stays on this host.
  assert.equal(
    cooked.pictureSaveUrl(
      "https://jtechforums.org/uploads/default/22035ff4894822a193dd032e620a97dc9bafbbaf",
      "4QTsNDei100RjOGhU5Jg4HQVju7",
      "https://jtechforums.org/uploads/default/original/2X/2/22035ff.png"
    ),
    "/uploads/default/22035ff4894822a193dd032e620a97dc9bafbbaf?dl=1"
  );
  assert.equal(
    cooked.pictureSaveUrl("/uploads/default/abc?x=1", "", ""),
    "/uploads/default/abc?x=1&dl=1"
  );
});

test("a small upload with no lightbox saves through its short URL", () => {
  assert.equal(
    cooked.pictureSaveUrl(
      "",
      "4QTsNDei100RjOGhU5Jg4HQVju7",
      "https://jtechforums.org/uploads/default/original/2X/2/22035ff.jpeg"
    ),
    "/uploads/short-url/4QTsNDei100RjOGhU5Jg4HQVju7.jpeg?dl=1"
  );
});

test("pictures from other sites have no Save", () => {
  assert.equal(
    cooked.pictureSaveUrl("", "", "https://example.com/phone.png"),
    ""
  );
  // Never a download link that leaves the forum's uploads.
  assert.equal(cooked.pictureSaveUrl("https://evil.example/steal", "", ""), "");
});
