#!/usr/bin/env -S bash -euo pipefail

echo "Download vpx..."
mkdir -p vpx

# renovate: depName=https://gitlab.freedesktop.org/gstreamer/meson-ports/libvpx.git
_commit='31fdd5dd78347b2468d8a3c4a946f21d230cf19b'

curl_tar "https://gitlab.freedesktop.org/gstreamer/meson-ports/libvpx/-/archive/${_commit}/libvpx.tar.gz" vpx 1

# Delete lines related to xcrun tool usage, it is irrelevant for us
sed -i '1183,1189d' vpx/meson.build
# Remove xcrun tool check, it is irrelevant for us
sed -i "/xcrun_exe = find_program('xcrun', required: true)/d" vpx/meson.build

# Remove some superfluous files
rm -rf vpx/{third_party/googletest,build_debug,test,tools,examples,examples.mk,configure,*.dox,.gitlab*}

# Backup source
bak_src 'vpx'

mkdir -p vpx/build
cd vpx/build

echo "Build vpx..."

meson \
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
