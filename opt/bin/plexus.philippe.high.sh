#! /bin/bash

# $Id: plexus.philippe.high.sh,v 1.5 2018/06/21 16:53:35 orba6563 Exp orba6563 $

COMMAND="$0"

if [ -r "${COMMMAND}-config" ]
then
    source "${COMMAND}-config"
fi

#
#PBS -l select=1:ncpus=48
#PBS -l walltime=384:00:00
#PBS -N cain_trial
#PBS -j oe

echo -e "plexus v.107\nKevin Cain, INSIGHT, 2016"
echo -e "built for Philippe Martinez"

# Set the source image folder within $WORKING_PATH/source
# read -p "Enter project folder:" SOURCE

# For Mesu, set MESU_FLAG=1;
: ${MESU_FLAG:=0}

HERE=$( dirname "${COMMAND}" )

ROOT_DIR="${HERE}/.."

: ${OPT:="${ROOT_DIR}/opt"}
: ${WORKDIR_ROOT:="${ROOT_DIR}/tmp"}

if [ "${MESU_FLAG}" -eq 0 ]
then
  BINARY_PATH="${OPT}/mve/apps"
  MVS_TEXTURING_PATH="${OPT}/texrecon/build/apps/texrecon"
  : ${WORKING_PATH:="${WORKDIR_ROOT}"}
  : ${OUTPUT:="${WORKDIR_ROOT}/output"}
  if [ -z "${SOURCE_DIRECTORY}" ]
  then
      read -p "Enter source directory:" SOURCE_DIRECTORY
  fi
  SOURCE="source/"${SOURCE_DIRECTORY}

  if [ -z "${DEPTH}" ]
  then
      read -p "Enter reconstruction depth (1-n):" DEPTH
  fi
  MESU_BINARY_PREFIX=""
fi

if [ "${MESU_FLAG}" -eq 1 ]
then
  # TODO: which software to use?
  BINARY_PATH="/home/cain/mve/apps"
  MVS_TEXTURING_PATH="/home/cain/texrecon/build/apps/texrecon"
  : ${WORKING_PATH:=/work/cain}
  SOURCE_DIRECTORY="source"
  SOURCE=$SOURCE_DIRECTORY
  OUTPUT="/work/cain/output"
  DEPTH=1
  MESU_BINARY_PREFIX="omplace"
fi

MVG="_mvg"
MVE="_mve"
EXT=".ply"
TEXTURED="-textured.ply"
STARTTIME=$(date -u +"%s")

# load modules
if [ "${MESU_FLAG}" -eq 1 ]; then
  . /usr/share/modules/init/sh
  module load mpt
fi
  
# Directory structure
# source image path $WORKING_PATH/source
# _mvg - Output from OpenMVG
# _mve - Output from OpenMVG export and MVE output

#
# convert relative path to abs
#
OUTPUT=$( readlink -m "${OUTPUT}" )
WORKING_PATH=$( readlink -m "${WORKING_PATH}" )


# Delete log file
rm -f "${WORKING_PATH}"/out.txt

echo -e "IMAGE SOURCE DIRECTORY: '$WORKING_PATH/$SOURCE'"
echo -e "IMAGE SOURCE DIRECTORY SET TO:  '$WORKING_PATH/$SOURCE'" > $WORKING_PATH/out.txt

echo -e "Depth value: $DEPTH"
echo -e "Depth value: $DEPTH" > $WORKING_PATH/out.txt

if [ ! -d "$WORKING_PATH/$SOURCE" ]
then
  # Control will enter here if $DIRECTORY doesn't exist.
  printf "\nIMAGE SOURCE DIRECTORY '$WORKING_PATH/$SOURCE' DOES NOT EXIST!\n-------------------------\n"
  printf "\nIMAGE SOURCE DIRECTORY '$WORKING_PATH/$SOURCE' DOES NOT EXIST!\n-------------------------\n" >> $WORKING_PATH/out.txt
  exit 1
fi

echo -e "Delete log files...."

