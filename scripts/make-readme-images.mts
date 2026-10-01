#!/usr/bin/env -S node --experimental-strip-types --no-warnings
// Builds the README collage and the feature-page images in docs/images/
// from the screenshots the system specs save.
//
//   # from the Discourse folder, with this plugin linked as plugins/jtech-tools
//   JTECH_SCREENSHOT_GALLERY=1 LOAD_PLUGINS=1 bin/rspec \
//     plugins/jtech-tools/spec/system/{dumbcourse,reqpm,feature_screenshots,popup_notifications_stacking_screenshots}_spec.rb
//   # then, from this repo
//   pnpm readme:images ../discourse/tmp/capybara

import { join } from "node:path";
import sharp, { type OverlayOptions, type Sharp } from "sharp";

const SRC = process.argv[2] ?? "../discourse/tmp/capybara";
const OUT = new URL("../docs/images/", import.meta.url).pathname;
const S = 2; // render at 2x, save downscaled for crisp edges

type Rgb = [number, number, number];
type Box = [number, number, number, number]; // x0, y0, x1, y1

// A finished bitmap: PNG bytes plus its size, so layout can read it.
type Img = { data: Buffer; width: number; height: number };

async function toImg(image: Sharp): Promise<Img> {
  const { data, info } = await image
    .png()
    .toBuffer({ resolveWithObject: true });
  return { data, width: info.width, height: info.height };
}

const rgb = ([r, g, b]: Rgb, alpha = 255) =>
  `rgba(${r},${g},${b},${alpha / 255})`;

const svg = (width: number, height: number, body: string) =>
  Buffer.from(
    `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}">${body}</svg>`
  );

// Layers are drawn in order on composite(), like painting onto the canvas.
class Canvas {
  readonly width: number;
  readonly height: number;
  readonly background: { svg: Buffer } | { color: Rgb | null };
  layers: { input: Buffer; left: number; top: number }[] = [];

  constructor(width: number, height: number, background: Canvas["background"]) {
    this.width = width;
    this.height = height;
    this.background = background;
  }

  draw(input: Buffer, left: number, top: number): void {
    this.layers.push({ input, left: Math.round(left), top: Math.round(top) });
  }

  text(x: number, y: number, text: string, size: number, color: Rgb): void {
    // Positioned by the top of the text, as Pillow does: the baseline sits
    // one ascender (0.905 em in Liberation Sans) lower.
    const body = `<text x="0" y="${0.905 * size}" font-family="Liberation Sans" font-weight="bold" font-size="${size}" fill="${rgb(color)}">${text.replace(/&/g, "&amp;").replace(/</g, "&lt;")}</text>`;
    this.draw(
      svg(Math.ceil(size * text.length), Math.ceil(size * 1.3), body),
      x,
      y
    );
  }

  async render(): Promise<Img> {
    const { width, height } = this;
    const base =
      "svg" in this.background
        ? sharp(this.background.svg)
        : sharp({
            create: {
              width,
              height,
              channels: 4,
              background: this.background.color
                ? rgb(this.background.color)
                : { r: 0, g: 0, b: 0, alpha: 0 },
            },
          });
    return toImg(
      base.composite(await Promise.all(this.layers.map((l) => this.clip(l))))
    );
  }

  // Pillow clips what's drawn past the edge; sharp refuses it, so cut each
  // layer down to the part that lands on the canvas.
  async clip({
    input,
    left,
    top,
  }: Canvas["layers"][number]): Promise<OverlayOptions> {
    const layer = sharp(input);
    const { width = 0, height = 0 } = await layer.metadata();
    const x0 = Math.max(left, 0);
    const y0 = Math.max(top, 0);
    const x1 = Math.min(left + width, this.width);
    const y1 = Math.min(top + height, this.height);
    if (
      x0 === left &&
      y0 === top &&
      x1 === left + width &&
      y1 === top + height
    ) {
      return { input, left, top };
    }
    const visible = await layer
      .extract({
        left: x0 - left,
        top: y0 - top,
        width: x1 - x0,
        height: y1 - y0,
      })
      .png()
      .toBuffer();
    return { input: visible, left: x0, top: y0 };
  }
}

const load = (name: string) => sharp(join(SRC, name)).removeAlpha();

async function crop(name: string, [x0, y0, x1, y1]: Box): Promise<Img> {
  return toImg(
    load(name).extract({ left: x0, top: y0, width: x1 - x0, height: y1 - y0 })
  );
}

