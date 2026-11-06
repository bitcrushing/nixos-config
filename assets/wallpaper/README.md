# Twilight wallpaper

`generate.py` paints the landscape from Stylix at build time. It exports a
static PNG for the greeter/lock screen, a memory-mappable XRGB image and a
small list of star, ripple, firefly and occasional shooting-star coordinates,
plus a signed sky-paint detail band, an anchored ridge glow, alpha-only
haze/cloud bands, sky masks, and a small balanced film-grain tile.
`modules/desktop/wallpaper.nix` configures the monitor order and frame rate.

`pkgs/twilight-wallpaper` is a native Wayland layer-shell client with no GUI
toolkit, video decoder or shader loop. It restores/draws only the rectangles
containing details or a changed cloud strip between film refreshes. Damage is batched into 128×32-pixel tiles:
hundreds of individual star-sized texture uploads cost niri much more CPU than
copying a little unchanged paint along with them.
Two reusable shared-memory buffers per monitor avoid allocations and tearing;
the base image is a read-only file mapping, not an in-memory animation cache.
For two 1080p monitors the image/buffer storage is about 48 MiB, plus a little
metadata and library overhead (the compositor has its own costs).

## Lossless optimizations

The generator batches stroke colours and geometry in NumPy, keeping the original
interleaved random draws and drawing order. Palette matching uses cache-sized
chunks and accumulates RGB distances channel by channel, rather than allocating
a pixels × palette × channels tensor. Coordinates use broadcast rows/columns,
and source canvases are released after joining the lake and landscape.
There is no reduced resolution, float32 conversion,
approximate palette search, or change to the seeds, dither or brush coverage.
Keeping NumPy/Pillow avoids having to reproduce their RNG and rasterization
semantics in a full rewrite; the desktop renderer is already manually managed C.

The C renderer precomputes runs of visible destination pixels for each sky layer
and their union. Composition and restoration skip masked mountain interiors;
haze damage tiles also exclude fully masked terrain. Grain and sky interpolation
use eight-pixel AVX2 kernels when supported, with the original four-pixel SSE2
fallback and identical integer rounding. All run lists are allocated at startup,
not per frame; no extra image cache or worker thread is introduced.

The alpha-only haze/cloud compositor also blends eight pixels at a time with
AVX2, splitting source runs at panorama wraps instead of checking wrapping and
layer type for every pixel. Its integer `/255` is exact, not the common `/256`
approximation. Subpixel alpha sampling still rounds before colour blending,
destination masks stay fixed, and non-AVX2 machines use the scalar reference.

`--check` compares both SIMD paths with scalar references, including short tails
and grain-tile boundaries. Alpha tests cover all 257 subpixel weights, short
runs, zero/full alpha and colour extremes; division is checked over its entire
numerator range. It also verifies that every changed displayed pixel
is covered by compositor damage, in addition to checking reusable buffers against
fresh rendering.

First-pass measurements on the Ryzen 9 3900X with the configured 3840×1080 `paintcrush` scene
(medians of three runs, without Python profiling):

| Work | Before | After |
| --- | ---: | ---: |
| Generate all assets, wall time | 25.5 s | 12.1 s |
| Generator peak RSS | 1161 MiB | 938 MiB |
| Render 100 s headlessly, CPU time | 16.9 s | 13.0 s |

The renderer samples use both outputs, 24 fps, grain at 8 fps/strength 0.8,
alternating buffers and four wrap/time jumps. Runtime RSS stayed around 79 MiB.
This is about 23% less renderer CPU work, not a measured compositor/GPU power
saving; resolution, cadence and effects are unchanged. Generated files matched
byte-for-byte for all four texture modes across two tested layouts/palettes,
and all 4,808 output frames in the original/optimized renderer comparison matched.
The NixOS build, damage checks, and ASan/UBSan kernel/scene smoke checks passed.

### Live desktop measurements

Instrumented previews on the actual two-monitor desktop, with the same scene,
24 fps target and 8 fps/0.8-strength grain. Each sample had a 5-second warmup
and a 30-second measurement window; the first-pass result was repeated.

| Metric | Original | First pass | SIMD haze blend |
| --- | ---: | ---: | ---: |
| Renderer CPU, % of one core | 14.8% | 10.8% | 9.0% |
| Renderer RSS | 79.2 MiB | 79.4 MiB | 79.4 MiB |
| Renderer PSS | 60.9 MiB | 61.0 MiB | 61.0 MiB |
| Submitted fps per output | 23.4 | 23.7 | 23.7 |
| Mean pixel-paint time per output | 2.12 ms | 1.46 ms | 1.45 ms |
| Mean shared sky keyframe work, at 2 Hz | 23.7 ms | 18.9 ms | 9.9 ms |

Pixel-paint timings exclude the shared keyframe work; submitted fps is not a
presentation-latency measurement. The new alpha blend saves about 17% of renderer
CPU versus the first pass, or 39% versus the original, without reducing cadence.
Niri used roughly 12–13% of a core for the whole desktop. Whole-GPU power stayed
around 41–42 W, with no clear reduction: unchanged film cadence still damages
the full scene at 8 Hz. Neither figure isolates the wallpaper's compositor/GPU
cost. These short desktop samples are not universal power/performance guarantees.
The original service was restored after the previews; activation is still `nrs`.

