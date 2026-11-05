# ARGUMENTS --------------------------------------------------------------------
##
# Cross-toolchain container version
##
ARG CROSS_SDK_BASE_TAG=4
##
# Base container version
##
ARG BASE_VERSION=4

##
# Board architecture
##
ARG IMAGE_ARCH=

##
# Host architecture
##
ARG HOST_ARCH=amd64

##
# Board GPU vendor prefix
##
ARG GPU=

##
# Directory of the application inside container
##
ARG APP_ROOT=

# BUILD ------------------------------------------------------------------------
# Build the app for host architecture and emit binaries for IMAGE_ARCH. The
# cross toolchain image provides target compilers (aarch64/arm) executed on
# HOST_ARCH, so this stage runs natively instead of under emulation.
##
# Build Step
##
FROM --platform=linux/${HOST_ARCH} \
    torizon/cross-toolchain-${IMAGE_ARCH}:${CROSS_SDK_BASE_TAG} AS build

ARG IMAGE_ARCH
ARG HOST_ARCH
ARG GPU
ARG APP_ROOT

ARG DEBIAN_FRONTEND=noninteractive

COPY .qt/qt-enterprise-setup.sh /usr/local/sbin/qt-enterprise-setup.sh
RUN chmod +x /usr/local/sbin/qt-enterprise-setup.sh

