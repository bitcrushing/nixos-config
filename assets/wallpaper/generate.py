"""Twilight lake wallpaper, generated from the stylix palette.

usage: generate.py WIDTH HEIGHT OUT_DIR TEXTURE base00 .. base0F
  TEXTURE: none | paint | crush | paintcrush
Writes OUT_DIR/full.png and one crop per 1920px-wide monitor, left to right
(OUT_DIR/0.png, 1.png, ...). Deterministic: fixed seeds, same input -> same image.

Colours are picked by hue for Rosé Pine (08 love, 09 gold, 0A rose, 0B pine,
0C foam, 0D iris), so another scheme will work but may need re-slotting.
"""
import os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

W, H, OUT, TEXTURE = int(sys.argv[1]), int(sys.argv[2]), sys.argv[3], sys.argv[4]
pal = [np.array([int(h[j:j + 2], 16) for j in (0, 2, 4)], float) / 255 for h in sys.argv[5:21]]
bg, surface, overlay, muted, subtle, text = pal[0], pal[1], pal[2], pal[3], pal[4], pal[5]
love, gold, rose, pine, foam, iris = pal[8], pal[9], pal[0xA], pal[0xB], pal[0xC], pal[0xD]
rng = np.random.default_rng(1983)
A = W / H
WATER = 0.70  # waterline, as a fraction of height
SUN_X = 0.56 * A  # centre of the horizon glow: near the monitor seam, between the peak and the right screen
PEAK_X = 0.24 * A  # the main mountain
MOON = (0.12 * A, 0.17)  # thin crescent high on the left, balancing the sunset on the right


# ---------------------------------------------------------------- scene

def mix(a, b, t): t = np.asarray(t, float); return a * (1 - t[..., None]) + b * t[..., None]
def smooth(e0, e1, t): t = np.clip((t - e0) / (e1 - e0), 0, 1); return t * t * (3 - 2 * t)
def noise1d(s, octaves=6, base=1.0, seed=0):
    r = np.random.default_rng(seed); f = np.zeros_like(s); amp = 1.0; freq = base; norm = 0
    for _ in range(octaves):
        f += amp * np.sin(s * freq * 2 * np.pi + r.uniform(0, 2 * np.pi)); norm += amp
        amp *= 0.5; freq *= 2.1
    return f / norm

SKY, LAKE, SHORE = 0, 6, 7  # region ids; mountain layers are 1..5 (far to near)

