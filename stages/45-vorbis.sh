#!/usr/bin/env -S bash -euo pipefail

echo "Download vorbis..."
mkdir -p vorbis

# renovate: datasource=github-releases depName=xiph/vorbis versioning=semver-coerced
_tag='1.3.7'

curl_tar "https://github.com/xiph/vorbis/releases/download/v${_tag}/libvorbis-${_tag}.tar.gz" vorbis 1

# Remove some superfluous files
rm -rf vorbis/{.github,symbian,install-sh,depcomp,macosx,Makefile.in,config.sub,aclocal.m4,config.guess,test,examples,vq,ltmain.sh,m4,configure,doc}

# Backup source
bak_src 'vorbis'

mkdir -p vorbis/build
cd vorbis/build

echo "Build vorbis..."
cmake \
  -DBUILD_TESTING=Off \
  -DINSTALL_CMAKE_PACKAGE_MODULE=On \
  ..

ninja -j"$(nproc)"

ninja install
