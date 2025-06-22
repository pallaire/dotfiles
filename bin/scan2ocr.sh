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
# scanimage --device-name="fujitsu:ScanSnap iX500:4624" --format=jpeg --mode Color --resolution 200 --brightness 16 --contrast 16 --source "ADF Duplex" --batch="${destwork}/scanpages%03d.jpg"
scanimage --device-name="net:localhost:fujitsu:ScanSnap iX500:4624" --format=jpeg --mode Color --resolution 200 --brightness 16 --contrast 16 --source "ADF Duplex" --batch="${destwork}/scanpages%03d.jpg"

# delete white pages
for i in "${destwork}/scanpages"*.jpg; do
  trashifblank.sh $i $workdt $destdeleted &
done

wait

# Merge all images to pdf
magick "${destwork}/scanpages"*.jpg $tmpname

# OCR the new PDF
ocrmypdf -l eng+fra --force-ocr -d $tmpname $outname

# Delete all images
rm "${destwork}/scanpages"*.jpg
rm "${destwork}/scanpages.pdf"

# Show the new file
# pdfarranger $outname &
