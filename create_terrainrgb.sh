#!/bin/bash

#custom version of rio rgbify which adds speed improvements is reccomended https://github.com/acalcutt/rio-rgbify

INPUT_DIR=./input
OUTPUT_DIR=./output

[[ $THREADS ]] || THREADS=12
[[ $VERSION ]] || VERSION=v4.0
[[ $MINZOOM ]] || MINZOOM=0
[[ $MAXZOOM ]] || MAXZOOM=11
[[ $FORMAT ]] || FORMAT=png

BASENAME=jaxa_terrainrgb_${MINZOOM}-${MAXZOOM}_${FORMAT}
vrtfile=${OUTPUT_DIR}/${BASENAME}.vrt
final_mbtiles=${OUTPUT_DIR}/${BASENAME}.mbtiles
vrtfile2=${OUTPUT_DIR}/${BASENAME}_warp.vrt

[ -d "$OUTPUT_DIR" ] || mkdir -p $OUTPUT_DIR || { echo "error: $OUTPUT_DIR " 1>&2; exit 1; }

#rm rio/*
gdalbuildvrt -overwrite -srcnodata -9999 -vrtnodata -9999 ${vrtfile} ${INPUT_DIR}/*_DSM.tif
gdalwarp -r cubicspline -t_srs EPSG:3857 -dstnodata 0 -co COMPRESS=DEFLATE ${vrtfile} ${vrtfile2}


# Process lower zoom levels in parallel (0-5)
echo "Processing zoom levels 0-5 in parallel..."
for z in $(seq $MINZOOM 5); do
    echo "Starting zoom level ${z} in background..."
    temp_mbtiles=${OUTPUT_DIR}/temp_z${z}.mbtiles
    
    # Process this zoom level in background
    rio rgbify -vvv -b -10000 -i 0.1 --min-z $z --max-z $z -j $THREADS --format $FORMAT ${vrtfile2} ${temp_mbtiles} &
done

# Wait for all background processes to complete
echo "Waiting for all lower zoom levels to complete..."
wait
echo "All lower zoom levels completed."

# Clear caches to release memory
echo "Clearing memory caches..."
echo 3 > /proc/sys/vm/drop_caches || true

# Process higher zoom levels one at a time (6-11)
for z in $(seq 6 $MAXZOOM); do
    echo "Processing zoom level ${z}..."
    temp_mbtiles=${OUTPUT_DIR}/temp_z${z}.mbtiles
    
    # Process just this zoom level
    rio rgbify -vvv -b -10000 -i 0.1 --min-z $z --max-z $z -j $THREADS --format $FORMAT ${vrtfile2} ${temp_mbtiles}
    
    echo "Finished processing zoom level ${z}. File size:"
    ls -lh ${temp_mbtiles}
    
    # Clear caches to release memory
    echo 3 > /proc/sys/vm/drop_caches || true
done

# Once all zoom levels are processed, merge them into a single mbtiles
echo "Merging all zoom levels into a single mbtiles file..."
cp ${OUTPUT_DIR}/temp_z${MINZOOM}.mbtiles ${final_mbtiles}

# For each subsequent zoom level, copy its tiles to the final mbtiles
for z in $(seq $((MINZOOM+1)) $MAXZOOM); do
    echo "Merging zoom level ${z}..."
    sqlite3 ${final_mbtiles} "ATTACH '${OUTPUT_DIR}/temp_z${z}.mbtiles' AS src; INSERT INTO tiles SELECT * FROM src.tiles; DETACH src;"
done

#sqlite3 ${mbtiles} 'CREATE UNIQUE INDEX tile_index on tiles (zoom_level, tile_column, tile_row);' #not needed with my custom rio-rgbify
#sqlite3 ${mbtiles} 'PRAGMA journal_mode=DELETE;' #not needed with my custom rio-rgbify
sqlite3 ${mbtiles} 'UPDATE metadata SET value = "'${BASENAME}'" WHERE name = "name" AND value = "";'
sqlite3 ${mbtiles} 'UPDATE metadata SET value = "JAXA ALOS World 3D 30m (AW3D30 '${VERSION}') converted with rio rgbify" WHERE name = "description";'
sqlite3 ${mbtiles} 'UPDATE metadata SET value = "'${FORMAT}'" WHERE name = "format";'
sqlite3 ${mbtiles} 'UPDATE metadata SET value = "1" WHERE name = "version";'
sqlite3 ${mbtiles} 'UPDATE metadata SET value = "baselayer" WHERE name = "type";'
sqlite3 ${mbtiles} "INSERT INTO metadata (name,value) VALUES('attribution','<a href=""https://earth.jaxa.jp/en/data/policy/"">AW3D30 (JAXA)</a>');"
sqlite3 ${mbtiles} "INSERT INTO metadata (name,value) VALUES('minzoom','${MINZOOM}');"
sqlite3 ${mbtiles} "INSERT INTO metadata (name,value) VALUES('maxzoom','${MAXZOOM}');"
sqlite3 ${mbtiles} "INSERT INTO metadata (name,value) VALUES('bounds','-180,-90,180,90');"
sqlite3 ${mbtiles} "INSERT INTO metadata (name,value) VALUES('center','0,0,5');"

# Optionally, clean up temporary files
echo "Cleaning up temporary files..."
for z in $(seq $MINZOOM $MAXZOOM); do
    rm ${OUTPUT_DIR}/temp_z${z}.mbtiles
done

echo "Processing complete. Final file size:"
ls -lh ${final_mbtiles}
