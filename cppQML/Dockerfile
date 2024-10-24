# ARGUMENTS --------------------------------------------------------------------
##
# SDK container version
##
ARG SDK_BASE_VERSION=3.4.0
##
# Base container version
##
ARG BASE_VERSION=3.4.0

##
# Board architecture
##
ARG IMAGE_ARCH=

##
# Board GPU vendor prefix
##
ARG GPU=

##
# Directory of the application inside container
##
ARG APP_ROOT=

# BUILD ------------------------------------------------------------------------
# TODO: cross compile x86 to arm
# We will use emulation here
##
# Build Step
##
FROM --platform=linux/${IMAGE_ARCH} \
    torizon/qt6-wayland${GPU}:${SDK_BASE_VERSION} AS build

ARG IMAGE_ARCH
ARG GPU
ARG APP_ROOT

# for vivante GPU we need some "special" sauce
RUN apt-get -q -y update && \
        if [ "${GPU}" = "-vivante" ] || [ "${GPU}" = "-imx8" ]; then \
            apt-get -q -y install \
            imx-gpu-viv-wayland-dev \
        ; else \
            apt-get -q -y install \
            libgl1 \
            libgles-dev \
        ; fi \
    && \
    apt-get clean && apt-get autoremove && \
    rm -rf /var/lib/apt/lists/*

# __deps__
RUN apt-get -q -y update && \
    apt-get -q -y install \
    build-essential \
    cmake \
    qt6-base-private-dev \
    qt6-base-dev \
    qt6-wayland \
    qt6-wayland-dev \
    qt6-declarative-dev \
    qt6-declarative-private-dev \
    qml6-module-qtqml \
    qml6-module-qtqml-workerscript \
    qml6-module-qtcore \
    qml6-module-qtquick \
    qml6-module-qtquick-window \
    qml6-module-qtquick-controls \
    qml6-module-qtquick-layouts \
    qml6-module-qtquick-templates \
    libqt6opengl6-dev \
    # ADD YOUR PACKAGES HERE
# DO NOT REMOVE THIS LABEL: this is used for VS Code automation
    # __torizon_packages_build_start__
    # __torizon_packages_build_end__
# DO NOT REMOVE THIS LABEL: this is used for VS Code automation
    && \
    apt-get clean && apt-get autoremove && \
    rm -rf /var/lib/apt/lists/*
# __deps__

COPY . ${APP_ROOT}
WORKDIR ${APP_ROOT}

# Remove the code from the debug builds, inside this container, to build the
# release version from a clean build
RUN rm -rf ${APP_ROOT}/build-${IMAGE_ARCH}

RUN if [ "$IMAGE_ARCH" = "arm64" ] ; then \
        cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_COMPILER=aarch64-linux-gnu-g++ -DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc -Bbuild-${IMAGE_ARCH} ; \
    elif [ "$IMAGE_ARCH" = "arm" ] ; then \
        cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_COMPILER=arm-linux-gnueabihf-g++ -DCMAKE_C_COMPILER=arm-linux-gnueabihf-gcc -Bbuild-${IMAGE_ARCH} ; \
    fi

RUN cmake --build build-${IMAGE_ARCH}

# BUILD ------------------------------------------------------------------------

# DEPLOY -----------------------------------------------------------------------
##
# Deploy Step
##
FROM --platform=linux/${IMAGE_ARCH} \
    torizon/qt6-wayland${GPU}:${BASE_VERSION} AS deploy

ARG IMAGE_ARCH
ARG GPU
ARG APP_ROOT

# SSH for remote debug
EXPOSE 2231
ARG SSHUSERNAME=torizon

# Make sure we don't get notifications we can't answer during building.
ENV DEBIAN_FRONTEND="noninteractive"

# for vivante GPU we need some "special" sauce
RUN apt-get -q -y update && \
        if [ "${GPU}" = "-vivante" ] || [ "${GPU}" = "-imx8" ]; then \
            apt-get -q -y install \
            imx-gpu-viv-wayland-dev \
        ; else \
            apt-get -q -y install \
            libgl1 \
            libgles-dev \
        ; fi \
    && \
    apt-get clean && apt-get autoremove && \
    rm -rf /var/lib/apt/lists/*

# your regular RUN statements here
# Install required packages
RUN apt-get -q -y update && \
    apt-get -q -y install \
    file \
    curl \
    qt6-base-private-dev \
    qt6-base-dev \
    qt6-wayland \
    qt6-wayland-dev \
    qt6-declarative-dev \
    qt6-declarative-private-dev \
    qml6-module-qtqml \
    qml6-module-qtqml-workerscript \
    qml6-module-qtcore \
    qml6-module-qtquick \
    qml6-module-qtquick-window \
    qml6-module-qtquick-controls \
    qml6-module-qtquick-layouts \
    qml6-module-qtquick-templates \
# DO NOT REMOVE THIS LABEL: this is used for VS Code automation
    # __torizon_packages_prod_start__
    # __torizon_packages_prod_end__
# DO NOT REMOVE THIS LABEL: this is used for VS Code automation
    && \
    apt-get clean && apt-get autoremove && \
    rm -rf /var/lib/apt/lists/*

USER torizon

# Copy the application compiled in the build step to the $APP_ROOT directory
# path inside the container, where $APP_ROOT is the torizon_app_root
# configuration defined in settings.json.
COPY --from=build ${APP_ROOT}/build-${IMAGE_ARCH}/bin ${APP_ROOT}

# "cd" (enter) into the APP_ROOT directory
WORKDIR ${APP_ROOT}

# Command executed in runtime when the container starts
CMD ["./__change__"]

# DEPLOY -----------------------------------------------------------------------
