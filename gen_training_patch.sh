echo "### BEGIN $0 $(date +'%F_%T')"

export PATH=$PATH:$HOME/anaconda3/bin

export MASKDIR=$1
export RASDIR=$2
export PATMASKDIR=$3
export PATRASDIR=$4
export PATCH_SIZE=$5
export N_PATCH=$6

#for TIF in $(find "$RASDIR" -type f | grep -e ".*\.png$" -e ".*\.tif$"); do
function gen_patch() {
    TIF=$1
    IFS=' '
    
    JSON=$(gdalinfo -json "$TIF")
    SIZE=($(echo $JSON | python3 -c "import sys, json; print(json.load(sys.stdin)['size'])" | tr -d [],))
    X_SIZE=${SIZE[0]}
    Y_SIZE=${SIZE[1]}
    MASK_TIF=$MASKDIR/$(basename "$TIF" | sed 's/\(\.[a-zA-Z]\{3\}\)$/-a\1/g')
    
    upperRight=($(echo $JSON | python3 -c "import sys, json; print(json.load(sys.stdin)['cornerCoordinates']['upperRight'])" | tr -d [],))
    lowerLeft=($(echo $JSON | python3 -c "import sys, json; print(json.load(sys.stdin)['cornerCoordinates']['lowerLeft'])" | tr -d [],))
    geoTransform=($(echo $JSON | python3 -c "import sys, json; print(json.load(sys.stdin)['geoTransform'])" | tr -d [],))
    
    PIXEL_SIZE_X=${geoTransform[1]}
    PIXEL_SIZE_Y=$(echo ${geoTransform[5]} | tr -d "-")
    #PIXEL_SIZE_X=$RES
    #PIXEL_SIZE_Y=$RES
    PATCH_SIZE_GX=$(perl -e "print $PATCH_SIZE * $PIXEL_SIZE_X")
    PATCH_SIZE_GY=$(perl -e "print $PATCH_SIZE * $PIXEL_SIZE_Y")
    IMG_EXT="${lowerLeft[0]} ${lowerLeft[1]} ${upperRight[0]} ${upperRight[1]}"
       
    # Patches for non-buildings
    j=1
    while [ $j -le $N_PATCH ]; do
        PATCH_XMIN=$(perl -e "print ${lowerLeft[0]} + rand($X_SIZE * $PIXEL_SIZE_X - $PATCH_SIZE_GX)")
        PATCH_YMIN=$(perl -e "print ${lowerLeft[1]} + rand($Y_SIZE * $PIXEL_SIZE_Y - $PATCH_SIZE_GY)")
        PATCH_XMAX=$(perl -e "print $PATCH_XMIN + $PATCH_SIZE_GX")
        PATCH_YMAX=$(perl -e "print $PATCH_YMIN + $PATCH_SIZE_GY")
	
	
        FNAME=$(printf %09d $(shuf -i 0-1000000000 -n 1 )).tif
        PATCH_IMG=${PATRASDIR}/img/$FNAME
        PATCH_MASK=${PATMASKDIR}/img/$FNAME
        #gdalwarp -q -r lanczos -tr $RES $RES -te $PATCH_XMIN $PATCH_YMIN $PATCH_XMAX $PATCH_YMAX "$TIF" "$PATCH_IMG"
        #gdalwarp -q -r lanczos -tr $RES $RES -te $PATCH_XMIN $PATCH_YMIN $PATCH_XMAX $PATCH_YMAX "$MASK_TIF" "$PATCH_MASK"
        gdal_translate -q -projwin $PATCH_XMIN $PATCH_YMAX $PATCH_XMAX $PATCH_YMIN "$TIF" "$PATCH_IMG"
        gdal_translate -q -projwin $PATCH_XMIN $PATCH_YMAX $PATCH_XMAX $PATCH_YMIN "$MASK_TIF" "$PATCH_MASK"
	
        j=$(expr $j + 1)
    done
#done
}
export -f gen_patch

echo "$PATMASKDIR" "$PATRASDIR"
rm -rf "$PATMASKDIR" "$PATRASDIR" && mkdir -p $PATMASKDIR/img $PATRASDIR/img
parallel --bar gen_patch {} ::: $(find "$RASDIR" -type f | grep -e ".*\.tif$")

echo "### END $0 $(date +'%F_%T')" 