# Delete MVE work directory
if [ -d "${OUTPUT}/${SOURCE_DIRECTORY}$MVE}" ]
then
    rm -r "${OUTPUT}/${SOURCE_DIRECTORY}$MVE}"/*
fi

echo -e "Initialize scene...."
echo -e "Initialize scene...." >> $WORKING_PATH/out.txt

# Create & Bundle a Scene in MVE if we're not using OpenMVG
# makescene
cd $BINARY_PATH

#./makescene -i /home/kevin/source/temple /home/kevin/output/temple_mve

$MESU_BINARY_PREFIX ./makescene/makescene -i $WORKING_PATH/$SOURCE $OUTPUT/$SOURCE_DIRECTORY$MVE >> $WORKING_PATH/out.txt 2>&1

CURRENTTIME=$(date -u +"%s")
diff=$(($CURRENTTIME - $STARTTIME))

echo -e "--> Format conversion complete [makescene] -- $(($diff / 60)):$(($diff % 60)) minutes" >> $WORKING_PATH/out.txt

# sfmrecon
# Note:  sensitive to initial pairs; set starting images by their scene index in /views
# Note:  the default -m value for sfmrecon feature search image size is 6MP, so we specify 150MP to maximize the number of features recovered
# By default sfmrecon runs a full bundle adjustment for every five images processed. We haven’t tested damage to the resulting output from lowering this value.
./sfmrecon/sfmrecon --initial-pair=0,1 -m150000000 $OUTPUT/$SOURCE_DIRECTORY$MVE >> $WORKING_PATH/out.txt 2>&1

CURRENTTIME=$(date -u +"%s")
diff=$(($CURRENTTIME - $STARTTIME))

echo -e "--> Structure computation complete [sfmrecon]\n-------------------------\n"
>> $WORKING_PATH/out.txt
echo -e "--> Structure computation complete [sfmrecon] -- $(($diff / 60)):$(($diff % 60)) minutes elapsed."

# Surface Reconstruction
# example call:  scene2pset -ddepth-L2 -iundist-L2 -n -s -c MVE_SCENE_DIR OUTPUT.ply
# It is often useful to compute scene2pset for different -F values, then reconstruct the resulting point clouds together; see below.
# -sn = scale input images by 1/(2^n)
# --bounding box = reconstruction within bounding volume

echo -e "Compute depth maps....\n-------------------------\n" >> $WORKING_PATH/out.txt
echo -e "Compute depth maps...."

$MESU_BINARY_PREFIX ./dmrecon/dmrecon -s$DEPTH --progress=silent $OUTPUT/$SOURCE_DIRECTORY$MVE >> $WORKING_PATH/out.txt 2>&1

CURRENTTIME=$(date -u +"%s")
diff=$(($CURRENTTIME - $STARTTIME))
echo -e "--> Depth maps written [dmrecon] -- $(($diff / 60)):$(($diff % 60)) minutes elapsed." >> $WORKING_PATH/out.txt 2>&1
echo -e "--> Depth maps written [dmrecon] -- $(($diff / 60)):$(($diff % 60)) minutes elapsed."

$MESU_BINARY_PREFIX ./scene2pset/scene2pset -F$DEPTH $OUTPUT/$SOURCE_DIRECTORY$MVE $OUTPUT/$SOURCE_DIRECTORY$MVE/point-$DEPTH$EXT >> $WORKING_PATH/out.txt 2>&1
# -fn = output points given by 1/(2^n)

CURRENTTIME=$(date -u +"%s")
diff=$(($CURRENTTIME - $STARTTIME))
echo -e "--> Point sets written [scene2pset] --$(($diff / 60)):$(($diff % 60)) minutes elapsed."

# Reconstruct the scene
# Simon Fuhrmann wrote:  'Make sure the -c parameter is as large as possible so that it does not remove relevant components. And make sure -t is as large as possible without destroying relevant geometry.'
# voxel refinement (0-3):  -r3

echo -e "Reconstruct the scene...." >> $WORKING_PATH/out.txt

$MESU_BINARY_PREFIX ./fssrecon/fssrecon $OUTPUT/$SOURCE_DIRECTORY$MVE/point-$DEPTH$EXT $OUTPUT/$SOURCE_DIRECTORY$MVE/$SOURCE_DIRECTORY-$DEPTH$EXT >> $WORKING_PATH/out.txt 2>&1

CURRENTTIME=$(date -u +"%s")
diff=$(($CURRENTTIME - $STARTTIME))
echo -e "--> Scene written [fssrecon] -- $(($diff / 60)) minutes and $(($diff % 60)) seconds elapsed."

$MESU_BINARY_PREFIX ./meshclean/meshclean -c10000 $OUTPUT/$SOURCE_DIRECTORY$MVE/$SOURCE_DIRECTORY-$DEPTH$EXT $OUTPUT/$SOURCE_DIRECTORY$MVE/$SOURCE_DIRECTORY-$DEPTH-clean$EXT >> $WORKING_PATH/out.txt 2>&1

CURRENTTIME=$(date -u +"%s")
diff=$(($CURRENTTIME - $STARTTIME))
echo -e "--> Isosurface cleaned [meshclean] -- $(($diff / 60)):$(($diff % 60)) minutes elapsed."

# Texture the scene
echo -e "\nTexture scene...." >> $WORKING_PATH/out.txt
$MESU_BINARY_PREFIX $MVS_TEXTURING_PATH/texrecon $OUTPUT/$SOURCE_DIRECTORY$MVE/::undistorted $OUTPUT/$SOURCE_DIRECTORY$MVE/$SOURCE_DIRECTORY-$DEPTH-clean.ply $OUTPUT/$SOURCE_DIRECTORY$MVE/$SOURCE_DIRECTORY-$DEPTH-textured$EXT >> $WORKING_PATH/out.txt 2>&1

CURRENTTIME=$(date -u +"%s")
diff=$(($CURRENTTIME - $STARTTIME))
echo -e "\n--> Textures written [texrecon] -- $(($diff / 60)):$(($diff % 60)) minutes elapsed."


