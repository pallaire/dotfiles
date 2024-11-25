#!/bin/bash
# echo "Simple Scan All arguments: $@" >>/home/pallaire/bin/scan2ocr.sh.log
# filename="/home/pallaire/Downloads/$(date +%Y-%m-%d_%H:%M:%S)_scan.pdf"
# ocrmypdf -l eng+fra --force-ocr -d "$3" $filename
# rm "$3"

# Destination
tmpname=/home/pallaire/Documents/scans/scanpages.pdf
outname="/home/pallaire/Documents/scans/$(date +%Y-%m-%d_%H:%M:%S)_scan.pdf"

# Scan all the page with duplex to temp PNGs
scanimage --device-name="fujitsu:ScanSnap iX500:4624" --format=jpeg --mode Color --resolution 200 --brightness 32 --contrast 32 --source "ADF Duplex" --batch=/home/pallaire/Documents/scans/scanpages%03d.jpg

# Merge all images to pdf
magick convert /home/pallaire/Documents/scans/scanpages*.jpg $tmpname

# OCR the new PDF
ocrmypdf -l eng+fra --force-ocr -d $tmpname $outname

# Delete all images
rm /home/pallaire/Documents/scans/scanpages*.jpg
rm /home/pallaire/Documents/scans/scanpages.pdf

# Show the new file
pdfarranger $outname &
