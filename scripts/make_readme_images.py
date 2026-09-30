"""Builds the README collage and the feature-page images in docs/images/
from the screenshots the system specs save.

    # from the Discourse folder, with this plugin linked as plugins/jtech-tools
    JTECH_SCREENSHOT_GALLERY=1 LOAD_PLUGINS=1 bin/rspec \
      plugins/jtech-tools/spec/system/{dumbcourse,reqpm,feature_screenshots,popup_notifications_stacking_screenshots}_spec.rb
    # then, from this repo
    pip install pillow
    python3 scripts/make_readme_images.py ../discourse/tmp/capybara
"""
from PIL import Image, ImageDraw, ImageFilter, ImageFont
import os
import sys

SRC = sys.argv[1] if len(sys.argv) > 1 else "../discourse/tmp/capybara"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "docs", "images")
S = 2  # render at 2x, save downscaled for crisp edges

def load(p): return Image.open(os.path.join(SRC, p)).convert("RGB")

def font(size, bold=False):
    for f in (["/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"] if bold
              else ["/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf"]):
        if os.path.exists(f): return ImageFont.truetype(f, size)

def rounded(img, r):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, img.width - 1, img.height - 1], r, fill=255)
    out = img.convert("RGBA"); out.putalpha(mask); return out

def shadow(canvas, box, r, blur=18, offset=8, alpha=60):
    x0, y0, x1, y1 = box
    sh = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle([x0, y0 + offset, x1, y1 + offset], r, fill=(20, 30, 60, alpha))
    canvas.alpha_composite(sh.filter(ImageFilter.GaussianBlur(blur)))

def pad(img, p=18, color=(255, 255, 255)):
    out = Image.new("RGB", (img.width + 2 * p, img.height + 2 * p), color)
    out.paste(img, (p, p))
    return out

def card(canvas, img, xy, width=None, caption=None, r=14, height=None):
    scale = (height / img.height) if height else (width / img.width)
    im = img.resize((int(img.width * scale), int(img.height * scale)), Image.LANCZOS)
    x, y = xy
    shadow(canvas, (x, y, x + im.width, y + im.height), r)
    canvas.alpha_composite(rounded(im, r), (x, y))
    if caption:
        d = ImageDraw.Draw(canvas)
        d.text((x + 4 * S, y + im.height + 10 * S), caption, fill=(40, 52, 80), font=font(15 * S, True))
    return im.width, im.height

def phone(canvas, screen, xy, width):
    scale = width / screen.width
    sc = screen.resize((int(screen.width * scale), int(screen.height * scale)), Image.LANCZOS)
    pad, top, bottom = 10 * S, 26 * S, 34 * S
    w, h = sc.width + 2 * pad, sc.height + top + bottom
    x, y = xy
    shadow(canvas, (x, y, x + w, y + h), 26 * S, blur=22, alpha=80)
    body = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(body)
    d.rounded_rectangle([0, 0, w - 1, h - 1], 26 * S, fill=(28, 32, 44))
    d.rounded_rectangle([w // 2 - 22 * S, 11 * S, w // 2 + 22 * S, 15 * S], 2 * S, fill=(70, 76, 92))  # speaker
    d.rounded_rectangle([w // 2 - 16 * S, h - 25 * S, w // 2 + 16 * S, h - 11 * S], 6 * S, fill=(52, 58, 74))  # d-pad
    body.alpha_composite(rounded(sc, 4 * S), (pad, top))
    canvas.alpha_composite(body, (x, y))
    return w, h

def crop(name, box): return load(name).crop(box)

shots = {
    "note": pad(crop("feature_screenshots/17_mod_note_replies_and_viewers_closed.png", (326, 372, 1176, 842))),
    "whisper": pad(crop("feature_screenshots/21_post_rendered_as_whisper_after_save.png", (322, 140, 1086, 552))),
    "reqpm": pad(crop("reqpm_11_hub_contacts.png", (497, 78, 1208, 346))),
    "popups": None,
}

# The three stacked cards, lifted off the page and restacked on a clean
# background (the page shows through the gaps in the screenshot).
_stack = load("popup_notifications_stack_23_three_replies_mixed.png")
_boxes = [(1027, 62, 1386, 158), (1027, 168, 1386, 284), (1027, 293, 1386, 408)]
_cards = [_stack.crop(b) for b in _boxes]
_gap, _p = 12, 22
_pop = Image.new("RGB", (max(c.width for c in _cards) + 2 * _p, sum(c.height for c in _cards) + _gap * 2 + 2 * _p), (239, 242, 248))
_y = _p
for c in _cards:
    _pop.paste(c, (_p, _y)); _y += c.height + _gap
shots["popups"] = _pop
phones = [load(f"dumbcourse_{n}.png") for n in ("04_latest", "05_post_sheet", "06_composer", "07_notifications")]

W, H = 1600 * S, 1000 * S
bg = Image.new("RGBA", (W, H))
top, bottomc = (230, 238, 255), (248, 250, 254)
d = ImageDraw.Draw(bg)
for yy in range(H):
    t = yy / H
    d.line([(0, yy), (W, yy)], fill=tuple(int(top[i] * (1 - t) + bottomc[i] * t) for i in range(3)) + (255,))

m = 48 * S
cap_gap = 44 * S
# top row: four phones, then the note card
px, py = m, 52 * S
for i, sc in enumerate(phones):
    w, h = phone(bg, sc, (px + i * 196 * S, py + (18 * S if i % 2 else 0)), 168 * S)
d.text((m + 4 * S, py + h + 30 * S), "Dumbcourse: the whole forum on a keypad phone", fill=(40, 52, 80), font=font(17 * S, True))

rx = m + 4 * 196 * S + 10 * S
rw = W - rx - m
nw, nh = card(bg, shots["note"], (rx, py), width=rw, caption="Private moderator notes")

# bottom row: equal heights
row_y = max(py + h + 30 * S, py + nh) + 70 * S
avail = W - 2 * m - 2 * 30 * S
row_h = 300 * S
ws = [shots[k].width * row_h / shots[k].height for k in ("whisper", "reqpm", "popups")]
f = min(1, avail / sum(ws))
row_h = int(row_h * f)
bx = m
for key, cap in (("whisper", "Whispers to chosen people"), ("reqpm", "REQ-PM contact cards"), ("popups", "Desktop pop-ups")):
    cw, ch = card(bg, shots[key], (bx, row_y), height=row_h, caption=cap)
    bx += cw + 30 * S

final_h = row_y + row_h + cap_gap + 20 * S
bg = bg.crop((0, 0, W, final_h)).convert("RGB").resize((W // S, final_h // S), Image.LANCZOS)

def save(img, name):
    img.convert("RGB").save(os.path.join(OUT, name), optimize=True)

save(bg, "collage.png")

# Per-feature images for docs/features.
save(shots["note"], "moderator-note.png")
save(shots["whisper"], "whisper.png")
save(shots["reqpm"], "reqpm.png")
save(shots["popups"], "popups.png")

# Dumbcourse: four phones in a row, at natural size.
strip = Image.new("RGBA", (4 * 300 + 20, 520), (0, 0, 0, 0))
for i, sc in enumerate(phones):
    pw, ph = phone(strip, sc, (20 + i * 300, 20), 240)
strip = strip.crop((0, 0, strip.width, ph + 50))
save(Image.alpha_composite(Image.new("RGBA", strip.size, (246, 248, 252, 255)), strip), "dumbcourse.png")
