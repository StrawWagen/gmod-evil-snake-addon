import math
import os

from PIL import Image, ImageDraw, ImageFilter

SIZE = 128
INK = (226, 219, 207)
BG_IN = (42, 38, 41)
BG_OUT = (12, 11, 12)
BOX = (112, 84)
FLOOR = 104
CEILING = 24

SS = 8
W, H = 170, 130
GROUND = 120
PITCH = 0.4
COIL_X = 70
COIL_R = (26, 19)
TURNS = 1.75
R_BODY = 6.4
R_NECK = 5.0
R_TAIL = 0.8
TAIL_SWEEP = 3.4
TAIL_OUT = 9
GAP = 1.5
RISE = 0.9
NECK = [(0, 0), (6, -14), (-2, -28), (4, -40), (16, -46)]
HEAD_TURN = -0.18
HEAD = 1.15
OUT = os.path.join(os.path.dirname(__file__), "..", "materials", "entities", "evil_snake.png")
PREVIEW = os.path.join(os.path.dirname(__file__), "..", "renders", "spawnicon_preview.png")


def layer(w=W, h=H):
    im = Image.new("L", (w * SS, h * SS), 0)
    return im, ImageDraw.Draw(im)


def dot(draw, x, y, r, fill=255):
    draw.ellipse(((x - r) * SS, (y - r) * SS, (x + r) * SS, (y + r) * SS), fill=fill)


def stroke(draw, points, r0, r1, fill=255):
    total = sum(math.dist(a, b) for a, b in zip(points, points[1:])) or 1
    run = 0
    for a, b in zip(points, points[1:]):
        seg = math.dist(a, b)
        n = max(1, int(seg * 4))
        for i in range(n + 1):
            f = (run + seg * i / n) / total
            dot(draw, a[0] + (b[0] - a[0]) * i / n, a[1] + (b[1] - a[1]) * i / n, r0 + (r1 - r0) * f, fill)
        run += seg


def tube(draw, samples, gap=0, trim=0):
    if gap:
        for x, y, r in samples[trim:len(samples) - trim]:
            dot(draw, x, y, r + gap, 0)
    for x, y, r in samples:
        dot(draw, x, y, r)


def spline(points, closed=False, n=8):
    pts = points[-1:] + points + points[:2] if closed else points[:1] + points + points[-1:]
    out = []
    for i in range(1, len(pts) - 2):
        p0, p1, p2, p3 = pts[i - 1:i + 3]
        for s in range(n):
            t = s / n
            out.append(tuple(0.5 * (2 * p1[k] + (p2[k] - p0[k]) * t + (2 * p0[k] - 5 * p1[k] + 4 * p2[k] - p3[k]) * t * t
                                    + (3 * p1[k] - p0[k] - 3 * p2[k] + p3[k]) * t ** 3) for k in (0, 1)))
    return out if closed else out + [points[-1]]


UPPER = [(-5, -2), (-3, -6.5), (3, -8), (11, -7.4), (18, -5.4), (22, -3.2), (21.4, -1.6), (12, -0.6), (3, 1.5)]
LOWER = [(-4, 1), (2, 2.4), (10, 5.6), (17.5, 9.6), (17, 11), (8, 10), (0, 8), (-4, 5)]
EYE = (9.5, -4.4, 1.35)
TONGUE = [(8, 3.2), (16, 6), (24, 7), (29, 6.4)]
FORK = [((29, 6.4), (33, 3.6)), ((29, 6.4), (33.4, 9))]


def place(points, at, angle, scale):
    c, s = math.cos(angle), math.sin(angle)
    return [(at[0] + (x * c - y * s) * scale, at[1] + (x * s + y * c) * scale) for x, y in points]


