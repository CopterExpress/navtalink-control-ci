#! /usr/bin/env bash

#
# Script for build the image. Used builder script of the target repo
# For build: docker run --privileged -it --rm -v /dev:/dev -v $(pwd):/builder/repo smirart/builder
#
# Copyright (C) 2019 Copter Express Technologies
#
# Author: Artem Smirnov <urpylka@gmail.com>
# Author: Andrey Dvornikov <dvornikov-aa@yandex.ru>
#

set -e # Exit immidiately on non-zero result

export DEBIAN_FRONTEND=${DEBIAN_FRONTEND:='noninteractive'}
export LANG=${LANG:='C.UTF-8'}
export LC_ALL=${LC_ALL:='C.UTF-8'}

echo_stamp() {
  # TEMPLATE: echo_stamp <TEXT> <TYPE>
  # TYPE: SUCCESS, ERROR, INFO

  # More info there https://www.shellhacks.com/ru/bash-colors/

  TEXT="$(date '+[%Y-%m-%d %H:%M:%S]') $1"
  TEXT="\e[1m$TEXT\e[0m" # BOLD

  case "$2" in
    SUCCESS)
    TEXT="\e[32m${TEXT}\e[0m";; # GREEN
    ERROR)
    TEXT="\e[31m${TEXT}\e[0m";; # RED
    *)
    TEXT="\e[34m${TEXT}\e[0m";; # BLUE
  esac
  echo -e ${TEXT}
}

BUILDER_DIR="/builder"
REPO_DIR="${BUILDER_DIR}/repo"
SCRIPTS_DIR="${REPO_DIR}/builder"
IMAGES_DIR="${REPO_DIR}/images"
LIB_DIR="${REPO_DIR}/lib"

function gh_curl() {
  curl -H "Authorization: token ${GITHUB_OAUTH_TOKEN}" \
       -H "Accept: application/vnd.github.v3.raw" \
       $@
}

[[ ! -d ${SCRIPTS_DIR} ]] && (echo_stamp "Directory ${SCRIPTS_DIR} doesn't exist" "ERROR"; exit 1)
[[ ! -d ${IMAGES_DIR} ]] && mkdir ${IMAGES_DIR} && echo_stamp "Directory ${IMAGES_DIR} was created successful" "SUCCESS"

if [[ -z ${TRAVIS_TAG} ]]; then IMAGE_VERSION="$(cd ${REPO_DIR}; git log --format=%h -1)"; else IMAGE_VERSION="${TRAVIS_TAG}"; fi
# IMAGE_VERSION="${TRAVIS_TAG:=$(cd ${REPO_DIR}; git log --format=%h -1)}"
REPO_URL="$(cd ${REPO_DIR}; git remote --verbose | grep origin | grep fetch | cut -f2 | cut -d' ' -f1 | sed 's/git@github\.com\:/https\:\/\/github.com\//')"
REPO_NAME="navtalink-control-ci"
IMAGE_NAME="navtalink-control_${IMAGE_VERSION}.img"
IMAGE_PATH="${IMAGES_DIR}/${IMAGE_NAME}"

get_image_asset() {
  # TEMPLATE: get_image_asset <IMAGE_PATH>
  local BUILD_DIR=$(dirname $1)
  local ORIGIN_IMAGE_ZIP="navtalink_${ORIGIN_IMAGE_VERSION}.img.zip"

  if [ ! -e "${BUILD_DIR}/${ORIGIN_IMAGE_ZIP}" ]; then
    echo_stamp "Downloading original NavTALink image from assets"
    local parser=". | map(select(.tag_name == \"${ORIGIN_IMAGE_REPO}\"))[0].assets | map(select(.name == \"${ORIGIN_IMAGE_ZIP}\"))[0].id"

    asset_id=`gh_curl -s https://api.github.com/repos/${ORIGIN_IMAGE_REPO}/releases | jq "$parser"`
    if [ "$asset_id" = "null" ]; then
      echo "ERROR: version not found ${ORIGIN_IMAGE_VERSION}"
      exit 1
    fi;

    wget -q --auth-no-challenge --header='Accept:application/octet-stream' \
      "https://${GITHUB_OAUTH_TOKEN}:@api.github.com/repos/${ORIGIN_IMAGE_REPO}/releases/assets/${asset_id}" \
      -O "${BUILD_DIR}/${ORIGIN_IMAGE_ZIP}"
    echo_stamp "Downloading complete" "SUCCESS" \
  else echo_stamp "Linux distribution already donwloaded"; fi

  echo_stamp "Unzipping Linux distribution image" \
  && unzip -p "${BUILD_DIR}/${ORIGIN_IMAGE_ZIP}" ${IMAGE_PATH} > $1 \
  && echo_stamp "Unzipping complete" "SUCCESS" \
  || (echo_stamp "Unzipping was failed!" "ERROR"; exit 1)
}

apt install -y curl

get_image_asset ${IMAGE_PATH}

# Make free space
${BUILDER_DIR}/image-resize.sh ${IMAGE_PATH} max '7G'

# Temporary disable ld.so
${BUILDER_DIR}/image-chroot.sh ${IMAGE_PATH} exec ${SCRIPTS_DIR}'/image-ld.sh' disable

# Include dotfiles in globs (asterisks)
shopt -s dotglob

# software install
${BUILDER_DIR}/image-chroot.sh ${IMAGE_PATH} exec ${SCRIPTS_DIR}'/image-software.sh'

${BUILDER_DIR}/image-resize.sh ${IMAGE_PATH}
