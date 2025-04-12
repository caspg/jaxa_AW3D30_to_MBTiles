#!/bin/bash

# Script to create temporary MBTiles for a single zoom level
# Usage: ./create_single_zoom_mbtiles.sh <zoom_level>

# Check if zoom level is provided
if [ -z "$1" ]; then
    echo "Error: Please provide a zoom level"
    echo "Usage: ./create_single_zoom_mbtiles.sh <zoom_level>"
    exit 1
fi

ZOOM_LEVEL=$1
INPUT_DIR=./input
OUTPUT_DIR=./output

[[ $THREADS ]] || THREADS=12
[[ $FORMAT ]] || FORMAT=png

# Create output directory if it doesn't exist
[ -d "$OUTPUT_DIR" ] || mkdir -p $OUTPUT_DIR || { echo "error: $OUTPUT_DIR " 1>&2; exit 1; }

# Create VRT file
BASENAME=jaxa_terrainrgb_z${ZOOM_LEVEL}_${FORMAT}
vrtfile=${OUTPUT_DIR}/${BASENAME}.vrt
vrtfile2=${OUTPUT_DIR}/${BASENAME}_warp.vrt
temp_mbtiles=${OUTPUT_DIR}/temp_z${ZOOM_LEVEL}.mbtiles

echo "Creating VRT file..."
gdalbuildvrt -overwrite -srcnodata -9999 -vrtnodata -9999 ${vrtfile} ${INPUT_DIR}/*_DSM.tif

echo "Warping to Web Mercator..."
gdalwarp -r cubicspline -t_srs EPSG:3857 -dstnodata 0 -co COMPRESS=DEFLATE ${vrtfile} ${vrtfile2}

echo "Processing zoom level ${ZOOM_LEVEL}..."
rio rgbify -vvv -b -10000 -i 0.1 --min-z $ZOOM_LEVEL --max-z $ZOOM_LEVEL -j $THREADS --format $FORMAT ${vrtfile2} ${temp_mbtiles}

echo "Finished processing zoom level ${ZOOM_LEVEL}"
echo "Output file: ${temp_mbtiles}"
echo "File size:"
ls -lh ${temp_mbtiles}

# Clean up temporary VRT files
rm ${vrtfile} ${vrtfile2} 
