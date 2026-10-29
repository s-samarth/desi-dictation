#!/usr/bin/env bash
# Record the launch video's dictated lines in your own voice.
#
#   ./scripts/record-voice.sh            every line in voice-lines.tsv, in order
#   ./scripts/record-voice.sh chat       one line again (by its id)
#   MIC="MacBook Air Microphone" ./scripts/record-voice.sh    another mic
#
# Each take is saved to public/voice/<id>.wav (48 kHz mono) and played back,
# so you can keep it or redo it. List the mics with:
#   ffmpeg -f avfoundation -list_devices true -i ""
set -euo pipefail
cd "$(dirname "$0")/.."

MIC="${MIC:-DGM20 USB Microphone}"
OUT=public/voice
ONLY="${1:-}"
mkdir -p "$OUT"
command -v ffmpeg >/dev/null || { echo "ffmpeg is missing: brew install ffmpeg"; exit 1; }

# One take of one line, repeated until you keep it. Returns 1 to quit.
record() {
  local id=$1 lang=$2 text=$3 file="$OUT/$1.wav" choice pid
  while true; do
    printf '\n\033[1m%s\033[0m  (%s)\n\n    \033[1;33m%s\033[0m\n\n' "$id" "$lang" "$text"
    read -rp "Enter to start (wait half a second, then speak). " _
    ffmpeg -hide_banner -loglevel error -y -f avfoundation -i ":$MIC" -ac 1 -ar 48000 "$file" </dev/null &
    pid=$!
    read -rp "● Recording. Enter to stop. " _
    kill -INT "$pid"
    wait "$pid" || true
    [[ -s $file ]] || { echo "Nothing was recorded. Does Terminal have the microphone? (System Settings → Privacy & Security → Microphone)"; return 1; }
    echo "Playing it back…"
    afplay "$file"
    read -rp "[k]eep (Enter), [r]edo, [q]uit? " choice
    case $choice in
      r*) continue ;;
      q*) return 1 ;;
      *) return 0 ;;
    esac
  done
}

echo "Mic: $MIC. Say each line naturally, in your own tone."
found=""
while IFS=$'\t' read -r -u 3 id lang text; do
  [[ -z $ONLY || $id == "$ONLY" ]] || continue
  found=1
  record "$id" "$lang" "$text" || exit 0
done 3< voice-lines.tsv

[[ -n $found ]] || { echo "No line called '$ONLY'. The ids are the first column of voice-lines.tsv."; exit 1; }
echo
echo "Done. Takes are in launch-video/$OUT/:"
ls "$OUT"
