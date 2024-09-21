#!/usr/bin/env bash

set -euo pipefail

case "$TARGET" in
  *darwin*) ;;
  *)
    exit 0
    ;;
esac

apt-get install systemtap-sdt-dev libbsd-dev linux-libc-dev

export CC="clang-17"
export CXX="clang++-17"
export CFLAGS="-I${CCTOOLS}/include"
export LDFLAGS="-L${CCTOOLS}/lib"
export APPLE_TARGET='__BYPASS__'

cd /srv

echo "Download dispatch ..."

mkdir -p 'dispatch/build'

# renovate: depName=git@github.com:tpoechtrager/apple-libdispatch.git
_commit='fdf3fc85a9557635668c78801d79f10161d83f12'

curl_tar "https://github.com/tpoechtrager/apple-libdispatch/archive/${_commit}.tar.gz" 'dispatch' 1

cd dispatch/build

cmake -G Ninja -DCMAKE_C_COMPILER="$CC" -DCMAKE_CXX_COMPILER="$CXX" ..

ninja -j"$(nproc)"

ninja install

rm -r /srv/dispatch