def scene(Hs):
    """Sky + mountains above the waterline, Hs rows tall.
    Returns the image, a region map and the local brush-stroke angle (radians)."""
    y, x = np.mgrid[0:Hs, 0:W].astype(float)
    u, v = x / H, y / H  # v in the same units as the full image
    s = u[0]
    # Sky: night at the top -> iris -> rose -> gold at the horizon, glow centred on the right screen
    sun_x = SUN_X
    glow = np.exp(-((u - sun_x) / 0.95) ** 2)
    t = smooth(0.0, WATER, v)
    sky = mix(bg * 0.70, mix(bg, iris * 0.55 + bg * 0.45, glow * 0.8), smooth(0.05, 0.45, t))
    sky = mix(sky, rose * 0.85 + bg * 0.15, smooth(0.55, 0.92, t) * (0.35 + 0.65 * glow))
    sky = mix(sky, gold, smooth(0.86, 1.0, t) * glow ** 2 * 0.85)
    # A few thin, lit cloud streaks
    for i, (cy, th, st) in enumerate([(0.30, 0.010, 0.35), (0.38, 0.007, 0.30), (0.46, 0.012, 0.25)]):
        yy = cy + 0.015 * noise1d(s * 0.4, 3, 0.5, seed=40 + i)
        band = np.exp(-((v - yy[None, :]) / th) ** 2) * smooth(-0.2, 0.6, noise1d(s * 0.9, 4, 0.6, seed=50 + i))[None, :]
        sky = mix(sky, rose * 0.7 + gold * 0.3, band * st * (0.3 + 0.7 * glow))
    # faint cool halo around the moon (the crescent itself is drawn after texturing)
    md = np.hypot(u - MOON[0], v - MOON[1])
    sky = sky + (np.exp(-(md / 0.16) ** 2) * 0.07)[..., None] * foam
    img = sky
    region = np.full((Hs, W), SKY, np.int16)
    angle = 0.05 * noise1d(s * 2, 3, 1.0, seed=60)[None, :] * np.ones((Hs, 1))  # sky: loose, near-horizontal
    # Mountains: far (hazy, warm-lit) to near (dark); main peak on the left screen
    layers = 5
    for i in range(layers):
        t = i / (layers - 1)
        horizon = WATER - 0.10 + 0.095 * t  # far ridges high, nearest one a thin far shore
        amp = 0.20 - 0.175 * t
        peak = np.exp(-((s - PEAK_X) / 0.45) ** 2) * (0.20 if i == 1 else 0.06 * (1 - t))
        prof = horizon - amp * (0.5 + 0.5 * noise1d(s * 0.55, 6, 0.6, seed=100 + i)) - peak
        mask = v >= prof[None, :]
        warm = np.exp(-((s - sun_x) / 0.9) ** 2)[:, None] * 0.6  # (W, 1)
        far = (iris * 0.45 + bg * 0.55)[None] * (1 - warm) + (rose * 0.35 + bg * 0.65)[None] * warm  # (W, 3)
        near = overlay * 0.3 + bg * 0.42
        k = t ** 0.7
        col = far * (1 - k) + near[None] * k
        # Haze collecting at the base of each far layer, so the next (darker)
        # ridge in front stands out against a lighter band.
        haze_col = (rose * 0.45 + iris * 0.25 + bg * 0.30)[None] * warm + (iris * 0.35 + bg * 0.65)[None] * (1 - warm)
        haze = smooth(0.0, 0.11, v - prof[None, :]) * 0.42 * (1 - t) ** 1.5
        layer = col[None] * (1 - haze[..., None]) + haze_col[None] * haze[..., None]
        img = np.where(mask[..., None], layer, img)
        region[mask] = i + 1
        # Strokes follow the ridge near the crest and relax to horizontal lower down
        slope = np.arctan(np.gradient(prof, s))
        follow = np.exp(-np.clip(v - prof[None, :], 0, None) / 0.07)
        angle = np.where(mask, slope[None, :] * follow, angle)
        rim = np.exp(-((v - prof[None, :]) / 0.0022) ** 2) * (1 - t) * 0.28 * glow
        img = img + rim[..., None] * gold
    return img, region, angle

top_rows = int(H * WATER)
above, region_above, angle_above = scene(top_rows)
# Lake: mirror of the scene, darker, with horizontal ripple distortion and softening
below_rows = H - top_rows
mirror = above[::-1][:below_rows].copy()
yy = np.arange(below_rows)
shift = (6 * noise1d(yy / 40.0, 4, 1.0, seed=7) * (1 + yy / below_rows * 2)).astype(int)
for r in range(below_rows):
    mirror[r] = np.roll(mirror[r], shift[r], axis=0)
m = Image.fromarray((np.clip(mirror, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(2.5))
mirror = np.asarray(m).astype(float) / 255
depth = smooth(0.0, 1.0, yy / below_rows)[:, None, None]
lake = mirror * (0.62 - 0.30 * depth) + bg * 0.35 * depth
img = np.concatenate([above, lake], axis=0)
region = np.concatenate([region_above, np.full((below_rows, W), LAKE, np.int16)], axis=0)
angle = np.concatenate([angle_above, np.zeros((below_rows, W))], axis=0)
# Near shoreline, dark, at the very bottom
s = np.arange(W) / H
shore = 1.0 - 0.06 - 0.05 * (0.5 + 0.5 * noise1d(s * 1.3, 5, 0.7, seed=300))
vv = np.arange(H)[:, None] / H
on_shore = vv >= shore[None, :]
img = np.where(on_shore[..., None], bg * 0.45, img)
region[on_shore] = SHORE
angle = np.where(on_shore, np.arctan(np.gradient(shore, s))[None, :], angle)



# ---------------------------------------------------------------- texture

def blur(a, r):
    im = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))
    return np.asarray(im.filter(ImageFilter.GaussianBlur(r))).astype(float) / 255

