#!/usr/bin/env -S bash -euo pipefail

case "$TARGET" in
  *linux*) ;;
  *)
    export UNSUPPORTED=1
    exit 1
    ;;
esac

echo "Download pciaccess..."
mkdir -p pciaccess

# renovate: datasource=gitlab-tags depName=xorg/lib/libpciaccess registryUrl=https://gitlab.freedesktop.org
_tag='0.18.1'

curl_tar "https://xorg.freedesktop.org/releases/individual/lib/libpciaccess-${_tag}.tar.xz" pciaccess 1

sed -i "/subdir('scanpci')/d" pciaccess/meson.build
sed -i "/subdir('man')/d" pciaccess/meson.build

rm -rf pciaccess/{.gitlab-ci.yml,man,scanpci}

# Backup source
bak_src 'pciaccess'

mkdir -p pciaccess/build
cd pciaccess/build

echo "Build pciaccess..."
if ! meson -Dzlib=enabled ..; then
  cat meson-logs/meson-log.txt
  exit 1
fi

ninja -j"$(nproc)"

ninja install
