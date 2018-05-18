#!/bin/bash
set -e

# We only support the pixel devices
if [[ $DEVICE != "sailfish" ]] && [[ $DEVICE != "marlin" ]] && [[ $DEVICE != "walleye" ]] && [[ $DEVICE != "taimen" ]]; then
  echo ">> [$(date)] Currently this container only supports building for pixel devices"
  exit 1
fi

# Setup global variables
BIG_BROTHER=""
if [[ $DEVICE = "walleye" ]]; then
  BIG_BROTHER="muskie"
elif [[ $DEVICE = "sailfish" ]]; then
  BIG_BROTHER="marlin"
fi

# Initialize Git user information
git config --global user.name $USER_NAME
git config --global user.email $USER_MAIL
git config --global color.ui false

# (Re)Initialize repo
cd "$SRC_DIR"
repo init -u https://github.com/CopperheadOS/platform_manifest.git -b refs/tags/${BUILD_TAG}

# Copy over the local_manifests
mkdir -p "$SRC_DIR/.repo/local_manifests"
rsync -a --delete --include '*.xml' --exclude '*' "$LMANIFEST_DIR/" "$SRC_DIR/.repo/local_manifests/"

# Clean out any changes
echo ">> [$(date)] Reseting repos"
repo forall -c 'git reset -q --hard ; git clean -q -fd'

# Sync work dir
repo sync --force-sync -j${NUM_OF_THREADS}

# Verify signatures for all repo tags
echo ">> [$(date)] Verifying tag signatures for all repositories"
repo forall -c 'git verify-tag --raw $(git describe)' || { echo ">> [$(date)] Tags could not be verified"; exit 1; }

# Ensure we have the correct keys
if [[ $DEVICE = "walleye" ]] || [[ $DEVICE = "taimen" ]]; then
  keys=(releasekey platform shared media)
else
  keys=(releasekey platform shared media verity)
fi

# Check to make sure we have the correct keys
if [[ -z "$(ls -A $KEYS_DIR)" ]]; then
  echo ">> [$(date)] Generating new keys"
  for c in "${keys[@]}"; do
    echo ">> [$(date)]  Generating $c..."
    "$SRC_DIR/development/tools/make_key" "$KEYS_DIR/$c" "$KEYS_SUBJECT" <<< '' &> /dev/null || true
  done
else
  echo ">> [$(date)] Ensuring all keys are in $KEYS_DIR"
  for c in "${keys[@]}"; do
    for e in pk8 x509.pem; do
      if [[ ! -f $KEYS_DIR/$c.$e ]]; then
        echo ">> [$(date)] $KEYS_DIR/$c.$e is missing"
        exit 1
      fi
    done
  done
  echo ">> [$(date)] Keys verified"
fi

# Generate avb.pem and avb_pkmd.bin for walleye and taimen
if [[ $DEVICE = "walleye" ]] || [[ $DEVICE = "taimen" ]]; then
  if [[ ! -f $KEYS_DIR/avb.pem ]]; then
    echo ">> [$(date)]  Generating avb.pem..."
    openssl genrsa -out "$KEYS_DIR/avb.pem" 2048
  fi

  if [[ ! -f $KEYS_DIR/avb_pkmd.bin ]]; then
    "$SRC_DIR/external/avb/avbtool" extract_public_key --key "$KEYS_DIR/avb.pem" --output "$KEYS_DIR/avb_pkmd.bin"
  fi
elif [[ $DEVICE = "sailfish" ]] || [[ $DEVICE = "marlin" ]]; then
  make -j${NUM_OF_THREADS} generate_verity_key
  "$SRC_DIR/out/host/linux-x86/bin/generate_verity_key" -convert "$KEYS_DIR/verity.x509.pem" "$KEYS_DIR/verity_key"
  openssl x509 -outform der -in "$KEYS_DIR/verity.x509.pem" -out "$SRC_DIR/kernel/google/marlin/verity_user.der.x509"
fi

