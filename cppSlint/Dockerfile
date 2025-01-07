# ARGUMENTS --------------------------------------------------------------------
##
# Base container version
##
ARG CROSS_SDK_BASE_TAG=3.3.0-bookworm
ARG BASE_VERSION=3.3.0

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
# Slint Version
##
ARG SLINT_VERSION=nightly

# BUILD ------------------------------------------------------------------------
FROM torizon/debian-cross-toolchain-${IMAGE_ARCH}${GPU}:${CROSS_SDK_BASE_TAG} AS build

ARG IMAGE_ARCH
ARG GPU
ARG APP_ROOT
ARG SLINT_VERSION

# Install an up-to-date cmake as well as ninja and make
RUN apt-get update && \
    apt-get install --assume-yes gpg wget && \
    wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | gpg --dearmor - | tee /usr/share/keyrings/kitware-archive-keyring.gpg >/dev/null && \
    echo 'deb [signed-by=/usr/share/keyrings/kitware-archive-keyring.gpg] https://apt.kitware.com/ubuntu/ jammy main' | tee /etc/apt/sources.list.d/kitware.list >/dev/null && \
    apt-get update && \
    apt-get install --assume-yes cmake ninja-build make && \
    rm -f /etc/apt/sources.list.d/kitware.list /usr/share/keyrings/kitware-archive-keyring.gpg && \
    rm -rf /var/lib/apt/lists/*

COPY --chmod=755 armhf-toolchain.cmake arm64-toolchain.cmake /

RUN if [ "$IMAGE_ARCH" = "arm64" ] ; then \
        echo arm64 > /cross-toolchain-arch.txt; \
        dpkg-divert --divert /usr/bin/cmake.real --rename /usr/bin/cmake; \
        printf '#!/bin/sh\nexport CMAKE_TOOLCHAIN_FILE=/arm64-toolchain.cmake\nexec /usr/bin/cmake.real $*\n' > /usr/bin/cmake; \
        chmod 755 /usr/bin/cmake ;\
    elif [ "$IMAGE_ARCH" = "armhf" ] ; then \
        echo armhf > /cross-toolchain-arch.txt; \
        dpkg-divert --divert /usr/bin/cmake.real --rename /usr/bin/cmake; \
        printf '#!/bin/sh\nexport CMAKE_TOOLCHAIN_FILE=/armhf-toolchain.cmake\nexec /usr/bin/cmake.real $*\n' > /usr/bin/cmake; \
        chmod 755 /usr/bin/cmake ;\
    elif [ "$IMAGE_ARCH" = "amd64" ] ; then \
        echo amd64 > /cross-toolchain-arch.txt; \
    fi

# Download Slint binary packages
RUN \
    CROSS_TOOLCHAIN_ARCH=$(cat /cross-toolchain-arch.txt) && \
    if [ "$SLINT_VERSION" = "nightly" ]; then \
        GITHUB_RELEASE=nightly; \
        GITHUB_FILENAME_INFIX=nightly; \
    else \
        GITHUB_RELEASE=$SLINT_VERSION; \
        GITHUB_FILENAME_INFIX=$SLINT_VERSION; \
    fi && \
    wget -O - https://github.com/slint-ui/slint/releases/download/$GITHUB_RELEASE/Slint-cpp-$GITHUB_FILENAME_INFIX-Linux-$CROSS_TOOLCHAIN_ARCH.tar.gz \
    | tar xzvf - --strip-components 1 -C /usr && \
    if [ "$SLINT_VERSION" = "nightly" ]; then \
        echo 'set(SLINT_GITHUB_RELEASE "nightly" CACHE STRING "")' >>  armhf-toolchain.cmake ;\
        echo 'set(SLINT_GITHUB_RELEASE "nightly" CACHE STRING "")' >>  arm64-toolchain.cmake ;\
    fi

# Install Slint build dependencies (libxcb, etc.)
RUN \
    --mount=type=cache,target=/var/cache/apt \
    CROSS_TOOLCHAIN_ARCH=$(cat /cross-toolchain-arch.txt) && \
    rm /etc/apt/sources.list.d/toradex.sources && \
    apt-get update && \
    apt-get install --assume-yes \
    pkg-config \
    libfontconfig1-dev:$CROSS_TOOLCHAIN_ARCH \
    libxcb1-dev:$CROSS_TOOLCHAIN_ARCH \
    libxcb-render0-dev:$CROSS_TOOLCHAIN_ARCH \
    libxcb-shape0-dev:$CROSS_TOOLCHAIN_ARCH \
    libxcb-xfixes0-dev:$CROSS_TOOLCHAIN_ARCH \
    libxkbcommon-dev:$CROSS_TOOLCHAIN_ARCH \
    libinput-dev:$CROSS_TOOLCHAIN_ARCH \
    libudev-dev:$CROSS_TOOLCHAIN_ARCH \
    libdrm2:$CROSS_TOOLCHAIN_ARCH \
    libgbm-dev:$CROSS_TOOLCHAIN_ARCH \
    python3 \
    clang \
    libstdc++-11-dev:$CROSS_TOOLCHAIN_ARCH && \
    rm -rf /var/lib/apt/lists/*

ENV PKG_CONFIG_ALLOW_CROSS=1

# __deps__
RUN apt-get -q -y update && \
    apt-get -q -y install \
# DO NOT REMOVE THIS LABEL: this is used for VS Code automation
    # __torizon_packages_build_start__
    # __torizon_packages_build_end__
# DO NOT REMOVE THIS LABEL: this is used for VS Code automation
    && \
    apt-get clean && apt-get autoremove && \
    rm -rf /var/lib/apt/lists/*
# __deps__

# get the arch and copy the /usr/lib to /usr/lib/${ARCH_TRIPLET}
RUN ARCH_TRIPLET=$(dpkg-architecture -qDEB_HOST_MULTIARCH) && \
    cp -r /usr/lib/libslint_cpp.so /usr/lib/${ARCH_TRIPLET}/libslint_cpp.so

# Default to Ninja
ENV CMAKE_GENERATOR=Ninja

COPY . ${APP_ROOT}
WORKDIR ${APP_ROOT}

# Remove the code from the debug builds, inside this container, to build the
# release version from a clean build
RUN rm -rf ${APP_ROOT}/build

RUN cmake -DCMAKE_BUILD_TYPE=Release -B build/${IMAGE_ARCH} -S . \
    && cmake --build build/${IMAGE_ARCH}

# BUILD ------------------------------------------------------------------------


# DEPLOY ------------------------------------------------------------------------
FROM --platform=linux/${IMAGE_ARCH} \
    torizon/wayland-base${GPU}:${BASE_VERSION} AS deploy

ARG IMAGE_ARCH
ARG GPU
ARG APP_ROOT

# Install Slint dependencies
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install libfontconfig1 libxkbcommon0 libinput10 fonts-noto-core fonts-noto-cjk fonts-noto-cjk-extra fonts-noto-color-emoji fonts-noto-ui-core fonts-noto-ui-extra \
    && rm -rf /var/lib/apt/lists/*

# copy Slint library
COPY --from=build /usr/lib/libslint* /usr/lib

# for vivante GPU we need some "special" sauce
RUN apt-get -q -y update && \
        if [ "${GPU}" = "-vivante" ] || [ "${GPU}" = "-imx8" ]; then \
            apt-get -q -y install \
            imx-gpu-viv-wayland-dev \
        ; else \
            apt-get -q -y install \
            libgl1 \
        ; fi \
    && \
    apt-get clean && apt-get autoremove && \
    rm -rf /var/lib/apt/lists/*

RUN apt-get -y update && apt-get install -y --no-install-recommends \
# DO NOT REMOVE THIS LABEL: this is used for VS Code automation
    # __torizon_packages_prod_start__
    # __torizon_packages_prod_end__
# DO NOT REMOVE THIS LABEL: this is used for VS Code automation
	&& apt-get clean && apt-get autoremove && rm -rf /var/lib/apt/lists/*

# Default to the Skia backend for best performance
ENV SLINT_BACKEND=linuxkms-skia
# Default to Slint running in fullscreen
ENV SLINT_FULLSCREEN=1

# Copy the application compiled in the build step to the $APP_ROOT directory
# path inside the container, where $APP_ROOT is the torizon_app_root
# configuration defined in settings.json
COPY --from=build ${APP_ROOT}/build/${IMAGE_ARCH} ${APP_ROOT}

# Remove the CMakeFiles directory, that is just needed for the build and not
# for the execution
RUN rm -rf ${APP_ROOT}/CMakeFiles

# "cd" (enter) into the APP_ROOT directory
WORKDIR ${APP_ROOT}

# Command executed in runtime when the container starts
CMD ["./__change__"]
# DEPLOY ------------------------------------------------------------------------
