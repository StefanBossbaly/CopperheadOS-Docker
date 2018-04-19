#!/bin/bash

# cd to working directory
cd "$SRC_DIR"

# Init Repo
if [ ! -d .repo ]; then
  repo init -u https://github.com/CopperheadOS/platform_manifest.git -b refs/tags/${BUILD_TAG}
fi
   
# Sync work dir
repo sync -j${NUM_OF_THREADS}

# Select device
source script/copperhead.sh
choosecombo release aosp_${DEVICE} user

# Pull down specific vendor files
vendor/android-prepare-vendor/execute-all.sh -d ${DEVICE} -b ${BUILD_ID} -o vendor/android-prepare-vendor
mkdir -p vendor/google_devices
rm -rf vendor/google_devices/${DEVICE}

mv vendor/android-prepare-vendor/${DEVICE}/$(echo $BUILD_ID | tr '[:upper:]' '[:lower:]')/vendor/google_devices/${DEVICE} vendor/google_devices
# TODO remove hardcoded value
mv vendor/android-prepare-vendor/${DEVICE}/$(echo $BUILD_ID | tr '[:upper:]' '[:lower:]')/vendor/google_devices/muskie vendor/google_devices

# Build project
make target-files-package -j${NUM_OF_THREADS}
make brillo_update_payload -j${NUM_OF_THREADS}
script/release.sh ${DEVICE}