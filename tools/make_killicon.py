import math
import os

from PIL import Image

from make_spawnicon import SS, head, layer, spline, tube

HEIGHT = 48
W, H = 150, 100
BODY = [(6, 86), (22, 89), (38, 84), (45, 72), (39, 60), (44, 49), (56, 44)]
R_TAIL = 1.0
R_BODY = 6.0
R_NECK = 5.0
HEAD = 1.9
HEAD_TURN = -0.05
OUT = os.path.join(os.path.dirname(__file__), "..", "materials", "killicons", "evil_snake.png")
PREVIEW = os.path.join(os.path.dirname(__file__), "..", "renders", "killicon_preview.png")


def radius(f):
    if f < 0.45:
        return R_TAIL + (R_BODY - R_TAIL) * (f / 0.45) ** 0.7
    return R_BODY + (R_NECK - R_BODY) * (f - 0.45) / 0.55


im, draw = layer(W, H)
body = spline(BODY, n=16)
tube(draw, [(x, y, radius(i / (len(body) - 1))) for i, (x, y) in enumerate(body)])
(ax, ay), (bx, by) = body[-2], body[-1]
head(draw, (bx, by), math.atan2(by - ay, bx - ax) + HEAD_TURN, HEAD)
alpha = im.resize((W * 2, H * 2), Image.LANCZOS)
alpha = alpha.crop(alpha.getbbox())
alpha = alpha.resize((round(alpha.width * HEIGHT / alpha.height), HEIGHT), Image.LANCZOS)
icon = Image.new("RGBA", alpha.size, (255, 255, 255, 0))
icon.putalpha(alpha)
os.makedirs(os.path.dirname(OUT), exist_ok=True)
icon.save(OUT, optimize=True)
print("materials/killicons/evil_snake.png  %dx%d" % icon.size)

os.makedirs(os.path.dirname(PREVIEW), exist_ok=True)
tint = Image.new("RGBA", icon.size, (170, 210, 80, 255))
tint.putalpha(alpha)
bg = Image.new("RGBA", (icon.width + 16, icon.height + 16), (24, 24, 24, 255))
bg.alpha_composite(tint, (8, 8))
big = bg.resize((bg.width * 5, bg.height * 5), Image.NEAREST)
sheet = Image.new("RGBA", (big.width, big.height + bg.height + 8), (24, 24, 24, 255))
sheet.alpha_composite(big)
sheet.alpha_composite(bg, (0, big.height + 4))
sheet.save(PREVIEW)
