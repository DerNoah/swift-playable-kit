#!/usr/bin/env python3
"""Generate a cute pixel-art chameleon sprite set for PlayableKit.

Produces the 24 frames PlayableKit's `PlayableCharacterNode` expects, with a
transparent background, plus (optionally) a looping demo GIF and a contact sheet.

Usage:
    python3 generate_chameleon_sprites.py OUTPUT_DIR [--gif GIF] [--sheet SHEET]

Frames written (W x H, RGBA, transparent):
    idle_00..03  walk_00..03  rolling_00..03  attention_00..01
    fainting_00..02  attacking_00..02  wave_00..03
"""

import argparse
import os
from PIL import Image, ImageDraw, ImageFilter, ImageChops

W, H = 48, 40
GROUND = 36  # baseline y for the feet

# ── palette (RGBA) ──────────────────────────────────────────────────────────
T      = (0, 0, 0, 0)
OUT    = (40, 74, 48, 255)      # dark outline
GREEN  = (126, 200, 112, 255)   # main body
DARK   = (96, 170, 90, 255)     # crest / shade
LIGHT  = (178, 230, 150, 255)   # highlight
BELLY  = (220, 244, 180, 255)   # belly / cream
WHITE  = (255, 255, 255, 255)
PUPIL  = (44, 46, 60, 255)
CHEEK  = (255, 158, 170, 255)
TONGUE = (234, 98, 120, 255)
TIP    = (250, 150, 168, 255)


def new_img():
    return Image.new("RGBA", (W, H), T)


def disc(d, cx, cy, r, fill):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=fill)


def add_outline(img, color=OUT):
    """Wrap the whole opaque silhouette in a 1px dark outline."""
    a = img.split()[3]
    big = a.filter(ImageFilter.MaxFilter(3)).point(lambda v: 255 if v > 0 else 0)
    solid = a.point(lambda v: 255 if v > 0 else 0)
    ring = ImageChops.subtract(big, solid)
    out = new_img()
    out.paste(color, (0, 0), ring)
    out.alpha_composite(img)
    return out


def draw_eye(d, ex, ey, open_=True, look=(2, 1)):
    """Big round 'Glubsch' eye centred at (ex, ey)."""
    if open_:
        disc(d, ex, ey, 7, WHITE)           # oversized eyeball (bulges out)
        px, py = ex + look[0], ey + look[1]
        disc(d, px, py, 3, PUPIL)           # big pupil
        disc(d, px - 1, py - 2, 1, WHITE)   # shine
    else:
        disc(d, ex, ey, 6, GREEN)           # happy closed eyelid (skin)
        d.arc([ex - 4, ey - 2, ex + 4, ey + 4], 200, 340, fill=PUPIL, width=1)


def draw_leg(d, x, top, length, fill=GREEN):
    d.rectangle([x - 2, top, x + 2, top + length], fill=fill)
    disc(d, x, top + length, 3, fill)       # rounded foot


def standing(bob=0, legs=None, eye_open=True, look=(2, 1), mouth_open=False,
             tongue=0, arm=None, cheek=True, crest=True):
    """Render the side-view chameleon (facing right). Returns RGBA pre-composite."""
    img = new_img()
    d = ImageDraw.Draw(img)
    cy = 22 + bob

    # tail – a little spiral curling up at the back (left)
    for (tx, ty, tr) in [(10, cy + 3, 4), (6, cy + 1, 3), (5, cy - 3, 2), (8, cy - 4, 2)]:
        disc(d, tx, ty, tr, GREEN)

    # legs (behind body)
    if legs is None:
        legs = [(16, GROUND - (cy + 6)), (30, GROUND - (cy + 6))]
    for (lx, ll) in legs:
        draw_leg(d, lx, cy + 6, max(2, ll))

    # body + belly
    d.ellipse([9, cy - 9, 33, cy + 10], fill=GREEN)
    d.ellipse([12, cy + 1, 29, cy + 11], fill=BELLY)

    # head (big and round, up-right)
    d.ellipse([27, cy - 12, 46, cy + 6], fill=GREEN)

    # crest bumps along the back/head
    if crest:
        for bx in range(15, 34, 5):
            disc(d, bx, cy - 9, 2, DARK)

    # cheek blush (just below the eye)
    if cheek:
        disc(d, 32, cy - 1, 2, CHEEK)

    # mouth
    if mouth_open:
        disc(d, 43, cy + 1, 2, PUPIL)
    else:
        d.line([41, cy + 2, 45, cy + 1], fill=OUT, width=1)

    # tongue (attack)
    if tongue > 0:
        d.line([44, cy + 1, 44 + tongue, cy + 1], fill=TONGUE, width=2)
        disc(d, 44 + tongue, cy + 1, 2, TIP)

    # big eye
    draw_eye(d, 38, cy - 5, open_=eye_open, look=look)

    # waving arm (near-side hand raised up over the back, clear of the face)
    if arm is not None:
        hx, hy = arm
        d.line([30, cy + 2, hx, hy], fill=GREEN, width=3)
        disc(d, hx, hy, 3, GREEN)

    return img


