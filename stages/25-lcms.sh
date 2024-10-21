#!/usr/bin/env -S bash -euo pipefail

echo "Download lcms..."
mkdir -p lcms

# renovate: datasource=github-releases depName=mm2/Little-CMS versioning=semver-coerced
_tag='2.16'

curl_tar "https://github.com/mm2/Little-CMS/releases/download/lcms${_tag}/lcms2-${_tag}.tar.gz" lcms 1

case "$TARGET" in
  aarch64*)
    # Patch to enable SSE codepath on aarch64
    patch -F5 -lp1 -d lcms -t <"$PREFIX"/patches/sse2neon.patch
    ;;
esac

sed -i "/subdir('testbed')/d" lcms/meson.build
sed -i "/subdir('testbed')/d" lcms/plugins/threaded/meson.build
sed -i "/subdir('testbed')/d" lcms/plugins/fast_float/meson.build

# Remove some superfluous files
rm -rf lcms/{.github,configure.ac,install-sh,depcomp,Makefile.in,config.sub,aclocal.m4,config.guess,ltmain.sh,m4,utils,configure,Projects,doc,testbed,plugins/{threaded/testbed,fast_float/testbed}}

# Backup source
bak_src 'lcms'

mkdir -p lcms/build
cd lcms/build

echo "Build lcms..."
meson \
  --errorlogs \
  -Dutils=false \
  -Dsamples=false \
  -Dthreaded="$(
    case "$TARGET" in
      *windows*)
        # TODO: Add support for pthreads on Windows
        echo "false"
        ;;
      *)
        echo "true"
        ;;
    esac
  )" \
  -Dfastfloat=true \
  ..

ninja -j"$(nproc)"

ninja install