## Film character and ridge contrast

Fine, monochrome emulsion grain refreshes at 8 fps while sky motion stays at
24 fps. Its amplitude follows luminance: roughly one RGB level in the mountain
midtones at the default strength, less in deep shadows, without lifting pure
black. It adds the same offset to all colour channels, not coloured TV snow,
scanlines, scratches or moving silhouettes. A slow, mixed-period exposure drift
is restrained to about ±0.25% at the default strength.

The noise comes from a balanced 512×512 signed-byte tile with changing row/block
phases, not a full-frame random-number generator or a sequence of cached frames.
SSE2/AVX2 applies it to restored pixels. When one shared-memory buffer already has
the current emulsion, the other copies it and redraws only changed sky/sprites;
there is no extra full-screen cache. A fresh noise epoch does damage the whole
wallpaper, so this costs more compositor/GPU work than sky-only animation.

`grainStrength` and `grainFps` in `modules/desktop/wallpaper.nix` control the look
and cadence. Strength 0 disables grain and exposure drift entirely; lowering
the grain fps reduces full-scene damage. Equivalent runtime variables are
`TWILIGHT_GRAIN_STRENGTH` (0..2) and `TWILIGHT_GRAIN_FPS` (1..24).
A short on/off preview at 24 fps measured about 15.4% versus 9.3% of one CPU
core for the renderer, 79.3 versus 78.8 MiB RSS, and 37 versus 34 W total GPU
power. These are noisy whole-session samples, not isolated GPU attribution.
An actual mountain crop measured about 0.83 RGB levels of temporal variation;
all sampled changes were monochrome, with under 0.04 levels of frame-to-frame
change in the patch's mean brightness.

The dark fringe on the main peak's left slope is reduced locally, not removed.
A feathered correction lifts only the darker part of the narrow edge toward a
reference on the same side of the silhouette. It never blurs mountain colours
across the sky boundary and leaves some contrast to define the peak.
Matched starting-frame references measured roughly 25% less mean dark-fringe
contrast in the sampled part of the slope; it is not flattened or fully erased.

The painted sky above the ridgeline drifts at 1 pixel/sec. The source is painted
as one uninterrupted rectangle from the clean sky gradient: no lit terrain
pixels, visible/hidden sky split, or ridge highlight is copied into it. Splitting
the source at the skyline previously imprinted a contour that drifted like a
ghost ridge. Mountains now enter only through the stationary destination mask.
Medium-scale signed RGB detail is separated from that terrain-free
painting and removed from the base image before being added back at its moving
position. This replaces the stationary brush pattern, rather than adding another
haze overlay. The broad illumination, mountain edges and fine canvas/dither stay fixed.
A feathered, stationary mask follows the skyline; damage is limited to tiles
that intersect it. At time zero the separated detail reconstructs the painting
to within one RGB level, checked by the generator.
Actual desktop captures measured 20/70 pixels of brush-detail travel after
20/70 seconds, with the sampled mountain region remaining pixel-identical.
Rendering continued beyond the old 60-second idle cutoff; manual pause still
showed zero CPU-time growth in a one-second check.

The sky-facing ridge glow is a separate additive layer. Narrow and wider halo
masks are fixed to the real skyline and are zero inside the terrain. A smooth,
terrain-free periodic modulation field drifts with the sky, gently changing the
mix of those widths and brightness (about ±14%), plus a restrained 72-second
breathing cycle. Neither glow mask scrolls, so a second mountain outline cannot
peel away. These changes are included in the existing 2 Hz keyframes/24 fps
interpolation; there is no extra render loop or full-screen surface.
Desktop captures at roughly 757 seconds of drift confirmed the previous floating
outline was gone. In a 20-second preview, about two thirds of sampled glow-only
sky pixels changed subtly while the sampled mountain interior stayed identical.
Before the film pass, the glow version used about 9.4% of one CPU core and 79 MiB RSS, versus 8.6% /
75 MiB for the previous version in that short session. Sky assets and both
keyframe caches now total 28.30 MiB. GPU power samples were not isolated enough
to attribute a reliable delta to this change.

The sky now uses subpixel sampling instead of one-pixel jumps. Fully composited
sky keyframes are cached every half-second, with horizontal linear interpolation
inside each source layer. A cheap integer SIMD blend between the two cached sky images
supplies the 24 fps intermediate frames. It avoids re-compositing all sky
layers 24 times/sec, optical flow, full-screen video, or a GPU shader loop.
Overlapping sky-layer support is merged before restoring buffers, so its visible
runs are blended only once per output frame. Only the sky band gets a second keyframe
cache (about 6.74 MiB extra here); this is not a full-resolution frame sequence.
The skyline masks and canvas never translate; the glow morphs only inside its
anchored support.
An actual 24 fps desktop capture showed paint changes on 45 of 47 captured frame
intervals, versus 5 with the old whole-pixel renderer at the same fps setting;
the largest sampled frame-to-frame paint change fell by about 60%.

