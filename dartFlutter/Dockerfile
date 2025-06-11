# ARGUMENTS --------------------------------------------------------------------
##
# Base Container version
# Using Flutter v3.27.x
##
ARG SDK_BASE_VERSION=SDK
##
# Base container version
##
ARG BASE_VERSION=runtime_release

##
# Board architecture
##
ARG IMAGE_ARCH=

##
# Directory of the application inside container
##
ARG APP_ROOT=

##
# Board GPU vendor prefix
##
ARG GPU=

##
# Build/Deploy Step
##

# BUILD ------------------------------------------------------------------------
FROM --platform=linux/${IMAGE_ARCH} \
    crossware.app:5050/public-repos/flutter:${SDK_BASE_VERSION} AS build

ARG IMAGE_ARCH
ARG APP_ROOT

COPY . ${APP_ROOT}
WORKDIR ${APP_ROOT}

RUN flutter-elinux clean; flutter-elinux pub get; flutter-elinux build elinux --release

# BUILD ------------------------------------------------------------------------


# DEPLOY -----------------------------------------------------------------------
FROM --platform=linux/${IMAGE_ARCH} \
    crossware.app:5050/public-repos/flutter:${BASE_VERSION}${GPU} AS final

ARG GPU
ARG APP_ROOT
ARG SSHUSERNAME

WORKDIR ${APP_ROOT}

# TODO: When the next version of the base containers, with this package added,
# is released, this libwayland-cursor0 package install can be removed from here
RUN apt-get -q -y update && \
    apt-get -q -y install \
    libwayland-cursor0 \
    && \
    apt-get clean && apt-get autoremove && \
    rm -rf /var/lib/apt/lists/*

COPY --chown=$SSHUSERNAME:$SSHUSERNAME run-release.sh ${APP_ROOT}/
RUN chmod +x ${APP_ROOT}/run-release.sh

COPY --from=build ${APP_ROOT}/build/elinux/arm64/release/bundle/ ${APP_ROOT}/bundle

ENV FLUTTER_DRM_DEVICE="/dev/dri/card0:/dev/dri/card1"
ENV APP_PATH=${APP_ROOT}/bundle

CMD ["run-release.sh"]
# DEPLOY -----------------------------------------------------------------------
