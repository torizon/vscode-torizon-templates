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
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build

ARG IMAGE_ARCH
ARG GPU
ARG APP_ROOT

COPY . ${APP_ROOT}
WORKDIR ${APP_ROOT}/__change__.Skia.Gtk

# build
RUN dotnet restore && \
    if [ "$IMAGE_ARCH" = "arm64" ] ; then \
        export ARCH=${IMAGE_ARCH} ; \
    elif [ "$IMAGE_ARCH" = "armhf" ] ; then \
        export ARCH="arm" ; \
    elif [ "$IMAGE_ARCH" = "amd64" ] ; then \
        export ARCH="x64" ; \
    fi && \
    dotnet publish -c Release -r linux-${IMAGE_ARCH} --no-self-contained && \
    # this if is a edge case when the ARCH and IMAGE_ARCH are equal, like arm64
    if [ "./bin/Release/net8.0/linux-${ARCH}" != "./bin/Release/net8.0/linux-${IMAGE_ARCH}" ]; then \
        mv ./bin/Release/net8.0/linux-${ARCH} ./bin/Release/net8.0/linux-${IMAGE_ARCH}; \
    fi

# BUILD ------------------------------------------------------------------------



# DEPLOY -----------------------------------------------------------------------
FROM --platform=linux/${IMAGE_ARCH} \
    torizon/dotnet8-gtk3${GPU}:${BASE_VERSION} AS deploy

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
            libgles2 libgl1-mesa-dev \
        ; fi \
    && \
    apt-get clean && apt-get autoremove && \
    rm -rf /var/lib/apt/lists/*

RUN apt-get -y update && apt-get install -y --no-install-recommends \
    # ADD YOUR PACKAGES HERE
# DO NOT REMOVE THIS LABEL: this is used for VS Code automation
    # __torizon_packages_prod_start__
    # __torizon_packages_prod_end__
# DO NOT REMOVE THIS LABEL: this is used for VS Code automation
	&& apt-get clean && apt-get autoremove && rm -rf /var/lib/apt/lists/*

ENV UNO_FULLSCREEN true

# Copy the application compiled in the build step to the $APP_ROOT directory
# path inside the container, where $APP_ROOT is the torizon_app_root
# configuration defined in settings.json
COPY --from=build ${APP_ROOT}/__change__.Skia.Gtk/bin/Release/net8.0/linux-${IMAGE_ARCH}/publish ${APP_ROOT}

# "cd" (enter) into the APP_ROOT directory
WORKDIR ${APP_ROOT}

# Command executed in runtime when the container starts
CMD ["./__change__.Skia.Gtk"]

# DEPLOY -----------------------------------------------------------------------
