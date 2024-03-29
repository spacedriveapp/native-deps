#!/usr/bin/env -S bash -euo pipefail

echo "Download lzma..."
mkdir -p lzma

# _tag='5.4.6'

# XZ upstream appears to be compromised, use Debian as a trusted repository for the source code
curl_tar "https://deb.debian.org/debian/pool/main/x/xz-utils/xz-utils_5.6.1+really5.4.5.orig.tar.xz" lzma 1

case "$TARGET" in
  *darwin*)
    mkdir -p "${PREFIX:?Missing prefix}/include/"
    # MacOS ships liblzma, however it doesn't include its headers
    cp -avr lzma/src/liblzma/api/{lzma,lzma.h} "${PREFIX}/include/"
    exit 0
    ;;
esac

# Remove some superfluous files
shopt -s extglob
rm -rf lzma/{.github,config.h.in,dos,Makefile.in,configure.ac,aclocal.m4,debug,lib,doxygen,windows,build-aux,m4,configure,tests,po,doc/examples,doc/*.!(txt),po4a}

# Ignore i18n compilation
sed -i 's/if(ENABLE_NLS)/if(FALSE)/' lzma/CMakeLists.txt
sed -i 's/if(GETTEXT_FOUND)/if(FALSE)/' lzma/CMakeLists.txt

# Backup source
bak_src 'lzma'

mkdir -p lzma/build
cd lzma/build

echo "Build lzma..."

cmake \
  -DENABLE_SMALL=On \
  -DBUILD_TESTING=Off \
  -DCREATE_XZ_SYMLINKS=Off \
  -DCREATE_LZMA_SYMLINKS=Off \
  -DCMAKE_SKIP_INSTALL_ALL_DEPENDENCY=On \
  ..

ninja -j"$(nproc)" liblzma

case "$TARGET" in
  *windows*)
    touch xz.exe xzdec.exe lzmadec.exe lzmainfo.exe
    ;;
  *)
    touch xz xzdec lzmadec lzmainfo
    ;;
esac

ninja install
