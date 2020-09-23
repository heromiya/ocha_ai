# /bin/bash

INPUT=$1
PATPRED=$2
PATCH_PROB=$3
TEST_RESULTS=$4

for PATCH in $(find $PATPRED -type f -regex ".*\.tif");do
    GTIFF=$(echo $PATCH | sed 's/patch_pred/patch_relief/g; s/[a-zA-Z]\{3\}.pred.//g')

    #JSON=$(gdalinfo $GTIFF -json)
    #UpperRight=($(echo $JSON | python3 -c "import sys, json; print(json.load(sys.stdin)['cornerCoordinates']['upperRight'])" | tr -d [],))
    #LowerLeft=($(echo $JSON | python3 -c "import sys, json; print(json.load(sys.stdin)['cornerCoordinates']['lowerLeft'])" | tr -d [],))

    eval $(gdalinfo $GTIFF | grep "Pixel Size" | sed 's/ //g; s/,/ /; s/-//g')
    PixelSize_X=${PixelSize[0]}
    PixelSize_Y=${PixelSize[1]}

    eval $(gdalinfo $GTIFF | grep Corner -A 4 | sed 's/ (/=(/g; s/ //g; s/,/ /; s/\(.*=(.*)\)=.*/\1/g' | tail -n 4)
    XMIN=${LowerLeft[0]}
    XMAX=${UpperRight[0]}
    YMIN=${LowerLeft[1]}
    YMAX=${UpperRight[1]}

    #XMAX=$(echo $JSON | python3 -c "import sys, json; print(json.load(sys.stdin)['cornerCoordinates']['upperRight'])" | tr -d [], | cut -f 1 -d " ")
    #XMIN=$(echo $JSON | python3 -c "import sys, json; print(json.load(sys.stdin)['cornerCoordinates']['lowerLeft'])" | tr -d [], | cut -f 1 -d " ")
    #YMAX=$(echo $JSON | python3 -c "import sys, json; print(json.load(sys.stdin)['cornerCoordinates']['upperRight'])" | tr -d [], | cut -f 2 -d " ")
    #YMIN=$(echo $JSON | python3 -c "import sys, json; print(json.load(sys.stdin)['cornerCoordinates']['lowerLeft'])" | tr -d [], | cut -f 2 -d " ")
    
    gdal_translate -co compress=deflate -a_srs EPSG:3857 -q -a_ullr $XMIN $YMAX $XMAX $YMIN $PATCH $(echo $PATCH | sed 's/\.tif/\.g.tif/g')
done
find $PATPRED/ -type f -regex ".*\.g\.tif" > $PATPRED/pred.lst
gdalbuildvrt -input_file_list $PATPRED/pred.lst $PATPRED/pred.vrt
gdal_translate -co compress=deflate $PATPRED/pred.vrt $TEST_RESULTS/$(basename $INPUT).pred.tif
#gdalwarp -multi -wm 4096 -overwrite -co compress=deflate -co BIGTIFF=YES

for PATCH in $(find $PATCH_PROB -type f -regex ".*\.tif");do
    GTIFF=$(echo $PATCH | sed 's/patch_prob/patch_relief/g; s/[a-zA-Z]\{3\}.prob.//g')
    #JSON=$(gdalinfo $GTIFF -json)

    eval $(gdalinfo $GTIFF | grep Corner -A 4 | sed 's/ (/=(/g; s/ //g; s/,/ /; s/\(.*=(.*)\)=.*/\1/g' | tail -n 4)
    XMIN=${LowerLeft[0]}
    XMAX=${UpperRight[0]}
    YMIN=${LowerLeft[1]}
    YMAX=${UpperRight[1]}

    #XMAX=$(echo $JSON | python3 -c "import sys, json; print(json.load(sys.stdin)['cornerCoordinates']['upperRight'])" | tr -d [], | cut -f 1 -d " ")
    #XMIN=$(echo $JSON | python3 -c "import sys, json; print(json.load(sys.stdin)['cornerCoordinates']['lowerLeft'])" | tr -d [], | cut -f 1 -d " ")
    #YMAX=$(echo $JSON | python3 -c "import sys, json; print(json.load(sys.stdin)['cornerCoordinates']['upperRight'])" | tr -d [], | cut -f 2 -d " ")
    #YMIN=$(echo $JSON | python3 -c "import sys, json; print(json.load(sys.stdin)['cornerCoordinates']['lowerLeft'])" | tr -d [], | cut -f 2 -d " ")

    gdal_translate -co compress=deflate -a_srs EPSG:3857 -scale 0 1 0 10000 -ot Int16 -q -a_ullr $XMIN $YMAX $XMAX $YMIN $PATCH $(echo $PATCH | sed 's/\.tif/\.g.tif/g')
done
find $PATCH_PROB/ -type f -regex ".*\.g\.tif" > $PATCH_PROB/prob.lst
gdalbuildvrt -input_file_list $PATCH_PROB/prob.lst $PATCH_PROB/prob.vrt
gdal_translate -co compress=deflate $PATCH_PROB/prob.vrt $TEST_RESULTS/$(basename $INPUT).prob.tif

#gdalwarp -multi -wm 4096 -overwrite -co compress=deflate -co BIGTIFF=YES  $PATCH_PROB/*.g.tif $TEST_RESULTS/$(basename $INPUT).prob.tif

exit 0
