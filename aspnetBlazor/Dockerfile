# ARGUMENTS --------------------------------------------------------------------
##
# Board architecture
##
ARG IMAGE_ARCH=

##
# Base container version
##
ARG BASE_VERSION=3.4-8.0.8

##
# Directory of the application inside container
##
ARG APP_ROOT=
# ARGUMENTS --------------------------------------------------------------------



# BUILD ------------------------------------------------------------------------
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build

ARG IMAGE_ARCH
ARG APP_ROOT

COPY . ${APP_ROOT}
WORKDIR ${APP_ROOT}

# build
RUN dotnet restore __change__.csproj && \
    if [ "$IMAGE_ARCH" = "arm64" ] ; then \
        export ARCH=${IMAGE_ARCH} ; \
    elif [ "$IMAGE_ARCH" = "armhf" ] ; then \
        export ARCH="arm" ; \
    elif [ "$IMAGE_ARCH" = "amd64" ] ; then \
        export ARCH="x64" ; \
    fi && \
    dotnet publish __change__.csproj -c Release -r linux-${ARCH} --no-self-contained && \
    mv ./bin/Release/net8.0/linux-${ARCH} ./bin/Release/net8.0/linux-${IMAGE_ARCH}

# BUILD ------------------------------------------------------------------------



# DEPLOY -----------------------------------------------------------------------
FROM --platform=linux/${IMAGE_ARCH} \
    torizon/aspdotnet:${BASE_VERSION} AS deploy

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
COPY --from=build ${APP_ROOT}/bin/Release/net8.0/linux-${IMAGE_ARCH}/publish ${APP_ROOT}

# "cd" (enter) into the APP_ROOT directory
WORKDIR ${APP_ROOT}

# Command executed in runtime when the container starts
CMD ["./__change__"]
# DEPLOY -----------------------------------------------------------------------