# Initialize CCache if it will be used
if [[ $USE_CCACHE = 1 ]]; then
  "$SRC_DIR/prebuilts/misc/linux-x86/ccache/ccache" -M $CCACHE_SIZE 2>&1
fi

# Do the inital fetch and setup of the chromium build
if [[ -z "$(ls -A $CHROMIUM_DIR)" ]]; then
  cd "$CHROMIUM_DIR"
  fetch --nohooks android --target_os_only=true
  "$CHROMIUM_DIR/src/build/linux/sysroot_scripts/install-sysroot.py" --arch=i386
  "$CHROMIUM_DIR/src/build/linux/sysroot_scripts/install-sysroot.py" --arch=amd64
fi

# Sync the chromium build with the latest
cd "$CHROMIUM_DIR/src"
yes | gclient revert --jobs ${NUM_OF_THREADS}
yes | gclient sync --with_branch_heads -r ${CHROMIUM_RELEASE_NAME} --jobs ${NUM_OF_THREADS}

# Clone or pull latest of the chromium patches
if [[ ! -d $CHROMIUM_DIR/chromium_patches ]]; then
  cd "$CHROMIUM_DIR"
  git clone https://github.com/CopperheadOS/chromium_patches.git
else
  cd "$CHROMIUM_DIR/chromium_patches"
  git reset -q --hard
  git clean -q -fd
  git pull
fi

# Apply the patches
echo ">> [$(date)] Applying chromium patches"
cd "$CHROMIUM_DIR/src"
git am "$CHROMIUM_DIR"/chromium_patches/*.patch

# Generate build args and build chromium apk
echo ">> [$(date)] Building chromium apk"
cd "$CHROMIUM_DIR/src"
if [[ $USE_CCACHE = 1 ]]; then
  cc_wrapper_arg='cc_wrapper = "/srv/src/prebuilts/misc/linux-x86/ccache/ccache"'
else
  cc_wrapper_arg=""
fi
gn gen --args='target_os="android" target_cpu = "arm64" is_debug = false is_official_build = true is_component_build = false symbol_level = 0 ffmpeg_branding = "Chrome" proprietary_codecs = true android_channel = "stable" android_default_version_name = "'${CHROMIUM_RELEASE_NAME}'" android_default_version_code = "'${CHROMIUM_RELEASE_CODE}'" '"${cc_wrapper_arg}" out/Default
ninja -C out/Default/ monochrome_public_apk

# Copy the apk over to the prebuilts
cp -f "$CHROMIUM_DIR/src/out/Default/apks/MonochromePublic.apk" "$SRC_DIR/external/chromium/prebuilt/arm64/MonochromePublic.apk"

# Select device
cd "$SRC_DIR"
source script/copperhead.sh
choosecombo release aosp_${DEVICE} user

# Download and move the vendor specific folder
echo ">> [$(date)] Downloading vendor specific files"
cd "$SRC_DIR"

# TODO Remove once issue is resolved
# https://github.com/anestisb/android-prepare-vendor/issues/126
cp -f /root/workarounds/download-nexus-images.sh "$SRC_DIR/vendor/android-prepare-vendor/scripts/download-nexus-image.sh"

"$SRC_DIR/vendor/android-prepare-vendor/execute-all.sh" -d ${DEVICE} -b ${BUILD_ID} -o "$SRC_DIR/vendor/android-prepare-vendor"
mkdir -p "$SRC_DIR/vendor/google_devices"
rm -rf "$SRC_DIR/vendor/google_devices/${DEVICE}"
mv "$SRC_DIR/vendor/android-prepare-vendor/${DEVICE}/$(echo $BUILD_ID | tr '[:upper:]' '[:lower:]')/vendor/google_devices/${DEVICE}" "$SRC_DIR/vendor/google_devices"

# The smaller variant of the pixels have to move their bigger brother's folder as well
if [[ ! -z $BIG_BROTHER ]]; then
  rm -fr "$SRC_DIR/vendor/google_devices/${BIG_BROTHER}"
  mv "$SRC_DIR/vendor/android-prepare-vendor/${DEVICE}/$(echo $BUILD_ID | tr '[:upper:]' '[:lower:]')/vendor/google_devices/${BIG_BROTHER}" "$SRC_DIR/vendor/google_devices"
fi

# TODO find a better way to get rid of the double talkback dep
if [[ -f $SRC_DIR/vendor/opengapps/build/modules/talkback/Android.mk ]]; then
  rm -f "$SRC_DIR/vendor/opengapps/build/modules/talkback/Android.mk"
fi

# OPEN_GAPPS takes priority
if [[ $OPEN_GAPPS = "yes" ]]; then
  # Special case for walleye (also known as wahoo)
  dev_name="$DEVICE"
  if [[ $DEVICE = "walleye" ]]; then
    dev_name="wahoo"
  fi

  # Add GAPPS_VARIANT += pico and call to vendor/opengapps/build/opengapps-packages.mk hook at the end
  sed -i "1s;^;GAPPS_VARIANT += pico\n\n;" "$SRC_DIR/device/google/$dev_name/device.mk"
  echo '$(call inherit-product, vendor/opengapps/build/opengapps-packages.mk)' >> "$SRC_DIR/device/google/$dev_name/device.mk"

  # PRODUCT_RESTRICT_VENDOR_FILES needs to be false
  if [[ ! -z $BIG_BROTHER ]]; then
    dev_mk_name=$BIG_BROTHER
  else
    dev_mk_name=$DEVICE
  fi
  sed -i 's/PRODUCT_RESTRICT_VENDOR_FILES.*/PRODUCT_RESTRICT_VENDOR_FILES := false/' "$SRC_DIR/device/google/$dev_mk_name/aosp_${DEVICE}.mk"
