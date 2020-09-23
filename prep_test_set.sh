# /bin/bash

export TIF=$1
export PATRASDIR=$2
export PATPRED=$3
export PATCH_SIZE=$4

rm -rf $PATRASDIR $PATPRED
mkdir -p $PATRASDIR $PATPRED

#JSON=$(gdalinfo $TIF -json)
#UpperRight=($(echo $JSON | python3 -c "import sys, json; print(json.load(sys.stdin)['cornerCoordinates']['upperRight'])" | tr -d [],))
#LowerLeft=($(echo $JSON | python3 -c "import sys, json; print(json.load(sys.stdin)['cornerCoordinates']['lowerLeft'])" | tr -d [],))

eval $(gdalinfo $TIF | grep Corner -A 4 | sed 's/ (/=(/g; s/ //g; s/,/ /; s/\(.*=(.*)\)=.*/\1/g' | tail -n 4)
export XMIN_FULL=${LowerLeft[0]}
export XMAX_FULL=${UpperRight[0]}
export YMIN_FULL=${LowerLeft[1]}
export YMAX_FULL=${UpperRight[1]}

eval $(gdalinfo $TIF | grep "Pixel Size" | sed 's/ //g; s/,/ /; s/-//g')
export PixelSize_X=${PixelSize[0]}
export PixelSize_Y=${PixelSize[1]}

export TILE_X=$(echo "$TIF" | sed 's/.*\/\([0-9]*\)[-_]\([0-9]*\).*/\1/')
export TILE_Y=$(echo "$TIF" | sed 's/.*\/\([0-9]*\)[-_]\([0-9]*\).*/\2/')
export X_SIZE=$(gdalinfo "$TIF" | grep "Size is" | sed 's/.* \([0-9]*\), \([0-9]*\)/\1/')
export Y_SIZE=$(gdalinfo "$TIF" | grep "Size is" | sed 's/.* \([0-9]*\), \([0-9]*\)/\2/')
export N_PATCH_X=$(perl -e "use POSIX; print ceil($X_SIZE / $PATCH_SIZE)")
export N_PATCH_Y=$(perl -e "use POSIX; print ceil($Y_SIZE / $PATCH_SIZE)")

export X_SIZE_EXTEND=$(perl -e "print $N_PATCH_X * $PATCH_SIZE * $PixelSize_X")
export Y_SIZE_EXTEND=$(perl -e "print $N_PATCH_Y * $PATCH_SIZE * $PixelSize_Y")

genPatch () {
    x=$1
    y=$2
    PAT_GTIFF="${PATRASDIR}/$(printf %03d ${x})-$(printf %03d ${y})-${PATCH_SIZE}-i.tif"
    PAT_PNG="${PATRASDIR}/$(printf %03d ${x})-$(printf %03d ${y})-${PATCH_SIZE}-i.png"
    X_LOC=$(expr $PATCH_SIZE \* $x)
    Y_LOC=$(expr $PATCH_SIZE \* $y)
    XMIN_SUB=$(echo "scale=10; $XMIN_FULL + $PATCH_SIZE * $PixelSize_X * $x" | bc)
    XMAX_SUB=$(echo "scale=10; $XMIN_FULL + $PATCH_SIZE * $PixelSize_X * ($x + 1)" | bc)
    YMIN_SUB=$(echo "scale=10; $YMIN_FULL + $PATCH_SIZE * $PixelSize_Y * $y" | bc)
    YMAX_SUB=$(echo "scale=10; $YMIN_FULL + $PATCH_SIZE * $PixelSize_Y * ($y + 1)" | bc)

    gdal_translate -co compress=deflate -q -projwin $XMIN_SUB $YMAX_SUB $XMAX_SUB $YMIN_SUB $TIF $PAT_GTIFF
}

export -f genPatch

parallel genPatch {} ::: $(seq 0 $(expr $N_PATCH_X - 1)) ::: $(seq 0 $(expr $N_PATCH_Y - 1))


#for x in $(seq 0 $(expr $N_PATCH_X - 1)); do
#    for y in $(seq 0 $(expr $N_PATCH_Y - 1)); do

#    done
#done
