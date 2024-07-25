#!/usr/bin/env bash

set -xeuo pipefail

case "$TARGET" in
  *darwin*)
    curl_tar \
      "https://github.com/spacedriveapp/apple-sdks/releases/download/2024.07.24/MacOSX${MACOS_SDK_VERSION:?}.sdk.tar.xz" \
      "${MACOS_SDKROOT:?}" 0

    curl_tar \
      "https://github.com/spacedriveapp/apple-sdks/releases/download/2024.07.24/iPhoneOS${IOS_SDK_VERSION:?}.sdk.tar.xz" \
      "${IOS_SDKROOT:?}" 0

    curl_tar \
      "https://github.com/spacedriveapp/apple-sdks/releases/download/2024.07.24/iPhoneSimulator${IOS_SDK_VERSION:?}.sdk.tar.xz" \
      "${IOS_SIMULATOR_SDKROOT:?}" 0
    ;;
  *)
    mkdir -p "${MACOS_SDKROOT:?}" "${IOS_SDKROOT:?}" "${IOS_SIMULATOR_SDKROOT:?}"
    ;;
esac
