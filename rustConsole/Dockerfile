# ARGUMENTS --------------------------------------------------------------------
##
# Base container version
##
ARG SDK_BASE_VERSION=1.78
ARG BASE_VERSION=4.0.0

##
# Board architecture
##
ARG IMAGE_ARCH=

##
# Directory of the application inside container
##
ARG APP_ROOT=


# BUILD ------------------------------------------------------------------------
FROM rust:${SDK_BASE_VERSION} AS build

ARG IMAGE_ARCH
ARG APP_ROOT

RUN apt-get update && \
    apt-get install -y \
    gcc-arm-linux-gnueabihf \
    gcc-aarch64-linux-gnu \
    # ADD YOUR PACKAGES HERE
# DO NOT REMOVE THIS LABEL: this is used for VS Code automation
    # __torizon_packages_build_start__
    # __torizon_packages_build_end__
# DO NOT REMOVE THIS LABEL: this is used for VS Code automation
    && \
    apt-get clean && apt-get autoremove && \
    rm -rf /var/lib/apt/lists/*

RUN if [ "$IMAGE_ARCH" = "arm64" ] ; then \
        echo aarch64-unknown-linux-gnu > ~/rust-toolchain-arch.txt; \
    elif [ "$IMAGE_ARCH" = "armhf" ] ; then \
        echo armv7-unknown-linux-gnueabihf > ~/rust-toolchain-arch.txt; \
    elif [ "$IMAGE_ARCH" = "amd64" ] ; then \
        echo x86_64-unknown-linux-gnu > ~/rust-toolchain-arch.txt; \
    fi

RUN rustup target add $(cat ~/rust-toolchain-arch.txt)

COPY . ${APP_ROOT}
WORKDIR ${APP_ROOT}

# Remove the code from the debug builds, inside this container, to build the
# release version from a clean build
RUN rm -rf ${APP_ROOT}/target


RUN TARGET=$(cat ~/rust-toolchain-arch.txt) && \
    cargo build --release --target $TARGET && \
    mkdir -p build && \
    cp -r target/$TARGET/release build

# BUILD ------------------------------------------------------------------------


# DEPLOY ------------------------------------------------------------------------
FROM --platform=linux/${IMAGE_ARCH} torizon/debian:${BASE_VERSION} AS deploy

ARG IMAGE_ARCH
ARG APP_ROOT

RUN apt-get -y update && apt-get install -y --no-install-recommends \
    # ADD YOUR PACKAGES HERE
# DO NOT REMOVE THIS LABEL: this is used for VS Code automation
    # __torizon_packages_prod_start__
    # __torizon_packages_prod_end__
# DO NOT REMOVE THIS LABEL: this is used for VS Code automation
    && apt-get clean && apt-get autoremove && rm -rf /var/lib/apt/lists/*

# Copy the application compiled in the build step to the $APP_ROOT directory
# path inside the container, where $APP_ROOT is the torizon_app_root
# configuration defined in settings.json
COPY --from=build ${APP_ROOT}/build/release/__change__ ${APP_ROOT}/__change__

# "cd" (enter) into the APP_ROOT directory
WORKDIR ${APP_ROOT}

# Command executed in runtime when the container starts
CMD ["./__change__"]
# DEPLOY ------------------------------------------------------------------------
