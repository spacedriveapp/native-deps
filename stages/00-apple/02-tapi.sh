#!/usr/bin/env bash

set -euo pipefail

case "$TARGET" in
  *darwin*) ;;
  *)
    exit 0
    ;;
esac

export CC="clang-16"
export CXX="clang++-16"
export CFLAGS="-I${CCTOOLS}/include"
export LDFLAGS="-L${CCTOOLS}/lib"
export APPLE_TARGET='__BYPASS__'

cd /srv

# LLVM install path
export INSTALLPREFIX="$CCTOOLS"

echo "Download tapi ..."

mkdir -p "tapi"

# renovate: depName=git@github.com:tpoechtrager/apple-libtapi.git
_commit='b8c5ac40267aa5f6004dd38cc2b2cd84f2d9d555'

curl_tar "https://github.com/tpoechtrager/apple-libtapi/archive/${_commit}.tar.gz" 'tapi' 1

cd tapi

export NINJA=1

./build.sh
./install.sh

rm -r /srv/tapi
