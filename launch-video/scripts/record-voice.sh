#!/usr/bin/env bash
# Record the launch video's dictated lines in your own voice.
#
#   ./scripts/record-voice.sh            every line in voice-lines.tsv, in order
#   ./scripts/record-voice.sh chat       one line again (by its id)
#
# It records the Mac's input device (System Settings → Sound → Input). Each
# take is saved to public/voice/<id>.wav (48 kHz mono), checked for level and
# played back, so you can keep it or redo it.
set -euo pipefail
cd "$(dirname "$0")/.."

OUT=public/voice
ONLY="${1:-}"
REC=scripts/.bin/rec
mkdir -p "$OUT" scripts/.bin
command -v ffmpeg >/dev/null || { echo "ffmpeg is missing: brew install ffmpeg"; exit 1; }
# macOS's own recorder (rec.swift): ffmpeg's mic capture spliced buffers here.
if [[ ! -x $REC || scripts/rec.swift -nt $REC ]]; then
  echo "Building the recorder (once)…"
  xcrun swiftc -O scripts/rec.swift -o "$REC"
fi

# Loudest moment of a take, in dB (0 is the most a file can hold).
peak() { ffmpeg -hide_banner -i "$1" -af volumedetect -f null - 2>&1 | grep -oE "max_volume: -?[0-9.]+" | cut -d' ' -f2; }

# One take of one line, repeated until you keep it. Returns 1 to quit.
record() {
  local id=$1 lang=$2 text=$3 file="$OUT/$1.wav" choice level
  while true; do
    printf '\n\033[1m%s\033[0m  (%s)\n\n    \033[1;33m%s\033[0m\n\n' "$id" "$lang" "$text"
    read -rp "Enter to start, then speak once it says Recording. " _
    "$REC" "$file" || return 1
    [[ -s $file ]] || { echo "Nothing was recorded. Does Terminal have the microphone? (System Settings → Privacy & Security → Microphone)"; return 1; }
    level=$(peak "$file")
    if awk -v p="$level" 'BEGIN { exit !(p < -12) }'; then
      echo "Too quiet (peak $level dB): turn the gain knob on the mic up, then redo. Aim for -6 to -3 dB."
    elif awk -v p="$level" 'BEGIN { exit !(p > -0.5) }'; then
      echo "Too loud (peak $level dB, it may distort): turn the gain down a little, then redo."
    else
      echo "Level OK (peak $level dB)."
    fi
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

echo "Say each line naturally, in your own tone."
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
