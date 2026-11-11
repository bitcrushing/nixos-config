// Moonwater Ember: a warm analog glow for Rosé Pine Moon.
//
// The terminal texture is premultiplied. There is no background tint or sweep:
// only the text is treated. A tight warm phosphor glow hugs the glyphs, uneven
// ink keeps the glyph bodies from looking sterile, and animated film grain
// keeps the pane alive. Alpha passes through untouched.
//
// Colour comes from the live palette: slot 3 is rose, slot 5 is gold. The glow
// stays mostly gold with a slow drift toward rose for analog warmth.

const float GLOW_CORE = 0.020;
const float GLOW_HALO = 0.050;
const float FLICKER = 0.06;
const float SCANLINE = 0.035;
const float GRAIN = 0.009;
const float TEXT_INK = 0.060;
const float TEXT_TOOTH = 0.030;

// Grain is rotated off the screen axes so it cannot form rows or columns.
const mat2 GRAIN_ROT = mat2(0.80, 0.60, -0.60, 0.80);

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// Higher-quality hash for film grain; hash21 shows axis-aligned structure
// when it is evaluated per pixel over a large area.
float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x),
        mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x),
        u.y
    );
}

float fbm2(vec2 p) {
    return 0.667 * vnoise(p) + 0.333 * vnoise(p * 2.03 + 17.0);
}

