#!/usr/bin/env bash
# scan2ocr — scan a stack on the ScanSnap iX500 (duplex, colour), drop blank
# pages, deskew, OCR (English + French) and write one searchable PDF.
#
# Pages are cleaned up *while the scanner is still feeding*, so when the last
# sheet comes out only the PDF assembly and OCR are left.
set -euo pipefail

# ---- Settings --------------------------------------------------------------
destination="/home/pallaire/Documents/scans"
destwork="${destination}/work"
destdeleted="${destwork}/deleted"
device="fujitsu:ScanSnap iX500:4624"
resolution=200
jpeg_quality=75
languages="eng+fra"
output_type="${OUTPUT_TYPE:-pdf}"   # set OUTPUT_TYPE=pdfa for archival PDF/A (slower: adds a Ghostscript pass)
jobs=$(nproc)

workdt=$(date +%Y-%m-%d_%H%M%S)    # no colons: safer on SMB shares, macOS, Windows
outname="${destination}/${workdt}_scan.pdf"

[[ -d $destination ]] || { echo "Error: destination does not exist: $destination" >&2; exit 1; }
mkdir -p "$destdeleted"

# Private work folder per run, so leftovers from an aborted run can never end
# up in this PDF. Removed on success, kept on failure for inspection.
work=$(mktemp -d "${destwork}/run.${workdt}.XXXX")
finished=0
trap 'if [[ $finished == 1 ]]; then rm -rf "$work"; else echo "Stopped — work files kept in $work" >&2; fi' EXIT

# ---- Per-page work (runs in parallel, as pages arrive) ---------------------
# Each ImageMagick call gets one thread; parallelism comes from running
# several pages side by side instead of every magick grabbing every core.
export MAGICK_THREAD_LIMIT=1
export workdt destdeleted jpeg_quality resolution

process_page() {
  local tiff=$1
  trashifblank.sh "$tiff" "$workdt" "$destdeleted"
  [[ -f $tiff ]] || return 0            # blank: already moved to deleted/
  # Deskew and encode to JPEG once. This JPEG goes into the PDF untouched.
  magick "$tiff" -background white -deskew 40% +repage \
    -units PixelsPerInch -density "$resolution" \
    -quality "$jpeg_quality" "${tiff%.tiff}.jpg"
  rm -f "$tiff"
}
export -f process_page

# ---- Scan -------------------------------------------------------------------
# --batch-print writes each finished file name to stdout; xargs starts
# processing that page right away while the scanner keeps going.
echo "Scanning..."
set +e
scanimage \
  -d "$device" \
  --source 'ADF Duplex' \
  --mode Color \
  --resolution "$resolution" \
  --page-width 215.9 \
  --page-height 355.6 \
  --swcrop \
  --format=tiff \
  --batch="${work}/page%04d.tiff" \
  --batch-print \
| xargs -r -P "$jobs" -I{} bash -c 'process_page "$1"' _ {}
status=("${PIPESTATUS[@]}")
set -e

if (( status[1] != 0 )); then
  echo "Error: processing one or more pages failed" >&2
  exit 1
fi
# 7 = feeder empty, which is how a normal batch ends; anything else (jam,
# cover open, double feed...) means the PDF may be missing pages.
if (( status[0] != 0 && status[0] != 7 )); then
  echo "Warning: scanner stopped with an error (code ${status[0]}); check the page count" >&2
fi

shopt -s nullglob
pages=("$work"/page*.jpg)
if (( ${#pages[@]} == 0 )); then
  echo "No pages to save (feeder empty, or every page was blank)." >&2
  exit 1
fi

# ---- Assemble + OCR ---------------------------------------------------------
# img2pdf wraps the JPEGs as-is: no re-encoding, tiny memory use.
echo "Building PDF from ${#pages[@]} pages..."
img2pdf "${pages[@]}" -o "$work/scan.pdf"

# No --deskew (already done) and no --force-ocr (fresh scans have no text),
# so ocrmypdf only adds the text layer and never re-rasterizes the pages.
# --rotate-pages fixes upside-down / sideways sheets losslessly.
echo "Running OCR..."
ocrmypdf -l "$languages" --rotate-pages --output-type "$output_type" \
  --jobs "$jobs" "$work/scan.pdf" "$outname"

finished=1
echo "Saved $outname"
# pdfarranger "$outname" &