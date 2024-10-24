#!/usr/bin/env -S bash -euo pipefail

echo "Download vvenc..."
mkdir -p vvenc

# renovate: datasource=github-releases depName=fraunhoferhhi/vvenc
_tag='1.12.0'

curl_tar "https://github.com/fraunhoferhhi/vvenc/archive/refs/tags/v${_tag}.tar.gz" 'vvenc' 1

sed -i '/add_subdirectory( "source\/App\/vvencapp" )/d' vvenc/CMakeLists.txt
sed -i '/add_subdirectory( "source\/App\/vvencFFapp" )/d' vvenc/CMakeLists.txt
sed -i '/add_subdirectory( "test\/vvenclibtest" )/d' vvenc/CMakeLists.txt
sed -i '/add_subdirectory( "test\/vvencinterfacetest" )/d' vvenc/CMakeLists.txt
sed -i '/include( cmake\/modules\/vvencTests.cmake )/d' vvenc/CMakeLists.txt
sed -i '/  if( VVENC_INSTALL_FULLFEATURE_APP )/,/  endif()/d' vvenc/cmake/modules/vvencInstall.cmake

# Add install_targets( MinSizeRel ) after install_targets( Release )
sed -i '/install_targets( Release )/a install_targets( MinSizeRel )' vvenc/cmake/modules/vvencInstall.cmake

# Remove some superfluous files
rm -rf vvenc/{.*,cfg,test,source/App}

# Backup source
bak_src 'vvenc'

mkdir -p vvenc/build
cd vvenc/build

echo "Build vvenc..."
cmake \
  -DVVENC_ENABLE_INSTALL=On \
  -DVVENC_ENABLE_TRACING=Off \
  -DVVENC_ENABLE_LINK_TIME_OPT="$([ "${LTO:-1}" -eq 1 ] && echo On || echo Off)" \
  -DVVENC_USE_ADDRESS_SANITIZER=Off \
  -DVVENC_ENABLE_THIRDPARTY_JSON=Off \
  -DVVENC_INSTALL_FULLFEATURE_APP=Off \
  -DVVENC_ENABLE_BUILD_TYPE_POSTFIX=Off \
  ..

ninja -j"$(nproc)"

ninja install
