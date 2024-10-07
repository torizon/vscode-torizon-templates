# ARGUMENTS --------------------------------------------------------------------
##
# Board architecture
##
ARG IMAGE_ARCH=

##
# Base container version
##
ARG BASE_VERSION=4.0.0

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
FROM --platform=linux/${IMAGE_ARCH} \
    torizon/wayland-base${GPU}:${BASE_VERSION} AS build

ARG IMAGE_ARCH
ARG GPU
ARG APP_ROOT

# stick to bookworm on /etc/apt/sources.list.d
RUN sed -i 's/sid/bookworm/g' /etc/apt/sources.list.d/debian.sources

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

# Install required packages
RUN apt-get -q -y update && \
    apt-get -q -y install \
    gcc \
    g++ \
    make \
    git \
    libatspi2.0-0 \
    libgconf-2-4 \
    libglib2.0-bin \
    libgtk2.0-0 \
    libgtk-3-0 \
    libnotify4 \
    libnss3 \
    libuuid1 \
    libxcb-dri3-0 \
    xdg-utils \
    libxss1 \
    libxtst6 \
    libasound2 \
    curl \
# DO NOT REMOVE THIS LABEL: this is used for VS Code automation
    # __torizon_packages_build_start__
    # __torizon_packages_build_end__
# DO NOT REMOVE THIS LABEL: this is used for VS Code automation
    && \
    apt-get clean && apt-get autoremove && \
    rm -rf /var/lib/apt/lists/*

# install the latest node js
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs

RUN npm config set registry https://registry.npmjs.org/

COPY . ${APP_ROOT}
WORKDIR ${APP_ROOT}

# Remove the code from the debug builds, inside this container, to build the
# release version from a clean build
RUN rm -rf ${APP_ROOT}/out


RUN npm install

# build the application
RUN  if [ "${IMAGE_ARCH}" = "arm64" ]; then \
        npx electron-forge package -a arm64 -p linux; \
    elif [ "${IMAGE_ARCH}" = "arm" ]; then \
        npx electron-forge package -a armv7l -p linux; \
    else \
        npx electron-forge package -a x86 -p linux; \
    fi;

# Copy the EGL lib inside the project's directory for vivante GPU
RUN  if [ "${GPU}" = "-vivante" ] || [ "${GPU}" = "-imx8" ]; then \
        cp /usr/lib/aarch64-linux-gnu/libEGL.so ${APP_ROOT}/out/__change__-linux-${IMAGE_ARCH} && \
        cp /usr/lib/aarch64-linux-gnu/libGLESv2.so ${APP_ROOT}/out/__change__-linux-${IMAGE_ARCH}; \
    # If it is a armv7l, this renames the output directory with the name expected by the Deploy fase
    elif [ "${IMAGE_ARCH}" = "arm" ]; then \
        mv ${APP_ROOT}/out/__change__-linux-armv7l ${APP_ROOT}/out/__change__-linux-${IMAGE_ARCH}; \
    fi;
# BUILD ------------------------------------------------------------------------



# DEPLOY -----------------------------------------------------------------------
FROM --platform=linux/${IMAGE_ARCH} \
    torizon/wayland-base${GPU}:${BASE_VERSION} AS deploy

ARG IMAGE_ARCH
ARG GPU
ARG APP_ROOT

# stick to bookworm on /etc/apt/sources.list.d
RUN sed -i 's/sid/bookworm/g' /etc/apt/sources.list.d/debian.sources

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

# your regular RUN statements here
# Install required packages
RUN apt-get -q -y update && \
    apt-get -q -y install \
    libatspi2.0-0 \
    libgconf-2-4 \
    libglib2.0-bin \
    libgtk2.0-0 \
    libgtk-3-0 \
    libnotify4 \
    libnss3 \
    libuuid1 \
    libxcb-dri3-0 \
    xdg-utils \
    libxss1 \
    libxtst6 \
    libasound2 \
    curl \
# DO NOT REMOVE THIS LABEL: this is used for VS Code automation
    # __torizon_packages_prod_start__
    # __torizon_packages_prod_end__
# DO NOT REMOVE THIS LABEL: this is used for VS Code automation
    && \
    apt-get clean && apt-get autoremove && \
    rm -rf /var/lib/apt/lists/*

# install the latest node js
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs

# Copy the application compiled in the build step to the $APP_ROOT directory
# path inside the container, where $APP_ROOT is the torizon_app_root
# configuration defined in settings.json
COPY --from=build ${APP_ROOT}/out/__change__-linux-${IMAGE_ARCH} ${APP_ROOT}

# "cd" (enter) into the APP_ROOT directory
WORKDIR ${APP_ROOT}

# Command executed in runtime when the container starts
# FIX: In this template arm32 is not working properly with egl, so if you are
# using an arm32 remove the "--use-gl=egl" and "--in-process-gpu" arguments.
CMD [ "./__change__", "--no-sandbox", "--ozone-platform=wayland", "--use-gl=egl", "--in-process-gpu" ]

# DEPLOY -----------------------------------------------------------------------