# NOTE: secret mount contents are excluded from BuildKit's cache key, so
# changing qt-login/qt-password alone won't invalidate this layer. The
# qt-cache-buster file (a random, non-secret nonce rotated by the
# "qt-enterprise-fill-license-login-password" task whenever credentials are
# set/changed) is part of this layer's cache key, invalidating only this
# project's cached builds (other projects keep their cache). The credential
# digest used to detect changes stays in the ignored .conf/qt6-enterprise/
# state file and never enters the image.
COPY .qt/qt-cache-buster /tmp/qt-cache-buster
RUN --mount=type=secret,id=qt-login \
    --mount=type=secret,id=qt-password \
    --mount=type=tmpfs,target=/etc/apt/auth.conf.d \
    eval "$(/usr/local/sbin/qt-enterprise-setup.sh full)" && \
    apt-get update && \
    if [ -f /etc/apt/auth.conf.d/qt-enterprise.conf ] && [ "$GPU" = "-imx8" ]; then \
        apt-get install -y --no-install-recommends \
        cmake \
        libegl-dev${TARGET_SUFFIX} \
        libgles-dev${TARGET_SUFFIX} \
        qt6.8.2-base-dev-tools \
        qt6.8.2-declarative-dev-tools \
        qt6.8.2-base-dev${TARGET_SUFFIX} \
        qt6.8.2-base-private-dev${TARGET_SUFFIX} \
        qt6.8.2-wayland-dev${TARGET_SUFFIX} \
        qt6.8.2-declarative-dev${TARGET_SUFFIX} \
        qt6.8.2-declarative-private-dev${TARGET_SUFFIX} \
        qt6.8.2-gtk-platformtheme${TARGET_SUFFIX} \
        qt6.8.2-xdgdesktopportal-platformtheme${TARGET_SUFFIX} \
        qt6.8.2-wayland${TARGET_SUFFIX} \
        qt6.8.2-image-formats-plugins${TARGET_SUFFIX} \
        qml6.8.2-module-qt-labs-animation${TARGET_SUFFIX} \
        qml6.8.2-module-qt-labs-folderlistmodel${TARGET_SUFFIX} \
        qml6.8.2-module-qt-labs-platform${TARGET_SUFFIX} \
        qml6.8.2-module-qt-labs-qmlmodels${TARGET_SUFFIX} \
        qml6.8.2-module-qt-labs-settings${TARGET_SUFFIX} \
        qml6.8.2-module-qt-labs-sharedimage${TARGET_SUFFIX} \
        qml6.8.2-module-qt-labs-wavefrontmesh${TARGET_SUFFIX} \
        qml6.8.2-module-qtqml${TARGET_SUFFIX} \
        qml6.8.2-module-qtqml-workerscript${TARGET_SUFFIX} \
        qml6.8.2-module-qtqml-models${TARGET_SUFFIX} \
        qml6.8.2-module-qtqml-xmllistmodel${TARGET_SUFFIX} \
        qml6.8.2-module-qmlnetwork${TARGET_SUFFIX} \
        qml6.8.2-module-qtcore${TARGET_SUFFIX} \
        qml6.8.2-module-qtquick${TARGET_SUFFIX} \
        qml6.8.2-module-qtquick-window${TARGET_SUFFIX} \
        qml6.8.2-module-qtquick-controls${TARGET_SUFFIX} \
        qml6.8.2-module-qtquick-layouts${TARGET_SUFFIX} \
        qml6.8.2-module-qtquick-templates${TARGET_SUFFIX} \
        qml6.8.2-module-qtquick-localstorage${TARGET_SUFFIX} \
        qml6.8.2-module-qtquick-dialogs${TARGET_SUFFIX} \
        qml6.8.2-module-qtquick-nativestyle${TARGET_SUFFIX} \
        qml6.8.2-module-qtquick-particles${TARGET_SUFFIX} \
        qml6.8.2-module-qtquick-shapes${TARGET_SUFFIX} \
        qml6.8.2-module-qtquick-tooling${TARGET_SUFFIX} \
        qml6.8.2-module-qt-test-controls${TARGET_SUFFIX} \
        qml6.8.2-module-qttest${TARGET_SUFFIX} \
        qml6.8.2-module-qtwayland-compositor${TARGET_SUFFIX} \
        qml6.8.2-module-qtwayland-client-texturesharing${TARGET_SUFFIX} \
    ;else \
        # Host packages are only build tools/check headers; Qt dev/runtime
        # comes from target architecture packages when cross-compiling.
        apt-get install -y --no-install-recommends \
        cmake \
        libegl-dev${TARGET_SUFFIX} \
        libgles-dev${TARGET_SUFFIX} \
        qt6-base-dev-tools \
        qt6-declarative-dev-tools \
        qt6-base-dev${TARGET_SUFFIX} \
        qt6-base-private-dev${TARGET_SUFFIX} \
        qt6-wayland-dev${TARGET_SUFFIX} \
        qt6-declarative-dev${TARGET_SUFFIX} \
        qt6-declarative-private-dev${TARGET_SUFFIX} \
        libqt6opengl6-dev${TARGET_SUFFIX} \
        qml6-module-qtqml${TARGET_SUFFIX} \
        qml6-module-qtqml-workerscript${TARGET_SUFFIX} \
        qml6-module-qtcore${TARGET_SUFFIX} \
        qml6-module-qtquick${TARGET_SUFFIX} \
        qml6-module-qtquick-window${TARGET_SUFFIX} \
        qml6-module-qtquick-controls${TARGET_SUFFIX} \
        qml6-module-qtquick-layouts${TARGET_SUFFIX} \
        qml6-module-qtquick-templates${TARGET_SUFFIX} \
    ;fi \
    && apt-get clean \
    && apt-get autoremove \
    && rm -rf /var/lib/apt/lists/*

# automate for torizonPackages.json
RUN --mount=type=secret,id=qt-login \
    --mount=type=secret,id=qt-password \
    --mount=type=tmpfs,target=/etc/apt/auth.conf.d \
    /usr/local/sbin/qt-enterprise-setup.sh auth-only && \
    apt-get -q -y update && \
    apt-get -q -y install \
# DO NOT REMOVE THIS LABEL: this is used for VS Code automation
    # __torizon_packages_build_start__
    # __torizon_packages_build_end__
# DO NOT REMOVE THIS LABEL: this is used for VS Code automation
    && \
    apt-get clean && apt-get autoremove && \
    rm -rf /var/lib/apt/lists/*

COPY .qt/qt-cmake.sh /usr/local/bin/qt-cmake
RUN chmod +x /usr/local/bin/qt-cmake

COPY . ${APP_ROOT}
WORKDIR ${APP_ROOT}

# Remove the code from the debug builds, inside this container, to build the
# release version from a clean build
RUN rm -rf ${APP_ROOT}/build-${IMAGE_ARCH}

RUN --mount=type=secret,id=qt-login \
    --mount=type=secret,id=qt-password \
    --mount=type=tmpfs,target=/etc/apt/auth.conf.d \
    /usr/local/sbin/qt-enterprise-setup.sh auth-only && \
    qt-cmake -DCMAKE_BUILD_TYPE=Release -Bbuild-${IMAGE_ARCH}

RUN cmake --build build-${IMAGE_ARCH}

# BUILD ------------------------------------------------------------------------

# DEPLOY -----------------------------------------------------------------------
##
# Deploy Step
##
FROM --platform=linux/${IMAGE_ARCH} \
    torizon/wayland-base${GPU}:${BASE_VERSION} AS deploy

ARG IMAGE_ARCH
ARG GPU
ARG APP_ROOT

# SSH for remote debug
EXPOSE 2231
ARG SSHUSERNAME=torizon

# Make sure we don't get notifications we can't answer during building.
ENV DEBIAN_FRONTEND="noninteractive"

COPY .qt/qt-enterprise-setup.sh /usr/local/sbin/qt-enterprise-setup.sh
RUN chmod +x /usr/local/sbin/qt-enterprise-setup.sh

RUN --mount=type=secret,id=qt-login \
    --mount=type=secret,id=qt-password \
    --mount=type=tmpfs,target=/etc/apt/auth.conf.d \
    /usr/local/sbin/qt-enterprise-setup.sh full && \
    apt-get update && \
    if [ -f /etc/apt/sources.list.d/qt-company.sources ] && [ "$GPU" = "-imx8" ]; then \
        apt-get install -y --no-install-recommends \
        boot2qt-launcher \
        qt6.8.2-full \
        libwayland-cursor0 \
    ;else \
        apt-get install -y --no-install-recommends \
        libqt6gui6 \
        libfontconfig1-dev \
        libqt6concurrent6 \
        libqt6dbus6 \
        libqt6network6 \
        libqt6printsupport6 \
        libqt6sql6 \
        libqt6test6 \
        libqt6widgets6 \
        libqt6xml6 \
        libqt6qml6 \
        libqt6opengl6 \
        libqt6quicktest6 \
        libqt6quickwidgets6 \
        qt6-base-private-dev \
        qt6-base-dev \
        qt6-wayland \
        qt6-wayland-dev \
        qt6-declarative-dev \
        qt6-declarative-private-dev \
        qml6-module-qtqml \
        qml6-module-qtqml-workerscript \
        qml6-module-qtcore \
        qml6-module-qtquick \
        qml6-module-qtquick-window \
        qml6-module-qtquick-controls \
        qml6-module-qtquick-layouts \
        qml6-module-qtquick-templates \
    ;fi \
    && apt-get -q -y install \
    file \
    curl \
# automate for torizonPackages.json
# DO NOT REMOVE THIS LABEL: this is used for VS Code automation
    # __torizon_packages_prod_start__
    # __torizon_packages_prod_end__
# DO NOT REMOVE THIS LABEL: this is used for VS Code automation
    && apt-get clean \
    && apt-get autoremove \
    && rm -rf /var/lib/apt/lists/* \
    && rm -f /usr/local/sbin/qt-enterprise-setup.sh

ENV QT_QPA_PLATFORM="wayland"

# EGLFS configuration
ENV QT_QPA_EGLFS_INTEGRATION="eglfs_kms"
ENV QT_QPA_EGLFS_KMS_ATOMIC="1"
ENV QT_QPA_EGLFS_KMS_CONFIG="/etc/kms.conf"

USER torizon

# Copy the application compiled in the build step to the $APP_ROOT directory
# path inside the container, where $APP_ROOT is the torizon_app_root
# configuration defined in settings.json.
COPY --from=build ${APP_ROOT}/build-${IMAGE_ARCH}/bin ${APP_ROOT}

# "cd" (enter) into the APP_ROOT directory
WORKDIR ${APP_ROOT}

# Command executed in runtime when the container starts
CMD ["./__change__"]

# DEPLOY -----------------------------------------------------------------------