async function resize(img: Img, scale: number): Promise<Img> {
  return toImg(
    sharp(img.data).resize(
      Math.trunc(img.width * scale),
      Math.trunc(img.height * scale),
      {
        fit: "fill",
        kernel: "lanczos3",
      }
    )
  );
}

async function rounded(img: Img, r: number): Promise<Buffer> {
  const mask = svg(
    img.width,
    img.height,
    `<rect width="${img.width}" height="${img.height}" rx="${r}" fill="#fff"/>`
  );
  return (
    await toImg(
      sharp(img.data)
        .ensureAlpha()
        .composite([{ input: mask, blend: "dest-in" }])
    )
  ).data;
}

function shadow(
  canvas: Canvas,
  [x0, y0, x1, y1]: Box,
  r: number,
  blur = 18,
  offset = 8,
  alpha = 60
): void {
  // Drawn on a patch with room for the blur to fade out, not the whole canvas
  const m = blur * 3;
  const w = x1 - x0 + 2 * m;
  const h = y1 - y0 + 2 * m;
  const body = `<filter id="b" filterUnits="userSpaceOnUse" x="0" y="0" width="${w}" height="${h}"><feGaussianBlur stdDeviation="${blur}"/></filter><rect x="${m}" y="${m}" width="${x1 - x0}" height="${y1 - y0}" rx="${r}" fill="${rgb([20, 30, 60], alpha)}" filter="url(#b)"/>`;
  canvas.draw(svg(w, h, body), x0 - m, y0 + offset - m);
}

async function pad(
  img: Img,
  p = 18,
  color: Rgb = [255, 255, 255]
): Promise<Img> {
  return toImg(
    sharp(img.data).extend({
      top: p,
      bottom: p,
      left: p,
      right: p,
      background: rgb(color),
    })
  );
}

async function card(
  canvas: Canvas,
  img: Img,
  [x, y]: [number, number],
  {
    width,
    height,
    caption,
    r = 14,
  }: { width?: number; height?: number; caption?: string; r?: number }
): Promise<[number, number]> {
  const im = await resize(
    img,
    height ? height / img.height : (width ?? img.width) / img.width
  );
  shadow(canvas, [x, y, x + im.width, y + im.height], r);
  canvas.draw(await rounded(im, r), x, y);
  if (caption) {
    canvas.text(
      x + 4 * S,
      y + im.height + 10 * S,
      caption,
      15 * S,
      [40, 52, 80]
    );
  }
  return [im.width, im.height];
}

async function phone(
  canvas: Canvas,
  screen: Img,
  [x, y]: [number, number],
  width: number
): Promise<[number, number]> {
  const sc = await resize(screen, width / screen.width);
  const [p, top, bottom] = [10 * S, 26 * S, 34 * S];
  const [w, h] = [sc.width + 2 * p, sc.height + top + bottom];
  shadow(canvas, [x, y, x + w, y + h], 26 * S, 22, 8, 80);
  const shell = [
    `<rect width="${w}" height="${h}" rx="${26 * S}" fill="${rgb([28, 32, 44])}"/>`,
    // speaker
    `<rect x="${Math.floor(w / 2) - 22 * S}" y="${11 * S}" width="${44 * S}" height="${4 * S}" rx="${2 * S}" fill="${rgb([70, 76, 92])}"/>`,
    // d-pad
    `<rect x="${Math.floor(w / 2) - 16 * S}" y="${h - 25 * S}" width="${32 * S}" height="${14 * S}" rx="${6 * S}" fill="${rgb([52, 58, 74])}"/>`,
  ].join("");
  canvas.draw(svg(w, h, shell), x, y);
  canvas.draw(await rounded(sc, 4 * S), x + p, y + top);
  return [w, h];
}

// The top `height` rows; like Pillow's crop, rows past the bottom come out
// transparent.
async function cropHeight(img: Img, height: number): Promise<Img> {
  const kept = Math.min(height, img.height);
  const top = await toImg(
    sharp(img.data).extract({ left: 0, top: 0, width: img.width, height: kept })
  );
  return toImg(
    sharp(top.data).extend({
      bottom: height - kept,
      background: { r: 0, g: 0, b: 0, alpha: 0 },
    })
  );
}

async function save(img: Img, name: string): Promise<void> {
  await sharp(img.data)
    .removeAlpha()
    .png({ compressionLevel: 9 })
    .toFile(join(OUT, name));
}

