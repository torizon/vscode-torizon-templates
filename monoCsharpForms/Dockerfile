# ARGUMENTS --------------------------------------------------------------------
##
# Board architecture
##
ARG IMAGE_ARCH=

##
# Base container version
##
ARG BASE_VERSION=4.0-6.12.0

##
# Directory of the application inside container
##
ARG APP_ROOT=
# ARGUMENTS --------------------------------------------------------------------



# BUILD ------------------------------------------------------------------------
FROM --platform=linux/${IMAGE_ARCH} \
    commontorizon/mono-sdk:${BASE_VERSION} AS build

ARG IMAGE_ARCH
ARG APP_ROOT


RUN apt-get -y update && apt-get install -y --no-install-recommends \
    # ADD YOUR PACKAGES HERE
# DO NOT REMOVE THIS LABEL: this is used for VS Code automation
    # __torizon_packages_build_start__
    # __torizon_packages_build_end__
# DO NOT REMOVE THIS LABEL: this is used for VS Code automation
    && \
	apt-get clean && apt-get autoremove && rm -rf /var/lib/apt/lists/*


COPY . ${APP_ROOT}
WORKDIR ${APP_ROOT}

# build
RUN msbuild

# BUILD ------------------------------------------------------------------------



# DEPLOY -----------------------------------------------------------------------
FROM --platform=linux/${IMAGE_ARCH} \
    commontorizon/mono-runtime:${BASE_VERSION} AS deploy

ARG IMAGE_ARCH
ARG APP_ROOT

RUN apt-get -y update && apt-get install -y --no-install-recommends \
    libmono-system-windows4.0-cil \
    libmono-system-windows-forms4.0-cil \
    libgtk2.0 \
    # ADD YOUR PACKAGES HERE
# DO NOT REMOVE THIS LABEL: this is used for VS Code automation
    # __torizon_packages_prod_start__
    # __torizon_packages_prod_end__
# DO NOT REMOVE THIS LABEL: this is used for VS Code automation
    && \
	apt-get clean && apt-get autoremove && rm -rf /var/lib/apt/lists/*

USER torizon


COPY ./assets ${APP_ROOT}/assets

# Copy the application compiled in the build step to the $APP_ROOT directory
# path inside the container, where $APP_ROOT is the torizon_app_root
# configuration defined in settings.json
COPY --from=build ${APP_ROOT}/bin/Debug ${APP_ROOT}

# "cd" (enter) into the APP_ROOT directory
WORKDIR ${APP_ROOT}

# Command executed in runtime when the container starts
CMD ["mono", "__change__.exe"]

# DEPLOY -----------------------------------------------------------------------
