#!/usr/bin/env bash

OUTPUT_HEIGHT=$(
  zenity --list \
    --title="Resize HEIGHT of the image to" \
    --print-column=1 \
    --column="Height" \
    2160 1440 1080 720
)

if [ -z $OUTPUT_HEIGHT ]; then
  exit 0
fi

echo -e "$NAUTILUS_SCRIPT_SELECTED_FILE_PATHS" | xargs -i convert "{}" -resize x$OUTPUT_HEIGHT "{}"
