# ARGUMENTS --------------------------------------------------------------------
##
# Base container version
# Using Slint v1.8.0 base images
##
ARG CROSS_SDK_BASE_TAG=4.0.0-1.8.0
ARG BASE_VERSION=4.2.0

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


# BUILD ------------------------------------------------------------------------
FROM commontorizon/slint-sdk-${IMAGE_ARCH}:${CROSS_SDK_BASE_TAG} AS build

ARG IMAGE_ARCH
ARG GPU
ARG APP_ROOT

# Rust
ENV RUSTUP_HOME=/rust
ENV CARGO_HOME=/cargo
ENV PATH=/cargo/bin:/rust/bin:$PATH

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

# Don't require font-config when the compiler runs
ENV RUST_FONTCONFIG_DLOPEN=on

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
FROM --platform=linux/${IMAGE_ARCH} torizon/wayland-base${GPU}:${BASE_VERSION} AS deploy

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
