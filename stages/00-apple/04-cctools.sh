#!/usr/bin/env bash

set -euo pipefail

case "$TARGET" in
  x86_64-darwin*)
    if [ "$OS_IPHONE" -ge 1 ]; then
      _target='x86_64-apple-darwin20'
    else
      _target='x86_64-apple-darwin19'
    fi
    ;;
  aarch64-darwin*)
    _target='arm64-apple-darwin20'
    ;;
  *)
    exit 0
    ;;
esac

echo "APPLE_TARGET=$_target" >>/etc/environment

apt-get install uuid-dev libedit-dev

export CC="clang-17"
export CXX="clang++-17"
export CFLAGS="-I${CCTOOLS}/include"
export LDFLAGS="-L${CCTOOLS}/lib"
export APPLE_TARGET='__BYPASS__'

cd /srv

echo "Download cctools ..."

mkdir -p "cctools"

# renovate: depName=git@github.com:tpoechtrager/cctools-port.git
_commit='dcfc6ba8b1a9d134d1c4139407ee4562a22fdfbb'

curl_tar "https://github.com/tpoechtrager/cctools-port/archive/${_commit}.tar.gz" 'cctools' 1

cd cctools/cctools

./configure \
  --prefix="$CCTOOLS" \
  --target="$_target" \
  --with-libxar="$CCTOOLS" \
  --with-libtapi="$CCTOOLS" \
  --with-libdispatch="$CCTOOLS" \
  --with-llvm-config=llvm-config-17 \
  --with-libblocksruntime="$CCTOOLS" \
  --enable-xar-support \
  --enable-lto-support \
  --enable-tapi-support

make -j"$(nproc)"

make install

rm -r /srv/cctools

# Create symlinks for llvm-otool because cctools use it when calling its own otool
ln -fs "$(command -v llvm-otool-17)" /opt/cctools/bin/llvm-otool
