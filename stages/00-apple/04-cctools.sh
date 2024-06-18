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

export CC="clang-18"
export CXX="clang++-18"
export CFLAGS="-I${CCTOOLS}/include"
export LDFLAGS="-L${CCTOOLS}/lib"
export APPLE_TARGET='__BYPASS__'

cd /srv

echo "Download cctools ..."

mkdir -p "cctools"

# renovate: depName=git@github.com:tpoechtrager/cctools-port.git
_commit='6dd6a4a282fb5f99b8b1166859883f23ea9e47f5'

curl_tar "https://github.com/tpoechtrager/cctools-port/archive/${_commit}.tar.gz" 'cctools' 1

cd cctools/cctools

./configure \
  --prefix="$CCTOOLS" \
  --target="$_target" \
  --with-libxar="$CCTOOLS" \
  --with-libtapi="$CCTOOLS" \
  --with-libdispatch="$CCTOOLS" \
  --with-llvm-config=llvm-config-18 \
  --with-libblocksruntime="$CCTOOLS" \
  --enable-xar-support \
  --enable-lto-support \
  --enable-tapi-support

make -j"$(nproc)"

make install

rm -r /srv/cctools

# Create symlinks for llvm-otool because cctools use it when calling its own otool
ln -fs "$(command -v llvm-otool-18)" /opt/cctools/bin/llvm-otool