vec3 toLinear(vec3 c) {
    return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

// 12 directions, rotated half a step so no tap lands on the screen axes.
// Sampling two rings instead of one removes the 8-lobed shell of the old
// halo: the inner ring keeps the rim tight, the outer one adds a soft tail.
const vec2 HALO_DIR[12] = vec2[12](
    vec2( 0.966,  0.259),
    vec2( 0.707,  0.707),
    vec2( 0.259,  0.966),
    vec2(-0.259,  0.966),
    vec2(-0.707,  0.707),
    vec2(-0.966,  0.259),
    vec2(-0.966, -0.259),
    vec2(-0.707, -0.707),
    vec2(-0.259, -0.966),
    vec2( 0.259, -0.966),
    vec2( 0.707, -0.707),
    vec2( 0.966, -0.259)
);

// How much a neighbouring texel looks like glyph rather than background.
float glyphAt(vec2 uv, vec3 bg) {
    vec4 t = texture(iChannel0, uv);
    vec3 c = t.rgb / max(t.a, 1e-4);
    return smoothstep(0.10, 0.32, distance(c, bg));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 p = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

    vec4 term = texture(iChannel0, uv);
    float a = term.a;
    vec3 col = term.rgb / max(a, 1e-4);

    vec3 bg = toLinear(iBackgroundColor);
    float text = smoothstep(0.10, 0.32, distance(col, bg));
    float lum = dot(col, vec3(0.2126, 0.7152, 0.0722));

    // Slow field that makes different parts of the text breathe
    // independently, plus a warped travelling shimmer.
    float breathe = fbm2(p * 3.2 + vec2(iTime * 0.50, -iTime * 0.35));
    float shimmer = 0.5 + 0.5 * sin(dot(p, vec2(8.0, 3.0)) - iTime * 1.6 + breathe * 5.0);
    float pulse = (0.84 + 0.26 * breathe) * (0.92 + 0.08 * shimmer);

    // Gentle analog flicker and a tiny horizontal waver on the glow only.
    float flick = vnoise(vec2(iTime * 1.1, 4.3));
    flick = 0.5 + 0.5 * (0.70 * flick + 0.30 * (0.5 + 0.5 * sin(iTime * 6.1)));
    float glowFlicker = 1.0 - FLICKER * (1.0 - flick);

    vec2 tx = 1.0 / iResolution.xy;
    float jitter = (vnoise(vec2(iTime * 1.4, p.y * 14.0)) - 0.5) * tx.x * 0.8;
    vec2 huv = uv + vec2(jitter, 0.0);

    // Phosphor halo: 12 directions on two rings. The inner ring at 2.1 px
    // keeps the rim tight, the outer ring at 4.0 px adds a soft tail. Weights
    // are calibrated so the near-rim brightness matches the old 8-tap ring.
    float halo = 0.0;
    for (int i = 0; i < 12; i++) {
        vec2 dir = HALO_DIR[i];
        halo += 0.120 * glyphAt(huv + dir * 2.1 * tx, bg);
        halo += 0.033 * glyphAt(huv + dir * 4.0 * tx, bg);
    }
    halo = clamp(halo, 0.0, 1.0);

    // Warmer gold/rose phosphor, with a paler core so glyphs stay legible.
    float warmth = 0.5 + 0.5 * sin(iTime * 0.17 + breathe * 3.0);
    vec3 warm = mix(toLinear(iPalette[5]), toLinear(iPalette[3]), 0.30 + 0.20 * warmth);
    vec3 core = mix(warm, toLinear(iForegroundColor), 0.55);

    // Fine static scanlines on the glow only, like phosphor lines.
    float scan = 1.0 - SCANLINE + SCANLINE * (0.5 + 0.5 * sin(fragCoord.y * 1.5708));
    float glowMod = pulse * glowFlicker * scan;

    // Glyph bodies are not perfectly flat: broad page unevenness plus a
    // character-scale field, so neighbouring letters catch the ink differently.
    // A fixed fine tooth roughens the strokes. Everything is multiplicative
    // and masked to the text, so contrast and the rim glow are untouched.
    float inkSlow = fbm2(p * 7.0 + vec2(iTime * 0.10, -iTime * 0.08));
    float inkChar = fbm2(p * 52.0 + vec2(-iTime * 0.24, iTime * 0.18));
    float ink = 0.35 * inkSlow + 0.65 * inkChar;
    float tooth = hash12(GRAIN_ROT * fragCoord * 2.3 + vec2(19.0, 3.0)) - 0.5;
    float bodyGain = 1.0 + TEXT_INK * (ink - 0.5) * 2.0 + TEXT_TOOTH * tooth;
    // UI panels differ from the terminal background too, but they are much
    // darker than every text colour. Gate on luminance so the ink lands on
    // glyphs (including text on panels) and not on flat chrome.
    float bodyMask = text * smoothstep(0.04, 0.14, lum);
    vec3 bodyCol = term.rgb * mix(vec3(1.0), vec3(bodyGain), bodyMask);

    vec3 outCol = bodyCol;
    // Core tint stays faint so glyph contrast survives; the warm rim does the
    // visible work and is kept off the glyph interior.
    outCol += core * (GLOW_CORE * text * glowMod);
    outCol += warm * (GLOW_HALO * halo * (1.0 - text) * glowMod);

    // Film grain: a slow, isotropic layer over a fixed one. The fixed part
    // keeps the pane textured between updates; the animated part is refreshed
    // at 8 fps and crossfaded, so it drifts rather than strobing like TV
    // static. Both halves are sampled on rotated coordinates.
    vec2 gq = GRAIN_ROT * fragCoord;
    float gPhase = iTime * 8.0;
    float gt = floor(gPhase);
    float gMix = smoothstep(0.0, 1.0, fract(gPhase));
    float ga = hash12(gq + vec2(gt * 37.0, gt * 91.0));
    float gb = hash12(gq + vec2((gt + 1.0) * 37.0, (gt + 1.0) * 91.0));
    // Crossfading halves the variance in the middle; restore it so the grain
    // does not pulse as it changes.
    float gNorm = inversesqrt(gMix * gMix + (1.0 - gMix) * (1.0 - gMix));
    float gAnim = 0.5 + (mix(ga, gb, gMix) - 0.5) * gNorm;
    float gFixed = hash12(gq * 1.7 + vec2(11.3, 7.1));
    float grain = (gAnim - 0.5) * 0.55 + (gFixed - 0.5) * 0.45;
    float grainMask = 1.0 - 0.80 * smoothstep(0.10, 0.60, lum);
    outCol += grain * (GRAIN * grainMask) * vec3(1.0, 0.94, 0.86);

    fragColor = vec4(max(outCol, 0.0), a);
}
