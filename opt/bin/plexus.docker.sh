#! /bin/bash

# $Id: plexus.docker.sh,v 1.4 2018/07/27 07:21:11 orba6563 Exp $

COMMAND="$0"

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

: ${OPT:="/opt"}
: ${WORKDIR_ROOT:="/tmp"}

if [ "${MESU_FLAG}" -eq 0 ]
then
    MVE_INSTALL_DIR="${OPT}/mve/apps"
    MVS_TEXTURING_PATH="${OPT}/mvs-texturing/build/apps/texrecon"

    if [ -z "${DEPTH}" ]
    then
	read -p "Reconstruction depth (1-n) should be set by the DEPTH shell variable"
	exit 1
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


SOURCE_DIRECTORY=_source_directory_


echo -e "Depth value: $DEPTH"

if [ ! -d "${IMAGE_SOURCE_DIR}" ]
then
  # Control will enter here if $DIRECTORY doesn't exist.
  printf "\nIMAGE SOURCE DIRECTORY '${IMAGE_SOURCE_DIR}' DOES NOT EXIST!\n-------------------------\n"
  exit 1
fi

# Delete MVE work directory
if [ -d "${IMAGE_OUTPUT_DIR}/$MVE" ]
then
    rm -rf "${IMAGE_OUTPUT_DIR}/$MVE"
fi

echo -e "Initialize scene...."

# Create & Bundle a Scene in MVE if we're not using OpenMVG
# makescene
#./makescene -i /home/kevin/source/temple /home/kevin/output/temple_mve

$MESU_BINARY_PREFIX ${MVE_INSTALL_DIR}/makescene/makescene -i "${IMAGE_SOURCE_DIR}" "${IMAGE_OUTPUT_DIR}/$MVE"

CURRENTTIME=$(date -u +"%s")
diff=$(($CURRENTTIME - $STARTTIME))

echo -e "--> Format conversion complete [makescene] -- $(($diff / 60)):$(($diff % 60)) minutes"

# sfmrecon
# Note:  sensitive to initial pairs; set starting images by their scene index in /views
# Note:  the default -m value for sfmrecon feature search image size is 6MP, so we specify 150MP to maximize the number of features recovered
# By default sfmrecon runs a full bundle adjustment for every five images processed. We haven�t tested damage to the resulting output from lowering this value.
${MVE_INSTALL_DIR}/sfmrecon/sfmrecon --initial-pair=0,1 -m150000000 ${IMAGE_OUTPUT_DIR}/$MVE

CURRENTTIME=$(date -u +"%s")
diff=$(($CURRENTTIME - $STARTTIME))

echo -e "--> Structure computation complete [sfmrecon]\n-------------------------\n"
echo -e "--> Structure computation complete [sfmrecon] -- $(($diff / 60)):$(($diff % 60)) minutes elapsed."

# Surface Reconstruction
# example call:  scene2pset -ddepth-L2 -iundist-L2 -n -s -c MVE_SCENE_DIR OUTPUT.ply
# It is often useful to compute scene2pset for different -F values, then reconstruct the resulting point clouds together; see below.
# -sn = scale input images by 1/(2^n)
# --bounding box = reconstruction within bounding volume

echo -e "Compute depth maps...."

$MESU_BINARY_PREFIX ${MVE_INSTALL_DIR}/dmrecon/dmrecon -s$DEPTH --progress=silent ${IMAGE_OUTPUT_DIR}/$MVE

CURRENTTIME=$(date -u +"%s")
diff=$(($CURRENTTIME - $STARTTIME))
echo -e "--> Depth maps written [dmrecon] -- $(($diff / 60)):$(($diff % 60)) minutes elapsed."

$MESU_BINARY_PREFIX ${MVE_INSTALL_DIR}/scene2pset/scene2pset -F$DEPTH ${IMAGE_OUTPUT_DIR}/$MVE ${IMAGE_OUTPUT_DIR}/${MVE}/scence2pset-$DEPTH$EXT
# -fn = output points given by 1/(2^n)

CURRENTTIME=$(date -u +"%s")
diff=$(($CURRENTTIME - $STARTTIME))
echo -e "--> Point sets written [scene2pset] --$(($diff / 60)):$(($diff % 60)) minutes elapsed."

# Reconstruct the scene
# Simon Fuhrmann wrote:  'Make sure the -c parameter is as large as possible so that it does not remove relevant components. And make sure -t is as large as possible without destroying relevant geometry.'
# voxel refinement (0-3):  -r3

echo -e "Reconstruct the scene...."

$MESU_BINARY_PREFIX ${MVE_INSTALL_DIR}/fssrecon/fssrecon ${IMAGE_OUTPUT_DIR}/${MVE}/scence2pset-$DEPTH$EXT ${IMAGE_OUTPUT_DIR}/${MVE}/fssrecon-$DEPTH$EXT

CURRENTTIME=$(date -u +"%s")
diff=$(($CURRENTTIME - $STARTTIME))
echo -e "--> Scene written [fssrecon] -- $(($diff / 60)) minutes and $(($diff % 60)) seconds elapsed."

$MESU_BINARY_PREFIX ${MVE_INSTALL_DIR}/meshclean/meshclean -c10000 ${IMAGE_OUTPUT_DIR}/${MVE}/fssrecon-$DEPTH$EXT ${IMAGE_OUTPUT_DIR}/${MVE}/meshclean-$DEPTH$EXT

CURRENTTIME=$(date -u +"%s")
diff=$(($CURRENTTIME - $STARTTIME))
echo -e "--> Isosurface cleaned [meshclean] -- $(($diff / 60)):$(($diff % 60)) minutes elapsed."

# Texture the scene
echo -e "\nTexture scene...."
$MESU_BINARY_PREFIX ${MVS_TEXTURING_PATH}/texrecon ${IMAGE_OUTPUT_DIR}/${MVE}::undistorted ${IMAGE_OUTPUT_DIR}/${MVE}/meshclean-$DEPTH$EXT ${IMAGE_OUTPUT_DIR}/${MVE}/texrecon-$DEPTH$EXT

CURRENTTIME=$(date -u +"%s")
diff=$(($CURRENTTIME - $STARTTIME))
echo -e "\n--> Textures written [texrecon] -- $(($diff / 60)):$(($diff % 60)) minutes elapsed."