def canvas(img):
    y, x = np.mgrid[0:H, 0:W].astype(float)
    # woven canvas: two crossed thread patterns, slightly irregular
    jitter = blur(rng.random((H, W)), 6) * 6
    weave = (np.sin((x + jitter) * 2 * np.pi / 4.2) * np.sin((y - jitter) * 2 * np.pi / 4.2))
    weave = weave * 0.5 + 0.5
    # brush strokes: noise stretched horizontally (the landscape is horizontal)
    n = rng.random((H // 2, W // 16))
    strokes = np.asarray(Image.fromarray((n * 255).astype(np.uint8)).resize((W, H), Image.BICUBIC)).astype(float) / 255
    strokes = blur(strokes, 1.5)
    grain = rng.normal(0, 1, (H, W))
    lum = 0.06 * (weave - 0.5) + 0.07 * (strokes - 0.5) + 0.018 * grain
    # textures sit mostly in the midtones, like paint on canvas
    return np.clip(img * (1 + lum[..., None] * 1.6), 0, 1)

BAYER8 = np.array([[0, 32, 8, 40, 2, 34, 10, 42], [48, 16, 56, 24, 50, 18, 58, 26],
                   [12, 44, 4, 36, 14, 46, 6, 38], [60, 28, 52, 20, 62, 30, 54, 22],
                   [3, 35, 11, 43, 1, 33, 9, 41], [51, 19, 59, 27, 49, 17, 57, 25],
                   [15, 47, 7, 39, 13, 45, 5, 37], [63, 31, 55, 23, 61, 29, 53, 21]]) / 64 - 0.5

def kmeans_palette(img, k, iters=15):
    flat = img.reshape(-1, 3)
    # Sample evenly across brightness bins, not by pixel count: the large dark
    # sky would otherwise get many near-identical shades and dither to mush.
    lum_all = flat @ np.array([0.3, 0.59, 0.11])
    bins = np.minimum((lum_all / max(lum_all.max(), 1e-6) * 12).astype(int), 11)
    picks = [rng.choice(np.flatnonzero(bins == b), min(5000, (bins == b).sum()), replace=False)
             for b in range(12) if (bins == b).any()]
    sample = flat[np.concatenate(picks)]
    # init from luminance quantiles so dark and light tones are all represented
    lum = sample @ np.array([0.3, 0.59, 0.11])
    cent = sample[np.argsort(lum)[np.linspace(0, len(sample) - 1, k).astype(int)]]
    for _ in range(iters):
        lab = ((sample[:, None] - cent[None]) ** 2).sum(-1).argmin(1)
        for j in range(k):
            m = sample[lab == j]
            if len(m): cent[j] = m.mean(0)
    return cent

def crush(img, k=32, pixel=2, spread=0.07):
    p = kmeans_palette(img, k)
    small = img[::pixel, ::pixel] if pixel > 1 else img
    h, w, _ = small.shape
    thr = np.tile(BAYER8, (h // 8 + 1, w // 8 + 1))[:h, :w]
    q = small + thr[..., None] * spread
    flat = q.reshape(-1, 3); out = np.empty_like(flat)
    for i in range(0, flat.shape[0], 200000):
        out[i:i + 200000] = p[((flat[i:i + 200000, None] - p[None]) ** 2).sum(-1).argmin(1)]
    out = out.reshape(h, w, 3)
    return np.repeat(np.repeat(out, pixel, 0), pixel, 1)[:H, :W] if pixel > 1 else out

# Thick dab styles per region: (length px, height px, angle jitter rad, coverage).
# The base layer: chunky, loosely oriented dabs (impressionistic rather than
# precise) that follow the terrain.
DABS = {
    SKY: ((8, 17), (4.5, 10.0), 0.14, 1.6),
    1: ((5, 12), (3.5, 7.0), 0.30, 1.8),
    2: ((6, 13), (4.0, 7.5), 0.30, 1.8),
    3: ((7, 14), (4.0, 8.5), 0.33, 1.8),
    4: ((8, 16), (5.0, 9.0), 0.33, 1.8),
    5: ((8, 17), (5.0, 10.0), 0.33, 1.8),
    LAKE: ((10, 23), (3.0, 6.0), 0.07, 1.6),
    SHORE: ((7, 14), (4.0, 8.5), 0.30, 1.6),
}

# Fine stroke styles per region: (length px, width px, angle jitter rad, coverage).
# Drawn on top of the dabs, sparser, to carry the direction.
# Distant hills get small strokes, near ones bigger; sky loose and long; water
# long and thin like ripples.
STROKES = {
    SKY: ((8, 26), (1.5, 3.0), 0.08, 0.6),
    1: ((5, 12), (1.2, 2.2), 0.22, 0.7),
    2: ((6, 15), (1.4, 2.5), 0.22, 0.7),
    3: ((7, 17), (1.6, 2.8), 0.25, 0.7),
    4: ((8, 19), (1.8, 3.0), 0.25, 0.7),
    5: ((9, 22), (2.0, 3.2), 0.25, 0.7),
    LAKE: ((10, 34), (1.0, 2.0), 0.03, 0.8),
    SHORE: ((5, 14), (1.5, 3.0), 0.20, 0.6),
}

def strokes(img, region, angle, jitter=0.06):
    """Paint each region on its own layer - thick oriented dabs, then sparser fine
    strokes - and composite through a slightly roughened region mask: brushy
    interiors, defined edges between hills."""
    lum_w = np.array([0.3, 0.59, 0.11])
    tints = [iris, rose, foam, gold]
    # rough edges: look the region map up at an offset mixing a slow wobble with
    # fine grain, so boundaries read as painted rather than drawn
    yy, xx = np.mgrid[0:H, 0:W]
    ox = ((blur(rng.random((H, W)), 3) - 0.5) * 8 + (blur(rng.random((H, W)), 0.8) - 0.5) * 7).astype(int)
    oy = ((blur(rng.random((H, W)), 3) - 0.5) * 8 + (blur(rng.random((H, W)), 0.8) - 0.5) * 7).astype(int)
    rough = region[np.clip(yy + oy, 0, H - 1), np.clip(xx + ox, 0, W - 1)]
    ring = np.linspace(0, 2 * np.pi, 12, endpoint=False)

    def colour(y, x):
        c = img[y, x]
        bright = min(1.0, (c @ lum_w) * 3)
        # jitter scaled by brightness (fixed jitter looks like compression noise in the dark)
        c = c * (1 + rng.normal(0, jitter)) + rng.normal(0, jitter * 0.4, 3) * bright
        # broken colour: a faint tint from a neighbouring hue in the scheme
        c = c * 0.92 + tints[rng.integers(len(tints))] * (c @ lum_w) * 0.08 * (0.3 + bright)
        return tuple((np.clip(c, 0, 1) * 255).astype(int))

    def centres(where, size, cover):
        n = int(where.size * cover / size)
        pick = rng.choice(where, n)
        return pick // W, pick % W, n

    out = img.copy()
    for rid in DABS:
        where = np.flatnonzero(region == rid)
        if where.size == 0:
            continue
        layer = Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8))
        d = ImageDraw.Draw(layer)
        # 1. thick dabs: small rotated ellipses
        (l0, l1), (h0, h1), ajit, cover = DABS[rid]
        cy, cx, n = centres(where, (l0 + l1) / 2 * (h0 + h1) / 2 * 0.8, cover)
        for y, x, a0, L, hgt in zip(cy, cx, angle[cy, cx] + rng.normal(0, ajit, n),
                                    rng.uniform(l0, l1, n), rng.uniform(h0, h1, n)):
            ca, sa = np.cos(a0), np.sin(a0)
            ex, ey = np.cos(ring) * L / 2, np.sin(ring) * hgt / 2
            d.polygon(list(zip(x + ex * ca - ey * sa, y + ex * sa + ey * ca)), fill=colour(y, x))
        # 2. fine directional strokes on top
        (l0, l1), (w0, w1), ajit, cover = STROKES[rid]
        cy, cx, n = centres(where, (l0 + l1) / 2 * (w0 + w1) / 2, cover)
        for y, x, a0, L, w, bend in zip(cy, cx, angle[cy, cx] + rng.normal(0, ajit, n),
                                        rng.uniform(l0, l1, n), rng.uniform(w0, w1, n), rng.normal(0, 0.12, n)):
            dx, dy = np.cos(a0) * L / 2, np.sin(a0) * L / 2
            mx, my = x - dy * bend, y + dx * bend  # slight curve
            d.line([(x - dx, y - dy), (mx, my), (x + dx, y + dy)], fill=colour(y, x), width=max(1, round(w)), joint="curve")
        painted = np.asarray(layer.filter(ImageFilter.GaussianBlur(0.4))).astype(float) / 255
        sel = rough == rid
        out[sel] = painted[sel] * 0.95 + img[sel] * 0.05
    return out


H, W = img.shape[:2]
if TEXTURE == "paint":
    img = canvas(strokes(img, region, angle))
elif TEXTURE == "crush":
    img = crush(img, k=32, pixel=2)
elif TEXTURE == "paintcrush":
    # 20 colours + strong ordered dither: a visible fine crosshatch over the brushwork
    img = crush(canvas(strokes(img, region, angle)), k=20, pixel=1, spread=0.12)
elif TEXTURE == "none":
    img = img + rng.normal(0, 0.005, img.shape)  # grain against banding
else:
    sys.exit(f"unknown TEXTURE {TEXTURE!r}")

# ---------------------------------------------------------------- crisp details
# Drawn after texturing so the brush pass doesn't smear them.

def stars(img):
    """Starfield fading out toward the glowing horizon; a few brighter ones with a soft cross."""
    srng = np.random.default_rng(77)
    n = int(W * H / 1400)
    sx = srng.uniform(0, W, n).astype(int)
    sy = (srng.uniform(0, 1, n) ** 1.6 * H * WATER * 0.8).astype(int)  # denser toward the top
    b = srng.uniform(0, 1, n) ** 3
    for px, py, bi in zip(sx, sy, b):
        sky_dark = 1 - smooth(0.25, 0.6, py / H) * (0.4 + 0.6 * np.exp(-((px / H - SUN_X) / 0.9) ** 2))
        k = bi * sky_dark
        if k < 0.04:
            continue
        if np.hypot(px / H - MOON[0], py / H - MOON[1]) < 0.03:
            continue
        tint = text if srng.random() > 0.2 else foam
        img[py, px] = np.clip(img[py, px] * (1 - k) + tint * k, 0, 1)
        if bi > 0.55:  # bright star: 4-neighbour glow
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                qx, qy = min(max(px + dx, 0), W - 1), min(max(py + dy, 0), H - 1)
                img[qy, qx] = np.clip(img[qy, qx] * (1 - k * 0.35) + tint * k * 0.35, 0, 1)
    return img

def waterline(img):
    """Thin line where the water meets the far shore, brightest under the glow."""
    row = int(H * WATER)
    glow = np.exp(-((np.arange(W) / H - SUN_X) / 1.1) ** 2)[:, None]
    line = rose * 0.6 + gold * 0.25 + bg * 0.15
    img[row] = img[row] * (1 - 0.55 * glow) + line * 0.55 * glow
    img[row + 1] = img[row + 1] * (1 - 0.25 * glow) + line * 0.25 * glow
    return img

def glints(img):
    """Short horizontal sparkles on the water under the glow."""
    grng = np.random.default_rng(91)
    top = int(H * WATER) + 4
    for _ in range(int(W / 25)):
        x = int(grng.normal(SUN_X * H, 0.35 * H)); y = int(top + grng.uniform(0, 1) ** 2 * H * 0.2)
        if not (0 <= x < W - 8 and y < H): continue
        length = int(grng.integers(2, 7)); k = grng.uniform(0.15, 0.45) * np.exp(-((y - top) / (H * 0.12)))
        img[y, x:x + length] = img[y, x:x + length] * (1 - k) + (gold * 0.6 + rose * 0.4) * k
    return img

def moon(img):
    """Thin crescent: a lit disc minus an offset dark disc, anti-aliased."""
    cx, cy, rad = MOON[0] * H, MOON[1] * H, 0.018 * H
    y0, y1, x0, x1 = int(cy - rad - 3), int(cy + rad + 3), int(cx - rad - 3), int(cx + rad + 3)
    yy, xx = np.mgrid[y0:y1, x0:x1].astype(float)
    lit = np.clip(rad - np.hypot(xx - cx, yy - cy) + 0.5, 0, 1)
    shadow = np.clip(rad * 0.92 - np.hypot(xx - (cx + rad * 0.42), yy - (cy - rad * 0.12)) + 0.5, 0, 1)
    k = (lit * (1 - shadow))[..., None] * 0.9
    img[y0:y1, x0:x1] = img[y0:y1, x0:x1] * (1 - k) + (text * 0.85 + foam * 0.15) * k
    return img

img = moon(glints(waterline(stars(img))))

os.makedirs(OUT, exist_ok=True)
out = Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8))
out.save(os.path.join(OUT, "full.png"))
for k in range(W // 1920):
    out.crop((k * 1920, 0, (k + 1) * 1920, H)).save(os.path.join(OUT, f"{k}.png"))
