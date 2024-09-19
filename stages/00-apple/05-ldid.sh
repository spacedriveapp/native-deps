#!/usr/bin/env bash

set -euo pipefail

case "$TARGET" in
  *darwin*) ;;
  *)
    exit 0
    ;;
esac

export CC="clang-17"
export CXX="clang++-17"
export CFLAGS="-I${CCTOOLS}/include"
export LDFLAGS="-L${CCTOOLS}/lib"
export APPLE_TARGET='__BYPASS__'

cd /srv

echo "Download ldid ..."

mkdir -p "ldid"

# renovate: depName=git@github.com:HeavenVolkoff/ldid.git
_commit='4bd94f4eb253ca1eea45fb1a9bd414a6c0664867'

curl_tar "https://github.com/HeavenVolkoff/ldid/archive/${_commit}.tar.gz" 'ldid' 1

# renovate: datasource=github-releases depName=libimobiledevice/libplist
_tag='2.6.0'

curl_tar "https://github.com/libimobiledevice/libplist/archive/refs/tags/${_tag}.tar.gz" 'ldid/libplist' 1
echo "$_tag" >'ldid/libplist/.tarball-version'

cd ldid/libplist

./autogen.sh

./configure \
  --prefix="$CCTOOLS" \
  --with-pic \
  --enable-static \
  --without-tests \
  --without-cython \
  --disable-debug \
  --disable-shared

make -j"$(nproc)"

cd ..

make -j"$(nproc)"

cp ldid "${CCTOOLS}/bin/"

rm -r /srv/ldid
