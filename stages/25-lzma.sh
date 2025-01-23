#!/usr/bin/env -S bash -euo pipefail

echo "Download lzma..."
mkdir -p lzma

# renovate: datasource=github-releases depName=tukaani-project/xz
_tag='5.6.4'

curl_tar "https://github.com/tukaani-project/xz/releases/download/v${_tag}/xz-${_tag}.tar.xz" lzma 1

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

mkdir -p ../doc/examples
case "$TARGET" in
  *windows*)
    touch xz.exe xzdec.exe lzmadec.exe lzmainfo.exe
    ;;
  *)
    touch xz xzdec lzmadec lzmainfo
    ;;
esac

ninja install
