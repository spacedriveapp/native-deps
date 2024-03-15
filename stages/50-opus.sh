#!/usr/bin/env -S bash -euo pipefail

echo "Download opus..."
mkdir -p opus

# renovate: datasource=github-tags depName=xiph/opus versioning=semver-coerced
_tag='1.4'

curl_tar "https://github.com/xiph/opus/archive/refs/tags/v${_tag}.tar.gz" opus 1

# Required patch to fix meson for arm builds
curl 'https://github.com/xiph/opus/commit/20c032d.patch' \
  | patch -F5 -lp1 -d opus -t

# Remove unused components
rm -rf opus/{.github,CMakeLists.txt,config.sub,aclocal.m4,config.guess,cmake,doc,Makefile.in,tests,ltmain.sh,m4,configure}

# Update version
cat > "$SRCDIR/package_version" <<-EOF
	AUTO_UPDATE=no
	PACKAGE_VERSION="$_tag"
EOF

# Backup source
bak_src 'opus'

mkdir -p opus/build
cd opus/build

echo "Build opus..."
meson \
  -Dintrinsics=enabled \
  -Ddocs=disabled \
  -Dtests=disabled \
  -Dcustom-modes=true \
  -Dextra-programs=disabled \
  ..

ninja -j"$(nproc)"

ninja install