const shots = {
  note: await pad(
    await crop(
      "feature_screenshots/17_mod_note_replies_and_viewers_closed.png",
      [326, 372, 1176, 842]
    )
  ),
  whisper: await pad(
    await crop(
      "feature_screenshots/21_post_rendered_as_whisper_after_save.png",
      [322, 140, 1086, 552]
    )
  ),
  reqpm: await pad(
    await crop("reqpm_11_hub_contacts.png", [497, 78, 1208, 346])
  ),
  popups: await popupStack(),
};

// The three stacked cards, lifted off the page and restacked on a clean
// background (the page shows through the gaps in the screenshot).
async function popupStack(): Promise<Img> {
  const name = "popup_notifications_stack_23_three_replies_mixed.png";
  const boxes: Box[] = [
    [1027, 62, 1386, 158],
    [1027, 168, 1386, 284],
    [1027, 293, 1386, 408],
  ];
  const cards = await Promise.all(boxes.map((b) => crop(name, b)));
  const [gap, p] = [12, 22];
  const pop = new Canvas(
    Math.max(...cards.map((c) => c.width)) + 2 * p,
    cards.reduce((sum, c) => sum + c.height, 0) + gap * 2 + 2 * p,
    { color: [239, 242, 248] }
  );
  let y = p;
  for (const c of cards) {
    pop.draw(c.data, p, y);
    y += c.height + gap;
  }
  return pop.render();
}

const phones = await Promise.all(
  ["04_latest", "05_post_sheet", "06_composer", "07_notifications"].map((n) =>
    toImg(load(`dumbcourse_${n}.png`))
  )
);

const [W, H] = [1600 * S, 1000 * S];
const gradient = svg(
  W,
  H,
  `<linearGradient id="g" x2="0" y2="1"><stop offset="0" stop-color="${rgb([230, 238, 255])}"/><stop offset="1" stop-color="${rgb([248, 250, 254])}"/></linearGradient><rect width="${W}" height="${H}" fill="url(#g)"/>`
);
const bg = new Canvas(W, H, { svg: gradient });

const m = 48 * S;
const capGap = 44 * S;
// top row: four phones, then the note card
const [px, py] = [m, 52 * S];
let h = 0;
for (const [i, sc] of phones.entries()) {
  [, h] = await phone(
    bg,
    sc,
    [px + i * 196 * S, py + (i % 2 ? 18 * S : 0)],
    168 * S
  );
}
bg.text(
  m + 4 * S,
  py + h + 30 * S,
  "Dumbcourse: the whole forum on a keypad phone",
  17 * S,
  [40, 52, 80]
);

const rx = m + 4 * 196 * S + 10 * S;
const rw = W - rx - m;
const [, nh] = await card(bg, shots.note, [rx, py], {
  width: rw,
  caption: "Private moderator notes",
});

// bottom row: equal heights
const rowY = Math.max(py + h + 30 * S, py + nh) + 70 * S;
const avail = W - 2 * m - 2 * 30 * S;
const bottomRow = [
  ["whisper", "Whispers to chosen people"],
  ["reqpm", "REQ-PM contact cards"],
  ["popups", "Desktop pop-ups"],
] as const;
let rowH = 300 * S;
const widths = bottomRow.map(
  ([key]) => (shots[key].width * rowH) / shots[key].height
);
rowH = Math.trunc(
  rowH * Math.min(1, avail / widths.reduce((a, b) => a + b, 0))
);
let bx = m;
for (const [key, caption] of bottomRow) {
  const [cw] = await card(bg, shots[key], [bx, rowY], {
    height: rowH,
    caption,
  });
  bx += cw + 30 * S;
}

const finalH = rowY + rowH + capGap + 20 * S;
const collage = await toImg(
  sharp((await cropHeight(await bg.render(), finalH)).data).resize(
    W / S,
    Math.trunc(finalH / S),
    { fit: "fill", kernel: "lanczos3" }
  )
);
await save(collage, "collage.png");

// Per-feature images for docs/features.
await save(shots.note, "moderator-note.png");
await save(shots.whisper, "whisper.png");
await save(shots.reqpm, "reqpm.png");
await save(shots.popups, "popups.png");

// Dumbcourse: four phones in a row, at natural size.
const strip = new Canvas(4 * 300 + 20, 520, { color: null });
let ph = 0;
for (const [i, sc] of phones.entries()) {
  [, ph] = await phone(strip, sc, [20 + i * 300, 20], 240);
}
await save(
  await toImg(
    sharp((await cropHeight(await strip.render(), ph + 50)).data).flatten({
      background: rgb([246, 248, 252]),
    })
  ),
  "dumbcourse.png"
);
