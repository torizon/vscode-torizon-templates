# ARGUMENTS --------------------------------------------------------------------
##
# Base container version
##
ARG BASE_VERSION=4.0.0
##
# Directory of the application inside container
##
ARG APP_ROOT=

##
# Board architecture
##
ARG IMAGE_ARCH=

##
# Board GPU vendor prefix
##
ARG GPU=

FROM --platform=linux/${IMAGE_ARCH} \
    torizon/wayland-base${GPU}:${BASE_VERSION} AS build

ARG IMAGE_ARCH
ARG GPU
ARG APP_ROOT

# stick to bookworm on /etc/apt/sources.list.d
RUN sed -i 's/sid/bookworm/g' /etc/apt/sources.list.d/debian.sources

# add the Microsoft OpenJDK repo
RUN apt-get install wget -y && \
    wget https://packages.microsoft.com/config/debian/10/packages-microsoft-prod.deb -O packages-microsoft-prod.deb && \
    dpkg -i packages-microsoft-prod.deb

# __deps__
RUN apt-get -q -y update && \
    apt-get -q -y install \
    ant \
    msopenjdk-21 \
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

RUN ant jar

FROM --platform=linux/${IMAGE_ARCH} \
    commontorizon/wayland-base${GPU}:${BASE_VERSION} AS deploy

ARG IMAGE_ARCH
ARG GPU
ARG APP_ROOT

# SSH for remote debug
EXPOSE 2231
ARG SSHUSERNAME=torizon

# Make sure we don't get notifications we can't answer during building.
ENV DEBIAN_FRONTEND="noninteractive"

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

# add the Microsoft OpenJDK repo
# TODO: we are using the release of the Debian 10
# TODO: we need to check for updates on the repo
RUN apt-get install wget -y && \
    wget https://packages.microsoft.com/config/debian/10/packages-microsoft-prod.deb -O packages-microsoft-prod.deb && \
    dpkg -i packages-microsoft-prod.deb

# your regular RUN statements here
# Install required packages
RUN apt-get -q -y update && \
    apt-get -q -y install \
    file \
    tzdata \
    locales \
    fontconfig \
    libxrender1 \
    libxtst6 \
    libxi6 \
    # TODO: use JLINK instead
    msopenjdk-21 \
# DOES NOT REMOVE THIS LABEL: this is used for VS Code automation
    # __torizon_packages_prod_start__
    # __torizon_packages_prod_end__
# DO NOT REMOVE THIS LABEL: this is used for VS Code automation
    && \
    apt-get clean && apt-get autoremove && \
    rm -rf /var/lib/apt/lists/*


USER torizon

COPY ./libs ${APP_ROOT}/libs
COPY ./assets ${APP_ROOT}/assets

# Copy the application compiled in the build step to the $APP_ROOT directory
# path inside the container, where $APP_ROOT is the torizon_app_root
# configuration defined in settings.json
COPY --from=build ${APP_ROOT} ${APP_ROOT}

# "cd" (enter) into the APP_ROOT directory
WORKDIR ${APP_ROOT}

# Command executed in runtime when the container starts
CMD [ "java", "-cp","libs/*:dist/__change__.jar", "__change__.Form1" ]
