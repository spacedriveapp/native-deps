#!/usr/bin/env bash

set -xeuo pipefail

case "$TARGET" in
  *darwin*) ;;
  *)
    exit 0
    ;;
esac

apt-get install libssl-dev libz-dev

export CC="clang-16"
export CXX="clang++-16"
export CFLAGS="-I${CCTOOLS}/include"
export LDFLAGS="-L${CCTOOLS}/lib"
export APPLE_TARGET='__BYPASS__'

cd /srv

echo "Download xar ..."

mkdir -p "xar/build"

# renovate: depName=git@github.com:tpoechtrager/xar.git
_commit='5fa4675419cfec60ac19a9c7f7c2d0e7c831a497'

curl_tar "https://github.com/tpoechtrager/xar/archive/${_commit}.tar.gz" 'xar' 1

cd xar/xar

./configure --prefix="$CCTOOLS"

make -j"$(nproc)"

make install

rm -r /srv/xar
