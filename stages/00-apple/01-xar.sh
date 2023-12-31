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

curl_tar 'https://github.com/tpoechtrager/xar/archive/5fa4675.tar.gz' 'xar' 1

cd xar/xar

./configure --prefix="$CCTOOLS"

make -j"$(nproc)"

make install

rm -r /srv/xar
