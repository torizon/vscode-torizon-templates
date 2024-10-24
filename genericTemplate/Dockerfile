ARG BASE_VERSION=3.5.0

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

# DEPLOY ------------------------------------------------------------------------
FROM --platform=linux/${IMAGE_ARCH} torizon/debian:${BASE_VERSION}

ARG IMAGE_ARCH
ARG GPU

RUN apt-get -y update && apt-get install -y --no-install-recommends \
# DO NOT REMOVE THIS LABEL: this is used for VS Code automation
    # __torizon_packages_prod_start__
    # __torizon_packages_prod_end__
# DO NOT REMOVE THIS LABEL: this is used for VS Code automation
	&& apt-get clean && apt-get autoremove && rm -rf /var/lib/apt/lists/*

# "cd" (enter) into the APP_ROOT directory
WORKDIR ${APP_ROOT}

# Command executed when starting the container
CMD [ "echo", "Generic", "Dockerfile", "Template", "successfully", "executed" ]
