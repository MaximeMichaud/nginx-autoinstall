#!/usr/bin/env bash
# Exercise the real selection path without root, downloads or installation.
set -euo pipefail
cd "$(dirname "$0")/.."

assert_plan() {
    local flavor=$1 channel=$2 version=$3 plan
    plan=$(env NGINX_FLAVOR="$flavor" NGINX_VER="$channel" bash nginx-autoinstall.sh --print-plan)
    grep -Fxq "NGINX_FLAVOR=$flavor" <<<"$plan"
    grep -Fxq "NGINX_VERSION=$version" <<<"$plan"
    grep -Fxq "NGINX_SOURCE_NAME=$flavor-$version" <<<"$plan"
    grep -Fxq "NGINX_SOURCE_URL=https://$flavor.org/download/$flavor-$version.tar.gz" <<<"$plan"
}

# Overrides intentionally use distinct version numbers to catch crossed pins.
export NGINX_STABLE_VER=1.30.90 NGINX_MAINLINE_VER=1.31.91
export FREENGINX_STABLE_VER=1.30.92 FREENGINX_MAINLINE_VER=1.31.93
assert_plan nginx STABLE 1.30.90
assert_plan nginx MAINLINE 1.31.91
assert_plan freenginx STABLE 1.30.92
assert_plan freenginx MAINLINE 1.31.93
assert_plan nginx 1 1.30.90
assert_plan freenginx 2 1.31.93
env -u NGINX_FLAVOR -u NGINX_VER bash nginx-autoinstall.sh --print-plan |
    grep -Fxq NGINX_SOURCE_NAME=nginx-1.30.90

reject() {
    if env "$@" bash nginx-autoinstall.sh --print-plan >/dev/null 2>&1; then
        printf 'Unexpectedly accepted: %s\n' "$*" >&2
        exit 1
    fi
}
reject NGINX_FLAVOR=unknown
reject NGINX_VER=unknown
reject NGINX_FLAVOR=freenginx FREENGINX_STABLE_VER=../invalid
for option in TLSDYN HPACK ZLIBNG; do
    reject NGINX_FLAVOR=freenginx "$option=y"
done
NGINX_FLAVOR=freenginx HTTP3=y bash nginx-autoinstall.sh --print-plan >/dev/null
printf 'Distribution, channel, version override and patch compatibility checks passed.\n'
