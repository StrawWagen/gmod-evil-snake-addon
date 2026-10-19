# /// script
# dependencies = ["numpy", "pillow"]
# ///
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "materials", "evil_snake", "skin.png")
PREVIEW = os.path.join(ROOT, "renders", "skin_preview.png")
W, H = 256, 512
SEED = 13

HIDE = np.array([226, 218, 222])
CREASE = np.array([128, 106, 116])
CREST = np.array([250, 246, 238])
VEIN = np.array([58, 30, 52])
PORE = np.array([34, 12, 18])
PORE_RIM = np.array([200, 160, 160])
TINT = np.array([60, 52, 58])

rng = np.random.default_rng(SEED)
fy = np.fft.fftfreq(H)[:, None] * H
fx = np.fft.fftfreq(W)[None, :] * W


def band(across, along, falloff=2.0):
    k = np.sqrt((fx / across) ** 2 + (fy / along) ** 2)
    spectrum = np.exp(-(k ** falloff))
    spectrum[0, 0] = 0
    noise = np.fft.fft2(rng.standard_normal((H, W)))
    field = np.real(np.fft.ifft2(noise * spectrum))
    return field / field.std()


def sample(field, x, y):
    x0, y0 = np.floor(x).astype(int), np.floor(y).astype(int)
    tx, ty = x - x0, y - y0
    x0, y0 = x0 % W, y0 % H
    x1, y1 = (x0 + 1) % W, (y0 + 1) % H
    top = field[y0, x0] * (1 - tx) + field[y0, x1] * tx
    bottom = field[y1, x0] * (1 - tx) + field[y1, x1] * tx
    return top * (1 - ty) + bottom * ty


def warp(field, amount, across, along):
    yy, xx = np.mgrid[0:H, 0:W].astype(float)
    return sample(field, xx + band(across, along) * amount, yy + band(across, along) * amount)


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


mottle = band(3, 4) * 0.6 + band(10, 12) * 0.4
folds = warp(band(2, 18, 1.4), 10, 4, 4)
wrinkles = warp(band(3, 70, 1.2), 2, 8, 6)
veins = warp(band(5, 4), 6, 6, 5)
twigs = warp(band(14, 12), 3, 14, 12)
pores = band(40, 80)
clusters = band(3, 5)

fold = np.sin(folds * 2.2)
crease = smooth(0.55, 1.0, -fold)
crest = smooth(0.4, 1.0, fold) * 0.5
wrinkle = smooth(0.6, 1.6, np.abs(wrinkles)) * 0.35
vein = np.exp(-(veins / 0.06) ** 2) * smooth(-0.6, 0.6, band(2, 2))
twig = np.exp(-(twigs / 0.05) ** 2) * smooth(-0.2, 1.0, band(4, 4)) * 0.55
vein = np.clip(vein + twig, 0, 1)
cluster = smooth(0.4, 1.4, clusters)
pore = smooth(1.7, 2.3, pores) * cluster
pore_rim = np.clip(smooth(1.2, 1.7, pores) * cluster - pore, 0, 1) * 0.6
blotch = smooth(0.0, 1.8, mottle) * 0.3

col = HIDE[None, None, :] * (1 - blotch[..., None] * 0.5)
col = col * (1 - wrinkle[..., None]) + CREASE * wrinkle[..., None]
col = col * (1 - crest[..., None]) + CREST * crest[..., None]
col = col * (1 - crease[..., None] * 0.7) + CREASE * crease[..., None] * 0.7
col = col * (1 - vein[..., None] * 0.85) + VEIN * vein[..., None] * 0.85
col = col * (1 - pore_rim[..., None]) + PORE_RIM * pore_rim[..., None]
col = col * (1 - pore[..., None]) + PORE * pore[..., None]
col = np.clip(col, 0, 255).astype(np.uint8)

os.makedirs(os.path.dirname(OUT), exist_ok=True)
Image.fromarray(col, "RGB").save(OUT, optimize=True)

os.makedirs(os.path.dirname(PREVIEW), exist_ok=True)
tinted = np.clip(col.astype(float) * TINT / 255 * 2.6, 0, 255).astype(np.uint8)
tiled = np.vstack([np.hstack([tinted] * 2)] * 2)
Image.fromarray(np.hstack([np.vstack([col] * 2), tiled]), "RGB").save(PREVIEW)
print(OUT, col.reshape(-1, 3).mean(0).round(1))
