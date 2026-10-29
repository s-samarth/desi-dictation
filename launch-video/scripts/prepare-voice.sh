#!/usr/bin/env bash
# Get the takes the video uses ready to mix: cut each one to its speech (0.1 s
# before, 0.2 s after), take out rumble, and bring it to -17 LUFS, a normal
# loudness for voice over music, with peaks kept under -3 dB so voice plus
# music never clips.
#
#   ./scripts/prepare-voice.sh mail fillers chat
#
# Reads public/voice/<id>.wav and writes public/voice/mix/<id>.wav. It prints how
# long each one speaks: copy that into `speech` in src/voiceover.ts.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p public/voice/mix

for id in "$@"; do
  in="public/voice/$id.wav"
  length=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$in")
  # Speech runs from the first sound to the last; blips under 0.25 s (a click
  # as the recorder starts, the Enter key at the end) don't count.
  read -r start end < <(ffmpeg -hide_banner -i "$in" -af silencedetect=noise=-40dB:d=0.25 -f null - 2>&1 |
    grep -oE "silence_(start|end): [0-9.]+" |
    awk -v len="$length" '
      BEGIN { from = 0; quiet = 0 }
      /silence_start/ { if ($2 - from >= 0.25) { if (first == "") first = from; last = $2 } quiet = 1 }
      /silence_end/ { from = $2; quiet = 0 }
      END {
        if (!quiet && len - from >= 0.25) { if (first == "") first = from; last = len }
        if (first == "") { first = 0; last = len }
        print first, last
      }')
  from=$(awk -v s="$start" 'BEGIN { print (s > 0.1 ? s - 0.1 : 0) }')
  to=$(awk -v e="$end" -v l="$length" 'BEGIN { print (e + 0.2 < l ? e + 0.2 : l) }')
  ffmpeg -hide_banner -loglevel error -y -i "$in" -ss "$from" -to "$to" \
    -af "highpass=f=80,loudnorm=I=-17:TP=-3:LRA=11" -ar 48000 -ac 1 "public/voice/mix/$id.wav"
  printf '%-10s speech %.2f s\n' "$id" "$(awk -v e="$end" -v s="$start" 'BEGIN { print e - s }')"
done
