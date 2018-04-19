FROM ubuntu:17.10
MAINTAINER Stefan Bossbaly <sbossb@gmail.com>

########################################################
# Volumes
########################################################
ENV SRC_DIR /srv/src
ENV CCACHE_DIR /srv/ccache
ENV KEYS_DIR /srv/keys

# By default we want to use CCACHE, you can disable this
# WARNING: disabling this may slow down a lot your builds!
ENV USE_CCACHE 1

# ccache maximum size. It should be a number followed by an optional suffix: k,
# M, G, T (decimal), Ki, Mi, Gi or Ti (binary). The default suffix is G. Use 0
# for no limit.
ENV CCACHE_SIZE 50G

# Sign the builds with the keys in $KEYS_DIR
ENV SIGN_BUILDS false

# When SIGN_BUILDS = true but no keys have been provided, generate a new set with this subject
ENV KEYS_SUBJECT '/C=US/ST=California/L=Mountain View/O=Android/OU=Android/CN=Android/emailAddress=android@android.com'

########################################################
# User Id
########################################################
ENV USER "root"
ENV USER_NAME "CopperheadOs Buildbot"
ENV USER_MAIL "copperheados-buildbot@docker.host"

# Apply the MicroG's signature spoofing patch
# Valid values are "no", "yes" (for the original MicroG's patch) and
# "restricted" (to grant the permission only to the system privileged apps).
#
# The original ("yes") patch allows user apps to gain the ability to spoof
# themselves as other apps, which can be a major security threat. Using the
# restricted patch and embedding the apps that requires it as system privileged
# apps is a much secure option. See the README.md ("Custom mode") for an
# example.
ENV SIGNATURE_SPOOFING "no"

########################################################
# Build Variables
########################################################
ENV DEVICE "walleye"
ENV BUILD_TAG "OPM2.171019.029.2018.04.02.21"
ENV BUILD_ID "OPM2.171019.029"
ENV NUM_OF_THREADS 8

########################################################
# Create Volume entry points
########################################################
VOLUME $SRC_DIR
VOLUME $CCACHE_DIR
VOLUME $KEYS_DIR

########################################################
# Copy required files
########################################################
COPY src/ /root/

########################################################
# Create missing directories
########################################################
RUN mkdir -p $SRC_DIR
RUN mkdir -p $CCACHE_DIR
RUN mkdir -p $KEYS_DIR

########################################################
# Install Dependencies
########################################################
RUN apt-get -qq update
RUN apt-get -qqy upgrade
RUN apt-get install -y bc bison build-essential ccache cron curl flex \
      g++-multilib gcc-multilib git gnupg gperf imagemagick lib32ncurses5-dev \
      lib32readline-dev lib32z1-dev libesd0-dev liblz4-tool libncurses5-dev \
      libsdl1.2-dev libssl-dev libwxgtk3.0-dev libxml2 libxml2-utils lsof lzop \
      maven openjdk-8-jdk pngcrush procps python rsync schedtool \
	  squashfs-tools wget xdelta3 xsltproc yasm zip zlib1g-dev

########################################################
# Install Repo Util
########################################################
ADD https://commondatastorage.googleapis.com/git-repo-downloads/repo /usr/local/bin/
RUN chmod 755 /usr/local/bin/*

########################################################
# Set the work directory
########################################################
WORKDIR $SRC_DIR

ENTRYPOINT ["/root/docker_entrypoint.sh"]
