# ARGUMENTS --------------------------------------------------------------------
##
# Board architecture
##
ARG IMAGE_ARCH=

##
# Base container version
##
ARG SDK_BASE_VERSION=3.3.1-8.0
ARG BASE_VERSION=3.3.1

##
# Directory of the application inside container
##
ARG APP_ROOT=

##
# Board GPU vendor prefix
##
ARG GPU=

# ARGUMENTS --------------------------------------------------------------------



# BUILD ------------------------------------------------------------------------
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build

ARG IMAGE_ARCH
ARG APP_ROOT

# this is needed for the build to work witht he libslint
RUN apt-get -q -y update && \
    apt-get -q -y install \
    libfontconfig1

COPY . ${APP_ROOT}
WORKDIR ${APP_ROOT}

# build
RUN dotnet restore && \
    if [ "$IMAGE_ARCH" = "arm64" ] ; then \
        export ARCH=${IMAGE_ARCH} ; \
    elif [ "$IMAGE_ARCH" = "armhf" ] ; then \
        export ARCH="arm" ; \
    elif [ "$IMAGE_ARCH" = "amd64" ] ; then \
        export ARCH="x64" ; \
    fi && \
    dotnet publish -c Release -r linux-${ARCH} && \
    if [ "${IMAGE_ARCH}" = "amd64" ]; then \
        mv ./bin/Release/net8.0/linux-x64 ./bin/Release/net8.0/linux-amd64 ; \
    fi
# BUILD ------------------------------------------------------------------------



# DEPLOY ------------------------------------------------------------------------
FROM --platform=linux/${IMAGE_ARCH} \
    commontorizon/wayland-base${GPU}:${BASE_VERSION} AS deploy

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
# Install Slint and .net dependencies
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive \
    apt-get install \
    libfontconfig1 \
    libxkbcommon0 \
    fonts-noto-core \
    fonts-noto-cjk \
    fonts-noto-cjk-extra \
    fonts-noto-color-emoji \
    fonts-noto-ui-core \
    fonts-noto-ui-extra \
    libicu72 \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get -y update && apt-get install -y --no-install-recommends \
# DO NOT REMOVE THIS LABEL: this is used for VS Code automation
    # __torizon_packages_prod_start__
    # __torizon_packages_prod_end__
# DO NOT REMOVE THIS LABEL: this is used for VS Code automation
	&& apt-get clean && apt-get autoremove && rm -rf /var/lib/apt/lists/*

# Default to the Skia backend for best performance
ENV SLINT_BACKEND=winit-skia
# Default to Slint running in fullscreen
ENV SLINT_FULLSCREEN=1
# Default style to fluent
ENV SLINT_STYLE=fluent

# Copy the application compiled in the build step to the $APP_ROOT directory
# path inside the container, where $APP_ROOT is the torizon_app_root
# configuration defined in settings.json
COPY --from=build ${APP_ROOT}/bin/Release/net8.0/linux-${IMAGE_ARCH}/publish ${APP_ROOT}

# "cd" (enter) into the APP_ROOT directory
WORKDIR ${APP_ROOT}

# Command executed in runtime when the container starts
CMD ["./__change__"]

# DEPLOY ------------------------------------------------------------------------
