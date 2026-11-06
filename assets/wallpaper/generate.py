"""Twilight lake wallpaper, generated from the stylix palette.

usage: generate.py WIDTH HEIGHT OUT_DIR TEXTURE base00 .. base0F
  TEXTURE: none | paint | crush | paintcrush
Writes OUT_DIR/full.png and one crop per 1920px-wide monitor, left to right
(OUT_DIR/0.png, 1.png, ...). Also writes base.argb and scene.txt for the native
renderer: one memory-mappable still, a small list of animated details, and
cached paint-detail and haze/cloud bands, not full-resolution animation frames.
Deterministic: fixed seeds, same input -> same image.

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
    # Broadcast row/column coordinates instead of retaining full-frame grids.
    u, v = np.arange(W, dtype=float)[None, :] / H, np.arange(Hs, dtype=float)[:, None] / H
    # v is in the same units as the full image.
    s = u[0]
    # Sky: night at the top -> iris -> rose -> gold at the horizon, glow centred on the right screen
    sun_x = SUN_X
    glow = np.exp(-((u - sun_x) / 0.95) ** 2)
    t = smooth(0.0, WATER, v)
    sky = mix(bg * 0.70, mix(bg, iris * 0.55 + bg * 0.45, glow * 0.8), smooth(0.05, 0.45, t))
    sky = mix(sky, rose * 0.85 + bg * 0.15, smooth(0.55, 0.92, t) * (0.35 + 0.65 * glow))
    sky = mix(sky, gold, smooth(0.86, 1.0, t) * glow ** 2 * 0.85)
    # Sky paint and cloud layers are exported separately below; the large-scale
    # illumination and mountain silhouettes do not move with them.
    # faint cool halo around the moon (the crescent itself is drawn after texturing)
    md = np.hypot(u - MOON[0], v - MOON[1])
    sky = sky + (np.exp(-(md / 0.16) ** 2) * 0.07)[..., None] * foam
    img = sky
    region = np.full((Hs, W), SKY, np.int16)
    angle = 0.05 * noise1d(s * 2, 3, 1.0, seed=60)[None, :] * np.ones((Hs, 1))  # sky: loose, near-horizontal
    ridge = np.full(W, WATER)
    ridge_strength = np.zeros(W)
    ridge_owner = np.full(W, -1, np.int8)
    # Mountains: far (hazy, warm-lit) to near (dark); main peak on the left screen
    layers = 5
    for i in range(layers):
        t = i / (layers - 1)
        horizon = WATER - 0.10 + 0.095 * t  # far ridges high, nearest one a thin far shore
        amp = 0.20 - 0.175 * t
        peak = np.exp(-((s - PEAK_X) / 0.45) ** 2) * (0.20 if i == 1 else 0.06 * (1 - t))
        prof = horizon - amp * (0.5 + 0.5 * noise1d(s * 0.55, 6, 0.6, seed=100 + i)) - peak
        exposed = prof < ridge
        ridge_strength[exposed] = (1 - t) * 0.28
        ridge_owner[exposed] = i
        ridge = np.minimum(ridge, prof)
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
        # Keep accents inside the hills, but export the sky-facing glow below.
        # No ridge illumination may enter the translated sky-paint source.
        img = img + (rim * (region != SKY))[..., None] * gold
    return img, region, angle, sky, ridge, ridge_strength, ridge_owner

top_rows = int(H * WATER)
above, region_above, angle_above, sky_gradient, ridge, ridge_strength, ridge_owner = scene(top_rows)
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
# Concatenation owns these pixels now; do not retain the large source canvases
# throughout painting and palette matching.
del above, lake, mirror, m, angle_above
# Near shoreline, dark, at the very bottom
s = np.arange(W) / H
shore = 1.0 - 0.06 - 0.05 * (0.5 + 0.5 * noise1d(s * 1.3, 5, 0.7, seed=300))
vv = np.arange(H)[:, None] / H
on_shore = vv >= shore[None, :]
img = np.where(on_shore[..., None], bg * 0.45, img)
region[on_shore] = SHORE
angle = np.where(on_shore, np.arctan(np.gradient(shore, s))[None, :], angle)
del on_shore



# ---------------------------------------------------------------- texture

def blur(a, r):
    im = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))
    return np.asarray(im.filter(ImageFilter.GaussianBlur(r))).astype(float) / 255

def canvas(img, sky):
    y, x = np.arange(H, dtype=float)[:, None], np.arange(W, dtype=float)[None, :]
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
    gain = 1 + lum[..., None] * 1.6
    return np.clip(img * gain, 0, 1), np.clip(sky * gain[:top_rows], 0, 1)

BAYER8 = np.array([[0, 32, 8, 40, 2, 34, 10, 42], [48, 16, 56, 24, 50, 18, 58, 26],
                   [12, 44, 4, 36, 14, 46, 6, 38], [60, 28, 52, 20, 62, 30, 54, 22],
                   [3, 35, 11, 43, 1, 33, 9, 41], [51, 19, 59, 27, 49, 17, 57, 25],
                   [15, 47, 7, 39, 13, 45, 5, 37], [63, 31, 55, 23, 61, 29, 53, 21]]) / 64 - 0.5

def nearest_palette(sample, palette):
    """Exact RGB distances, without a pixels × colours × channels temporary."""
    labels = np.empty(len(sample), np.intp)
    for start in range(0, len(sample), 16384):
        chunk = sample[start:start + 16384]
        distance = (chunk[:, None, 0] - palette[None, :, 0]) ** 2
        for channel in (1, 2):
            distance += (chunk[:, None, channel] - palette[None, :, channel]) ** 2
        labels[start:start + len(chunk)] = distance.argmin(1)
    return labels

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
        lab = nearest_palette(sample, cent)
        for j in range(k):
            m = sample[lab == j]
            if len(m): cent[j] = m.mean(0)
    return cent

def crush(img, k=32, pixel=2, spread=0.07, palette=None):
    p = kmeans_palette(img, k) if palette is None else palette
    small = img[::pixel, ::pixel] if pixel > 1 else img
    h, w, _ = small.shape
    thr = np.tile(BAYER8, (h // 8 + 1, w // 8 + 1))[:h, :w]
    q = small + thr[..., None] * spread
    flat = q.reshape(-1, 3); out = np.empty_like(flat)
    out[:] = p[nearest_palette(flat, p)]
    out = out.reshape(h, w, 3)
    return np.repeat(np.repeat(out, pixel, 0), pixel, 1)[:img.shape[0], :img.shape[1]] if pixel > 1 else out

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
    tints = np.array([iris, rose, foam, gold])
    # rough edges: look the region map up at an offset mixing a slow wobble with
    # fine grain, so boundaries read as painted rather than drawn
    yy, xx = np.arange(H)[:, None], np.arange(W)[None, :]
    ox = ((blur(rng.random((H, W)), 3) - 0.5) * 8 + (blur(rng.random((H, W)), 0.8) - 0.5) * 7).astype(int)
    oy = ((blur(rng.random((H, W)), 3) - 0.5) * 8 + (blur(rng.random((H, W)), 0.8) - 0.5) * 7).astype(int)
    rough = region[np.clip(yy + oy, 0, H - 1), np.clip(xx + ox, 0, W - 1)]
    ring = np.linspace(0, 2 * np.pi, 12, endpoint=False)
    ring_cos, ring_sin = np.cos(ring), np.sin(ring)

    def colours(cy, cx, source, r, visible):
        n = len(cy)
        gain, noise, tint = np.empty(n), np.empty((n, 3)), np.empty(n, np.intp)
        # Keep draws interleaved exactly as in the per-stroke version: changing
        # their order would repaint the scene, even with the same seed.
        for i in range(n):
            gain[i] = 1 + r.normal(0, jitter)
            noise[i] = r.normal(0, jitter * 0.4, 3)
            tint[i] = r.integers(len(tints))
        if not visible: return None
        c = source[cy, cx]
        bright = np.minimum(1.0, (c @ lum_w) * 3)
        # jitter scaled by brightness (fixed jitter looks like compression noise in the dark)
        c = c * gain[:, None] + noise * bright[:, None]
        # broken colour: a faint tint from a neighbouring hue in the scheme
        c = c * 0.92 + tints[tint] * (c @ lum_w)[:, None] * 0.08 * (0.3 + bright[:, None])
        return (np.clip(c, 0, 1) * 255).astype(int)

    def centres(where, size, cover, r):
        n = int(where.size * cover / size)
        pick = r.choice(where, n)
        return pick // W, pick % W, n

    def paint(layer, rid, where, source, angles, r):
        if where.size == 0: return
        d = ImageDraw.Draw(layer) if layer is not None else None
        # 1. thick dabs: small rotated ellipses
        (l0, l1), (h0, h1), ajit, cover = DABS[rid]
        cy, cx, n = centres(where, (l0 + l1) / 2 * (h0 + h1) / 2 * 0.8, cover, r)
        orientations = angles[cy, cx] + r.normal(0, ajit, n)
        lengths, heights = r.uniform(l0, l1, n), r.uniform(h0, h1, n)
        inks = colours(cy, cx, source, r, d is not None)
        if d is not None:
            ca, sa = np.cos(orientations)[:, None], np.sin(orientations)[:, None]
            ex, ey = ring_cos * lengths[:, None] / 2, ring_sin * heights[:, None] / 2
            px, py = cx[:, None] + ex * ca - ey * sa, cy[:, None] + ex * sa + ey * ca
            for xs, ys, tint in zip(px, py, inks):
                d.polygon(list(zip(xs, ys)), fill=tuple(tint))
        # 2. fine directional strokes on top
        (l0, l1), (w0, w1), ajit, cover = STROKES[rid]
        cy, cx, n = centres(where, (l0 + l1) / 2 * (w0 + w1) / 2, cover, r)
        orientations = angles[cy, cx] + r.normal(0, ajit, n)
        lengths, widths, bends = r.uniform(l0, l1, n), r.uniform(w0, w1, n), r.normal(0, 0.12, n)
        inks = colours(cy, cx, source, r, d is not None)
        if d is not None:
            dxs, dys = np.cos(orientations) * lengths / 2, np.sin(orientations) * lengths / 2
            for y, x, dx, dy, w, bend, tint in zip(cy, cx, dxs, dys, widths, bends, inks):
                mx, my = x - dy * bend, y + dx * bend  # slight curve
                d.line([(x - dx, y - dy), (mx, my), (x + dx, y + dy)], fill=tuple(tint), width=max(1, round(w)), joint="curve")

    out = img.copy()
    for rid in DABS:
        where = np.flatnonzero(region == rid)
        if where.size == 0: continue
        if rid == SKY:
            # Paint one uninterrupted sky rectangle from the clean gradient.
            # Splitting visible/hidden sky or sampling img here imprints the
            # skyline/rim into the source and produces a drifting ghost ridge.
            layer = Image.fromarray((np.clip(sky_gradient, 0, 1) * 255).astype(np.uint8))
            sky_angles = np.broadcast_to(0.05 * noise1d(np.arange(W) / H * 2, 3, 1.0, seed=60), (top_rows, W))
            paint(layer, SKY, np.arange(top_rows * W), sky_gradient, sky_angles, np.random.default_rng(97))
            # Preserve the terrain's random stream without feeding it into the sky.
            paint(None, SKY, where, img, angle, rng)
        else:
            layer = Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8))
            paint(layer, rid, where, img, angle, rng)
        painted = np.asarray(layer.filter(ImageFilter.GaussianBlur(0.4))).astype(float) / 255
        sel = rough == rid
        if rid == SKY:
            painted_sky = painted * 0.95 + sky_gradient * 0.05
            out[:top_rows][sel[:top_rows]] = painted_sky[sel[:top_rows]]
        else:
            out[sel] = painted[sel] * 0.95 + img[sel] * 0.05
    return out, painted_sky


H, W = img.shape[:2]
painted_sky = sky_gradient.copy()
if TEXTURE in ("paint", "paintcrush"):
    img, painted_sky = canvas(*strokes(img, region, angle))
if TEXTURE in ("crush", "paintcrush"):
    # Both sky sources use the same palette and spatial dither as the scene.
    k, pixel, spread = (20, 1, 0.12) if TEXTURE == "paintcrush" else (32, 2, 0.07)
    palette = kmeans_palette(img, k)
    img = crush(img, pixel=pixel, spread=spread, palette=palette)
    painted_sky = crush(painted_sky, pixel=pixel, spread=spread, palette=palette)
elif TEXTURE == "none":
    grain = rng.normal(0, 0.005, img.shape)
    img = img + grain  # grain against banding
    painted_sky = painted_sky + grain[:top_rows]
elif TEXTURE != "paint":
    sys.exit(f"unknown TEXTURE {TEXTURE!r}")
del angle, sky_gradient

def soften_peak_shadow(img):
    """Retain a little dark edge on the main peak, not an ink-like cutout.
    Compare only with a reference on the same side of the silhouette: a blur
    across the mountain/sky boundary would wash out the shape and its colours."""
    y = np.arange(top_rows)[:, None]
    x = np.arange(W)[None, :]
    distance = ridge[None, :] * H - y
    slope = -np.gradient(ridge, np.arange(W) / H)
    left_side = smooth(PEAK_X - 0.60, PEAK_X - 0.30, np.arange(W) / H)
    left_side *= 1 - smooth(PEAK_X - 0.03, PEAK_X + 0.08, np.arange(W) / H)
    left_side *= smooth(0.005, 0.09, slope) * (ridge_owner == 1)
    weight = 0.55 * np.exp(-(distance / (H * 0.006)) ** 2) * left_side[None, :]
    reference = blur(img, 2.5)
    reference_y = np.where(region_above == SKY, y - 14, y + 14)
    reference = reference[np.clip(reference_y, 0, H - 1), x]
    darker = ((reference - img[:top_rows]) @ np.array([0.3, 0.59, 0.11])) > 0
    img[:top_rows] = mix(img[:top_rows], reference, weight * darker)
    return img

img = soften_peak_shadow(img)

# ---------------------------------------------------------------- crisp details
# Drawn after texturing so the brush pass doesn't smear them.

def stars(img, animated=False):
    """Keep half the stars static; export the others as tiny independently pulsing sprites."""
    srng = np.random.default_rng(77)
    n = int(W * H / 1400)
    sx = srng.uniform(0, W, n).astype(int)
    sy = (srng.uniform(0, 1, n) ** 1.6 * H * WATER * 0.8).astype(int)  # denser toward the top
    b = srng.uniform(0, 1, n) ** 3
    trng = np.random.default_rng(78)  # separate stream: animation never moves or recolours stars
    rate = trng.uniform(1 / 7, 1 / 2.5, n)
    phase = trng.uniform(0, 1, n)
    depth = np.where(trng.random(n) < 0.5, trng.uniform(0.55, 0.92, n), 0.0)
    for i, (px, py, bi) in enumerate(zip(sx, sy, b)):
        sky_dark = 1 - smooth(0.25, 0.6, py / H) * (0.4 + 0.6 * np.exp(-((px / H - SUN_X) / 0.9) ** 2))
        k = bi * sky_dark
        if k < 0.04:
            continue
        if region[py, px] != SKY:
            continue
        if np.hypot(px / H - MOON[0], py / H - MOON[1]) < 0.03:
            continue
        tint = text if srng.random() > 0.2 else foam
        if animated and depth[i] > 0:
            radius = 2 if bi > 0.55 else int(bi > 0.22)
            effects.append(("S", px, py, radius, rate[i], phase[i], min(1, k * 1.35), depth[i], *tint))
            continue
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
    """Short horizontal sparkles on the water under the glow (still image only)."""
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

def paint_offset(detail, mask):
    """Integer rounding shared with the native signed-detail compositor."""
    value = detail.astype(np.int32) * mask[..., None].astype(np.int32)
    return np.sign(value) * ((np.abs(value) + 127) // 255)

def separate_sky_paint(img):
    """Move the original brushwork above the ridges, not another translucent veil.
    Leave the broad illumination and fine canvas/dither stationary; export only
    medium-scale colour detail, with a fixed feathered mask following the peaks."""
    sky8 = (np.clip(painted_sky, 0, 1) * 255).astype(np.uint8)
    periodic = Image.fromarray(np.tile(sky8, (1, 3, 1)))
    fine = np.asarray(periodic.filter(ImageFilter.GaussianBlur(1.1)))[:, W:W * 2].astype(np.int16)
    broad = np.asarray(periodic.filter(ImageFilter.GaussianBlur(28)))[:, W:W * 2].astype(np.int16)
    detail = np.clip(fine - broad, -127, 127).astype(np.int8)
    crest = np.argmax(region != SKY, axis=0)
    distance = crest[None, :] - np.arange(top_rows)[:, None]
    weight = smooth(3, 12, distance) * (1 - smooth(95, 180, distance))
    mask = np.rint(weight * sky_mask[:top_rows]).astype(np.uint8)
    active = np.flatnonzero(mask.any(axis=1))
    y0, y1 = int(active[0]), int(active[-1]) + 1
    payload = np.empty((y1 - y0, W, 4), np.uint8)
    payload[..., :3] = detail[y0:y1].view(np.uint8)
    payload[..., 3] = mask[y0:y1]
    offset = paint_offset(detail[y0:y1], payload[..., 3])
    original = (np.clip(img[y0:y1], 0, 1) * 255).astype(np.uint8)
    base = np.clip(original.astype(np.int32) - offset, 0, 255)
    restored = np.clip(base + offset, 0, 255)
    if np.max(np.abs(restored - original.astype(np.int32))) > 1:
        raise ValueError("sky paint does not reconstruct the original scene")
    img[y0:y1] = base / 255
    # Signed RGB residual + an UNSCROLLED destination mask, not an RGBA overlay.
    return img, ("P", y0, 1.0, np.zeros(3, np.uint8), payload)

def ridge_glow_layer():
    """Two fixed glow widths plus a terrain-free drifting modulation field.
    Only intensity/softness evolve; no silhouette pixels are ever translated."""
    sigma = H * 0.006
    y0 = max(0, int(np.floor(ridge.min() * H - sigma * 3)))
    y1 = min(top_rows, int(np.ceil(ridge.max() * H)) + 1)
    distance = ridge[None, :] * H - np.arange(y0, y1)[:, None]
    illumination = np.exp(-((np.arange(W) / H - SUN_X) / 0.95) ** 2)
    strength = ridge_strength * illumination
    payload = np.empty((y1 - y0, W, 3), np.uint8)
    visible = region[y0:y1] == SKY
    for channel, width in enumerate((H * 0.0022, sigma)):
        halo = np.exp(-(distance / width) ** 2) * strength[None, :] * visible
        payload[..., channel] = np.rint(np.clip(halo, 0, 1) * 255).astype(np.uint8)
    u = np.arange(W) / W
    modulation = (0.5 + 0.22 * np.sin(2 * np.pi * (11 * u + 0.17))
                  + 0.14 * np.sin(2 * np.pi * (23 * u + 0.61))
                  + 0.08 * np.sin(2 * np.pi * (47 * u + 0.83)))
    payload[..., 2] = np.rint(np.clip(modulation, 0, 1) * 255).astype(np.uint8)[None, :]
    # Fixed support is essential: morphing must never draw inside a mountain.
    if np.any(payload[..., :2][~visible]):
        raise ValueError("ridge glow extends into the terrain")
    return "G", y0, 0.8, (np.clip(gold, 0, 1) * 255).astype(np.uint8), payload

def glow_opacity(narrow, wide, modulation, breath=128):
    """Integer reference for the native anchored glow compositor."""
    phase = (modulation.astype(np.int32) * 3 + breath + 2) // 4
    broad_weight = 26 + (phase * 102 + 127) // 255
    amount = (narrow.astype(np.int32) * (255 - broad_weight)
              + wide.astype(np.int32) * broad_weight + 127) // 255
    gain = 220 + (phase * 72 + 127) // 255
    return np.minimum(255, (amount * gain + 128) // 256)

def sky_haze_layers():
    """Broad, gently rolling sky texture beneath the thinner cloud streaks.
    Periodic multiscale noise is painted once, not synthesized every frame."""
    hrng = np.random.default_rng(96)
    layers = []
    for top, bottom, speed, strength, tint in [
        (0.19, 0.41, 0.8, 0.20, iris * 0.50 + foam * 0.20 + bg * 0.30),
        (0.30, 0.56, 1.2, 0.18, rose * 0.60 + gold * 0.15 + bg * 0.25),
    ]:
        y0, y1 = int(H * top), int(np.ceil(H * bottom))
        rows = y1 - y0
        field = np.zeros((rows, W))
        for cell_x, cell_y, weight in [(150, 48, 0.55), (55, 20, 0.30), (18, 7, 0.15)]:
            grid = hrng.integers(0, 256, (max(3, rows // cell_y), max(4, W // cell_x)), dtype=np.uint8)
            # Resize three periods and take the middle one so the interpolation
            # itself wraps, instead of producing a visible vertical seam.
            periodic = Image.fromarray(np.tile(grid, (1, 3))).resize((W * 3, rows), Image.BICUBIC)
            field += weight * np.asarray(periodic)[:, W:W * 2] / 255
        v = np.linspace(0, 1, rows)[:, None]
        envelope = np.sin(np.pi * v) ** 1.4
        density = smooth(0.26, 0.72, field)
        alpha = (np.clip(density * envelope * strength, 0, 1) * 255).astype(np.uint8)
        colour = (np.clip(tint, 0, 1) * 255).astype(np.uint8)
        layers.append(("A", y0, speed, colour, alpha))
    return layers

def cloud_layers():
    """Layer broad moving haze, the original three cloud profiles and two wisps.
    Alpha-only bands keep runtime storage smaller than full animation frames."""
    s = np.arange(W) / H
    glow = np.exp(-((s - SUN_X) / 0.95) ** 2)
    edge = smooth(0, 0.10, s) * smooth(0, 0.10, A - s)
    tint = (np.clip(rose * 0.7 + gold * 0.3, 0, 1) * 255).astype(np.uint8)
    specs = [
        (0.30, 0.010, 0.35, 0.35, None),
        (0.38, 0.007, 0.30, 0.25, None),
        (0.46, 0.012, 0.25, 0.45, None),
        (0.335, 0.0025, 0.12, 0.18, (0.64 * A, 0.16 * A)),
        (0.42, 0.0028, 0.10, 0.30, (0.83 * A, 0.10 * A)),
    ]
    layers = sky_haze_layers()
    crng = np.random.default_rng(95)
    for i, (cy, th, strength, speed, wisp) in enumerate(specs):
        centre = cy + 0.015 * noise1d(s * 0.4, 3, 0.5, seed=40 + i)
        y0 = max(0, int(np.floor((centre.min() - 3 * th) * H)))
        y1 = min(H, int(np.ceil((centre.max() + 3 * th) * H)) + 1)
        v = np.arange(y0, y1)[:, None] / H
        band = np.exp(-((v - centre[None, :]) / th) ** 2)
        band *= smooth(-0.2, 0.6, noise1d(s * 0.9, 4, 0.6, seed=50 + i))[None, :]
        band *= strength * (0.3 + 0.7 * glow)[None, :] * edge[None, :]
        if wisp:
            band *= np.exp(-((s - wisp[0]) / wisp[1]) ** 2)[None, :]
        # A little directional grain blends the separated cloud paint into the
        # canvas. Feather both horizontal edges to make wrapping seamless.
        grain = crng.integers(0, 256, (max(2, (y1 - y0) // 3), max(2, W // 12)), dtype=np.uint8)
        grain = np.asarray(Image.fromarray(grain).resize((W, y1 - y0), Image.BICUBIC)) / 255
        alpha = (np.clip(band * (0.86 + 0.28 * grain), 0, 1) * 255).astype(np.uint8)
        layers.append(("A", y0, speed, tint, alpha))
    return layers

def with_clouds(img):
    for kind, y0, _, tint, data in clouds:
        y1 = y0 + data.shape[0]
        if kind == "P":
            offset = paint_offset(data[..., :3].view(np.int8), data[..., 3])
            img[y0:y1] = np.clip(img[y0:y1] * 255 + offset, 0, 255) / 255
        elif kind == "G":
            amount = glow_opacity(data[..., 0], data[..., 1], data[..., 2])
            increment = (amount[..., None] * tint.astype(np.int32) + 127) // 255
            img[y0:y1] = np.clip(img[y0:y1] * 255 + increment, 0, 255) / 255
        else:
            k = data / 255 * (sky_mask[y0:y1] / 255)
            img[y0:y1] = mix(img[y0:y1], tint / 255, k)
    return img

def moving_details():
    """Sparse travelling wavelets, reflected light, shoreline fireflies and rare meteors.
    All positions come from the same region map as the painting, not runtime guesses."""
    r = np.random.default_rng(94)
    for _ in range(W // 14):
        x = int(r.integers(12, W - 12))
        y = int(r.integers(top_rows + 10, H - 12))
        length = r.uniform(8, 28) * (0.5 + (y / H - WATER) * 5)
        # Leave room for the whole wave's motion without crossing the painted shore.
        x0, x1 = max(0, int(x - 1.5 * length - 2)), min(W, int(x + 1.5 * length + 3))
        if not np.all(region[y - 7:y + 11, x0:x1] == LAKE):
            continue
        warm = np.exp(-((x / H - SUN_X) / 0.5) ** 2)
        cool = np.exp(-((x / H - MOON[0]) / 0.15) ** 2)
        tint = (gold * 0.6 + rose * 0.4) * warm + foam * (1 - warm)
        strength = r.uniform(0.12, 0.22) + warm * 0.30 + cool * 0.15
        effects.append(("R", x, y, length, r.uniform(1 / 6, 1 / 2.8), r.random(), strength, 0, *tint))
    for _ in range(max(3, W // 220)):
        x = int(r.integers(12, W - 12))
        y = int(shore[x] * H - r.uniform(18, 42))
        effects.append(("F", x, y, 12, r.uniform(1 / 9, 1 / 4), r.random(), 0.9, 0, *gold))
    for x, period in ((W * 0.27, 47), (W * 0.78, 61)):
        effects.append(("M", x, H * 0.12, H * 0.22, 1 / period, r.uniform(0.2, 0.9), 0.9, 0, *foam))

os.makedirs(OUT, exist_ok=True)
# A small, balanced emulsion tile, reused with different row/block phases.
# Padding lets the native SIMD pass read across a wrapped row without branches.
grng = np.random.default_rng(99)
half = np.clip(np.rint(grng.normal(0, 36, 512 * 512 // 2)), -96, 96).astype(np.int8)
grain = grng.permutation(np.concatenate([half, -half])).reshape(512, 512)
np.concatenate([grain, grain[:, :16]], axis=1).tofile(os.path.join(OUT, "film-grain.i8"))
to8 = lambda a: Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))
# Keep the scrolling cloud paint behind the rough painted mountain boundaries.
sky_mask = np.asarray(Image.fromarray((region == SKY).astype(np.uint8) * 255).filter(ImageFilter.MinFilter(7)))
img, sky_paint = separate_sky_paint(img)
clouds = [sky_paint, ridge_glow_layer(), *cloud_layers()]
cloud_y0 = min(y for _, y, _, _, _ in clouds)
cloud_y1 = max(y + data.shape[0] for _, y, _, _, data in clouds)
sky_mask[cloud_y0:cloud_y1].tofile(os.path.join(OUT, "sky.a8"))
with open(os.path.join(OUT, "clouds.txt"), "w") as meta, open(os.path.join(OUT, "clouds.bin"), "wb") as output:
    meta.write(f"CLOUDS2 {W} {H} {cloud_y0} {cloud_y1 - cloud_y0} {len(clouds)}\n")
    for kind, y, speed, tint, data in clouds:
        meta.write(f"{kind} {y} {data.shape[0]} {speed} {' '.join(map(str, tint))}\n")
        output.write(data.tobytes())
still = to8(moon(glints(waterline(stars(with_clouds(img.copy()))))))
still.save(os.path.join(OUT, "full.png"))
monitors = W // 1920
for k in range(monitors):
    still.crop((k * 1920, 0, (k + 1) * 1920, H)).save(os.path.join(OUT, f"{k}.png"))

effects = []
base = np.asarray(to8(moon(waterline(stars(img, animated=True))))).astype(np.uint32)
# wl_shm XRGB8888, explicitly little endian (this flake is x86_64-linux).
argb = (0xff000000 | (base[:, :, 0] << 16) | (base[:, :, 1] << 8) | base[:, :, 2]).astype("<u4")
argb.tofile(os.path.join(OUT, "base.argb"))
moving_details()
with open(os.path.join(OUT, "scene.txt"), "w") as f:
    f.write(f"TWILIGHT1 {W} {H}\n")
    for effect in effects:
        f.write(effect[0] + " " + " ".join(f"{v:.8g}" for v in effect[1:]) + "\n")
