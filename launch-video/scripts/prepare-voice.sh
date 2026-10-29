#!/usr/bin/env bash
# Get the takes the video uses ready to mix: cut each one to its speech (0.1 s
# before, 0.2 s after), take out rumble, and bring it to -16 LUFS, a normal
# loudness for voice over music.
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
  silences=$(ffmpeg -hide_banner -i "$in" -af silencedetect=noise=-40dB:d=0.25 -f null - 2>&1 |
    grep -oE "silence_(start|end): [0-9.]+")
  # Speech starts where a leading silence ends, and stops where the last silence starts.
  start=0
  if grep -q "^silence_start: 0$" <<<"$silences"; then
    start=$(grep -m1 "silence_end" <<<"$silences" | cut -d' ' -f2)
  fi
  end=$(grep "silence_start" <<<"$silences" | tail -1 | cut -d' ' -f2)
  awk -v e="$end" -v s="$start" 'BEGIN { exit !(e <= s) }' && end=$length
  from=$(awk -v s="$start" 'BEGIN { print (s > 0.1 ? s - 0.1 : 0) }')
  to=$(awk -v e="$end" -v l="$length" 'BEGIN { print (e + 0.2 < l ? e + 0.2 : l) }')
  ffmpeg -hide_banner -loglevel error -y -i "$in" -ss "$from" -to "$to" \
    -af "highpass=f=80,loudnorm=I=-16:TP=-1.5:LRA=11" -ar 48000 -ac 1 "public/voice/mix/$id.wav"
  printf '%-10s speech %.2f s\n' "$id" "$(awk -v e="$end" -v s="$start" 'BEGIN { print e - s }')"
done
