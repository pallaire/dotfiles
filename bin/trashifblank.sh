#!/usr/bin/env bash
set -euo pipefail

imagepath="$1"
workdt="$2"
trashpath="$3"

# Tunables (override from the environment if needed)
INK_LEVEL=${INK_LEVEL:-15}   # % darker than white, in any channel, to count as ink
MIN_INK=${MIN_INK:-0.0015}   # fraction of the page that must be ink (0.15%)
MARGIN=${MARGIN:-4}          # % trimmed off each edge (scanner shadows, punch holes)

# echo "Testing page ${imagepath} for blanks"

# Steps, in order:
#   shave        drop the edges, where shadows and holes live
#   resize       faster, and averages out scanner noise
#   negate + max ink = the biggest drop from white in any channel (catches coloured text)
#   median 3x3   removes isolated dust specks
#   threshold    anything past INK_LEVEL counts as ink
#   fx:mean      fraction of the page that is ink (0..1)
ink=$(magick "${imagepath}[0]" \
  -shave "${MARGIN}%x${MARGIN}%" \
  -resize '1200x1200>' \
  -negate -separate -evaluate-sequence max \
  -statistic median 3x3 \
  -threshold "${INK_LEVEL}%" \
  -format "%[fx:mean]" info:)

if awk -v a="$ink" -v b="$MIN_INK" 'BEGIN { exit !(a < b) }'; then
  pagenumber=$(basename "$imagepath" | tr -cd '0-9')
  echo "${pagenumber} is blank, removing it"
  mv "$imagepath" "${trashpath}/${workdt}_${pagenumber}.tiff"
fi