# ARGUMENTS --------------------------------------------------------------------
##
# Base container version
# Using Slint v1.7.2 base images
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


# BUILD ------------------------------------------------------------------------
FROM torizon/debian-cross-toolchain-${IMAGE_ARCH}${GPU}:${CROSS_SDK_BASE_TAG} AS build

ARG IMAGE_ARCH
ARG GPU
ARG COMPILER_ARCH
ARG APP_ROOT
ENV IMAGE_ARCH ${IMAGE_ARCH}

RUN if [ "$IMAGE_ARCH" = "arm64" ] ; then \
        echo aarch64-unknown-linux-gnu > /rust-toolchain-arch.txt; \
        echo arm64 > /cross-toolchain-arch.txt; \
    elif [ "$IMAGE_ARCH" = "armhf" ] ; then \
        echo armv7-unknown-linux-gnueabihf > /rust-toolchain-arch.txt; \
        echo armhf > /cross-toolchain-arch.txt; \
    elif [ "$IMAGE_ARCH" = "amd64" ] ; then \
        echo x86_64-unknown-linux-gnu > /rust-toolchain-arch.txt; \
        echo amd64 > /cross-toolchain-arch.txt; \
    fi

# Install Rust
ENV RUSTUP_HOME=/rust
ENV CARGO_HOME=/cargo
ENV PATH=/cargo/bin:/rust/bin:$PATH

RUN curl https://sh.rustup.rs -sSf | sh -s -- -y
RUN rustup target add $(cat /rust-toolchain-arch.txt)

RUN mkdir -p /cargo/registry && chmod 777 /cargo/registry

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

RUN mkdir -p /cargo/registry && chmod 777 /cargo/registry

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

# Don't require font-config when the compiler runs
ENV RUST_FONTCONFIG_DLOPEN=on

COPY . ${APP_ROOT}
WORKDIR ${APP_ROOT}

# Remove the code from the debug builds, inside this container, to build the
# release version from a clean build
RUN rm -rf ${APP_ROOT}/target


# BUILD ------------------------------------------------------------------------

RUN TARGET=$(cat /rust-toolchain-arch.txt) && \
    cargo build --release --target $TARGET && \
    mkdir -p build && \
    cp -r target/$TARGET/release build

# DEPLOY ------------------------------------------------------------------------
FROM --platform=linux/${IMAGE_ARCH} \
    torizon/wayland-base${GPU}:${BASE_VERSION} AS deploy

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
        ; fi \
    && \
    apt-get clean && apt-get autoremove && \
    rm -rf /var/lib/apt/lists/*

# Install Slint dependencies
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install libfontconfig1 libxkbcommon0 libinput10 fonts-noto-core fonts-noto-cjk fonts-noto-cjk-extra fonts-noto-color-emoji fonts-noto-ui-core fonts-noto-ui-extra \
    && rm -rf /var/lib/apt/lists/*

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
COPY --from=build ${APP_ROOT}/build/release/__change__ ${APP_ROOT}/__change__

# "cd" (enter) into the APP_ROOT directory
WORKDIR ${APP_ROOT}


# ADD YOUR ARGUMENTS HERE
CMD [ "./__change__" ]

# DEPLOY ------------------------------------------------------------------------
