#!/usr/bin/env -S bash -euo pipefail

echo "Download heif..."
mkdir -p heif

# renovate: datasource=github-releases depName=strukturag/libheif
_tag='1.19.6'

curl_tar "https://github.com/strukturag/libheif/releases/download/v${_tag}/libheif-${_tag}.tar.gz" heif 1

case "$TARGET" in
  *windows*)
    sed -ie 's/__attribute__((__visibility__("default")))/__declspec(dllexport)/' heif/libheif/api/libheif/heif.h
    ;;
esac

# Remove unused components
rm -r heif/{go,fuzzing,tests,examples}

# Backup source
bak_src 'heif'

mkdir -p heif/build
cd heif/build

echo "Build heif..."

env SHARED="$(
  if [ "$OS_IPHONE" -gt 0 ] || [ "$OS_ANDROID" -eq 1 ]; then
    echo "Off"
  else
    echo "On"
  fi
)" PREFIX="$OUT" cmake \
  -DWITH_DAV1D=On \
  -DWITH_LIBDE265=On \
  -DWITH_LIBSHARPYUV=On \
  -DWITH_FFMPEG_DECODER=On \
  -DWITH_UNCOMPRESSED_CODEC=On \
  -DWITH_REDUCED_VISIBILITY=On \
  -DWITH_HEADER_COMPRESSION=On \
  -DCMAKE_C_VISIBILITY_PRESET=hidden \
  -DCMAKE_CXX_VISIBILITY_PRESET=hidden \
  -DENABLE_MULTITHREADING_SUPPORT=On \
  -DCMAKE_VISIBILITY_INLINES_HIDDEN=On \
  -DWITH_X265=Off \
  -DWITH_RAV1E=Off \
  -DWITH_SvtEnc=Off \
  -DWITH_KVAZAAR=Off \
  -DWITH_FUZZERS=Off \
  -DWITH_EXAMPLES=Off \
  -DBUILD_TESTING=Off \
  -DWITH_GDK_PIXBUF=Off \
  -DWITH_AOM_DECODER=Off \
  -DWITH_AOM_ENCODER=Off \
  -DWITH_JPEG_DECODER=Off \
  -DWITH_JPEG_ENCODER=Off \
  -DWITH_OpenJPEG_DECODER=Off \
  -DWITH_OpenJPEG_ENCODER=Off \
  -DENABLE_PLUGIN_LOADING=Off \
  -DWITH_UNCOMPRESSED_CODEC=Off \
  ..

ninja -j"$(nproc)"

case "$TARGET" in
  *windows*)
    cat <<EOF >libheif.ver
LIBHEIF_1 {
    global:
        heif_*;
    local:
        *;
};
EOF

    # Generate def file
    find . -name '*.obj' -exec env EXTERN_PREFIX="" makedef ./libheif.ver {} + >heif-1.def

    # Generate lib file
    dlltool -m "$(case "$TARGET" in x86_64*) echo "i386:x86-64" ;; aarch64*) echo "arm64" ;; esac)" \
      -d ./heif-1.def -l heif.lib -D ./libheif/libheif.dll
    ;;
esac

ninja install

if [ -f "heif.lib" ]; then
  cp -at "${OUT}/lib/" heif.lib
fi

# Copy static libs for iOS
if [ "$OS_IPHONE" -gt 0 ] || [ "$OS_ANDROID" -eq 1 ]; then
  cp -r "$PREFIX"/lib/*.a "${OUT}/lib/"
fi
