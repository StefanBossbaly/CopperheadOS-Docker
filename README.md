# CopperheadOS-Docker
Docker container for building CopperheadOS. Still very much a work in progress

## Enviroment Variables

### `USE_CCACHE`
Enable or disable using `ccache`. Can significantly speed up later builds for both 
the CopperheadOS and chromium build processes. All cache files are saved to `CCACHE_DIR`.
Defaults to the value of 1.

### `CCACHE_SIZE`
If `USE_CCACHE` is true this variable determines the size of the ccache.
This value should be a number followed by an optional suffix: "k", "M", "G", "T".
The default suffix is G. Use 0 for no limit. Defaults to the value of "50G". 

### `SIGNATURE_SPOOFING`
If set, privileged apps will be allowed to spoof their signature. This is needed
for packages like Microg or FakeStore to spoof being Google Play Services or the
Google Play Store. Please note that there is a security risk to setting this to
"yes". Defaults to "no".

### `OPEN_GAPPS`
If set, the `PICO` [package](https://github.com/opengapps/opengapps/wiki/Package-Comparison) will be included in the system image.
Defaults to "no".

### `DEVICE`
The codename of the device the build will be for. Currently supported is all the
Google Pixel devices (sailfish, marlin, walleye, taimen). Defaults to "walleye".

### `BUILD_TAG`
The release version of [CopperheadOS](https://github.com/CopperheadOS/android-prepare-vendor/releases).
Defaults to "OPM2.171019.029.2018.04.02.21".

### `BUILD_ID`
The Build ID of the build. Defaults to "OPM2.171019.029".

### `CHROMIUM_RELEASE_NAME`
The Chromium release name that is going to be built and included in the CopperheadOS
build. Defaults to "66.0.3359.106".

### `CHROMIUM_RELEASE_CODE`
The Chromium release code that is going to be built and included in the CopperheadOS
build. Defaults to "335910652".

### `NUM_OF_THREADS`
The number of threads/processes that will be used during the various stages of
the build. Defaults to 8.

## Volumes

### `/srv/src`
Location of where all the repositories will be downloaded and built.

### `/srv/chromium`
Location of where the chromium repositories will be downloaded and built.
The chromium prebuilt package is no longer provided and we will now have
to build it from source.

### `/srv/ccache`
Location of where the ccache files are saved for both the CopperheadOS build
and the chromium build.

### `/srv/keys`
Location of where the release keys are located. If the directory is empty the
script will generate keys for you based on the `DEVICE` provided to the container.

### `/srv/tmp`
Location of the temporary directory.

### `/srv/local_manifests`
Location of any custom manifests that will be included when syncing repos.

### `/srv/zips`
Location of where the output `*.zips` and `*.xz` files will be copied to after the
build process is complete. Will include the target files and packages derived from
the target files (OTA, Flash Archive).

## Example Commands

### Basic CopperheadOS
If you want just plain CoppperheadOS just provide the enviroment variables.

```
$ sudo docker run \
    -v /media/hdd/copperheados/src:/srv/src \
    -v /media/hdd/copperheados/chromium:/srv/chromium \
    -v /media/hdd/copperheados/ccache:/srv/ccache \
    -v /media/hdd/copperheados/keys:/srv/keys \
    -v /media/hdd/copperheados/tmp:/srv/tmp \
    -v /media/hdd/copperheados/zips:/srv/zips \
    -e USE_CCACHE=1 \
    -e CCACHE_SIZE="70G" \
    -e SIGNATURE_SPOOFING="no" \
    -e DEVICE="walleye" \
    -e BUILD_TAG="OPM2.171019.029.B1.2018.05.08.01" \
    -e BUILD_ID="OPM2.171019.029.B1" \
    -e NUM_OF_THREADS=8 \
    bflux/copperheados-docker
```

### CopperheadOS with Microg
[Microg](https://microg.org/) is a FOSS implementation of most of the Google
Play Services Libraries. Most importantly it supports GCM and Account
Authentication. Inorder to support microg `SIGNATURE_SPOOFING` patch must be
applied. In addation `CUSTOM_PACKAGES` should include `GmsCore`, `GsfProxy` and
`FakeStore`. `FakeStore` is needed since most apps that rely on Google Play
Services will get upset if they don't see an app with the `com.android.vending`
package id installed on the system.

```
$ sudo docker run \
    -v /media/hdd/copperheados/src:/srv/src \
    -v /media/hdd/copperheados/chromium:/srv/chromium \
    -v /media/hdd/copperheados/ccache:/srv/ccache \
    -v /media/hdd/copperheados/keys:/srv/keys \
    -v /media/hdd/copperheados/tmp:/srv/tmp \
    -v /media/hdd/CopperheadOS-Docker/local_manifest/prebuilt:/srv/local_manifests \
    -v /media/hdd/copperheados/zips:/srv/zips \
    -e USE_CCACHE=1 \
    -e CCACHE_SIZE="70G" \
    -e SIGNATURE_SPOOFING="yes" \
    -e DEVICE="walleye" \
    -e BUILD_TAG="OPM2.171019.029.B1.2018.05.08.01" \
    -e BUILD_ID="OPM2.171019.029.B1" \
    -e NUM_OF_THREADS=8 \
    -e CUSTOM_PACKAGES="GmsCore GsfProxy MozillaNlpBackend NominatimNlpBackend com.google.android.maps FakeStore" \
    bflux/copperheados-docker
```

### CopperheadOS with Google Play Services
If you are a complete newb like I am and aren't ready to give up the Google Play
Store and Google Play Services, then simply mount the `local_manifest/opengapps` folder
as the `/srv/local_manifests` volume and set the `OPEN_GAPPS` variable to `yes`.

```
$ sudo docker run \
    -v /media/hdd/copperheados/src:/srv/src \
    -v /media/hdd/copperheados/chromium:/srv/chromium \
    -v /media/hdd/copperheados/ccache:/srv/ccache \
    -v /media/hdd/copperheados/keys:/srv/keys \
    -v /media/hdd/copperheados/tmp:/srv/tmp \
    -v /media/hdd/CopperheadOS-Docker/local_manifest/opengapps:/srv/local_manifests \
    -v /media/hdd/copperheados/zips:/srv/zips \
    -e USE_CCACHE=1 \
    -e CCACHE_SIZE="70G" \
    -e SIGNATURE_SPOOFING="no" \
    -e OPEN_GAPPS="yes" \
    -e DEVICE="walleye" \
    -e BUILD_TAG="OPM2.171019.029.B1.2018.05.08.01" \
    -e BUILD_ID="OPM2.171019.029.B1" \
    -e NUM_OF_THREADS=8 \
    bflux/copperheados-docker
```
