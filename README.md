# CopperheadOS-Docker
Docker container for building CopperheadOS. Still very much a work in progress

## Enviroment Variables
| Variable Name        | Description                                       |                     Default Value  |
|:---------------------|---------------------------------------------------|-----------------------------------:|
| `USE_CCACHE`         | Enable or disable CCACHE                          |                                  1 |
| `CCACHE_SIZE`        | CCACHE max size.                                  |                                50G |
| `SIGNATURE_SPOOFING` | NOT SUPPORTED ... yet                             |                                 no |
| `DEVICE`             | Name of the device that the build is targeting    |                          "walleye" |
| `BUILD_TAG`          | Name of the build tag                             |    "OPM2.171019.029.2018.04.02.21" |
| `BUILD_ID`           | Name of the build id                              |                  "OPM2.171019.029" |
| `NUM_OF_THREADS`     | Number of threads to use while syncing/compiling  |                                  8 |

## Example Command
```
$ sudo docker run \
    -v /home/stefan/copperheados/src:/srv/src \
    -v /home/stefan/copperheados/ccache:/srv/ccache \
    -e DEVICE="walleye" \
    -e BUILD_TAG="OPM2.171019.029.2018.04.02.21" \
    -e BUILD_ID="OPM2.171019.029" \
    -e NUM_OF_THREADS=16 \
    bflux/copperheados-docker
```
