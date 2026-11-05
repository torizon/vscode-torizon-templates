#!/bin/bash
set -euo pipefail

target_arch="${IMAGE_ARCH:-}"
gpu="${GPU:-}"
enterprise_qt="/opt/qt-6.8.2/aarch64-linux-gnu/bin/qt-cmake"
qt_prefix=""

case "$target_arch" in
    arm64)
        qt_prefix="/usr/lib/aarch64-linux-gnu/cmake"
        ;;
    arm|armhf)
        qt_prefix="/usr/lib/arm-linux-gnueabihf/cmake"
        ;;
    amd64|x86_64|"")
        qt_prefix="/usr/lib/x86_64-linux-gnu/cmake"
        ;;
esac

# Preserve explicit compilers when callers pass -DCMAKE_*_COMPILER.
has_c=0
has_cxx=0
has_prefix=0
has_qt_dir=0
has_sysname=0
for arg in "$@"; do
    if [[ "$arg" == -DCMAKE_C_COMPILER=* ]]; then
        has_c=1
    fi
    if [[ "$arg" == -DCMAKE_CXX_COMPILER=* ]]; then
        has_cxx=1
    fi
    if [[ "$arg" == -DCMAKE_PREFIX_PATH=* ]]; then
        has_prefix=1
    fi
    if [[ "$arg" == -DQt6_DIR=* ]]; then
        has_qt_dir=1
    fi
    if [[ "$arg" == -DCMAKE_SYSTEM_NAME=* ]]; then
        has_sysname=1
    fi
done

extra_args=()
case "$target_arch" in
    arm64)
        if [[ "$has_c" -eq 0 ]]; then
            extra_args+=("-DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc")
        fi
        if [[ "$has_cxx" -eq 0 ]]; then
            extra_args+=("-DCMAKE_CXX_COMPILER=aarch64-linux-gnu-g++")
        fi
        if [[ "$has_sysname" -eq 0 ]]; then
            extra_args+=("-DCMAKE_SYSTEM_NAME=Linux" "-DCMAKE_SYSTEM_PROCESSOR=arm64")
        fi
        ;;
    arm|armhf)
        if [[ "$has_c" -eq 0 ]]; then
            extra_args+=("-DCMAKE_C_COMPILER=arm-linux-gnueabihf-gcc")
        fi
        if [[ "$has_cxx" -eq 0 ]]; then
            extra_args+=("-DCMAKE_CXX_COMPILER=arm-linux-gnueabihf-g++")
        fi
        if [[ "$has_sysname" -eq 0 ]]; then
            extra_args+=("-DCMAKE_SYSTEM_NAME=Linux" "-DCMAKE_SYSTEM_PROCESSOR=arm")
        fi
        ;;
    amd64|x86_64|"")
        ;;
    *)
        echo "Unsupported IMAGE_ARCH: $target_arch" >&2
        exit 2
        ;;
esac

if [[ "$has_prefix" -eq 0 ]] && [[ "$has_qt_dir" -eq 0 ]] && [[ -n "$qt_prefix" ]] && [[ -d "$qt_prefix/Qt6" ]]; then
    extra_args+=("-DCMAKE_PREFIX_PATH=$qt_prefix")
fi

if [[ "$target_arch" == "arm64" ]] && [[ "$gpu" == "-imx8" ]] && [[ -x "$enterprise_qt" ]]; then
    exec "$enterprise_qt" "${extra_args[@]}" "$@"
fi

exec /usr/bin/cmake "${extra_args[@]}" "$@"