Before the separate glow, a short live comparison measured about 8.1% of one CPU core for the interpolated
renderer at 24 fps, versus 6.2% at 12 fps; both used about 75 MiB RSS (including
shared buffers). Total GPU power was about 38 W versus 32 W in that session.
These are noisy whole-session samples, not isolated wallpaper power figures.
12 fps with interpolation is the lower-power alternative; 24 fps is configured
as requested. Manual pause still stopped renderer CPU usage in the check.

Two broad, textured haze layers drift behind the streaks at 0.8 and 1.2
pixels/sec: cool iris/foam haze higher up, warmer rose/gold haze near the horizon.
They move about 24/36 pixels in 30 seconds, so motion is more apparent than the
thin wisps alone. Their periodic textures are generated once at build time.
The underlying gradient/fine canvas, star positions, crescent and mountains stay put;
this animates the atmosphere rather than scrolling the whole landscape.
Timed desktop captures confirmed the upper haze moved 16 pixels in 20 seconds,
with the sampled mountain region remaining pixel-identical.

The original three cloud streaks still scroll independently at 0.25–0.45 pixels/sec,
alongside two fainter wisps. All bands wrap across the entire panorama, not at the
monitor seam. A sky mask keeps them behind the mountains. Only the affected sky
band has an extra composited cache; there is no second full-screen background.
Layers are composed at 2 Hz; interpolation updates the moving sky regions at
the scene's 24 fps, while the rest of the landscape remains untouched. The still
used by the greeter and lock screen includes the haze/clouds at their initial positions.
Before adding subpixel interpolation the sky assets/cache totalled 18.24 MiB,
versus 10.49 MiB before separating the original paint. A short 12 fps A/B preview measured about
4.5% of one CPU core for the renderer (previously 2%) and 69 MiB RSS, including
shared buffers. Niri stayed around 7.2–7.6% of one core and total GPU power was
about 35 W with both animated versions. These short whole-session samples do
not establish a precise incremental power cost or a still-wallpaper baseline.

Updates are capped at 24 fps and gated by compositor frame callbacks, so outputs
that stop receiving frames don't run a timer. There is no inactivity timer:
animation keeps running while the desktop is visible, even without input.
Lock-screen/fullscreen occlusion and monitor-off throttling depend on which
surfaces the compositor continues to send frames to; there is no separate
polling loop or idle inhibitor. SIGUSR1 still pauses manually.
No animation can use as little GPU power as a still, especially with desktop
blur enabled. Sparse damage limits uploads, but does not control the compositor's
blur-cache invalidation or GPU clock policy.

The visible preset uses wider, brighter ripples with twice the travel, larger
star glows and deeper twinkles, brighter wandering fireflies, and longer meteor
trails every 47/61 seconds. The base painting and buffer allocation are unchanged;
24 fps, the larger details, and film grain increase compositor work over the subtle preset.

Before adding scrolling clouds, a short 12 fps animated/frozen comparison
measured about 0.5% of one CPU core for the renderer and 50 MiB RSS (including
shared buffers; about 34 MiB PSS). Niri used 10.8% versus 6.2% of one core, and
total GPU power was about 42 W versus 26 W. The compositor/GPU cost matters
much more than the renderer's own CPU usage. These are whole-session samples,
not isolated GPU guarantees or measurements of the added cloud cache.

Pause/resume without losing the background:

```sh
systemctl --user kill --signal=SIGUSR1 twilight-wallpaper.service
```

Lower `fps` in `modules/desktop/wallpaper.nix` for a quieter desktop. In particular,
12 fps with subpixel interpolation is still much smoother than the old one-pixel
sky steps and reduces display/compositor work versus 24 fps.
The login and lock screens always use the still. Noctalia GUI overrides in
`~/.local/state/noctalia/settings.toml` win over Nix settings: if its desktop
wallpaper was manually enabled, turn it off there to avoid covering this one.

The build runs `twilight-wallpaper --check SCENE_DIR HDMI-A-1 HDMI-A-2`:
100 seconds of headless animation at 24 fps are compared to freshly rendered frames to
catch stale pixels/incorrect sprite bounds in the reusable buffers. Monitor
seams, cloud wrapping, interpolation rounding/keyframe continuity and long
pause/resume time jumps are covered too. Monitor
names/order and dimensions must match the generated scene (currently 2×1080p,
scale 1); reconnecting a configured monitor is supported.
Film checks compare SIMD and scalar results across tile boundaries, verify pure
black and the configured refresh cadence, and exercise alternating buffers to
catch noise accumulation or copied sprite trails.

The glow test freezes the other layers and jumps 757 seconds ahead, checking
that brightness/softness evolve but no pixel outside the fixed halo masks changes.
`TWILIGHT_TIME_OFFSET=757` can reproduce a long-drift preview immediately without
waiting twelve minutes; it defaults to zero and is not set by the user service.
