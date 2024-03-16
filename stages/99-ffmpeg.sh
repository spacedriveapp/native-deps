#!/usr/bin/env -S bash -euo pipefail

echo "Download ffmpeg..."
mkdir -p ffmpeg

curl_tar 'https://github.com/FFmpeg/FFmpeg/archive/refs/tags/n6.1.1.tar.gz' ffmpeg 1

# Handbreak patches
for patch in \
  'https://github.com/HandBrake/HandBrake/raw/5c81a46/contrib/ffmpeg/A01-mov-read-name-track-tag-written-by-movenc.patch' \
  'https://github.com/HandBrake/HandBrake/raw/5c81a46/contrib/ffmpeg/A02-movenc-write-3gpp-track-titl-tag.patch' \
  'https://github.com/HandBrake/HandBrake/raw/5c81a46/contrib/ffmpeg/A03-mov-read-3gpp-udta-tags.patch' \
  'https://github.com/HandBrake/HandBrake/raw/5c81a46/contrib/ffmpeg/A04-movenc-write-3gpp-track-names-tags-for-all-available.patch' \
  'https://github.com/HandBrake/HandBrake/raw/5c81a46/contrib/ffmpeg/A05-dvdsubdec-fix-processing-of-partial-packets.patch' \
  'https://github.com/HandBrake/HandBrake/raw/5c81a46/contrib/ffmpeg/A06-dvdsubdec-return-number-of-bytes-used.patch' \
  'https://github.com/HandBrake/HandBrake/raw/5c81a46/contrib/ffmpeg/A07-dvdsubdec-use-pts-of-initial-packet.patch' \
  'https://github.com/HandBrake/HandBrake/raw/5c81a46/contrib/ffmpeg/A08-ccaption_dec-fix-pts-in-real_time-mode.patch' \
  'https://github.com/HandBrake/HandBrake/raw/5c81a46/contrib/ffmpeg/A09-matroskaenc-aac-extradata-updated.patch' \
  'https://github.com/HandBrake/HandBrake/raw/5c81a46/contrib/ffmpeg/A10-amfenc-Add-support-for-pict_type-field.patch' \
  'https://github.com/HandBrake/HandBrake/raw/5c81a46/contrib/ffmpeg/A11-amfenc-Fixes-the-color-information-in-the-ou.patch' \
  'https://github.com/HandBrake/HandBrake/raw/5c81a46/contrib/ffmpeg/A12-amfenc-HDR-metadata.patch' \
  'https://github.com/HandBrake/HandBrake/raw/5c81a46/contrib/ffmpeg/A13-libavcodec-amfenc-Fix-issue-with-missing-headers-in-.patch' \
  'https://github.com/HandBrake/HandBrake/raw/5c81a46/contrib/ffmpeg/A14-avcodec-add-ambient-viewing-environment-packet-side-.patch' \
  'https://github.com/HandBrake/HandBrake/raw/5c81a46/contrib/ffmpeg/A15-avformat-mov-add-support-for-amve-ambient-viewing-en.patch' \
  'https://github.com/HandBrake/HandBrake/raw/5c81a46/contrib/ffmpeg/A16-videotoolbox-dec-h264.patch' \
  'https://github.com/HandBrake/HandBrake/raw/5c81a46/contrib/ffmpeg/A17-libswscale-fix-yuv420p-to-p01xle-color-conversion-bu.patch' \
  'https://github.com/HandBrake/HandBrake/raw/5c81a46/contrib/ffmpeg/A18-qsv-fix-decode-10bit-hdr.patch' \
  'https://github.com/HandBrake/HandBrake/raw/5c81a46/contrib/ffmpeg/A19-ffbuild-common-use-gzip-n-flag-for-cuda.patch' \
  'https://github.com/HandBrake/HandBrake/raw/5c81a46/contrib/ffmpeg/A20-vf_scale_preserve_range.patch' \
  'https://github.com/HandBrake/HandBrake/raw/5c81a46/contrib/ffmpeg/A21-dvdsubdec-do-not-discard-zero-sized-rects.patch'; do
  curl "$patch" | patch -F5 -lp1 -d ffmpeg -t
done

# Backup source
bak_src 'ffmpeg'

cd ffmpeg

echo "Build ffmpeg..."

env_specific_arg=()

if [ "$(uname -m)" = "${TARGET%%-*}" ] && (case "$TARGET" in *linux* | x86_64-windows*) exit 0 ;; *) exit 1 ;; esac) then
  # zig cc doesn't support compiling cuda code yet, so we use the host clang for it
  # Unfortunatly that means we only suport cuda in the same architecture as the host system
  # https://github.com/ziglang/zig/pull/10704#issuecomment-1023616464
  env_specific_arg+=(
    --nvcc="clang-16 -target ${TARGET}"
    --enable-cuda-llvm
    --enable-ffnvcodec
    --disable-cuda-nvcc
  )
else
  # There are no Nvidia GPU drivers for macOS or Windows on ARM
  env_specific_arg+=(
    --nvcc=false
    --disable-cuda-llvm
    --disable-ffnvcodec
    --disable-cuda-nvcc
  )
fi

case "$TARGET" in
  x86_64*)
    env_specific_arg+=(
      --x86asmexe=nasm
      --enable-x86asm
    )
    ;;
  aarch64*)
    env_specific_arg+=(
      --x86asmexe=false
      --enable-vfp
      --enable-neon
    )
    ;;