def ball(rot):
    """Curled-up chameleon for the rolling (walk-on-top) animation."""
    img = new_img()
    d = ImageDraw.Draw(img)
    cx, cy = 24, 22
    disc(d, cx, cy, 12, GREEN)
    disc(d, cx, cy + 3, 9, BELLY)
    # tail curl wrapped on top
    for (tx, ty, tr) in [(cx - 9, cy - 5, 3), (cx - 11, cy - 1, 2), (cx - 8, cy + 1, 2)]:
        disc(d, tx, ty, tr, DARK)
    draw_eye(d, cx + 5, cy - 3, open_=True, look=(2, 1))
    disc(d, cx + 1, cy + 6, 2, CHEEK)
    img = add_outline(img)
    return img.rotate(-90 * rot, resample=Image.NEAREST, center=(cx, cy))


def settle(img):
    """Drop feet to GROUND-ish and add outline."""
    return add_outline(img)


# ── per-state frame builders ────────────────────────────────────────────────
def frames():
    f = {}

    # idle: gentle breathing bob + a blink on the last frame
    f["idle"] = [
        settle(standing(bob=0)),
        settle(standing(bob=-1)),
        settle(standing(bob=0)),
        settle(standing(bob=0, eye_open=False)),
    ]

    # walk: 4-phase leg cycle + slight bob
    walk_legs = [
        [(15, 8), (31, 5)],
        [(16, 6), (30, 7)],
        [(17, 5), (29, 8)],
        [(16, 7), (30, 6)],
    ]
    f["walk"] = [settle(standing(bob=(-1 if i % 2 else 0), legs=walk_legs[i]))
                 for i in range(4)]

    # rolling (walk-on-top): curled ball rotating
    f["rolling"] = [ball(i) for i in range(4)]

    # attention (sit): upright, looking up, small blink
    f["attention"] = [
        settle(standing(bob=2, look=(1, -2), legs=[(18, 4), (28, 4)])),
        settle(standing(bob=2, look=(1, -2), legs=[(18, 4), (28, 4)], eye_open=False)),
    ]

    # fainting (jump): crouch -> airborne -> land
    f["fainting"] = [
        settle(standing(bob=3, legs=[(16, 3), (30, 3)])),
        settle(standing(bob=-6, legs=[(18, 2), (28, 2)])),
        settle(standing(bob=1, legs=[(16, 5), (30, 5)])),
    ]

    # attacking (interact): windup -> tongue out -> retract
    f["attacking"] = [
        settle(standing(mouth_open=True)),
        settle(standing(mouth_open=True, tongue=12, look=(3, 1))),
        settle(standing(mouth_open=True, tongue=4)),
    ]

    # wave: near-side hand waving up over the back (left), clear of the eye
    arms = [(24, 8), (22, 4), (26, 9), (23, 6)]
    f["wave"] = [settle(standing(arm=arms[i], cheek=True)) for i in range(4)]

    return f


def save_frames(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    fr = frames()
    counts = {}
    for state, imgs in fr.items():
        for i, img in enumerate(imgs):
            img.save(os.path.join(out_dir, f"{state}_{i:02d}.png"))
        counts[state] = len(imgs)
    return fr, counts


def upscale(img, k, bg=None):
    big = img.resize((img.width * k, img.height * k), Image.NEAREST)
    if bg is not None:
        canvas = Image.new("RGBA", big.size, bg)
        canvas.alpha_composite(big)
        return canvas
    return big


def make_sheet(fr, path, k=4):
    cols = max(len(v) for v in fr.values())
    rows = len(fr)
    cellw, cellh = W * k, H * k
    sheet = Image.new("RGBA", (cols * cellw, rows * cellh), (235, 236, 238, 255))
    for r, (state, imgs) in enumerate(fr.items()):
        for c, img in enumerate(imgs):
            sheet.alpha_composite(upscale(img, k), (c * cellw, r * cellh))
    sheet.save(path)


def make_gif(fr, path, k=5, bg=(238, 240, 243, 255)):
    # play through a showcase sequence
    seq = (fr["idle"] + fr["walk"] * 2 + fr["wave"] +
           fr["attacking"] + fr["fainting"] + fr["attention"])
    frames_big = [upscale(im, k, bg=bg).convert("P", palette=Image.ADAPTIVE)
                  for im in seq]
    frames_big[0].save(path, save_all=True, append_images=frames_big[1:],
                       duration=150, loop=0, disposal=2)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out_dir")
    ap.add_argument("--gif")
    ap.add_argument("--sheet")
    args = ap.parse_args()
    fr, counts = save_frames(args.out_dir)
    print("wrote frames:", counts, "->", args.out_dir)
    if args.sheet:
        make_sheet(fr, args.sheet)
        print("wrote sheet ->", args.sheet)
    if args.gif:
        make_gif(fr, args.gif)
        print("wrote gif ->", args.gif)


if __name__ == "__main__":
    main()
