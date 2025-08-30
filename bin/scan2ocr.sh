#!/bin/bash

# Destinations
destination="/home/pallaire/Documents/scans"
destwork="${destination}/work"
destdeleted="${destwork}/deleted"
workdt=$(date +%Y-%m-%d_%H:%M:%S)
tmpname="${destwork}/scanpages.pdf"
outname="${destination}/${workdt}_scan.pdf"

if [ ! -d "$destination" ]; then
  echo "Error: Folder destination path does not exist: $destination"
  exit 1
fi

if [ ! -d "$destdeleted" ]; then
  echo "Creating working folders"
  mkdir -p $destdeleted
fi

# Scan all the page with duplex to temp PNGs
# Setup the page size as LEGAL, if pages are LETTER the scaner will cut them automatically
scanimage --device-name="fujitsu:ScanSnap iX500:4624" --format=tiff --mode Color --resolution 200 --brightness 16 --contrast 16 --source "ADF Duplex" --ald=yes --page-width 215.9 --page-height 355.6 -y 355.6 -x 215.9 --batch="${destwork}/scanpages%03d.tiff"

# delete white pages
for i in "${destwork}/scanpages"*.tiff; do
  trashifblank.sh $i $workdt $destdeleted &
done

wait

# Merge all images to pdf
magick "${destwork}/scanpages"*.tiff $tmpname

# OCR the new PDF
ocrmypdf -l eng+fra --force-ocr -d $tmpname $outname

# Delete all images
rm "${destwork}/scanpages"*.jpg
rm "${destwork}/scanpages"*.tiff
rm "${destwork}/scanpages.pdf"

# Show the new file
# pdfarranger $outname &
