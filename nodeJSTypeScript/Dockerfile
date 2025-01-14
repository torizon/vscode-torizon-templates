# ARGUMENTS --------------------------------------------------------------------
##
# Base container version
##
ARG BASE_VERSION=4.2.0

##
# Board architecture
##
ARG IMAGE_ARCH=

##
# Directory of the application inside container
##
ARG APP_ROOT=

# ARGUMENTS --------------------------------------------------------------------



# BUILD ------------------------------------------------------------------------
FROM --platform=linux/${IMAGE_ARCH} \
    torizon/debian:${BASE_VERSION} AS build

ARG IMAGE_ARCH
ARG APP_ROOT

# Install required packages
RUN apt-get -q -y update && \
    apt-get -q -y install \
    gcc \
    g++ \
    make \
    curl \
# DO NOT REMOVE THIS LABEL: this is used for VS Code automation
    # __torizon_packages_build_start__
    # __torizon_packages_build_end__
# DO NOT REMOVE THIS LABEL: this is used for VS Code automation
    && apt-get clean && apt-get autoremove && \
    rm -rf /var/lib/apt/lists/*

# install the latest node js
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs

# install npm and typescript
RUN npm config set registry https://registry.npmjs.org/
RUN npm install -g typescript
RUN npm install -g ts-node

COPY . ${APP_ROOT}
WORKDIR ${APP_ROOT}

# Remove the code from the debug builds, inside this container, to build the
# release version from a clean build
RUN rm -rf ${APP_ROOT}/out


RUN if [ "$IMAGE_ARCH" = "arm64" ] ; then \
        npm run output-arm64; \
    elif [ "$IMAGE_ARCH" = "arm" ] ; then \
        npm run output-arm; \
    elif [ "$IMAGE_ARCH" = "amd64" ] ; then \
        npm run output-amd64; \
    fi


# BUILD ------------------------------------------------------------------------



# DEPLOY -----------------------------------------------------------------------
FROM --platform=linux/${IMAGE_ARCH} \
    torizon/debian:${BASE_VERSION} AS deploy

ARG IMAGE_ARCH
ARG APP_ROOT

# Install required packages
RUN apt-get -q -y update && \
    apt-get -q -y install \
    curl \
    libatomic1 \
# DO NOT REMOVE THIS LABEL: this is used for VS Code automation
    # __torizon_packages_prod_start__
    # __torizon_packages_prod_end__
# DO NOT REMOVE THIS LABEL: this is used for VS Code automation
    && apt-get clean && apt-get autoremove && \
    rm -rf /var/lib/apt/lists/*

# install the latest node js
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs

# your regular RUN statements here

# Copy the application compiled in the build step to the $APP_ROOT directory
# path inside the container, where $APP_ROOT is the torizon_app_root
# configuration defined in settings.json
COPY --from=build ${APP_ROOT}/out ${APP_ROOT}/out

# "cd" (enter) into the APP_ROOT directory
WORKDIR ${APP_ROOT}

# Command executed in runtime when the container starts
CMD [ "node", "out" ]

# DEPLOY -----------------------------------------------------------------------
