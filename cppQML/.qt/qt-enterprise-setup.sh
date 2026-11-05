#!/bin/bash
set -euo pipefail

# mode=full   also registers the enterprise apt repo (first-time setup)
# mode=auth-only  only rewrites the auth.conf.d credentials (needed again in
#                  later RUN steps, since /etc/apt/auth.conf.d is tmpfs-mounted
#                  per-RUN and does not persist between layers)
mode="${1:-auth-only}"

LOGIN="$(cat /run/secrets/qt-login 2>/dev/null || true)"
PASS="$(cat /run/secrets/qt-password 2>/dev/null || true)"

# Single source of truth for the IMAGE_ARCH -> Debian architecture mapping
# used by Dockerfile and Dockerfile.sdk. When HOST_ARCH is set and differs
# from the mapped target architecture, register it with dpkg so apt can
# resolve target-arch packages (e.g. libegl-dev:arm64), and print
# TARGET_SUFFIX=... on stdout for the caller to `eval` into its shell. This
# runs regardless of whether Qt Enterprise or community Qt is used, since
# both branches install target-arch packages when cross-compiling.
target_deb_arch=""
if [ -n "${HOST_ARCH:-}" ]; then
    target_deb_arch="$HOST_ARCH"
    case "${IMAGE_ARCH:-}" in
        arm64)
            target_deb_arch="arm64"
            ;;
        arm|armhf)
            target_deb_arch="armhf"
            ;;
        amd64|x86_64)
            target_deb_arch="amd64"
            ;;
        *)
            echo "ERROR: unsupported IMAGE_ARCH '${IMAGE_ARCH:-}' (expected arm64, arm, armhf, amd64, or x86_64)" >&2
            exit 1
            ;;
    esac
fi

target_suffix=""
if [ -n "$target_deb_arch" ] && [ "$target_deb_arch" != "$HOST_ARCH" ]; then
    target_suffix=":${target_deb_arch}"
    dpkg --add-architecture "$target_deb_arch"
fi

if [ -n "$LOGIN" ] && [ -n "$PASS" ] && [ "${GPU:-}" = "-imx8" ]; then
    printf "machine https://debian-packages.qt.io\nlogin %s\npassword %s\n" \
        "$LOGIN" "$PASS" \
        > /etc/apt/auth.conf.d/qt-enterprise.conf

    if [ "$mode" = "full" ]; then
        echo "--- Qt Enterprise credentials detected, enabling enterprise repo ---" >&2
        mkdir -p /etc/apt/keyrings/tqtc
        wget -qO /etc/apt/keyrings/tqtc/qt-company-debian-repo.gpg \
            https://cdn.qt.io/debian/keys/qt-company-debian-repo.gpg
        mkdir -p /etc/apt/sources.list.d
        printf "Types: deb\nURIs: https://debian-packages.qt.io/debian/enterprise/qt-6.8.2-arm64-test-gles\nSuites: tqtc-bookworm\nComponents: main\nSigned-By: /etc/apt/keyrings/tqtc/qt-company-debian-repo.gpg\n" \
            > /etc/apt/sources.list.d/qt-company.sources
    fi
elif [ "$mode" = "full" ]; then
    echo "--- Qt Enterprise credentials not found, using community Qt ---" >&2
fi

echo "TARGET_SUFFIX=${target_suffix}"
