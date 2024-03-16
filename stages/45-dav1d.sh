#!/usr/bin/env -S bash -euo pipefail

echo "Download dav1d..."
mkdir -p dav1d

# renovate: datasource=gitlab-releases depName=videolan/dav1d registryUrl=https://code.videolan.org
_tag='1.4.1'

curl_tar "https://code.videolan.org/videolan/dav1d/-/archive/${_tag}/dav1d-${_tag}.tar.bz2" dav1d 1

sed -i "/subdir('doc')/d" dav1d/meson.build
sed -i "/subdir('tools')/d" dav1d/meson.build
sed -i "/subdir('tests')/d" dav1d/meson.build
sed -i "/subdir('examples')/d" dav1d/meson.build

mv dav1d/tools/compat "${TMP:-/tmp}/dav1d-compat"
# Remove some superfluous files
rm -rf dav1d/{.github,package,doc,examples,tools/*,tests}
mv "${TMP:-/tmp}/dav1d-compat" dav1d/tools/compat

# Backup source
bak_src 'dav1d'

mkdir -p dav1d/build
cd dav1d/build

echo "Build dav1d..."
if ! meson \
  -Denable_docs=false \
  -Denable_tools=false \
  -Denable_tests=false \
  -Denable_examples=false \
  ..; then
  cat meson-logs/meson-log.txt
  exit 1
fi

ninja -j"$(nproc)"

ninja install
