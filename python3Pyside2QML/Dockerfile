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


FROM --platform=linux/${IMAGE_ARCH} \
    torizon/qt5-wayland${GPU}:${BASE_VERSION} AS deploy

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

# your regular RUN statements here
# Install required packages
RUN apt-get -q -y update && \
    apt-get -q -y install \
    python3-minimal \
    python3-pip \
    python3-venv \
    qml-module-qtquick-controls \
    qml-module-qtquick-controls2 \
    qml-module-qtquick2 \
    python3-pyside2.qtwidgets \
    python3-pyside2.qtgui \
    python3-pyside2.qtqml \
    python3-pyside2.qtcore \
    python3-pyside2.qtquick \
    python3-pyside2.qtnetwork \
    qml-module-qtquick-dialogs \
    qtwayland5 \
# DOES NOT REMOVE THIS LABEL: this is used for VS Code automation
    # __torizon_packages_prod_start__
    # __torizon_packages_prod_end__
# DO NOT REMOVE THIS LABEL: this is used for VS Code automation
    && apt-get clean && apt-get autoremove && \
    rm -rf /var/lib/apt/lists/*

# edge case for amd64
# this prevent the error: texture atlas allocation failed
RUN apt-get -q -y update && \
    if [ "${IMAGE_ARCH}" = "amd64" ]; then \
        apt-get -q -y install \
        libqt5quick5 \
    ; fi \
    && \
    apt-get clean && apt-get autoremove && \
    rm -rf /var/lib/apt/lists/*

# Create virtualenv
RUN python3 -m venv ${APP_ROOT}/.venv --system-site-packages

# Install pip packages on venv
COPY requirements-release.txt /requirements-release.txt
RUN . ${APP_ROOT}/.venv/bin/activate && \
    pip3 install --upgrade pip && pip3 install -r requirements-release.txt && \
    rm requirements-release.txt

USER torizon

# Copy the application source code in the workspace to the $APP_ROOT directory
# path inside the container, where $APP_ROOT is the torizon_app_root
# configuration defined in settings.json
COPY ./src ${APP_ROOT}/src

WORKDIR ${APP_ROOT}

ENV APP_ROOT=${APP_ROOT}
ENV QT_QPA_PLATFORM="wayland"

# Activate and run the code
CMD . ${APP_ROOT}/.venv/bin/activate && python3 src/main.py --no-sandbox