else
  # If needed, apply the microG's signature spoofing patch
  if [[ $SIGNATURE_SPOOFING = "yes" ]]; then
    cd "$SRC_DIR/frameworks/base"
    echo ">> [$(date)] Applying the restricted signature spoofing patch to frameworks/base"
    sed 's/android:protectionLevel="dangerous"/android:protectionLevel="signature|privileged"/' "/root/patches/android_frameworks_base-O.patch" | patch --quiet -p1
    git clean -q -f
  fi

  # Add custom packages to be installed
  if [[ ! -z $CUSTOM_PACKAGES ]]; then
    echo ">> [$(date)] Adding custom packages ($CUSTOM_PACKAGES)"
    sed -i "1s;^;PRODUCT_PACKAGES += $CUSTOM_PACKAGES\n\n;" "$SRC_DIR/build/target/product/core.mk"
  fi
fi

# Apply FDroid patch
key=$(keytool -list -printcert -file "$KEYS_DIR/releasekey.x509.pem" | grep 'SHA256:' | tr -d ':' | cut -d' ' -f 3)
sed -i -e "s/67760df25e94ae6c955d9e17ca1bc8e195da5d91d5a58023805ab3579463d1b8/${key}/g" "$SRC_DIR/packages/apps/F-Droid/privileged-extension/app/src/main/java/org/fdroid/fdroid/privileged/ClientWhitelist.java"

# Build target files
cd "$SRC_DIR"
make target-files-package -j${NUM_OF_THREADS}
make brillo_update_payload -j${NUM_OF_THREADS}

# Link key directory
mkdir -p "$SRC_DIR/keys"
ln -sf "$KEYS_DIR" "$SRC_DIR/keys/${DEVICE}"

# Generate release files from target files
script/release.sh ${DEVICE}

# Move archives files to ZIP_DIR
cd "$SRC_DIR/out/release-${DEVICE}-${BUILD_NUMBER}"
cp -f *.zip "$ZIP_DIR"
cp -f *.tar.xz "$ZIP_DIR"
cp -f "$CHROMIUM_DIR/src/out/Default/apks/MonochromePublic.apk" "$ZIP_DIR/MonochromePublic_${CHROMIUM_RELEASE_NAME}.apk"