esac

case "$TARGET" in
  *darwin*)
    env_specific_arg+=(
      # TODO: Metal suport is disabled because no open source compiler is available for it
      # TODO: Maybe try macOS own metal compiler under darling? https://github.com/darlinghq/darling/issues/326
      # TODO: Add support for vulkan (+ libplacebo) on macOS with MoltenVK
      --sysroot="${MACOS_SDKROOT:?Missing macOS SDK path}"
      --disable-metal
      --disable-vulkan
      --disable-w32threads
      --disable-libshaderc
      --disable-libplacebo
      --disable-mediafoundation
      --enable-pthreads
      --enable-coreimage
      --enable-videotoolbox
      --enable-avfoundation
      --enable-audiotoolbox
    )
    ;;
  *linux*)
    env_specific_arg+=(
      --disable-coreimage
      --disable-w32threads
      --disable-videotoolbox
      --disable-avfoundation
      --disable-audiotoolbox
      --disable-mediafoundation
      --enable-lto
      --enable-vulkan
      --enable-pthreads
      --enable-libshaderc
      --enable-libplacebo
    )
    ;;
  *windows*)
    # TODO: Add support for mediafoundation on Windows (zig doesn't seem to have the necessary bindings to it yet)
    # FIX-ME: LTO isn't working on Windows rn
    env_specific_arg+=(
      --disable-pthreads
      --disable-coreimage
      --disable-videotoolbox
      --disable-avfoundation
      --disable-audiotoolbox
      --disable-mediafoundation
      --enable-vulkan
      --enable-w32threads
      --enable-libshaderc
      --enable-libplacebo
    )
    ;;
esac

case "$TARGET" in
  *darwin* | aarch64-windows*) ;;
    # Apple only support its own APIs for hardware (de/en)coding on macOS
    # Windows on ARM doesn't have external GPU support yet
  *)
    env_specific_arg+=(
      --enable-amf
      --enable-libvpl
    )
    ;;
esac

_arch="${TARGET%%-*}"
case "$TARGET" in
  aarch64-darwin*)
    _arch=arm64
    ;;
esac

if ! ./configure \
  --cpu="$_arch" \
  --arch="$_arch" \
  --prefix="$OUT" \
  --target-os="$(
    case "$TARGET" in
      *linux*)
        echo "linux"
        ;;
      *darwin*)
        echo "darwin"
        ;;
      *windows*)
        echo "mingw64"
        ;;
    esac
  )" \
  --cc=cc \
  --nm=nm \
  --ar=ar \
  --cxx=c++ \
  --strip=strip \
  --ranlib=ranlib \
  --host-cc=clang-16 \
  --windres="windres" \
  --pkg-config=pkg-config \
  --pkg-config-flags="--static" \
  --disable-static \
  --disable-debug \
  --disable-doc \
  --disable-htmlpages \
  --disable-txtpages \
  --disable-manpages \
  --disable-podpages \
  --disable-indevs \
  --disable-outdevs \
  --disable-parser=avs2 \
  --disable-parser=avs3 \
  --disable-postproc \
  --disable-programs \
  --disable-libwebp \
  --disable-sdl2 \
  --disable-metal \
  --disable-opengl \
  --disable-network \
  --disable-openssl \
  --disable-schannel \
  --disable-securetransport \
  --disable-xlib \
  --disable-libxcb \
  --disable-libxcb-shm \
  --disable-libxcb-xfixes \
  --disable-libxcb-shape \
  --disable-libv4l2 \
  --disable-v4l2-m2m \
  --disable-xmm-clobber-test \
  --disable-neon-clobber-test \
  --enable-asm \
  --enable-avcodec \
  --enable-avfilter \
  --enable-avformat \
  --enable-bzlib \
  --enable-cross-compile \
  --enable-gpl \
  --enable-inline-asm \
  --enable-libdav1d \
  --enable-libmp3lame \
  --enable-libopus \
  --enable-libsoxr \
  --enable-libsvtav1 \
  --enable-libtheora \
  --enable-libvorbis \
  --enable-libvpx \
  --enable-libx264 \
  --enable-libx265 \
  --enable-libzimg \
  --enable-lzma \
  --enable-opencl \
  --enable-optimizations \
  --enable-postproc \
  --enable-shared \
  --enable-swscale \
  --enable-version3 \
  --enable-zlib \
  "${env_specific_arg[@]}"; then
  cat ffbuild/config.log >&2
  exit 1
fi

case "$TARGET" in
  *linux*)
    # Replace incorrect identifyed sysctl as enabled on linux
    sed -i 's/#define HAVE_SYSCTL 1/#define HAVE_SYSCTL 0/' config.h
    ;;
esac

make -j"$(nproc)" V=1

make install

case "$TARGET" in
  *windows*)
    # Move dll.a to lib
    find "${OUT}/lib" -type f -name '*.dll.a' -exec sh -euc \
      'for dlla in "$@"; do lib="$(basename "$dlla" .dll.a).lib" && lib="${lib#"lib"}" && if ! [ -f "$lib" ]; then mv "$dlla" "$(dirname "$dlla")/${lib}"; fi; done' \
      sh {} +
    ;;
esac
