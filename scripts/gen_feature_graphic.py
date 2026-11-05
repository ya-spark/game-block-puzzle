"""Draws the Block Puzzle feature graphic (1024x500) with Pillow: original art, no assets.

Run from anywhere: python3 scripts/gen_feature_graphic.py
"""
import os
import math
from PIL import Image, ImageDraw, ImageFilter, ImageFont
W, H = 1024, 500
def grad():
    img = Image.new("RGB", (W, H)); px = img.load()
    for y in range(H):
        for x in range(W):
            t = (x / W) * 0.45 + (y / H) * 0.55
            px[x, y] = (int(62 - 32 * t), int(40 - 20 * t), int(142 - 70 * t))
    return img.convert("RGBA")
def block(d, x, y, s, c):
    dark = tuple(int(v * 0.62) for v in c); light = tuple(min(255, int(v * 1.2) + 25) for v in c)
    r = s // 5
    d.rounded_rectangle([x, y + s // 14, x + s, y + s + s // 14], r, fill=dark)           # bottom edge
    d.rounded_rectangle([x, y, x + s, y + s], r, fill=c)
    d.rounded_rectangle([x + s // 9, y + s // 11, x + s - s // 9, y + s // 2], r // 2 + 2, fill=light)
def glow(draw_fn, radius, boost=1.4):
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0)); draw_fn(ImageDraw.Draw(layer))
    b = layer.filter(ImageFilter.GaussianBlur(radius)); r, g, bl, a = b.split()
    return Image.merge("RGBA", (r, g, bl, a.point(lambda v: min(255, int(v * boost)))))
def star(d, cx, cy, r, color, thin=0.2):
    pts = []
    for i in range(8):
        ang = math.pi / 4 * i - math.pi / 2; rad = r if i % 2 == 0 else r * thin
        pts.append((cx + rad * math.cos(ang), cy + rad * math.sin(ang)))
    d.polygon(pts, fill=color)
RED, BLUE, YEL, PUR, ORG, TEAL = (255, 96, 120), (80, 170, 255), (255, 205, 70), (178, 120, 255), (255, 150, 60), (60, 214, 190)
img = grad()
# soft light behind the grid
img = Image.alpha_composite(img, glow(lambda d: d.ellipse([20, 40, 480, 470], fill=(150, 110, 255, 110)), 60))
cell, gap, ox, oy = 84, 9, 60, 212
grid = Image.new("RGBA", (W, H), (0, 0, 0, 0)); gd = ImageDraw.Draw(grid)
filled = {(0, 0): RED, (0, 1): RED, (0, 2): BLUE, (1, 0): YEL, (1, 1): PUR, (2, 0): YEL}
empty = [(1, 2), (2, 1), (2, 2)]
def pos(r, c): return ox + c * (cell + gap), oy + r * (cell + gap)
for (r, c), col in filled.items():
    x, y = pos(r, c); block(gd, x, y, cell, col)
for r, c in empty:
    x, y = pos(r, c)
    gd.rounded_rectangle([x, y, x + cell, y + cell], cell // 5, outline=(255, 255, 255, 235), width=5, fill=(20, 12, 60, 150))
img = Image.alpha_composite(img, glow(lambda d: [d.rounded_rectangle([pos(r, c)[0], pos(r, c)[1], pos(r, c)[0] + cell, pos(r, c)[1] + cell], 20, fill=(120, 240, 255, 200)) for r, c in empty], 22, 1.2))
img = Image.alpha_composite(img, grid)
# the floating L piece with streaks, about to drop into the gap (tilted a little)
px0, py0 = 153, 12
pcells = [(1, 0), (0, 1), (1, 1)]   # (col, row): matches the L-shaped slot
streak = Image.new("RGBA", (W, H), (0, 0, 0, 0)); sd = ImageDraw.Draw(streak)
for cx, h, a in [(px0 + cell + gap + cell // 2, 62, 200), (px0 + cell // 2, 44, 150)]:
    top = py0 + (0 if cx > px0 + cell else cell + gap) - h
    for y in range(max(0, top), top + h):
        t = (y - top) / h
        sd.line([(cx - 7, y), (cx + 7, y)], fill=(240, 232, 255, int(a * t * t)))
img = Image.alpha_composite(img, streak.filter(ImageFilter.GaussianBlur(1.2)))
piece = Image.new("RGBA", (W, H), (0, 0, 0, 0)); pd = ImageDraw.Draw(piece)
for dc, dr in pcells:
    block(pd, px0 + dc * (cell + gap), py0 + dr * (cell + gap), cell, TEAL)
pglow = glow(lambda d: [d.rounded_rectangle([px0 + dc * (cell + gap) - 6, py0 + dr * (cell + gap) - 6, px0 + dc * (cell + gap) + cell + 6, py0 + dr * (cell + gap) + cell + 6], 24, fill=(110, 255, 230, 170)) for dc, dr in pcells], 16, 1.3)
piece = Image.alpha_composite(pglow, piece).rotate(-6, resample=Image.BICUBIC, center=(px0 + cell, py0 + cell))
img = Image.alpha_composite(img, piece)
# sparkles
fx = Image.new("RGBA", (W, H), (0, 0, 0, 0)); fd = ImageDraw.Draw(fx)
for (x, y, r, c) in [(40, 90, 24, (255, 255, 255, 255)), (470, 80, 28, (255, 240, 170, 255)), (440, 300, 20, (190, 255, 255, 255)), (395, 440, 16, (255, 255, 255, 230))]:
    star(fd, x, y, r, c)
for (x, y, r, c) in [(110, 40, 5, (255, 255, 255, 230)), (540, 60, 5, (255, 220, 120, 230)), (500, 470, 5, (190, 255, 255, 230))]:
    fd.ellipse([x - r, y - r, x + r, y + r], fill=c)
img = Image.alpha_composite(img, fx)
# title
try:
    f1 = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 118)
    f2 = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 40)
except Exception:
    f1 = f2 = ImageFont.load_default()
tl = Image.new("RGBA", (W, H), (0, 0, 0, 0)); td = ImageDraw.Draw(tl)
def text(x, y, s, f, fill, shadow=(30, 10, 80, 255), off=6):
    td.text((x + off, y + off), s, font=f, fill=shadow); td.text((x, y), s, font=f, fill=fill)
text(560, 118, "Block", f1, (255, 255, 255, 255)); text(560, 232, "Puzzle", f1, (255, 214, 90, 255))
text(566, 372, "Drag. Drop. Clear.", f2, (200, 240, 255, 255), off=3)
img = Image.alpha_composite(img, tl)
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
out = os.path.join(ROOT, "store", "google-play", "graphics", "feature-graphic-1024x500.png")
img.convert("RGB").save(out); print("saved", out)
