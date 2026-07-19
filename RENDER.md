# Rendering the flight — Orbit Portfolio

This project is **render-ready**: the page, engine, prompts, and pipeline are done. The only
thing not yet generated is the AI footage (needs the Higgsfield CLI, which wasn't available
when the scaffold was built). Until you render, the page shows the neon **poster** version of
each scene with all copy — perfectly viewable, just no camera motion.

## Camera architecture: A (continuous forward take)

One camera that only ever glides **forward** — deep space → into a module → out the far side →
into the next module, as a single unbroken take. There are **no connector clips**: the legs
*are* the journey. Each leg starts from the *previous leg's actual last frame*, so every seam
is frame-identical while the camera never reverses (no rewind stutter). This is the right shape
for an immersive space flight; architecture B (dive → pull up to a map → fly over) is only for
god's-eye diorama worlds.

## Prerequisites

| Need | Status | Action |
|---|---|---|
| `ffmpeg` / `ffprobe` | ✅ installed | — |
| `jq`, `curl` | ✅ present | — |
| **`higgsfield` CLI** | ❌ **you must install** | It's a proprietary CLI (not the PyPI `higgsfield` package). Install per the `higgsfield-generate` skill / Higgsfield's docs. |
| Higgsfield auth | ❌ | `higgsfield auth login` (interactive OAuth — only you can run it), then `higgsfield workspace set <id>` if needed |
| Credits | ❌ | Confirm balance with `higgsfield workspace list` before rendering |

## Budget (architecture A = N stills + N videos, no connectors)

For 5 scenes: **5 stills + 5 legs**, plus ~15% re-roll headroom ≈ **5 stills + ~6 videos**.

The CLI exposes no pricing and plans differ, so **calibrate before the full run**: generate ONE
still and ONE leg, diff `higgsfield workspace list` before/after, then extrapolate. As a *rough*
prior (observed on a plus plan, not guaranteed): a still ≈ 15 credits, a standard `seedance_2_0`
video ≈ 40–55 → ballpark **~300–360 credits** for the whole flight. Verify against your own numbers.

Cheap previz path: run the whole chain on `seedance_2_0_mini` first (720p, ~¼ cost, still
frame-locked so it's seamless), approve the journey, then re-render on the standard model.

## Run it

```bash
cd ~/Documents/orbit-portfolio
bash scripts/render.sh                          # standard: seedance_2_0, 1080p
# VMODEL=seedance_2_0_mini bash scripts/render.sh   # cheap 720p previz
# VMODEL=kling3_0        bash scripts/render.sh   # alternate provider (different NSFW filter)
```

It is **safe to re-run**: finished stills and legs are cached in `./work/` and skipped, so a
failure mid-flight resumes where it stopped. The script:

1. Generates 5 stills concurrently (`prompts/still_1..5.txt`).
2. Renders 5 legs **sequentially** (`prompts/leg_1..5.txt`), each chained from the previous
   leg's real last frame — 3 auto re-rolls per leg on NSFW/503/credit hiccups.
3. Encodes each leg → `assets/vid/<id>.mp4` (crf 19, sharpen, motion-interpolated to 48fps,
   upscaled to ≥1080p if the render is smaller, all-intra — every frame a keyframe, so
   scroll-scrubbing seeks are instant — faststart) and
   writes each leg's **first frame** as its poster `assets/<id>.png` (so poster == video frame 0).

Legs are sequential by nature (leg *k* needs leg *k−1*'s output), so this is the slow part —
budget ~5–8 min per leg.

### The one rule that makes or breaks it

Because each leg feeds the next, **a bad last frame poisons every leg after it**. After the
script renders a leg, glance at `work/last_<k>.png` before trusting the chain: it should look
like a frame from a calm forward glide (no sideways motion blur, no half-finished move). If it's
off, delete `work/leg_<k>.mp4` and re-run to re-roll just that leg.

## If a leg keeps getting flagged NSFW

Seedance's content filter sometimes false-flags innocent interiors. In order:

1. **Re-run** — it's often non-deterministic (the script already tries 3×). Delete
   `work/leg_<k>.mp4` first isn't needed; a failed leg leaves no mp4.
2. **Scrub the prompt** in `prompts/leg_<k>.txt` — remove trigger words, add
   "empty, unoccupied, no people, architectural, tasteful".
3. **Fall back to Kling for that one leg**: `VMODEL=kling3_0 bash scripts/render.sh` (it resumes
   from cache, so only the missing leg renders, on Kling's different filter). Expect a slight
   grain/motion shift on that single clip — acceptable, and better than a missing leg.

## Preview

```bash
cd ~/Documents/orbit-portfolio
python3 -m http.server 8000
# open http://localhost:8000
```

Works before rendering too (shows posters + copy). The engine loads each clip as a Blob, so it
does **not** need a byte-range-serving host — any static server or `python -m http.server` is fine.

## QA the seams once footage exists (Step 8)

- Scroll slowly across each seam (between legs): the last frame of one leg and the first frame of
  the next must be near-identical — that's guaranteed by the frame handoff + the 0.08 crossfade.
  A visible pop means a leg's last frame was bad (re-roll that leg).
- Console: confirm no errors and `video.seekable.end(0) > 0` (blob seeking works).
- Reduced-motion: the page should fall back to posters, no video, no particles.
- Phone: the engine hardens phone scrubbing automatically (seek-coalescing, iOS priming,
  safe-area). You chose **desktop-only**, so there's no native 9:16 chain — phones get the 16:9
  film, degraded gracefully. To add a true mobile version later, render a parallel 9:16 chain
  (SKILL Step 6b) and wire `clipMobile`/`stillMobile`.

## Editing copy

All headlines/body/tags live in `index.html` under `sections[]`. Edit freely — text is decoupled
from the footage. The scene **visuals** are driven by `prompts/still_*.txt` and `prompts/leg_*.txt`;
if you change what a room *contains*, update both the still and the leg prompt for that scene and
re-render from that leg onward (delete its `work/leg_<k>.mp4` and everything after it).
