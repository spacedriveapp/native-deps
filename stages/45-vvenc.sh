#!/usr/bin/env -S bash -euo pipefail

echo "Download vvenc..."
mkdir -p vvenc

# renovate: datasource=github-releases depName=fraunhoferhhi/vvenc
_tag='1.13.1'

curl_tar "https://github.com/fraunhoferhhi/vvenc/archive/refs/tags/v${_tag}.tar.gz" 'vvenc' 1

sed -i '/add_subdirectory( "source\/App\/vvencapp" )/d' vvenc/CMakeLists.txt
sed -i '/add_subdirectory( "source\/App\/vvencFFapp" )/d' vvenc/CMakeLists.txt
sed -i '/add_subdirectory( "test\/vvenclibtest" )/d' vvenc/CMakeLists.txt
sed -i '/add_subdirectory( "test\/vvencinterfacetest" )/d' vvenc/CMakeLists.txt
sed -i '/if( NOT BUILD_SHARED_LIBS )/,/endif()/d' vvenc/CMakeLists.txt
sed -i '/# set _WIN32_WINNT/,/endif()/d' vvenc/CMakeLists.txt
sed -i '/include( cmake\/modules\/vvencTests.cmake )/d' vvenc/CMakeLists.txt

case "$TARGET" in
  aarch64*)
    sed -i '/int src8tOff = cStride;/d' vvenc/source/Lib/CommonLib/arm/neon/InterpolationFilter_neon.cpp
    ;;
esac

# Remove some superfluous files
rm -rf vvenc/{.*,cfg,test,source/App}

# Backup source
bak_src 'vvenc'

mkdir -p vvenc/build
cd vvenc/build

echo "Build vvenc..."
cmake \
  -DVVENC_LIBRARY_ONLY=On \
  -DVVENC_ENABLE_INSTALL=On \
  -DVVENC_ENABLE_TRACING=Off \
  -DVVENC_ENABLE_LINK_TIME_OPT="$([ "${LTO:-1}" -eq 1 ] && echo On || echo Off)" \
  -DVVENC_USE_ADDRESS_SANITIZER=Off \
  -DVVENC_ENABLE_THIRDPARTY_JSON=Off \
  -DVVENC_INSTALL_FULLFEATURE_APP=Off \
  -DVVENC_ENABLE_BUILD_TYPE_POSTFIX=Off \
  -DVVENC_ENABLE_X86_SIMD="$(case "$TARGET" in x86_64*) echo 'On' ;; aarch64*) echo 'Off' ;; esac)" \
  ..

ninja -j"$(nproc)"

ninja install

sed -ri 's/^(Libs.private:.*)$/\1 -lstdc++/' "${PREFIX}/lib/pkgconfig/libvvenc.pc"
