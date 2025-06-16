#!/bin/bash

imagepath="$1"
workdt="$2"
trashpath="$3"

echo "Testing page ${imagepath} for blanks"
histogram=$(magick "${imagepath}" -threshold 50% -format %c histogram:info:-)

# Get the white and black values from the histogram
white=$(echo "${histogram}" | grep "white" | sed -n 's/^ *\(.*\):.*$/\1/p')
black=$(echo "${histogram}" | grep "black" | sed -n 's/^ *\(.*\):.*$/\1/p')

if [ -z $black ]; then
  black=0
fi

# Calculate using bc, the percentage of black, if it is under 1/2 a percent, it is white
blank=$(echo "scale=4; ${black}/${white} < 0.005" | bc)

if [ ${blank} -eq "1" ]; then
  pagenumber=$(echo "$i" | sed 's/[^0-9]//g')
  echo "${pagenumber} is blank removing it"
  mv $imagepath "${trashpath}/${workdt}_${pagenumber}.jpg"

fi
