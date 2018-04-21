#!/bin/bash
set -e

# We only support the pixel devices
if [[ $DEVICE != "sailfish" ]] && [[ $DEVICE != "marlin" ]] && [[ $DEVICE != "walleye" ]] && [[ $DEVICE != "taimen" ]]; then
  echo ">> [$(date)] Currently this container only supports building for pixel devices"
  exit 1
fi

# Initialize Git user information
git config --global user.name $USER_NAME
git config --global user.email $USER_MAIL
git config --global color.ui false

# Build
cd "$SRC_DIR"

# Initialize repo
if [ ! -d .repo ]; then
  repo init -u https://github.com/CopperheadOS/platform_manifest.git -b refs/tags/${BUILD_TAG}
fi

# Ensure we have the correct keys
if [[ $DEVICE = "walleye" ]] || [[ $DEVICE = "taimen" ]]; then
  keys=(releasekey platform shared media)
else
  keys=(releasekey platform shared media verity)
fi

# Check to make sure we have the correct keys
if [ -z "$(ls -A "$KEYS_DIR")" ]; then
  echo ">> [$(date)] Generating new keys"
  for c in "{keys[@]}"; do
    echo ">> [$(date)]  Generating $c..."
    "$SRC_DIR/development/tools/make_key" "$KEYS_DIR/$c" "$KEYS_SUBJECT" <<< '' &> /dev/null
  done
else
  for c in "{keys[@]}"; do
    for e in pk8 x509.pem; do
      if [ ! -f "$KEYS_DIR/$c.$e" ]; then
        echo ">> [$(date)] \"\$KEYS_DIR/$c.$e\" is missing"
        exit 1
      fi
   done
fi

if [[ $DEVICE = "walleye" ]] || [[ $DEVICE = "taimen" ]]; then
  if [ ! -f "$KEYS_DIR/avb.pem" ]; then
    echo ">> [$(date)]  Generating avb.pem..."
    openssl genrsa -out "$KEYS_DIR/avb.pem" 2048
  fi

  if [ ! -f "$KEYS_DIR/avb_pkmd.bin" ]; then
    "$SRC_DIR/external/avb/avbtool" extract_public_key --key "$KEYS_DIR/avb.pem" --output "$KEYS_DIR/avb_pkmd.bin"
  fi
fi

# Sync work dir
repo sync -j${NUM_OF_THREADS}

# Initialize CCache if it will be used
if [ "$USE_CCACHE" = 1 ]; then
  "$SRC_DIR/prebuilts/misc/linux-x86/ccache/ccache" -M $CCACHE_SIZE 2>&1
fi

# Clean out any unsaved changes out of the src repo
for path in "frameworks/base"; do
  if [ -d "$path" ]; then
    cd "$path"
    git reset -q --hard
    git clean -q -fd
    cd "$SRC_DIR"
  fi
done

# Select device
source script/copperhead.sh
choosecombo release aosp_${DEVICE} user

# Download and move the vendor specific folder
vendor/android-prepare-vendor/execute-all.sh -d ${DEVICE} -b ${BUILD_ID} -o vendor/android-prepare-vendor
mkdir -p vendor/google_devices
rm -rf vendor/google_devices/${DEVICE}
mv vendor/android-prepare-vendor/${DEVICE}/$(echo $BUILD_ID | tr '[:upper:]' '[:lower:]')/vendor/google_devices/${DEVICE} vendor/google_devices

# The smaller variant of the pixels have to move their bigger brother's folder as well
if [ "$DEVICE" = "walleye" ] || [ "$DEVICE" = "sailfish" ]; then
  big_brother=""
  if [ "$DEVICE" = "walleye" ]; then
    big_brother="muskie"
  else
    big_brother="marlin"
  fi
  
  rm -fr vendor/google_devices/${big_brother}
  mv vendor/android-prepare-vendor/${DEVICE}/$(echo $BUILD_ID | tr '[:upper:]' '[:lower:]')/vendor/google_devices/${big_brother} vendor/google_devices
fi

# If needed, apply the microG's signature spoofing patch
if [ "$SIGNATURE_SPOOFING" = "yes" ]; then
  cd frameworks/base
  patch_name="android_frameworks_base-O.patch"
  echo ">> [$(date)] Applying the restricted signature spoofing patch (based on $patch_name) to frameworks/base"
  sed 's/android:protectionLevel="dangerous"/android:protectionLevel="signature|privileged"/' "/root/${patch_name}" | patch --quiet -p1
  git clean -q -f
  cd ../..
fi

# Build project
make target-files-package -j${NUM_OF_THREADS}
make brillo_update_payload -j${NUM_OF_THREADS}

# Link key directory
mkdir -p "$SRC_DIR/keys"
ln -sf "$KEYS_DIR" "$SRC_DIR/keys/${DEVICE}"

# Sign package
script/release.sh ${DEVICE}