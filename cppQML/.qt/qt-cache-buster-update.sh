#!/bin/bash
set -euo pipefail

BUSTER_FILE="${QT_CACHE_BUSTER_FILE:?}"
STATE_FILE="${QT_ENTERPRISE_STATE_FILE:?}"
LOGIN="${QT_LICENSE_LOGIN:-}"
PASS="${QT_LICENSE_PASSWORD:-}"

mkdir -p "$(dirname "$BUSTER_FILE")" "$(dirname "$STATE_FILE")"

if [ -z "$LOGIN" ] && [ -z "$PASS" ]; then
    DIGEST="no-qt-enterprise-credentials"
else
    DIGEST=$(printf '%s\n' "${LOGIN}::${PASS}" | sha256sum | cut -d' ' -f1)
fi

if [ -f "$STATE_FILE" ] && [ "$(cat "$STATE_FILE")" = "$DIGEST" ]; then
    echo "Qt credentials unchanged, keeping this template's cached builds"
else
    printf '%s\n' "$DIGEST" > "$STATE_FILE"
    printf '%s\n' "$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n')" > "$BUSTER_FILE"
    echo "Qt credentials changed, invalidating only this template's cached builds"
fi
