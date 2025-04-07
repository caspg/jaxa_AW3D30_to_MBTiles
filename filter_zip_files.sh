#!/bin/bash

# filter-dem-regions.sh
#
# This script filters ALOS AW3D30 DEM links from an input file and saves
# links for specific regions (Europe, North America, Australia, New Zealand,
# South Korea, and Taiwan) to a single output file.
#
# Usage: ./filter-dem-regions.sh [input_file] [output_file]

# Default input and output file names
INPUT_FILE=${1:-"file_list_zip.txt"}
OUTPUT_FILE=${2:-"file_list_zip_veloplanner.txt"}

# Check if input file exists
if [ ! -f "$INPUT_FILE" ]; then
  echo "Error: Input file '$INPUT_FILE' not found."
  exit 1
fi

echo "Filtering DEM links from $INPUT_FILE..."

# Create/empty the output file
> "$OUTPUT_FILE"

# Counter for filtered links
FILTERED_COUNT=0

# Process each line in the input file
while read -r url; do
  # Skip empty lines
  [ -z "$url" ] && continue
  
  # Extract coordinates from the URL pattern
  # Format: https://www.eorc.jaxa.jp/ALOS/aw3d30/data/release_v2303/[NS]XXX[EW]XXX_[NS]XXX[EW]XXX.zip
  if [[ $url =~ \/([NS])([0-9]+)([EW])([0-9]+)_([NS])([0-9]+)([EW])([0-9]+)\.zip$ ]]; then
    start_ns="${BASH_REMATCH[1]}"
    start_lat="${BASH_REMATCH[2]}"
    start_ew="${BASH_REMATCH[3]}"
    start_lon="${BASH_REMATCH[4]}"
    end_ns="${BASH_REMATCH[5]}"
    end_lat="${BASH_REMATCH[6]}"
    end_ew="${BASH_REMATCH[7]}"
    end_lon="${BASH_REMATCH[8]}"
    
    # Convert to numerical coordinates with sign - strip leading zeros to avoid octal interpretation
    if [ "$start_ns" == "S" ]; then
      start_lat_num=$(( -1 * 10#${start_lat} ))
    else
      start_lat_num=$(( 10#${start_lat} ))
    fi
    
    if [ "$start_ew" == "W" ]; then
      start_lon_num=$(( -1 * 10#${start_lon} ))
    else
      start_lon_num=$(( 10#${start_lon} ))
    fi
    
    if [ "$end_ns" == "S" ]; then
      end_lat_num=$(( -1 * 10#${end_lat} ))
    else
      end_lat_num=$(( 10#${end_lat} ))
    fi
    
    if [ "$end_ew" == "W" ]; then
      end_lon_num=$(( -1 * 10#${end_lon} ))
    else
      end_lon_num=$(( 10#${end_lon} ))
    fi
    
    # Check if the tile is within any of our regions of interest
    IN_REGION=0
    REGION_NAME=""
    
    # Europe: 35N-72N, 25W-45E (includes Iceland and full Scandinavia)
    if (( (start_lat_num >= 35 && start_lat_num <= 72) || (end_lat_num >= 35 && end_lat_num <= 72) )) && 
       (( (start_lon_num >= -25 && start_lon_num <= 45) || (end_lon_num >= -25 && end_lon_num <= 45) )); then
      IN_REGION=1
      REGION_NAME="Europe"
    fi
    
    # North America: 15N-85N, 170W-50W
    if (( (start_lat_num >= 15 && start_lat_num <= 85) || (end_lat_num >= 15 && end_lat_num <= 85) )) && 
       (( (start_lon_num >= -170 && start_lon_num <= -50) || (end_lon_num >= -170 && end_lon_num <= -50) )); then
      IN_REGION=1
      REGION_NAME="North America"
    fi
    
    # Australia: 10S-45S, 110E-155E
    if (( (start_lat_num >= -45 && start_lat_num <= -10) || (end_lat_num >= -45 && end_lat_num <= -10) )) && 
       (( (start_lon_num >= 110 && start_lon_num <= 155) || (end_lon_num >= 110 && end_lon_num <= 155) )); then
      IN_REGION=1
      REGION_NAME="Australia"
    fi
    
    # New Zealand: 33S-48S, 165E-180E
    if (( (start_lat_num >= -48 && start_lat_num <= -33) || (end_lat_num >= -48 && end_lat_num <= -33) )) && 
       (( (start_lon_num >= 165 && start_lon_num <= 180) || (end_lon_num >= 165 && end_lon_num <= 180) )); then
      IN_REGION=1
      REGION_NAME="New Zealand"
    fi
    
    # South Korea: 33N-39N, 125E-131E
    if (( (start_lat_num >= 33 && start_lat_num <= 39) || (end_lat_num >= 33 && end_lat_num <= 39) )) && 
       (( (start_lon_num >= 125 && start_lon_num <= 131) || (end_lon_num >= 125 && end_lon_num <= 131) )); then
      IN_REGION=1
      REGION_NAME="South Korea"
    fi
    
    # Taiwan: 21N-26N, 119E-122.5E
    if (( (start_lat_num >= 21 && start_lat_num <= 26) || (end_lat_num >= 21 && end_lat_num <= 26) )) && 
       (( (start_lon_num >= 119 && start_lon_num <= 123) || (end_lon_num >= 119 && end_lon_num <= 123) )); then
      IN_REGION=1
      REGION_NAME="Taiwan"
    fi
    
    # If in any region, add to the output file
    if [ $IN_REGION -eq 1 ]; then
      echo "$url" >> "$OUTPUT_FILE"
      FILTERED_COUNT=$((FILTERED_COUNT + 1))
    fi
  fi
done < "$INPUT_FILE"

echo "Filtering complete. Found $FILTERED_COUNT URLs in the regions of interest."
echo "Results saved to $OUTPUT_FILE"