def head(draw, at, angle, scale=1.0, eye=True):
    stroke(draw, spline(place(TONGUE, at, angle, scale)), 0.95 * scale, 0.8 * scale)
    for a, b in FORK:
        stroke(draw, place([a, b], at, angle, scale), 0.8 * scale, 0.45 * scale)
    for shape in (LOWER, UPPER):
        draw.polygon([(x * SS, y * SS) for x, y in spline(place(shape, at, angle, scale), closed=True)], fill=255)
    if eye:
        (ex, ey), = place([EYE[:2]], at, angle, scale)
        dot(draw, ex, ey, EYE[2] * scale, 0)


def coil():
    turn = math.pi * 2
    start = math.pi
    end = start + turn * TURNS
    ring = lambda t: COIL_R[0] + (COIL_R[1] - COIL_R[0]) * (t - start) / (end - start)
    rise = lambda t: (t - start) / turn * R_BODY * 2 * RISE
    point = lambda t: (COIL_X + ring(t) * math.cos(t), GROUND - R_BODY - rise(t) + ring(t) * math.sin(t) * PITCH)
    runs, run, front = [], [], None
    steps = 400
    for i in range(steps + 1):
        t = start + (end - start) * i / steps
        x, y = point(t)
        f = math.sin(t) > 0
        if front is not None and f != front:
            runs.append((front, run))
            run = [run[-1]]
        front = f
        run.append((x, y, R_BODY))
    runs.append((front, run))
    tail = []
    for i in range(121):
        f = i / 120
        t = start - TAIL_SWEEP * (1 - f)
        rr = ring(start) + TAIL_OUT * (1 - f)
        r = R_TAIL + (R_BODY - R_TAIL) * f ** 0.7
        tail.append((COIL_X + rr * math.cos(t), GROUND - r + rr * math.sin(t) * PITCH, r))
    return runs, tail, point(end)


def creature():
    im, draw = layer()
    runs, tail, top = coil()
    backs = [r for f, r in runs if not f]
    fronts = [r for f, r in runs if f]
    for r in backs:
        tube(draw, r)
    for r in fronts:
        tube(draw, r, GAP, 6)
    tube(draw, tail, GAP, 6)
    neck = spline([(top[0] + x, top[1] + y) for x, y in NECK])
    samples = [(x, y, R_BODY + (R_NECK - R_BODY) * min(1, i / (len(neck) * 0.6))) for i, (x, y) in enumerate(neck)]
    tube(draw, samples, GAP, 6)
    (ax, ay), (bx, by) = neck[-2], neck[-1]
    angle = math.atan2(by - ay, bx - ax) + HEAD_TURN
    head(draw, (bx, by), angle, HEAD)
    return im


def tile(alpha, hanging=False):
    alpha = alpha.crop(alpha.getbbox())
    k = min(BOX[0] / alpha.width, BOX[1] / alpha.height)
    alpha = alpha.resize((max(1, round(alpha.width * k)), max(1, round(alpha.height * k))), Image.LANCZOS)
    if hanging:
        alpha = alpha.transpose(Image.FLIP_TOP_BOTTOM)
    y = CEILING if hanging else FLOOR - alpha.height
    bg = Image.new("RGB", (SIZE, SIZE))
    px = bg.load()
    for j in range(SIZE):
        for i in range(SIZE):
            t = min(1, math.hypot(i - SIZE / 2, j - SIZE / 2) / (SIZE * 0.72)) ** 2
            px[i, j] = tuple(round(a + (b - a) * t) for a, b in zip(BG_IN, BG_OUT))
    bg.paste(Image.new("RGB", alpha.size, INK), ((SIZE - alpha.width) // 2, y), alpha)
    return bg


if __name__ == "__main__":
    icon = tile(creature().resize((W * 2, H * 2), Image.LANCZOS).filter(ImageFilter.GaussianBlur(0.3)))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    icon.save(OUT, optimize=True)
    print("materials/entities/evil_snake.png  %dx%d" % icon.size)
    os.makedirs(os.path.dirname(PREVIEW), exist_ok=True)
    icon.resize((SIZE * 3, SIZE * 3), Image.LANCZOS).save(PREVIEW)
