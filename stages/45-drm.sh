#!/usr/bin/env -S bash -euo pipefail

case "$TARGET" in
  *linux*) ;;
  *)
    export UNSUPPORTED=1
    exit 1
    ;;
esac

echo "Download drm..."
mkdir -p drm

# renovate: datasource=git-tags depName=drm/libdrm registryUrl=https://cgit.freedesktop.org
_tag='2.4.123'

curl_tar "https://dri.freedesktop.org/libdrm/libdrm-${_tag}.tar.xz" drm 1

rm -rf drm/{etnaviv,man,tests}

# Backup source
bak_src 'drm'

mkdir -p drm/build
cd drm/build

configs=()

case "$TARGET" in
  android) configs+=(-Dudev=false) ;;&
  aarch64-linux-android) configs+=(-Dfreedreno-kgsl=true) ;;
  *) configs+=(-Dudev=true) ;;
esac

echo "Build drm..."
if ! meson \
  "${configs[@]}" \
  -Dintel=auto \
  -Dradeon=auto \
  -Damdgpu=auto \
  -Dnouveau=auto \
  -Domap=auto \
  -Dexynos=auto \
  -Dfreedreno=auto \
  -Dtegra=auto \
  -Dvc4=auto \
  -Dvmwgfx=disabled \
  -Detnaviv=disabled \
  -Dvalgrind=disabled \
  -Dcairo-tests=disabled \
  -Dman-pages=disabled \
  -Dtests=false \
  -Dinstall-test-programs=false \
  ..; then
  cat meson-logs/meson-log.txt
  exit 1
fi

ninja -j"$(nproc)"

ninja install
