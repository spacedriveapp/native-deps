#!/usr/bin/env -S bash -euo pipefail

case "$TARGET" in
  *linux*) ;;
  *)
    export UNSUPPORTED=1
    exit 1
    ;;
esac

echo "Download va..."
mkdir -p va

# renovate: datasource=github-releases depName=intel/libva
_tag='2.20.0'

curl_tar "https://github.com/intel/libva/releases/download/${_tag}/libva-${_tag}.tar.bz2" va 1

rm -rf va/{.github,doc}

# Backup source
bak_src 'va'

mkdir -p va/build
cd va/build

echo "Build va..."
if ! meson \
  -Dwith_x11='no' \
  -Dwith_glx='no' \
  -Dwith_win32='no' \
  -Dwith_wayland='no' \
  -Denable_docs=false \
  -Ddisable_drm=false \
  ..; then
  cat meson-logs/meson-log.txt
  exit 1
fi

ninja -j"$(nproc)"

ninja install
