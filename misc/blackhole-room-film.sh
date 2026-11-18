#!/bin/bash
# Renders the film of a black hole circling the room from
# examples/blackhole-room.dx, one frame per phase of the hole's orbit.
#
# Usage, from the top of the repository:
#
#   misc/blackhole-room-film.sh OUT.mp4 [FRAMES] [PIXELS] [SAMPLES] [BOUNCES] [WORKERS]
#
# The defaults (240 frames of 240x240 pixels, 20 samples per pixel, 4 bounces,
# 8 workers) take a few hours of CPU time. Dex evaluates on one core, so the
# frames are shared out between several Dex processes.
#
# Set DEX to choose the compiler, e.g. DEX=/path/to/dex. Needs ffmpeg.

set -euo pipefail

out=${1:?usage: $0 OUT.mp4 [FRAMES] [PIXELS] [SAMPLES] [BOUNCES] [WORKERS]}
frames=${2:-240}
pixels=${3:-240}
samples=${4:-20}
bounces=${5:-4}
workers=${6:-8}
dex=${DEX:-stack exec dex --}

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir "$work/frames"

for ((w = 0; w < workers; w++)); do
  count=$(( (frames - w + workers - 1) / workers ))
  {
    cat examples/blackhole-room.dx
    cat <<DRIVER

film_camera = Camera $pixels (10.0 .* z_hat) 0.3 1.0
film_params = Params $samples $bounces True 550.0

def render_frame(f:Nat) -> {IO} () =
  hole = orbiting_hole (n_to_f f / $frames.0)
  h : Hamiltonian = \\x p. room_kerr(hole, x, p)
  name = "$work/frames/frame-" <> show (1000 + f) <> ".png"
  write_file name (img_to_png (take_picture film_params h hole the_room film_camera))

unsafe_io \\. for j:(Fin $count). render_frame ($w + $workers * ordinal j)
DRIVER
  } > "$work/worker-$w.dx"
  # Test mode keeps the example's own two pictures tiny.
  DEX_TEST_MODE=t $dex --lib-path lib script "$work/worker-$w.dx" > "$work/worker-$w.log" 2>&1 &
done
wait

rendered=$(ls "$work/frames" | wc -l | tr -d ' ')
if [ "$rendered" -ne "$frames" ]; then
  keep=$(mktemp -d)
  cp "$work"/worker-*.log "$keep"
  echo "Only $rendered of $frames frames were rendered. Logs are in $keep" >&2
  exit 1
fi

ffmpeg -y -loglevel error -framerate 60 -start_number 1000 \
  -i "$work/frames/frame-%d.png" \
  -vf "scale=720:720:flags=lanczos" \
  -c:v libx264 -pix_fmt yuv420p -crf 14 -movflags +faststart "$out"
echo "Wrote $out ($frames frames at 60 fps)"
