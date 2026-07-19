# Orbit Portfolio — Alessio Jeshili

A scroll-scrubbed "fly through the world" landing page. As you scroll, one camera flies
continuously through deep space and a neon sci-fi space station — each module it enters is
one of the services offered: **custom software**, **web showcase sites**, and **AI in
business systems**, ending on a command-deck call-to-action.

- **Art direction:** neon-night / cosmic (deep-space void, cyan/violet/magenta/amber neon).
- **Camera:** architecture A — one continuous forward take, no cuts, no rewind. See `RENDER.md`.
- **Engine:** `scrub-engine.js` (portable, vanilla JS, zero dependencies).

## Status

Render-ready **scaffold**. The page, engine, prompts, and pipeline are complete; the AI
footage isn't generated yet (needs the Higgsfield CLI). Right now the page shows a neon
**poster** version of each scene with all copy — fully viewable. Generate the flight with
`bash scripts/render.sh` once Higgsfield is installed + authed → **see `RENDER.md`**.

## Layout

```
index.html            the page — theme + all section copy (edit copy here)
scrub-engine.js       the scroll-scrub camera engine (do not need to edit)
RENDER.md             how to generate the footage (READ THIS to render)
prompts/
  style-preamble.txt  the shared visual style (kept identical across scenes)
  still_1..5.txt      one scene-still prompt per section
  leg_1..5.txt        one camera-leg prompt per section (architecture A)
scripts/
  render.sh           generate stills → chain legs → encode → posters (safe to re-run)
  knockout.py         optional background knockout (unused — scenes are full-bleed space)
assets/
  <id>.png            scene posters (placeholder nebula glows now; real frame 0 after render)
  vid/<id>.mp4        the camera legs (created by render.sh)
work/                 scratch: raw renders, boundary frames, job JSON (cache for re-runs)
```

## Preview

```bash
python3 -m http.server 8000   # then open http://localhost:8000
```

## Sections

1. **Arrival** — intro / who I am (hero, greets on landing)
2. **Custom Software** — tailored software systems
3. **Web Showcase Sites** — websites that make an impression
4. **AI in Business Systems** — AI integrated into company processes
5. **Command Deck** — CTA to alessiojeshili@gmail.com
