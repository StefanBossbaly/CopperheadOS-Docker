#!/bin/bash
set -e

# Initialize CCache if it will be used
if [ "$USE_CCACHE" = 1 ]; then
	ccache -M $CCACHE_SIZE 2>&1
fi

# Initialize Git user information
git config --global user.name $USER_NAME
git config --global user.email $USER_MAIL

# Build
cd "$SRC_DIR"

# Initialize repo
if [ ! -d .repo ]; then
  repo init -u https://github.com/CopperheadOS/platform_manifest.git -b refs/tags/${BUILD_TAG}
fi

if [ "$SIGN_BUILDS" = true ]; then
  if [ -z "$(ls -A "$KEYS_DIR")" ]; then
    echo ">> [$(date)] SIGN_BUILDS = true but empty \$KEYS_DIR, generating new keys"
    for c in releasekey platform shared media; do
      echo ">> [$(date)]  Generating $c..."
      "SRC_DIR/development/tools/make_key" "$KEYS_DIR/$c" "$KEYS_SUBJECT" <<< '' &> /dev/null
    done
  else
    for c in releasekey platform shared media; do
      for e in pk8 x509.pem; do
        if [ ! -f "$KEYS_DIR/$c.$e" ]; then
          echo ">> [$(date)] SIGN_BUILDS = true and not empty \$KEYS_DIR, but \"\$KEYS_DIR/$c.$e\" is missing"
          exit 1
        fi
      done
    done
  fi
  
  if [ ! -f "$KEYS_DIR/avb.pem" ]; then
    echo ">> [$(date)]  Generating avb.pem..."
    openssl genrsa -out "$KEYS_DIR/avb.pem" 2048
  fi
  
  if [ ! -f "$KEYS_DIR/avb_pkmd.bin" ]; the
    "SRC_DIR/external/avb/avbtool" extract_public_key --key "$KEYS_DIR/avb.pem" --output "$KEYS_DIR/avb_pkmd.bin"
  fi
fi

# Sync work dir
repo sync -j${NUM_OF_THREADS}

# Select device
source script/copperhead.sh
choosecombo release aosp_${DEVICE} user

vendor/android-prepare-vendor/execute-all.sh -d ${DEVICE} -b ${BUILD_ID} -o vendor/android-prepare-vendor
mkdir -p vendor/google_devices
rm -rf vendor/google_devices/${DEVICE}
rm -fr vendor/google_devices/muskie

mv vendor/android-prepare-vendor/${DEVICE}/$(echo $BUILD_ID | tr '[:upper:]' '[:lower:]')/vendor/google_devices/${DEVICE} vendor/google_devices
# TODO remove hardcoded value
mv vendor/android-prepare-vendor/${DEVICE}/$(echo $BUILD_ID | tr '[:upper:]' '[:lower:]')/vendor/google_devices/muskie vendor/google_devices

# If needed, apply the microG's signature spoofing patch
if [ "$SIGNATURE_SPOOFING" = "yes" ] || [ "$SIGNATURE_SPOOFING" = "restricted" ]; then
  cd frameworks/base
  if [ "$SIGNATURE_SPOOFING" = "yes" ]; then
    patch_name = "android_frameworks_base-O.patch"
	echo ">> [$(date)] Applying the standard signature spoofing patch ($patch_name) to frameworks/base"
	echo ">> [$(date)] WARNING: the standard signature spoofing patch introduces a security threat"
	patch --quiet -p1 -i "/root/signature_spoofing_patches/$patch_name"
  else
    echo ">> [$(date)] Applying the restricted signature spoofing patch (based on $patch_name) to frameworks/base"
	sed 's/android:protectionLevel="dangerous"/android:protectionLevel="signature|privileged"/' "/root/signature_spoofing_patches/$patch_name" | patch --quiet -p1
  fi
  git clean -q -f
  cd ../..

  # Override device-specific settings for the location providers
  mkdir -p "vendor/$vendor/overlay/microg/frameworks/base/core/res/res/values/"
  cp /root/signature_spoofing_patches/frameworks_base_config.xml "vendor/$vendor/overlay/microg/frameworks/base/core/res/res/values/config.xml"
fi



# Build project
make target-files-package -j${NUM_OF_THREADS}
make brillo_update_payload -j${NUM_OF_THREADS}
script/release.sh ${DEVICE}