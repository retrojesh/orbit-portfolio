#!/bin/bash
# ============================================================================
# Orbit Portfolio — render pipeline (architecture A: continuous forward take)
# ----------------------------------------------------------------------------
# Generates 5 scene stills, then renders 5 camera legs SEQUENTIALLY (each leg
# starts from the previous leg's ACTUAL last frame — this is what makes every
# seam frame-identical while the camera only ever glides forward). No connectors.
#
# Requires: higgsfield CLI (authed), ffmpeg, jq, curl.
# Safe to re-run: finished stills/legs are cached in ./work and skipped.
# Resume after a failure by just running it again.
#
#   bash scripts/render.sh                 # standard (seedance_2_0, 1080p)
#   VMODEL=seedance_2_0_mini bash scripts/render.sh   # cheap previz (720p)
#   VMODEL=kling3_0 bash scripts/render.sh            # alternate provider
# ============================================================================
set -uo pipefail

P="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$P/work"; ASSETS="$P/assets"; PROMPTS="$P/prompts"
mkdir -p "$WORK" "$ASSETS/vid"

# Ordered section ids — MUST match index.html sections, in order.
IDS="arrival custom web ai deck"

# Chain video model. Architecture A needs --start-image; it must NOT use
# --end-image (an end-image forces the camera to pull back = seam stutter).
VMODEL="${VMODEL:-seedance_2_0}"
case "$VMODEL" in
  kling3_0)          VOPTS="--mode std --sound off";        LEG_DUR=10 ;;  # no --resolution on kling
  seedance_2_0_mini) VOPTS="--mode std --resolution 720p";  LEG_DUR=8  ;;  # cheap frame-locked previz
  *)                 VOPTS="--mode std --resolution 1080p"; LEG_DUR=8  ;;  # seedance_2_0 default
esac

# ---- preflight ------------------------------------------------------------
fail=0
command -v higgsfield >/dev/null || { echo "ERROR: higgsfield CLI not on PATH."; fail=1; }
command -v ffmpeg     >/dev/null || { echo "ERROR: ffmpeg not on PATH (brew install ffmpeg)."; fail=1; }
command -v jq         >/dev/null || { echo "ERROR: jq not on PATH (brew install jq)."; fail=1; }
command -v curl       >/dev/null || { echo "ERROR: curl not on PATH."; fail=1; }
[ "$fail" = 1 ] && exit 1
if ! higgsfield workspace list >/dev/null 2>&1; then
  echo "ERROR: higgsfield not authenticated. Run:  higgsfield auth login"; exit 1
fi
echo "Model: $VMODEL   opts: $VOPTS   leg duration: ${LEG_DUR}s"

# ---- 1. scene stills (concurrent) -----------------------------------------
gen_still() { # num
  local n="$1"
  if [ -s "$WORK/still_$n.png" ]; then echo "still $n cached"; return 0; fi
  higgsfield generate create gpt_image_2 --prompt "$(cat "$PROMPTS/still_$n.txt")" \
    --aspect_ratio 3:2 --resolution 2k --quality high --wait --wait-timeout 15m --json \
    > "$WORK/still_$n.json" 2> "$WORK/still_$n.err"
  local url; url=$(jq -r '.[0].result_url // empty' "$WORK/still_$n.json")
  if [ -n "$url" ]; then curl -fsSL "$url" -o "$WORK/still_$n.png" && echo "still $n ok"
  else echo "still $n FAIL — see work/still_$n.err (re-run to retry)"; fi
}
echo "== 1/3  generating 5 scene stills =="
for n in 1 2 3 4 5; do gen_still "$n" & done; wait
for n in 1 2 3 4 5; do [ -s "$WORK/still_$n.png" ] || { echo "Missing still_$n.png — re-run."; exit 1; }; done

# ---- 2. camera legs (SEQUENTIAL, chained) ---------------------------------
# leg 1 starts from still_1; leg k>1 starts from leg (k-1)'s real last frame.
render_leg() { # k id startimg
  local k="$1" id="$2" startimg="$3" attempt=1 url=""
  if [ -s "$WORK/leg_$k.mp4" ]; then
    echo "  leg $k ($id) cached"
  else
    while [ "$attempt" -le 3 ]; do
      echo "  leg $k ($id) attempt $attempt ..."
      higgsfield generate create "$VMODEL" --prompt "$(cat "$PROMPTS/leg_$k.txt")" \
        --start-image "$startimg" \
        $VOPTS --aspect_ratio 16:9 --duration "$LEG_DUR" \
        --wait --wait-timeout 20m --json > "$WORK/leg_$k.json" 2> "$WORK/leg_$k.err"
      url=$(jq -r '.[0].result_url // empty' "$WORK/leg_$k.json")
      [ -n "$url" ] && break
      echo "  leg $k attempt $attempt failed (NSFW / 503 / credit race?) — see work/leg_$k.json"
      attempt=$((attempt+1))
    done
    if [ -z "$url" ]; then
      echo "!! LEG $k ($id) FAILED after 3 tries. See RENDER.md 'NSFW fallback'. Nothing after it can render."
      return 1
    fi
    curl -fsSL "$url" -o "$WORK/leg_$k.mp4" || { echo "download failed"; return 1; }
  fi
  # boundary frames: first -> this scene's poster; last -> next leg's start image
  ffmpeg -v error -y -ss 0     -i "$WORK/leg_$k.mp4" -frames:v 1 -q:v 2 "$WORK/first_$k.png"
  ffmpeg -v error -y -sseof -0.15 -i "$WORK/leg_$k.mp4" -frames:v 1 -q:v 2 "$WORK/last_$k.png"
  # Sanity nudge: eyeball work/last_$k.png before trusting the next leg (see RENDER.md).
  echo "  leg $k ($id) ready"
}
echo "== 2/3  rendering 5 legs sequentially (this is the slow part) =="
set -- $IDS
k=0; start="$WORK/still_1.png"
for id in "$@"; do
  k=$((k+1))
  render_leg "$k" "$id" "$start" || exit 1
  start="$WORK/last_$k.png"
done

# ---- 3. encode for scrubbing + posters ------------------------------------
enc() { ffmpeg -v error -y -i "$1" -an \
  -vf "minterpolate=fps=48:mi_mode=mci:mc_mode=aobmc:vsbmc=1,scale=w='if(lt(iw,1920),1920,iw)':h=-2:flags=lanczos,unsharp=5:5:0.45:5:5:0.0" \
  -c:v libx264 -preset slow -crf 19 -pix_fmt yuv420p \
  -g 1 -movflags +faststart "$2"; echo "  enc $2 ($(du -h "$2"|cut -f1))"; }
echo "== 3/3  encoding clips + posters =="
k=0
for id in $IDS; do
  k=$((k+1))
  enc "$WORK/leg_$k.mp4" "$ASSETS/vid/$id.mp4"
  cp "$WORK/first_$k.png" "$ASSETS/$id.png"   # poster == leg's own first frame (exact match)
done

echo ""
echo "DONE. Preview with:  cd \"$P\" && python3 -m http.server 8000   then open http://localhost:8000"
