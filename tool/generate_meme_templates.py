#!/usr/bin/env python3
"""Draws the bundled Tamil meme template images (original flat illustrations).

Every image is drawn from scratch by this script: generic cartoon characters,
no photographs, no film stills and no likeness of any real person. Run with
`python3 tool/generate_meme_templates.py` (needs Pillow) to regenerate
`assets/memes/tm001.png` .. `tm020.png`.
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "memes")
FONT = os.path.join(ROOT, "assets", "fonts", "Anton-Regular.ttf")
W = 1080
S = 2  # supersampling

SKIN = {"light": (255, 214, 170), "tan": (224, 172, 120), "brown": (176, 120, 80), "dark": (130, 84, 56)}
INK = (40, 30, 30)


def hexc(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def shade(c, f):
    return tuple(max(0, min(255, int(v * f))) for v in c)


class Canvas:
    def __init__(self, c1, c2=None, pattern=None, seed=1):
        self.im = Image.new("RGB", (W * S, W * S), c1)
        self.d = ImageDraw.Draw(self.im, "RGBA")
        if c2:
            for y in range(W * S):
                t = y / (W * S - 1)
                col = tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))
                self.d.line([(0, y), (W * S, y)], fill=col)
        r = random.Random(seed)
        if pattern == "dots":
            for gy in range(0, W + 1, 60):
                for gx in range(0, W + 1, 60):
                    self.circle(gx + (30 if (gy // 60) % 2 else 0), gy, 6, (255, 255, 255, 40))
        elif pattern == "rays":
            cx, cy = W / 2, W * 0.45
            for i in range(0, 24, 2):
                a1, a2 = i * math.pi / 12, (i + 1) * math.pi / 12
                self.poly([(cx, cy), (cx + 1500 * math.cos(a1), cy + 1500 * math.sin(a1)),
                           (cx + 1500 * math.cos(a2), cy + 1500 * math.sin(a2))], (255, 255, 255, 30))
        elif pattern == "confetti":
            for _ in range(90):
                x, y = r.randint(0, W), r.randint(0, W)
                col = r.choice([(255, 235, 59, 200), (255, 64, 129, 200), (0, 229, 255, 200), (105, 240, 174, 200)])
                self.rect(x, y, x + r.randint(14, 26), y + r.randint(8, 14), col)
        elif pattern == "stripes":
            for x in range(-W, W * 2, 90):
                self.poly([(x, 0), (x + 45, 0), (x + 45 + W, W), (x + W, W)], (255, 255, 255, 22))

    # primitives take 1080-space coordinates
    def p(self, v):
        return v * S

    def circle(self, x, y, r, fill, outline=None, width=0):
        self.d.ellipse([self.p(x - r), self.p(y - r), self.p(x + r), self.p(y + r)], fill=fill,
                       outline=outline, width=int(width * S))

    def ell(self, x1, y1, x2, y2, fill, outline=None, width=0):
        self.d.ellipse([self.p(x1), self.p(y1), self.p(x2), self.p(y2)], fill=fill, outline=outline,
                       width=int(width * S))

    def rect(self, x1, y1, x2, y2, fill, r=0, outline=None, width=0):
        box = [self.p(x1), self.p(y1), self.p(x2), self.p(y2)]
        if r:
            self.d.rounded_rectangle(box, radius=self.p(r), fill=fill, outline=outline, width=int(width * S))
        else:
            self.d.rectangle(box, fill=fill, outline=outline, width=int(width * S))

    def poly(self, pts, fill, outline=None):
        self.d.polygon([(self.p(x), self.p(y)) for x, y in pts], fill=fill, outline=outline)

    def line(self, pts, fill, width):
        self.d.line([(self.p(x), self.p(y)) for x, y in pts], fill=fill, width=int(width * S), joint="curve")

    def arc(self, box, a1, a2, fill, width):
        x1, y1, x2, y2 = box
        self.d.arc([self.p(x1), self.p(y1), self.p(x2), self.p(y2)], a1, a2, fill=fill, width=int(width * S))

    def text(self, x, y, s, size, fill):
        f = ImageFont.truetype(FONT, int(size * S))
        self.d.text((self.p(x), self.p(y)), s, font=f, fill=fill, anchor="mm")

    def curve(self, pts, fill, width, steps=24):
        # quadratic bezier through 3 points
        (x0, y0), (x1, y1), (x2, y2) = pts
        out = []
        for i in range(steps + 1):
            t = i / steps
            out.append(((1 - t) ** 2 * x0 + 2 * (1 - t) * t * x1 + t * t * x2,
                        (1 - t) ** 2 * y0 + 2 * (1 - t) * t * y1 + t * t * y2))
        self.line(out, fill, width)

    def save(self, name):
        im = self.im.resize((W, W), Image.LANCZOS)
        im = im.quantize(colors=160, method=Image.MEDIANCUT, dither=Image.NONE)
        im.save(os.path.join(OUT, name), optimize=True)


# ---------------------------------------------------------------- props
def heart(c, x, y, s, fill):
    c.circle(x - s * 0.25, y - s * 0.15, s * 0.28, fill)
    c.circle(x + s * 0.25, y - s * 0.15, s * 0.28, fill)
    c.poly([(x - s * 0.5, y - s * 0.05), (x + s * 0.5, y - s * 0.05), (x, y + s * 0.5)], fill)


def broken_heart(c, x, y, s):
    heart(c, x, y, s, (233, 30, 99))
    c.line([(x, y - s * 0.4), (x - s * 0.1, y - s * 0.1), (x + s * 0.12, y + s * 0.1), (x, y + s * 0.5)], (255, 255, 255), s * 0.07)


def star(c, x, y, r, fill):
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        rr = r if i % 2 == 0 else r * 0.45
        pts.append((x + rr * math.cos(a), y + rr * math.sin(a)))
    c.poly(pts, fill)


def sweat(c, x, y, s):
    c.poly([(x, y - s), (x - s * 0.55, y + s * 0.25), (x + s * 0.55, y + s * 0.25)], (120, 200, 255))
    c.circle(x, y + s * 0.25, s * 0.55, (120, 200, 255))


def zzz(c, x, y, s):
    for i, k in enumerate((1.0, 0.75, 0.55)):
        c.text(x + i * s * 0.9, y - i * s * 0.9, "Z", s * k * 1.4, (255, 255, 255, 230))


def question(c, x, y, s, fill=(255, 255, 255, 235)):
    c.text(x, y, "?", s, fill)


def phone(c, x, y, w, h, screen=(40, 60, 100), tilt=0):
    c.rect(x, y, x + w, y + h, (30, 30, 36), r=w * 0.14)
    c.rect(x + w * 0.07, y + h * 0.05, x + w * 0.93, y + h * 0.95, screen, r=w * 0.1)


def chai(c, x, y, s):
    c.rect(x, y, x + s, y + s * 1.2, (255, 255, 255, 235), r=s * 0.12)
    c.rect(x + s * 0.08, y + s * 0.15, x + s * 0.92, y + s * 0.5, (176, 110, 60), r=s * 0.08)
    c.arc((x + s * 0.7, y + s * 0.2, x + s * 1.4, y + s * 0.9), -90, 90, (255, 255, 255, 235), s * 0.1)
    for i in range(3):
        c.curve([(x + s * (0.3 + i * 0.2), y - s * 0.1), (x + s * (0.2 + i * 0.2), y - s * 0.35),
                 (x + s * (0.3 + i * 0.2), y - s * 0.6)], (255, 255, 255, 150), s * 0.05)


def plate(c, x, y, s):
    c.ell(x - s, y - s * 0.3, x + s, y + s * 0.3, (245, 245, 245))
    c.ell(x - s * 0.8, y - s * 0.4, x + s * 0.8, y + s * 0.15, (233, 170, 40))
    for i in range(10):
        c.circle(x + math.cos(i * 1.9) * s * 0.45, y - s * 0.12 + math.sin(i * 2.7) * s * 0.12, s * 0.06, (200, 90, 40))


def banana(c, x, y, s, flip=1):
    pts = [(x, y), (x + flip * s * 0.4, y - s * 0.35), (x + flip * s, y - s * 0.3), (x + flip * s * 0.45, y - s * 0.05)]
    c.poly(pts, (255, 224, 70))
    c.line([(x, y), (x - flip * s * 0.1, y + s * 0.1)], (110, 80, 30), s * 0.1)


def paper(c, x, y, w, h, lines=True, rot=0):
    c.rect(x, y, x + w, y + h, (255, 255, 255), r=6, outline=(200, 200, 200), width=3)
    if lines:
        for i in range(1, 6):
            c.line([(x + w * 0.12, y + h * i / 7), (x + w * 0.88, y + h * i / 7)], (210, 215, 225), 4)


def sunglasses(c, cx, cy, w, tilt=0):
    r = w * 0.28
    for dx in (-w * 0.27, w * 0.27):
        c.rect(cx + dx - r, cy - r * 0.7 + tilt * dx / w, cx + dx + r, cy + r * 0.8 + tilt * dx / w, (15, 15, 20), r=r * 0.45)
        c.rect(cx + dx - r * 0.7, cy - r * 0.5 + tilt * dx / w, cx + dx - r * 0.2, cy - r * 0.15 + tilt * dx / w, (255, 255, 255, 90), r=4)
    c.line([(cx - w * 0.27 + r, cy), (cx + w * 0.27 - r, cy)], (15, 15, 20), w * 0.045)


def glasses(c, cx, cy, w):
    r = w * 0.2
    for dx in (-w * 0.26, w * 0.26):
        c.circle(cx + dx, cy, r, (255, 255, 255, 60), outline=(40, 40, 50), width=7)
    c.line([(cx - w * 0.26 + r, cy - 4), (cx + w * 0.26 - r, cy - 4)], (40, 40, 50), 7)


# ---------------------------------------------------------------- characters
def person(c, cx, cy, sc=1.0, skin="tan", hair="short", hair_color=(30, 25, 25), shirt=(70, 110, 200),
           face="blank", beard=None, specs=None, collar=True, ears=True, width=1.0, brow_color=None):
    sk = SKIN[skin]
    sh = shade(sk, 0.85)
    rw, rh = 150 * sc * width, 175 * sc
    # shoulders / shirt
    c.ell(cx - rw * 1.75, cy + rh * 1.0, cx + rw * 1.75, cy + rh * 2.6, shirt)
    c.rect(cx - rw * 0.42, cy + rh * 0.7, cx + rw * 0.42, cy + rh * 1.25, sh)  # neck
    if collar:
        c.poly([(cx - rw * 0.5, cy + rh * 1.0), (cx, cy + rh * 1.5), (cx + rw * 0.5, cy + rh * 1.0)], sk)
    # ears
    if ears:
        for s_ in (-1, 1):
            c.ell(cx + s_ * rw * 0.95 - 28 * sc, cy - 28 * sc, cx + s_ * rw * 0.95 + 28 * sc, cy + 52 * sc, sk)
    # hair behind head
    if hair in ("curly", "long"):
        c.ell(cx - rw * 1.05, cy - rh * 1.05, cx + rw * 1.05, cy + rh * 0.4, hair_color)
    # head
    c.ell(cx - rw, cy - rh, cx + rw, cy + rh, sk)
    # hair front
    if hair == "short":
        c.ell(cx - rw * 1.02, cy - rh * 1.08, cx + rw * 1.02, cy - rh * 0.1, hair_color)
        c.ell(cx - rw * 0.85, cy - rh * 0.78, cx + rw * 0.85, cy + rh * 0.02, sk)
    elif hair == "quiff":
        c.ell(cx - rw * 1.02, cy - rh * 1.15, cx + rw * 1.02, cy - rh * 0.1, hair_color)
        c.ell(cx - rw * 0.9, cy - rh * 0.72, cx + rw * 0.9, cy + rh * 0.02, sk)
        c.poly([(cx - rw * 0.6, cy - rh * 0.85), (cx - rw * 0.2, cy - rh * 1.45), (cx + rw * 0.7, cy - rh * 1.2),
                (cx + rw * 0.9, cy - rh * 0.75)], hair_color)
    elif hair == "curly":
        for i in range(9):
            a = math.pi + i * math.pi / 8
            c.circle(cx + math.cos(a) * rw * 0.95, cy - rh * 0.25 + math.sin(a) * rh * 1.0, 46 * sc, hair_color)
        c.ell(cx - rw * 0.85, cy - rh * 0.75, cx + rw * 0.85, cy + rh * 0.02, sk)
    elif hair == "tufts":  # bald with side tufts
        for s_ in (-1, 1):
            c.ell(cx + s_ * rw * 0.98 - 34 * sc, cy - rh * 0.55, cx + s_ * rw * 0.98 + 34 * sc, cy - rh * 0.05, hair_color)
    elif hair == "wild":
        for i in range(12):
            a = math.pi + i * math.pi / 11
            x2 = cx + math.cos(a) * rw * 1.35
            y2 = cy - rh * 0.2 + math.sin(a) * rh * 1.4
            c.poly([(cx + math.cos(a) * rw * 0.8, cy - rh * 0.2 + math.sin(a) * rh * 0.8),
                    (x2, y2), (cx + math.cos(a + 0.28) * rw * 0.8, cy - rh * 0.2 + math.sin(a + 0.28) * rh * 0.8)], hair_color)
        c.ell(cx - rw * 0.9, cy - rh * 0.78, cx + rw * 0.9, cy + rh * 0.02, sk)
    elif hair == "long":
        c.ell(cx - rw * 1.0, cy - rh * 1.08, cx + rw * 1.0, cy - rh * 0.05, hair_color)
        c.ell(cx - rw * 0.8, cy - rh * 0.8, cx + rw * 0.8, cy + rh * 0.0, sk)
        for s_ in (-1, 1):
            c.rect(cx + s_ * rw * 1.0 - (30 if s_ < 0 else 0), cy - rh * 0.4, cx + s_ * rw * 1.0 + (0 if s_ < 0 else 30), cy + rh * 1.2, hair_color, r=20)
    # face
    bc = brow_color or hair_color
    if face != "cool":
        draw_face(c, cx, cy, sc, rw, rh, face, sk, bc)
    # beard
    if beard == "mustache":
        c.ell(cx - rw * 0.45, cy + rh * 0.38, cx + rw * 0.45, cy + rh * 0.58, hair_color)
    elif beard == "big":
        c.ell(cx - rw * 0.55, cy + rh * 0.34, cx + rw * 0.55, cy + rh * 0.62, hair_color)
    elif beard in ("full", "saltpepper"):
        col = hair_color if beard == "full" else (190, 190, 195)
        c.ell(cx - rw * 0.98, cy + rh * 0.1, cx + rw * 0.98, cy + rh * 1.12, col)
        c.ell(cx - rw * 0.75, cy - rh * 0.05, cx + rw * 0.75, cy + rh * 0.78, sk)
        c.ell(cx - rw * 0.5, cy + rh * 0.33, cx + rw * 0.5, cy + rh * 0.55, col)
        if beard == "saltpepper":
            for i in range(30):
                rr = random.Random(i)
                c.circle(cx + rr.uniform(-rw * 0.8, rw * 0.8), cy + rr.uniform(rh * 0.6, rh * 1.0), 5, (70, 70, 75))
    elif beard == "stubble":
        for i in range(160):
            rr = random.Random(i)
            x = rr.uniform(-rw * 0.7, rw * 0.7)
            y = rr.uniform(rh * 0.35, rh * 0.95)
            if (x / (rw * 0.9)) ** 2 + (y / rh) ** 2 < 1:
                c.circle(cx + x, cy + y, 3, (70, 55, 50, 170))
    # face again for mouth on top of beard is handled in draw_face before beard; redraw mouth
    if beard:
        draw_mouth(c, cx, cy, sc, rw, rh, face, beard=True)
    if face == "cool":
        sunglasses(c, cx, cy - rh * 0.05, rw * 1.55)
        draw_mouth(c, cx, cy, sc, rw, rh, "smug", beard=bool(beard))
    if specs == "glasses":
        glasses(c, cx, cy - rh * 0.08, rw * 1.7)


def draw_mouth(c, cx, cy, sc, rw, rh, face, beard=False):
    y = cy + rh * 0.5
    ink = INK
    if face in ("shock", "scream"):
        c.ell(cx - rw * 0.2, y - rh * 0.08, cx + rw * 0.2, y + rh * 0.38, (90, 20, 30))
        c.ell(cx - rw * 0.12, y + rh * 0.16, cx + rw * 0.12, y + rh * 0.36, (230, 90, 100))
    elif face in ("smug", "sarcasm"):
        c.curve([(cx - rw * 0.3, y + rh * 0.08), (cx + rw * 0.05, y + rh * 0.2), (cx + rw * 0.35, y - rh * 0.05)], ink, 10 * sc)
    elif face in ("cry",):
        c.ell(cx - rw * 0.28, y, cx + rw * 0.28, y + rh * 0.3, (90, 20, 30))
        c.rect(cx - rw * 0.22, y + 2, cx + rw * 0.22, y + rh * 0.07, (255, 255, 255))
    elif face == "angry":
        c.rect(cx - rw * 0.32, y, cx + rw * 0.32, y + rh * 0.2, (255, 255, 255), r=10, outline=ink, width=7)
        for i in range(1, 5):
            c.line([(cx - rw * 0.32 + i * rw * 0.128, y), (cx - rw * 0.32 + i * rw * 0.128, y + rh * 0.2)], ink, 4)
    elif face in ("happy", "laugh", "party"):
        c.poly([(cx - rw * 0.4, y - rh * 0.02), (cx + rw * 0.4, y - rh * 0.02), (cx + rw * 0.28, y + rh * 0.3),
                (cx - rw * 0.28, y + rh * 0.3)], (90, 20, 30))
        c.ell(cx - rw * 0.4, y - rh * 0.1, cx + rw * 0.4, y + rh * 0.12, (255, 255, 255)) if False else None
        c.rect(cx - rw * 0.36, y - rh * 0.02, cx + rw * 0.36, y + rh * 0.08, (255, 255, 255))
        c.ell(cx - rw * 0.16, y + rh * 0.17, cx + rw * 0.16, y + rh * 0.32, (230, 90, 100))
    elif face in ("fake",):
        c.rect(cx - rw * 0.42, y, cx + rw * 0.42, y + rh * 0.2, (255, 255, 255), r=18, outline=ink, width=7)
        for i in range(1, 7):
            c.line([(cx - rw * 0.42 + i * rw * 0.12, y), (cx - rw * 0.42 + i * rw * 0.12, y + rh * 0.2)], ink, 3)
    elif face in ("confused", "blank", "dead", "sleepy"):
        c.line([(cx - rw * 0.25, y + rh * 0.12), (cx + rw * 0.25, y + rh * 0.12)], ink, 9 * sc)
    elif face == "wavy":
        c.curve([(cx - rw * 0.3, y + rh * 0.14), (cx - rw * 0.1, y + rh * 0.02), (cx + rw * 0.0, y + rh * 0.14)], ink, 9 * sc)
        c.curve([(cx, y + rh * 0.14), (cx + rw * 0.1, y + rh * 0.26), (cx + rw * 0.3, y + rh * 0.12)], ink, 9 * sc)
    elif face == "heart":
        c.curve([(cx - rw * 0.3, y), (cx, y + rh * 0.3), (cx + rw * 0.3, y)], ink, 10 * sc)
    elif face == "sad":
        c.curve([(cx - rw * 0.28, y + rh * 0.25), (cx, y + rh * 0.02), (cx + rw * 0.28, y + rh * 0.25)], ink, 10 * sc)


def eye(c, x, y, r, pupil=0.45, look=(0, 0), white=(255, 255, 255)):
    c.circle(x, y, r, white, outline=INK, width=5)
    c.circle(x + look[0] * r * 0.45, y + look[1] * r * 0.45, r * pupil, INK)
    c.circle(x + look[0] * r * 0.45 - r * 0.12, y + look[1] * r * 0.45 - r * 0.15, r * pupil * 0.28, (255, 255, 255))


def draw_face(c, cx, cy, sc, rw, rh, face, sk, bc):
    ex = rw * 0.42
    ey = cy - rh * 0.1
    r = 38 * sc
    brow_w = 10 * sc
    if face in ("shock", "scream"):
        for s_ in (-1, 1):
            eye(c, cx + s_ * ex, ey, r * 1.35, 0.22)
            c.curve([(cx + s_ * (ex + r * 1.2), ey - r * 2.2), (cx + s_ * ex, ey - r * 2.7), (cx + s_ * (ex - r * 1.2), ey - r * 2.2)], bc, brow_w)
    elif face in ("smug", "sarcasm"):
        for s_ in (-1, 1):
            eye(c, cx + s_ * ex, ey, r, 0.5, look=(0.8 if face == "sarcasm" else 0, 0))
            c.rect(cx + s_ * ex - r * 1.1, ey - r * 1.1, cx + s_ * ex + r * 1.1, ey - r * 0.1, sk)  # lid
            c.line([(cx + s_ * ex - r * 1.1, ey - r * 0.1), (cx + s_ * ex + r * 1.1, ey - r * 0.1)], INK, 7)
        c.curve([(cx - ex - r, ey - r * 1.7), (cx - ex, ey - r * 2.1), (cx - ex + r, ey - r * 1.6)], bc, brow_w)
        c.curve([(cx + ex - r, ey - r * 2.2), (cx + ex, ey - r * 2.9), (cx + ex + r, ey - r * 2.0)], bc, brow_w)
    elif face == "cry":
        for s_ in (-1, 1):
            c.curve([(cx + s_ * ex - r, ey), (cx + s_ * ex, ey + r * 0.5), (cx + s_ * ex + r, ey)], INK, 9 * sc)
            c.curve([(cx + s_ * (ex + r * 1.1), ey - r * 1.6), (cx + s_ * ex, ey - r * 2.0), (cx + s_ * (ex - r * 1.1), ey - r * 2.5)], bc, brow_w)
            for k in range(2):
                c.poly([(cx + s_ * ex + k * 18 - 10, ey + r * 0.4), (cx + s_ * ex + k * 18 + 10, ey + r * 0.4),
                        (cx + s_ * ex + k * 30, ey + r * 5.5)], (120, 200, 255, 220))
    elif face == "angry":
        for s_ in (-1, 1):
            eye(c, cx + s_ * ex, ey, r * 0.95, 0.5)
            c.line([(cx + s_ * (ex + r * 1.3), ey - r * 2.2), (cx + s_ * (ex - r * 1.2), ey - r * 1.1)], bc, brow_w * 1.3)
        for s_ in (-1, 1):
            c.circle(cx + s_ * rw * 0.62, cy + rh * 0.3, 34 * sc, (230, 70, 70, 120))
    elif face in ("happy", "laugh", "party"):
        for s_ in (-1, 1):
            c.curve([(cx + s_ * ex - r, ey + r * 0.3), (cx + s_ * ex, ey - r * 0.9), (cx + s_ * ex + r, ey + r * 0.3)], INK, 10 * sc)
            c.curve([(cx + s_ * (ex + r), ey - r * 1.7), (cx + s_ * ex, ey - r * 2.2), (cx + s_ * (ex - r), ey - r * 1.8)], bc, brow_w)
    elif face == "fake":
        for s_ in (-1, 1):
            eye(c, cx + s_ * ex, ey, r * 1.0, 0.3)
            c.curve([(cx + s_ * (ex + r), ey - r * 1.7), (cx + s_ * ex, ey - r * 2.0), (cx + s_ * (ex - r), ey - r * 1.6)], bc, brow_w)
    elif face in ("confused",):
        eye(c, cx - ex, ey, r * 1.1, 0.45, look=(0.5, -0.6))
        eye(c, cx + ex, ey, r * 0.9, 0.45, look=(0.5, -0.6))
        c.curve([(cx - ex - r, ey - r * 1.8), (cx - ex, ey - r * 2.1), (cx - ex + r, ey - r * 1.7)], bc, brow_w)
        c.curve([(cx + ex - r, ey - r * 2.3), (cx + ex, ey - r * 3.0), (cx + ex + r, ey - r * 2.1)], bc, brow_w)
    elif face in ("blank", "dead"):
        for s_ in (-1, 1):
            eye(c, cx + s_ * ex, ey, r * 0.95, 0.28)
            if face == "dead":
                c.curve([(cx + s_ * ex - r, ey + r * 1.4), (cx + s_ * ex, ey + r * 1.9), (cx + s_ * ex + r, ey + r * 1.4)], (120, 90, 100, 150), 9)
        c.line([(cx - ex - r, ey - r * 1.8), (cx - ex + r, ey - r * 1.8)], bc, brow_w)
        c.line([(cx + ex - r, ey - r * 1.8), (cx + ex + r, ey - r * 1.8)], bc, brow_w)
    elif face == "sleepy":
        for s_ in (-1, 1):
            c.curve([(cx + s_ * ex - r, ey), (cx + s_ * ex, ey + r * 0.7), (cx + s_ * ex + r, ey)], INK, 9 * sc)
            c.line([(cx + s_ * ex - r, ey - r * 1.8), (cx + s_ * ex + r, ey - r * 1.7)], bc, brow_w)
    elif face == "heart":
        for s_ in (-1, 1):
            heart(c, cx + s_ * ex, ey, r * 2.0, (233, 30, 99))
            c.curve([(cx + s_ * (ex + r), ey - r * 1.9), (cx + s_ * ex, ey - r * 2.4), (cx + s_ * (ex - r), ey - r * 2.0)], bc, brow_w)
    elif face == "sad":
        for s_ in (-1, 1):
            eye(c, cx + s_ * ex, ey, r, 0.5, look=(0, 0.6))
            c.curve([(cx + s_ * (ex + r * 1.1), ey - r * 1.6), (cx + s_ * ex, ey - r * 2.0), (cx + s_ * (ex - r * 1.1), ey - r * 2.6)], bc, brow_w)
    # nose
    c.curve([(cx - 18 * sc, cy + rh * 0.12), (cx - 30 * sc, cy + rh * 0.3), (cx + 6 * sc, cy + rh * 0.32)], shade(sk, 0.7), 8 * sc)
    draw_mouth(c, cx, cy, sc, rw, rh, face)


def hand(c, x, y, r, skin="tan"):
    c.circle(x, y, r, SKIN[skin], outline=shade(SKIN[skin], 0.7), width=4)
    for i in range(4):
        c.ell(x - r * 0.9 + i * r * 0.5, y - r * 1.25, x - r * 0.5 + i * r * 0.5, y - r * 0.35, SKIN[skin], outline=shade(SKIN[skin], 0.7), width=3)


def thumbs_up(c, x, y, r, skin="tan"):
    """Closed fist with the thumb pointing up."""
    sk, ol = SKIN[skin], shade(SKIN[skin], 0.7)
    c.rect(x - r, y, x + r, y + r * 1.5, sk, r=r * 0.35, outline=ol, width=4)  # fist
    c.rect(x - r * 0.95, y - r * 1.25, x - r * 0.1, y + r * 0.2, sk, r=r * 0.38, outline=ol, width=4)  # thumb
    for i in range(1, 4):  # finger separations
        c.line([(x - r * 0.05 + 0.0, y + r * 0.5 * i / 1.5 + 0.0), (x + r * 0.9, y + r * 0.5 * i / 1.5)], ol, 4)


def arm(c, x1, y1, x2, y2, shirt, w=70):
    c.line([(x1, y1), (x2, y2)], shirt, w)
    c.circle(x1, y1, w / 2, shirt)


def speed_lines(c, x, y, n, length, col=(255, 255, 255, 120)):
    for i in range(n):
        yy = y + i * 48
        c.line([(x, yy), (x + length - (i % 2) * 60, yy)], col, 10)


# ---------------------------------------------------------------- templates
def tm001():  # confused
    c = Canvas(hexc("#00796B"), hexc("#004D40"), "dots")
    person(c, 540, 520, 1.25, "tan", "tufts", (60, 40, 30), (60, 120, 190), "confused", beard="mustache")
    for i, (x, y, s) in enumerate([(210, 220, 150), (860, 260, 200), (780, 120, 110), (150, 420, 100)]):
        question(c, x, y, s)
    c.save("tm001.png")


def tm002():  # crying
    c = Canvas(hexc("#1565C0"), hexc("#0D47A1"), "stripes")
    person(c, 540, 540, 1.25, "tan", "tufts", (60, 40, 30), (240, 240, 240), "cry", beard="mustache")
    c.save("tm002.png")


def tm003():  # angry
    c = Canvas(hexc("#C62828"), hexc("#6A1B1A"), "rays")
    person(c, 540, 540, 1.25, "tan", "tufts", (60, 40, 30), (255, 193, 7), "angry", beard="mustache")
    arm(c, 190, 900, 320, 780, (255, 193, 7))
    hand(c, 330, 760, 52)
    for i in range(3):
        c.line([(120 + i * 30, 270 + i * 40), (210 + i * 30, 330 + i * 40)], (255, 255, 255, 220), 14)
    c.save("tm003.png")


def tm004():  # sarcasm
    c = Canvas(hexc("#F9A825"), hexc("#F57F17"), "dots")
    person(c, 540, 540, 1.25, "tan", "short", (50, 40, 40), (120, 144, 156), "sarcasm", specs="glasses", beard="stubble")
    c.save("tm004.png")


def tm005():  # goundamani-style reaction (round face, hands on cheeks)
    c = Canvas(hexc("#6A1B9A"), hexc("#311B92"), "confetti")
    person(c, 540, 540, 1.2, "brown", "tufts", (40, 30, 30), (255, 112, 67), "shock", beard=None, width=1.12)
    for s_ in (-1, 1):
        arm(c, 540 + s_ * 360, 930, 540 + s_ * 235, 600, (255, 112, 67), 64)
        hand(c, 540 + s_ * 225, 590, 46, "brown")
    c.save("tm005.png")


def tm006():  # senthil-style shock (jaw drop, wild hair)
    c = Canvas(hexc("#EF6C00"), hexc("#BF360C"), "rays")
    person(c, 540, 560, 1.15, "dark", "wild", (25, 20, 20), (38, 166, 154), "scream", width=0.9)
    sweat(c, 280, 280, 40)
    sweat(c, 800, 330, 50)
    for i in range(4):
        c.line([(110 + i * 20, 160), (190 + i * 20, 90)], (255, 255, 255, 200), 12)
    c.save("tm006.png")


def tm007():  # no cash, cheque
    c = Canvas(hexc("#2E7D32"), hexc("#1B5E20"), "dots")
    person(c, 400, 480, 1.05, "light", "quiff", (40, 30, 30), (255, 255, 255), "smug", beard="stubble")
    # empty wallet
    c.rect(600, 640, 960, 880, (121, 85, 72), r=26)
    c.rect(600, 640, 960, 740, (93, 64, 55), r=26)
    c.circle(930, 760, 18, (255, 213, 79))
    # cheque
    paper(c, 640, 380, 330, 190)
    c.rect(660, 400, 760, 420, (90, 90, 90))
    c.ell(840, 480, 940, 550, (255, 255, 255, 0), outline=(120, 120, 120), width=4)
    c.save("tm007.png")


def tm008():  # mass walk
    c = Canvas(hexc("#0D1B4A"), hexc("#000000"), "rays")
    speed_lines(c, 60, 330, 8, 300)
    person(c, 600, 480, 1.2, "tan", "quiff", (20, 15, 15), (30, 30, 36), "cool", beard="stubble")
    star(c, 190, 150, 60, (255, 235, 59))
    star(c, 900, 190, 40, (255, 235, 59))
    star(c, 850, 880, 55, (255, 235, 59))
    c.save("tm008.png")


def tm009():  # plan successful
    c = Canvas(hexc("#212121"), hexc("#000000"), "rays")
    person(c, 520, 500, 1.2, "light", "short", (190, 190, 195), (20, 20, 25), "cool", beard="saltpepper")
    arm(c, 900, 1000, 820, 800, (20, 20, 25), 80)
    thumbs_up(c, 820, 740, 60, "light")
    for x, y, s in [(170, 210, 56), (930, 250, 44), (130, 840, 40)]:
        star(c, x, y, s, (255, 202, 40))
    c.save("tm009.png")


def tm010():  # style
    c = Canvas(hexc("#B71C1C"), hexc("#7F0000"), "rays")
    person(c, 540, 560, 1.2, "brown", "wild", (30, 30, 30), (255, 255, 255), "smug", beard="mustache")
    # sunglasses flying
    c.circle(0, 0, 0, (0, 0, 0, 0))
    sunglasses(c, 840, 190, 230, tilt=-30)
    for x, y, s in [(700, 120, 40), (990, 280, 36), (940, 100, 30)]:
        star(c, x, y, s, (255, 235, 59))
    c.save("tm010.png")


def tm011():  # VIP experience
    c = Canvas(hexc("#455A64"), hexc("#263238"), "grid" and "dots")
    person(c, 540, 520, 1.2, "tan", "short", (30, 30, 30), (38, 50, 56), "smug", beard="full")
    arm(c, 220, 1000, 430, 860, (38, 50, 56), 90)
    arm(c, 860, 1000, 650, 860, (38, 50, 56), 90)
    c.rect(400, 820, 680, 900, (38, 50, 56), r=30)
    c.save("tm011.png")


def tm012():  # expression
    c = Canvas(hexc("#8D6E63"), hexc("#4E342E"), "stripes")
    person(c, 540, 520, 1.3, "brown", "curly", (35, 25, 25), (96, 125, 139), "confused", beard="full")
    c.text(190, 230, "?", 140, (255, 255, 255, 230))
    c.text(880, 210, "!", 150, (255, 235, 59, 230))
    c.save("tm012.png")


def tm013():  # love failure: seen, no reply
    c = Canvas(hexc("#37474F"), hexc("#12202A"))
    # rain
    r = random.Random(3)
    for _ in range(60):
        x, y = r.randint(0, W), r.randint(0, W)
        c.line([(x, y), (x - 14, y + 44)], (180, 200, 220, 130), 5)
    person(c, 400, 560, 1.05, "tan", "short", (30, 25, 25), (96, 125, 139), "sad", beard="stubble")
    phone(c, 640, 520, 250, 440)
    c.rect(670, 600, 860, 650, (255, 255, 255, 230), r=22)
    c.rect(670, 680, 800, 730, (30, 136, 229), r=22)
    for dx in (0, 22):  # blue "seen" ticks
        c.line([(790 + dx, 705), (802 + dx, 718), (826 + dx, 690)], (79, 195, 247), 7)
    broken_heart(c, 850, 280, 150)
    c.save("tm013.png")


def tm014():  # friendship gang: plan cancelled
    c = Canvas(hexc("#7B1FA2"), hexc("#4A148C"), "confetti")
    spec = [(220, "tan", "short", (255, 112, 67), "sad", None), (540, "brown", "curly", (38, 166, 154), "blank", "stubble"),
            (860, "light", "quiff", (66, 165, 245), "cry", None)]
    for x, sk, hr, sh, f, b in spec:
        person(c, x, 560, 0.7, sk, hr, (35, 25, 25), sh, f, beard=b)
    c.rect(60, 900, 1020, 980, (93, 64, 55), r=26)
    c.save("tm014.png")


def tm015():  # college: question paper shock
    c = Canvas(hexc("#00838F"), hexc("#006064"), "dots")
    person(c, 540, 470, 1.1, "tan", "curly", (30, 25, 25), (255, 241, 118), "scream", width=0.95)
    paper(c, 330, 800, 420, 250)
    sweat(c, 270, 300, 46)
    sweat(c, 840, 330, 54)
    c.save("tm015.png")


def tm016():  # office friday evening
    c = Canvas(hexc("#546E7A"), hexc("#263238"))
    c.ell(700, 60, 940, 300, (255, 255, 255), outline=(40, 40, 40), width=10)  # clock
    c.line([(820, 180), (820, 90)], (40, 40, 40), 10)
    c.line([(820, 180), (890, 215)], (40, 40, 40), 10)
    c.rect(100, 780, 980, 1040, (120, 90, 70), r=20)
    person(c, 400, 500, 1.1, "brown", "short", (25, 20, 20), (255, 255, 255), "dead", specs="glasses", beard=None)
    c.rect(520, 700, 940, 860, (60, 70, 80), r=18)  # laptop
    c.rect(545, 722, 915, 840, (30, 136, 229), r=8)
    sweat(c, 660, 250, 46)
    c.save("tm016.png")


def tm017():  # salary day: two panels
    c = Canvas(hexc("#FFD54F"), hexc("#FFB300"))
    c.rect(0, 540, W, W, hexc("#546E7A"))
    c.rect(0, 535, W, 548, (255, 255, 255))
    # top: king
    c.poly([(430, 150), (460, 70), (500, 120), (540, 50), (580, 120), (620, 70), (650, 150)], (255, 193, 7), outline=(180, 120, 0))
    person(c, 540, 300, 0.62, "tan", "short", (30, 25, 25), (156, 39, 176), "happy", beard="mustache")
    for x, y in [(130, 120), (900, 130), (160, 380), (930, 400)]:
        c.rect(x, y, x + 120, y + 64, (102, 187, 106), r=8)
        c.circle(x + 60, y + 32, 16, (56, 142, 60))
    # bottom: beggar
    person(c, 540, 800, 0.62, "tan", "tufts", (30, 25, 25), (120, 100, 90), "dead", beard="stubble")
    c.rect(780, 860, 960, 1000, (121, 85, 72), r=18)
    c.circle(790, 900, 12, (255, 213, 79, 0))
    c.save("tm017.png")


def tm018():  # sleeping
    c = Canvas(hexc("#1A237E"), hexc("#0D1442"))
    for x, y, s in [(150, 150, 40), (900, 220, 30), (700, 100, 24)]:
        star(c, x, y, s, (255, 235, 59, 200))
    c.circle(890, 160, 80, (255, 249, 196))
    c.circle(920, 140, 70, hexc("#1A237E"))
    c.rect(40, 640, 1040, 1040, (92, 107, 192), r=40)  # bed
    c.rect(80, 600, 520, 760, (255, 255, 255), r=60)  # pillow
    person(c, 330, 560, 0.85, "tan", "tufts", (40, 30, 30), (255, 255, 255), "sleepy", beard="mustache", collar=False)
    c.rect(300, 700, 1040, 1040, (63, 81, 181), r=40)  # blanket
    zzz(c, 600, 480, 55)
    c.save("tm018.png")


def tm019():  # street interview prank
    c = Canvas(hexc("#37474F"), hexc("#546E7A"), "stripes")
    c.rect(0, 800, W, W, hexc("#455A64"))
    person(c, 300, 500, 0.95, "brown", "quiff", (25, 20, 20), (255, 82, 82), "smug", beard="stubble")
    person(c, 790, 500, 0.95, "tan", "short", (35, 25, 25), (255, 255, 255), "confused", specs="glasses")
    arm(c, 380, 1000, 560, 800, (255, 82, 82), 70)
    hand(c, 580, 780, 44, "brown")
    c.rect(560, 560, 600, 760, (40, 40, 44), r=16)
    c.circle(580, 540, 44, (60, 60, 66))
    for x, y, s in [(900, 160, 130), (700, 120, 90)]:
        question(c, x, y, s)
    c.save("tm019.png")


def tm020():  # weekend celebration
    c = Canvas(hexc("#EC407A"), hexc("#8E24AA"), "confetti", seed=5)
    person(c, 540, 580, 1.2, "tan", "short", (30, 25, 25), (255, 235, 59), "party", beard=None)
    c.poly([(440, 230), (540, 20), (640, 230)], (0, 229, 255), outline=(255, 255, 255))
    c.circle(540, 20, 24, (255, 235, 59))
    for s_ in (-1, 1):
        arm(c, 540 + s_ * 400, 1000, 540 + s_ * 390, 540, (255, 235, 59), 80)
        hand(c, 540 + s_ * 392, 480, 54, "tan")
    c.save("tm020.png")


def main():
    os.makedirs(OUT, exist_ok=True)
    for i in range(1, 21):
        globals()[f"tm{i:03d}"]()
    print("done")


if __name__ == "__main__":
    main()
