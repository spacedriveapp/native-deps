#!/usr/bin/env -S bash -euo pipefail

echo "Download vpx..."
mkdir -p vpx

# renovate: depName=https://gitlab.freedesktop.org/gstreamer/meson-ports/libvpx.git
_commit='ca06d4d4007685ea8e45c48d0ad3c6c704cdfde2'

curl_tar "https://gitlab.freedesktop.org/gstreamer/meson-ports/libvpx/-/archive/${_commit}/libvpx.tar.gz" vpx 1

# Delete lines related to xcrun tool usage, it is irrelevant for us
sed -i '1183,1189d' vpx/meson.build
# Remove xcrun tool check, it is irrelevant for us
sed -i "/xcrun_exe = find_program('xcrun', required: true)/d" vpx/meson.build

# Remove some superfluous files
rm -rf vpx/{third_party/googletest,build_debug,test,tools,examples,examples.mk,configure,*.dox,.gitlab*}

case "$TARGET" in
  *android*)
    mkdir -p vpx/cpu_features
    curl_tar 'https://github.com/spacedriveapp/ndk-sysroot/releases/download/2024.10.20/cpufeatures.tar.xz' vpx/cpu_features 0
    ;;
esac

# Backup source
bak_src 'vpx'

mkdir -p vpx/build
cd vpx/build

configs=()

case "$TARGET" in
  *android*) configs+=(-Dcpu_features_path=cpu_features) ;;
  *) ;;
esac

echo "Build vpx..."

meson \
  "${configs[@]}" \
  -Dvp8=enabled \
  -Dvp9=enabled \
  -Dlibs=enabled \
  -Dvp8_decoder=enabled \
  -Dvp9_decoder=enabled \
  -Dvp8_encoder=enabled \
  -Dvp9_encoder=enabled \
  -Dmultithread=enabled \
  -Dinstall_libs=enabled \
  -Dvp9_highbitdepth=enabled \
  -Dbetter_hw_compatibility=enabled \
  -Ddocs=disabled \
  -Dtools=disabled \
  -Dgprof=disabled \
  -Dexamples=disabled \
  -Dinstall_docs=disabled \
  -Dinstall_bins=disabled \
  -Dunit_tests=disabled \
  -Dinternal_stats=disabled \
  -Ddecode_perf_tests=disabled \
  -Dencode_perf_tests=disabled \
  ..

ninja -j"$(nproc)"

ninja install
