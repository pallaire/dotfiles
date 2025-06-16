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
  #   echo "Testing page ${i} for blanks"
  #   histogram=$(magick "${i}" -threshold 50% -format %c histogram:info:-)
  #
  #   # Get the white and black values from the histogram
  #   white=$(echo "${histogram}" | grep "white" | sed -n 's/^ *\(.*\):.*$/\1/p')
  #   black=$(echo "${histogram}" | grep "black" | sed -n 's/^ *\(.*\):.*$/\1/p')
  #
  #   if [ -z $black ]; then
  #     black=0
  #   fi
  #
  #   # Calculate using bc, the percentage of black, if it is under 1/2 a percent, it is white
  #   blank=$(echo "scale=4; ${black}/${white} < 0.005" | bc)
  #
  #   if [ ${blank} -eq "1" ]; then
  #     pagenumber=$(echo "$i" | sed 's/[^0-9]//g')
  #     echo "${pagenumber} is blank removing it"
  #     mv "${i}" "${destdeleted}/${workdt}_${pagenumber}.jpg"
  #   fi
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
