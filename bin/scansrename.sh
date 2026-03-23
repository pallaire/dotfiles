#!/bin/bash

# Check if any PDFs exist
shopt -s nullglob

files=($HOME/Documents/Scans/*.pdf)
if [[ ${#files[@]} -eq 0 ]]; then
  echo "No PDF files found in $HOME/Documents/Scans/"
  exit 1
fi

for file in "${files[@]}"; do
  echo "Processing $file"

  # remove spaces from filename
  newname="${file// /}" # Remove all spaces
  if [[ "$newname" != "$file" ]]; then
      mv "$file" "$newname"
  fi

  # ask AI to create a new file name
  AIname=$(claude -p "$(pdftotext -f 1 -l 1 "$newname" -) Generate a short, clean filename ( no extension ) based on this document. It should start with the date this document was sent, use the YYYY-mm-dd format, use today's date if you can't find it in the document. Then add the sender company name. Then 3-10 words about the document. Then is this for Amelie or Patrick. No special characters except spaces and dashes. No dash between the date and the sender. Dashes between every other parts. Do not include .pdf. If you cannot determine enough information to build a proper filename, reply with exactly: SKIP")
  
  # Strip any backticks or extra whitespace Claude might add
  AIname=$(echo "$AIname" | tr -d '`' | xargs)

  if [[ "$AIname" == "SKIP" ]]; then
    echo "Skipping, information can't be found"
    continue
  fi


  echo "AI new name would be : $AIname"

  mv "$newname" "$HOME/Documents/Scans/$AIname.pdf"

  echo ""

done