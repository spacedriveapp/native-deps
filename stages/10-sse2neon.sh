#!/usr/bin/env -S bash -euo pipefail

case "$TARGET" in
  aarch64*) ;;
  *)
    export UNSUPPORTED=1
    exit 1
    ;;
esac

echo "Download sse2neon..."

mkdir -p sse2neon

# renovate: datasource=github-releases depName=DLTcollab/sse2neon
_tag='1.7.0'

curl_tar "https://github.com/DLTcollab/sse2neon/archive/refs/tags/v${_tag}.tar.gz" 'sse2neon' 1

# Remove unused components
rm -r sse2neon/{.ci,.github,tests}

# Backup source
bak_src 'sse2neon'

# Install
mkdir -p "${PREFIX}/include"
mv sse2neon/sse2neon.h "${PREFIX}/include/"
