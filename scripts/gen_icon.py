#!/usr/bin/env python3
"""Block Puzzle icon: a Z piece falling toward the slot that fits it, with speed streaks and sparkles.
Writes store/google-play/graphics/icon-512.png and the Android launcher icons (adaptive foreground
plus the legacy square). The adaptive background colour stays in res/values/ic_launcher_background.xml.
Original art drawn with Pillow; no external assets."""
import math
import os
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")
S = 512
CELL = 80
COLS, ROWS = 4, 5
GW, GH = COLS * CELL, ROWS * CELL
RED, YEL, BLU, GRN, PUR = (255, 95, 115), (255, 205, 70), (85, 175, 255), (70, 215, 130), (180, 110, 255)


def gem(d, x, y, s, c):
    r = max(2, s // 5)
    dark = tuple(int(v * 0.55) for v in c)
    light = tuple(min(255, int(v * 1.2) + 25) for v in c)
    d.rounded_rectangle([x, y, x + s - 1, y + s - 1], r, fill=dark)
    p = max(2, s // 11)
    d.rounded_rectangle([x + p, y + p, x + s - 1 - p, y + s - 1 - p * 2], r, fill=c)
    d.rounded_rectangle([x + p * 2, y + p * 2, x + s - 1 - p * 3, y + s // 2 - 2], r, fill=light)


def glow(size, fn, radius, boost=1.0):
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    fn(ImageDraw.Draw(layer))
    out = layer.filter(ImageFilter.GaussianBlur(radius))
    if boost != 1.0:
        r, g, b, a = out.split()
        out = Image.merge("RGBA", (r, g, b, a.point(lambda v: min(255, int(v * boost)))))
    return out


def star(d, cx, cy, r, color):
    pts = []
    for i in range(8):
        a = math.pi / 4 * i - math.pi / 2
        rad = r if i % 2 == 0 else r * 0.18
        pts.append((cx + rad * math.cos(a), cy + rad * math.sin(a)))
    d.polygon(pts, fill=color)


def content():
    """The grid scene on a transparent canvas of S x S, grid centred."""
    ox, oy = (S - GW) // 2, (S - GH) // 2
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))

    def xy(c, r):
        return ox + c * CELL, oy + r * CELL

    # slot for the Z piece: row 3 cols 0-1, row 4 cols 1-2
    slot = [(0, 3), (1, 3), (1, 4), (2, 4)]
    img = Image.alpha_composite(img, glow((S, S), lambda d: [d.rounded_rectangle([*xy(c, r), xy(c, r)[0] + CELL - 4, xy(c, r)[1] + CELL - 4], 14, fill=(120, 235, 255, 230)) for c, r in slot], 18, 1.6))
    stack = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    sd = ImageDraw.Draw(stack)
    for (c, r), col in {(0, 4): YEL, (3, 4): BLU, (2, 3): GRN, (3, 3): RED}.items():
        gem(sd, *xy(c, r), CELL - 4, col)
    img = Image.alpha_composite(img, stack)
    ghost = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    gd = ImageDraw.Draw(ghost)
    for c, r in slot:
        x, y = xy(c, r)
        gd.rounded_rectangle([x + 5, y + 5, x + CELL - 9, y + CELL - 9], 14, outline=(225, 255, 255, 240), width=4, fill=(120, 230, 255, 50))
    img = Image.alpha_composite(img, ghost)

    # speed streaks above the falling piece (piece: row 0 cols 0-1, row 1 cols 1-2)
    streaks = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    st = ImageDraw.Draw(streaks)
    top = oy + 6
    for c, h, a, w in [(0, 60, 150, 10), (1, 50, 190, 12), (2, 40, 130, 10)]:
        x = ox + c * CELL + CELL // 2
        for y in range(max(0, top - h), top + 4):
            t = (y - (top - h)) / (h + 4)
            st.line([(x - w // 2, y), (x + w // 2, y)], fill=(240, 228, 255, int(a * t * t)))
    img = Image.alpha_composite(img, streaks.filter(ImageFilter.GaussianBlur(1.2)))

    piece = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    pd = ImageDraw.Draw(piece)
    cells = [(0, 0), (1, 0), (1, 1), (2, 1)]
    aura = glow((S, S), lambda d: [d.rounded_rectangle([xy(c, r)[0] - 4, xy(c, r)[1] - 4, xy(c, r)[0] + CELL, xy(c, r)[1] + CELL], 16, fill=(255, 150, 175, 190)) for c, r in cells], 14, 1.4)
    for c, r in cells:
        gem(pd, *xy(c, r), CELL - 4, RED if (c, r) != (1, 1) else PUR)
    piece = Image.alpha_composite(aura, piece).rotate(-7, resample=Image.BICUBIC, center=(S // 2, oy + CELL))
    img = Image.alpha_composite(img, piece)

    fx = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    fd = ImageDraw.Draw(fx)
    for x, y, r, c in [(ox + 8, oy + 2 * CELL + 10, 22, (255, 255, 255, 255)), (ox + GW - 4, oy + CELL + 20, 28, (255, 240, 170, 255)),
                       (ox + GW + 10, oy + 3 * CELL - 10, 18, (190, 255, 255, 255))]:
        star(fd, x, y, r, c)
    for x, y, r, c in [(ox + 120, oy - 10, 5, (255, 255, 255, 230)), (ox + GW - 60, oy + 20, 4, (255, 220, 120, 230)), (ox - 6, oy + 150, 4, (210, 170, 255, 230))]:
        fd.ellipse([x - r, y - r, x + r, y + r], fill=c)
    return Image.alpha_composite(img, fx)


def background():
    img = Image.new("RGB", (S, S))
    px = img.load()
    for y in range(S):
        for x in range(S):
            t = y / S * 0.7 + x / S * 0.3
            px[x, y] = (int(52 - 22 * t), int(34 - 14 * t), int(112 - 36 * t))
    bg = img.convert("RGBA")
    return Image.alpha_composite(bg, glow((S, S), lambda d: d.ellipse([90, 40, 430, 330], fill=(130, 90, 255, 90)), 60))


def main():
    full = Image.alpha_composite(background(), content()).convert("RGB")
    full.save(os.path.join(ROOT, "store", "google-play", "graphics", "icon-512.png"))
    # adaptive foreground: content scaled into the 66 % safe zone of a transparent 108 dp canvas
    box = content().crop((60, 60, S - 60, S - 60))
    for name, px in (("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)):
        full.resize((px, px), Image.LANCZOS).save(os.path.join(RES, f"mipmap-{name}", "ic_launcher.png"))
        fg = px * 9 // 4  # 108 dp at this density
        canvas = Image.new("RGBA", (fg, fg), (0, 0, 0, 0))
        side = int(fg * 0.64)
        scaled = box.resize((side, side), Image.LANCZOS)
        canvas.paste(scaled, ((fg - side) // 2, (fg - side) // 2), scaled)
        canvas.save(os.path.join(RES, f"mipmap-{name}", "ic_launcher_foreground.png"))
    print("icons written")


if __name__ == "__main__":
    main()
