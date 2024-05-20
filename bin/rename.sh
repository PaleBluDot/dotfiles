#!/bin/bash

# Get the current working directory
dir="/Users/psanchez/github/PaleBluDot/aclu-emails/src/productions/rename"

# Ensure the directory exists
if [ ! -d "$dir" ]; then
  echo "Directory not found: $dir"
  exit 1
fi

# Iterate through each file in the directory
for file in "$dir"/*; do
  # Check if the file is a regular file
  if [ -f "$file" ]; then
    filename=$(basename -- "$file")
    extension="${filename##*.}"
    filename_noext="${filename%.*}"

    # Extracting parts from the filename
    IFS=' _-' read -r -a parts <<< "$filename_noext"

    # Ensure the file follows a valid pattern
    if [ ${#parts[@]} -ge 3 ]; then
      # Constructing the new filename
      new_filename="${parts[0]}${parts[1]} CO ${parts[2]}"
      new_filename="$new_filename.$extension"

      # Rename the file
      mv "$dir/$filename" "$dir/$new_filename"

      echo "Renamed: $filename -> $new_filename"
    else
      echo "Skipping invalid filename: $filename"
      echo "Parts: ${parts[@]}"
    fi
  else
    echo "Skipping non-regular file: $file"
  fi
done
