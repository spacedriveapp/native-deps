#!/usr/bin/env bash

set -xeuo pipefail

case "$TARGET" in
  *-android*)
    curl_tar \
      https://github.com/spacedriveapp/ndk-sysroot/releases/download/2024.10.20/ndk_sysroot.tar.xz \
      "${NDK_SDKROOT:?Missing ndk sysroot}" 0
    ;;
  *)
    mkdir -p "${NDK_SDKROOT:?Missing ndk sysroot}"
    ;;
esac
