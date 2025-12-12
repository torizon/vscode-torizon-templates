# ARGUMENTS --------------------------------------------------------------------
##
# SDK container version
##
ARG SDK_BASE_VERSION=4
##
# Base container version
##
ARG BASE_VERSION=4

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

# BUILD ------------------------------------------------------------------------
# TODO: cross compile x86 to arm
# We will use emulation here
##
# Build Step
##
FROM --platform=linux/${IMAGE_ARCH} \
    torizon/wayland-base-dev${GPU}:${BASE_VERSION} AS build

ARG IMAGE_ARCH
ARG GPU
ARG APP_ROOT

ARG DEBIAN_FRONTEND=noninteractive

# If the hash of credentials has changed, update the next layers.
RUN --mount=type=secret,id=qt-login \
    --mount=type=secret,id=qt-password \
    --mount=type=tmpfs,target=/etc/apt/auth.conf.d \
    bash -c '\
    LOGIN="$(cat /run/secrets/qt-login 2>/dev/null || true)" && \
    PASS="$(cat /run/secrets/qt-password 2>/dev/null || true)" && \
    if [ -n "$LOGIN" ] && [ -n "$PASS" ] && [ "$GPU" = "-imx8" ]; then \
        echo "--- Qt Enterprise credentials detected, enabling enterprise repo ---"; \
        mkdir -p /etc/apt/keyrings/tqtc; \
        wget -qO /etc/apt/keyrings/tqtc/qt-company-debian-repo.gpg \
            https://cdn.qt.io/debian/keys/qt-company-debian-repo.gpg; \
        printf "machine https://debian-packages.qt.io\nlogin %s\npassword %s\n" \
            "$LOGIN" "$PASS" \
            > /etc/apt/auth.conf.d/qt-enterprise.conf; \
        mkdir -p /etc/apt/sources.list.d; \
        printf "Types: deb\nURIs: https://debian-packages.qt.io/debian/enterprise/qt-6.8.2-arm64-test-gles\nSuites: tqtc-bookworm\nComponents: main\nSigned-By: /etc/apt/keyrings/tqtc/qt-company-debian-repo.gpg\n" \
            > /etc/apt/sources.list.d/qt-company.sources; \
    else \
        echo "--- Qt Enterprise credentials not found, using community Qt ---"; \
    fi' && \
    apt-get update && \
    if [ -f /etc/apt/auth.conf.d/qt-enterprise.conf ] && [ "$GPU" = "-imx8" ]; then \
        apt-get install -y --no-install-recommends \
        cmake \
        qt6.8.2-full-dev \
        qt6.8.2-declarative-dev \
    ;else \
        apt-get install -y --no-install-recommends \
        cmake \
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
        libqt6opengl6-dev \
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
    && apt-get clean \
    && apt-get autoremove \
    && rm -rf /var/lib/apt/lists/*

# automate for torizonPackages.json
RUN --mount=type=secret,id=qt-login \
    --mount=type=secret,id=qt-password \
    --mount=type=tmpfs,target=/etc/apt/auth.conf.d \
    bash -c '\
    LOGIN="$(cat /run/secrets/qt-login 2>/dev/null || true)" && \
    PASS="$(cat /run/secrets/qt-password 2>/dev/null || true)" && \
    if [ -n "$LOGIN" ] && [ -n "$PASS" ] && [ "$GPU" = "-imx8" ]; then \
        printf "machine https://debian-packages.qt.io\nlogin %s\npassword %s\n" \
            "$LOGIN" "$PASS" \
            > /etc/apt/auth.conf.d/qt-enterprise.conf; \
    fi' && \
    apt-get -q -y update && \
    apt-get -q -y install \
# DO NOT REMOVE THIS LABEL: this is used for VS Code automation
    # __torizon_packages_build_start__
    # __torizon_packages_build_end__
# DO NOT REMOVE THIS LABEL: this is used for VS Code automation
    && \
    apt-get clean && apt-get autoremove && \
    rm -rf /var/lib/apt/lists/*

COPY . ${APP_ROOT}
WORKDIR ${APP_ROOT}

# Remove the code from the debug builds, inside this container, to build the
# release version from a clean build
RUN rm -rf ${APP_ROOT}/build-${IMAGE_ARCH}

RUN --mount=type=secret,id=qt-login \
    --mount=type=secret,id=qt-password \
    --mount=type=tmpfs,target=/etc/apt/auth.conf.d \
    bash -c '\
    LOGIN="$(cat /run/secrets/qt-login 2>/dev/null || true)" && \
    PASS="$(cat /run/secrets/qt-password 2>/dev/null || true)" && \
    if [ -n "$LOGIN" ] && [ -n "$PASS" ] && [ "$GPU" = "-imx8" ]; then \
        printf "machine https://debian-packages.qt.io\nlogin %s\npassword %s\n" \
            "$LOGIN" "$PASS" \
            > /etc/apt/auth.conf.d/qt-enterprise.conf; \
    fi' && \
    if [ "$IMAGE_ARCH" = "arm64" ] ; then \
        if [ -f /etc/apt/auth.conf.d/qt-enterprise.conf ] && [ "$GPU" = "-imx8" ]; then \
            /opt/qt-6.8.2/aarch64-linux-gnu/bin/qt-cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_COMPILER=aarch64-linux-gnu-g++ -DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc -Bbuild-${IMAGE_ARCH} \
        ;else \
            cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_COMPILER=aarch64-linux-gnu-g++ -DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc -Bbuild-${IMAGE_ARCH} \
        ;fi \
    ;elif [ "$IMAGE_ARCH" = "arm" ] ; then \
        cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_COMPILER=arm-linux-gnueabihf-g++ -DCMAKE_C_COMPILER=arm-linux-gnueabihf-gcc -Bbuild-${IMAGE_ARCH} ; \
    elif [ "$IMAGE_ARCH" = "armhf" ] ; then \
        cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_COMPILER=arm-linux-gnueabihf-g++ -DCMAKE_C_COMPILER=arm-linux-gnueabihf-gcc -Bbuild-${IMAGE_ARCH} ; \
    fi

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

RUN --mount=type=secret,id=qt-login \
    --mount=type=secret,id=qt-password \
    --mount=type=tmpfs,target=/etc/apt/auth.conf.d \
    bash -c '\
    LOGIN="$(cat /run/secrets/qt-login 2>/dev/null || true)" && \
    PASS="$(cat /run/secrets/qt-password 2>/dev/null || true)" && \
    if [ -n "$LOGIN" ] && [ -n "$PASS" ] && [ "$GPU" = "-imx8" ]; then \
        echo "--- Qt Enterprise credentials detected, enabling enterprise repo ---"; \
        mkdir -p /etc/apt/keyrings/tqtc && \
        wget -qO /etc/apt/keyrings/tqtc/qt-company-debian-repo.gpg \
            https://cdn.qt.io/debian/keys/qt-company-debian-repo.gpg; \
        printf "machine https://debian-packages.qt.io\nlogin %s\npassword %s\n" \
            "$LOGIN" "$PASS" \
            > /etc/apt/auth.conf.d/qt-enterprise.conf; \
        printf "Types: deb\nURIs: https://debian-packages.qt.io/debian/enterprise/qt-6.8.2-arm64-test-gles\nSuites: tqtc-bookworm\nComponents: main\nSigned-By: /etc/apt/keyrings/tqtc/qt-company-debian-repo.gpg\n" \
            > /etc/apt/sources.list.d/qt-company.sources; \
    else \
        echo "--- Qt Enterprise credentials not found, using community Qt ---"; \
    fi' && \
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
    && rm -rf /var/lib/apt/lists/*

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

