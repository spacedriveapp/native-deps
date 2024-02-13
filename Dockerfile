# escape=`

ARG OUT="/opt/out"
ARG TARGET="x86_64-linux-gnu"
ARG VERSION="0.0.0"

# renovate: datasource=github-releases depName=ziglang/zig
ARG ZIG_VERSION='0.11.0'
# renovate: datasource=github-releases depName=mesonbuild/meson
ARG MESON_VERSION='1.3.2'
# renovate: datasource=github-releases depName=Kitware/CMake
ARG CMAKE_VERSION='3.28.3'
# renovate: datasource=github-releases depName=NixOS/patchelf
ARG PATCHELF_VERSION='0.18.0'
# renovate: datasource=github-releases depName=joseluisq/macosx-sdks
ARG MACOS_SDK_VERSION='14.2'

#--

FROM debian:bookworm@sha256:4482958b4461ff7d9fabc24b3a9ab1e9a2c85ece07b2db1840c7cbc01d053e90 as build-base

SHELL ["bash", "-euxo", "pipefail", "-c"]

# Configure apt to be docker friendly
ADD https://gist.githubusercontent.com/HeavenVolkoff/ff7b77b9087f956b8df944772e93c071/raw `
	/etc/apt/apt.conf.d/99docker-apt-config

RUN rm -f /etc/apt/apt.conf.d/docker-clean

RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

RUN --mount=type=cache,target=/var/cache/apt --mount=type=cache,target=/var/lib/apt `
	apt-get update && apt-get upgrade && apt-get install -y ca-certificates

# Add LLVM 16 repository
ADD https://apt.llvm.org/llvm-snapshot.gpg.key /etc/apt/trusted.gpg.d/apt.llvm.org.asc

RUN chmod 644 /etc/apt/trusted.gpg.d/apt.llvm.org.asc

RUN echo "deb https://apt.llvm.org/bookworm/ llvm-toolchain-bookworm-16 main" `
	> /etc/apt/sources.list.d/llvm.list

# Install build dependencies
RUN --mount=type=cache,target=/var/cache/apt --mount=type=cache,target=/var/lib/apt `
	apt-get update && apt-get install `
	nasm `
	curl `
	make `
	patch `
	libtool `
	python3 `
	gettext `
	llvm-16 `
	autoconf `
	clang-16 `
	pkg-config `
	ninja-build `
	libarchive-tools `
	protobuf-compiler

# Configure sysroot and prefix
ARG OUT
ENV OUT="${OUT:?}"
ENV PREFIX="/opt/prefix"
ENV SYSROOT="/opt/sysroot"
ENV CCTOOLS="/opt/cctools"
ENV CIPHERSUITES="TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_256_GCM_SHA384:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384"

# Ensure sysroot and cctools are present on PATH
ENV PATH="${CCTOOLS}/bin:${SYSROOT}/bin:$PATH"

# Create required directories
RUN mkdir -p "$OUT" "$CCTOOLS" "${PREFIX}/bin" "${SYSROOT}/bin" "${SYSROOT}/wrapper"

# Utility to download, extract and cache archived files
COPY --chmod=0750 ./scripts/curl_tar.sh "${SYSROOT}/bin/curl_tar"

# Download and install zig toolchain
ARG ZIG_VERSION
RUN --mount=type=cache,target=/root/.cache `
	curl_tar "https://ziglang.org/builds/zig-linux-$(uname -m)-${ZIG_VERSION:?}.tar.xz" "$SYSROOT" 1 `
	&& mv "${SYSROOT}/zig" "${SYSROOT}/bin/zig"

# Download and install cmake
ARG CMAKE_VERSION
RUN --mount=type=cache,target=/root/.cache `
	curl_tar "https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION:?}/cmake-${CMAKE_VERSION:?}-linux-$(uname -m).tar.gz" "$SYSROOT" 1

# Download and install meson, with a patch to add zig support
ARG MESON_VERSION
RUN --mount=type=cache,target=/root/.cache `
	curl_tar "https://github.com/mesonbuild/meson/archive/refs/tags/${MESON_VERSION:?}.tar.gz" /srv/meson 1
ADD 'https://github.com/mesonbuild/meson/pull/12293.patch' /srv/meson/12293.patch
RUN cd /srv/meson `
	&& patch -F5 -lp1 -d /srv/meson -t < 12293.patch `
	&& packaging/create_zipapp.py --outfile "${SYSROOT}/bin/meson" --compress `
	&& rm -rf /srv/meson

# Download and install patchelf, used to do some light rpath ELF manipulation
ARG PATCHELF_VERSION
RUN --mount=type=cache,target=/root/.cache `
	curl_tar "https://github.com/NixOS/patchelf/releases/download/${PATCHELF_VERSION:?}/patchelf-${PATCHELF_VERSION:?}-$(uname -m).tar.gz" "$SYSROOT" 1

# Download and install gas-preprocessor, used by our zig wrapper to handle GNU flavored assembly files
ADD --chmod=0750 'https://github.com/libav/gas-preprocessor/raw/master/gas-preprocessor.pl' "${SYSROOT}/bin/gas-preprocessor.pl"

# Download compat tool for generating def files for windows
ADD --chmod=0750 'https://github.com/FFmpeg/FFmpeg/raw/master/compat/windows/makedef' "${SYSROOT}/bin/makedef"

# Workaround for -lsynchronization linking issue on Windows GNU targets
# https://github.com/ziglang/zig/issues/14919
RUN cd "${SYSROOT}/lib/libc/mingw/lib-common" `
	&& { [ -f 'synchronization.def' ] || ln -s 'api-ms-win-core-synch-l1-2-0.def' 'synchronization.def'; }

#--

FROM build-base AS base-layer

# Configure macOS SDK for darwin targets
ARG MACOS_SDK_VERSION
ENV MACOS_SDK_VERSION="${MACOS_SDK_VERSION:?}"
ENV MACOS_SDKROOT="/opt/MacOSX${MACOS_SDK_VERSION}.sdk"

# Export which target we are building for
ARG TARGET
ENV TARGET="${TARGET:?}"

# Cache bust
RUN echo "Building: ${TARGET}$(case "$TARGET" in *darwin*) echo " (macOS SDK: ${MACOS_SDK_VERSION})" ;; esac)"

# Script wrapper for some common build tools. Auto choose between llvm, zig or apple specific versions
COPY --chmod=0750 ./scripts/tool-wrapper.sh "${SYSROOT}/bin/tool-wrapper.sh"
RUN for tool in `
	ar nm lib lipo size otool strip ranlib readelf libtool objdump dlltool `
	objcopy strings bitcode-strip install_name_tool; `
	do ln -s "$(command -v tool-wrapper.sh)" "${SYSROOT}/bin/${tool}"; done

# Custom llvm rc wrapper script with some pre-configurations
# Do not name this llvm-rc or rc.exe, to avoid cmake weird special behavior for those tool names
COPY --chmod=0750 ./scripts/rc.sh "${SYSROOT}/bin/rc"
COPY --chmod=0750 ./scripts/rc.sh "${SYSROOT}/bin/windres"

# Polyfill macOS sw_vers command
COPY --chmod=0750 ./scripts/sw_vers.sh "${SYSROOT}/bin/sw_vers"

#--

FROM base-layer AS layer-00

# Download, build and install Apple specific SDK and tools
RUN --mount=type=cache,target=/root/.cache `
	--mount=type=bind,source=stages/00-apple/00-sdk.sh,target=/srv/00-sdk.sh `
	/srv/00-sdk.sh

RUN --mount=type=cache,target=/var/cache/apt --mount=type=cache,target=/var/lib/apt --mount=type=cache,target=/root/.cache `
	--mount=type=bind,source=stages/00-apple/01-xar.sh,target=/srv/01-xar.sh `
	/srv/01-xar.sh

RUN --mount=type=cache,target=/var/cache/apt --mount=type=cache,target=/var/lib/apt --mount=type=cache,target=/root/.cache `
	--mount=type=bind,source=stages/00-apple/02-tapi.sh,target=/srv/02-tapi.sh `
	/srv/02-tapi.sh

RUN --mount=type=cache,target=/var/cache/apt --mount=type=cache,target=/var/lib/apt --mount=type=cache,target=/root/.cache `
	--mount=type=bind,source=stages/00-apple/03-dispatch.sh,target=/srv/03-dispatch.sh `
	/srv/03-dispatch.sh

RUN --mount=type=cache,target=/var/cache/apt --mount=type=cache,target=/var/lib/apt --mount=type=cache,target=/root/.cache `
	--mount=type=bind,source=stages/00-apple/04-cctools.sh,target=/srv/04-cctools.sh `
	/srv/04-cctools.sh

# Ensure no one tries to call the native system linker
RUN ln -s '/usr/bin/false' "${SYSROOT}/bin/ld"

# Add wrapper script for zig compilers, we need to ensure that they are called with the correct arguments
COPY --chmod=0750 ./scripts/cc.sh "${SYSROOT}/bin/cc"
RUN ln -s 'cc' "${SYSROOT}/bin/c++"
RUN chmod +x "${SYSROOT}/bin/cc" "${SYSROOT}/bin/c++"

# Create cmake and meson toolchain files
RUN --mount=type=bind,rw,source=scripts/toolchain.sh,target=/srv/toolchain.sh /srv/toolchain.sh

# Create a cmake wrapper script with some pre-configurations
COPY --chmod=0750 ./scripts/cmake.sh "${SYSROOT}/wrapper/cmake"

# Create a meson wrapper script with some pre-configurations
COPY --chmod=0750 ./scripts/meson.sh "${SYSROOT}/wrapper/meson"

# Wrapper script that pre-configure autotools and build flags fro each target
COPY --chmod=0750 ./scripts/build.sh /srv/build.sh

#--

FROM layer-00 AS layer-10-sse2neon

RUN --mount=type=cache,target=/root/.cache --mount=type=bind,source=stages/10-sse2neon.sh,target=/srv/stage.sh `
	/srv/build.sh

FROM layer-00 AS layer-10-compiler-rt

RUN --mount=type=cache,target=/root/.cache `
	--mount=type=bind,source=stages/10-compiler-rt.sh,target=/srv/stage.sh `
	/srv/build.sh

FROM layer-00 AS layer-10

COPY --from=layer-10-sse2neon "${PREFIX}/." "$PREFIX"
COPY --from=layer-10-compiler-rt "/usr/lib/llvm-16/lib/clang/16/." '/usr/lib/llvm-16/lib/clang/16'

#--

FROM layer-10 AS layer-20-brotli

RUN --mount=type=cache,target=/root/.cache `
	--mount=type=bind,source=stages/20-brotli.sh,target=/srv/stage.sh `
	/srv/build.sh

FROM layer-10 AS layer-20-bzip2

RUN --mount=type=cache,target=/root/.cache `
	--mount=type=bind,source=stages/20-bzip2.sh,target=/srv/stage.sh `
	/srv/build.sh

FROM layer-10 AS layer-20-lzo

RUN --mount=type=cache,target=/root/.cache `
	--mount=type=bind,source=stages/20-lzo.sh,target=/srv/stage.sh `
	/srv/build.sh

FROM layer-10 AS layer-20-zlib

RUN --mount=type=cache,target=/root/.cache `
	--mount=type=bind,source=stages/20-zlib.sh,target=/srv/stage.sh `
	/srv/build.sh

FROM layer-10 AS layer-20

COPY --from=layer-20-brotli "${PREFIX}/." "$PREFIX"
COPY --from=layer-20-bzip2 "${PREFIX}/." "$PREFIX"
COPY --from=layer-20-lzo "${PREFIX}/." "$PREFIX"
COPY --from=layer-20-zlib "${PREFIX}/." "$PREFIX"

#--

FROM layer-20 AS layer-25-lcms

RUN --mount=type=cache,target=/root/.cache `
	--mount=type=bind,source=stages/25-lcms.sh,target=/srv/stage.sh `
	--mount=type=bind,source=patches/25-lcms,target="${PREFIX}/patches" `
	/srv/build.sh

FROM layer-20 AS layer-25-lzma

RUN --mount=type=cache,target=/root/.cache `
	--mount=type=bind,source=stages/25-lzma.sh,target=/srv/stage.sh `
	/srv/build.sh

FROM layer-20 AS layer-25-ogg

RUN --mount=type=cache,target=/root/.cache `
	--mount=type=bind,source=stages/25-ogg.sh,target=/srv/stage.sh `
	/srv/build.sh

FROM layer-20 AS layer-25

COPY --from=layer-25-lcms "${PREFIX}/." "$PREFIX"
COPY --from=layer-25-lzma "${PREFIX}/." "$PREFIX"
COPY --from=layer-25-ogg "${PREFIX}/." "$PREFIX"

#--

FROM layer-25 AS layer-45-dav1d

RUN --mount=type=cache,target=/root/.cache `
	--mount=type=bind,source=stages/45-dav1d.sh,target=/srv/stage.sh `
	/srv/build.sh

FROM layer-25 AS layer-45-de265

RUN --mount=type=cache,target=/root/.cache `
	--mount=type=bind,source=stages/45-de265.sh,target=/srv/stage.sh `
	--mount=type=bind,source=patches/45-de265,target="${PREFIX}/patches" `
	/srv/build.sh

FROM layer-25 AS layer-45-opencl

RUN --mount=type=cache,target=/root/.cache `
	--mount=type=bind,source=stages/45-opencl/25-opencl-headers.sh,target=/srv/stage.sh `
	/srv/build.sh

RUN --mount=type=cache,target=/root/.cache `
	--mount=type=bind,source=stages/45-opencl/45-opencl.sh,target=/srv/stage.sh `
	/srv/build.sh

FROM layer-25 AS layer-45-sharpyuv

RUN --mount=type=cache,target=/root/.cache `
	--mount=type=bind,source=stages/45-sharpyuv.sh,target=/srv/stage.sh `
	/srv/build.sh

FROM layer-25 AS layer-45-vorbis

RUN --mount=type=cache,target=/root/.cache `
	--mount=type=bind,source=stages/45-vorbis.sh,target=/srv/stage.sh `
	/srv/build.sh

FROM layer-25 AS layer-45

COPY --from=layer-45-dav1d "${PREFIX}/." "$PREFIX"
COPY --from=layer-45-de265 "${PREFIX}/." "$PREFIX"
COPY --from=layer-45-opencl "${PREFIX}/." "$PREFIX"
COPY --from=layer-45-sharpyuv "${PREFIX}/." "$PREFIX"
COPY --from=layer-45-vorbis "${PREFIX}/." "$PREFIX"

#--

FROM layer-45 AS layer-50-amf

RUN --mount=type=cache,target=/root/.cache `
	--mount=type=bind,source=stages/50-amf.sh,target=/srv/stage.sh `
	/srv/build.sh

FROM layer-45 AS layer-50-nvenc

RUN --mount=type=cache,target=/root/.cache `
	--mount=type=bind,source=stages/50-nvenc.sh,target=/srv/stage.sh `
	/srv/build.sh

FROM layer-45 AS layer-50-lame

RUN --mount=type=cache,target=/root/.cache `
	--mount=type=bind,source=stages/50-lame.sh,target=/srv/stage.sh `
	/srv/build.sh

FROM layer-45 AS layer-50-onevpl

RUN --mount=type=cache,target=/root/.cache `
	--mount=type=bind,source=stages/50-onevpl.sh,target=/srv/stage.sh `
	/srv/build.sh

FROM layer-45 AS layer-50-opus

RUN --mount=type=cache,target=/root/.cache `
	--mount=type=bind,source=stages/50-opus.sh,target=/srv/stage.sh `
	/srv/build.sh

FROM layer-45 AS layer-50-soxr

RUN --mount=type=cache,target=/root/.cache `
	--mount=type=bind,source=stages/50-soxr.sh,target=/srv/stage.sh `
	--mount=type=bind,source=patches/50-soxr,target="${PREFIX}/patches" `
	/srv/build.sh

FROM layer-45 AS layer-50-svt-av1

RUN --mount=type=cache,target=/root/.cache `
	--mount=type=bind,source=stages/50-svt-av1.sh,target=/srv/stage.sh `
	/srv/build.sh

FROM layer-45 AS layer-50-theora

RUN --mount=type=cache,target=/root/.cache `
	--mount=type=bind,source=stages/50-theora.sh,target=/srv/stage.sh `
	/srv/build.sh

FROM layer-45 AS layer-50-vpx

RUN --mount=type=cache,target=/root/.cache `
	--mount=type=bind,source=stages/50-vpx.sh,target=/srv/stage.sh `
	/srv/build.sh

FROM layer-45 AS layer-50-vulkan

RUN --mount=type=cache,target=/root/.cache `
	--mount=type=bind,source=stages/50-vulkan/45-vulkan.sh,target=/srv/stage.sh `
	/srv/build.sh
RUN --mount=type=cache,target=/root/.cache `
	--mount=type=bind,source=stages/50-vulkan/50-shaderc.sh,target=/srv/stage.sh `
	/srv/build.sh
RUN --mount=type=cache,target=/root/.cache `
	--mount=type=bind,source=stages/50-vulkan/55-spirv-cross.sh,target=/srv/stage.sh `
	/srv/build.sh
RUN --mount=type=cache,target=/root/.cache `
	--mount=type=bind,source=stages/50-vulkan/60-placebo.sh,target=/srv/stage.sh `
	/srv/build.sh

FROM layer-45 AS layer-50-x264

RUN --mount=type=cache,target=/root/.cache `
	--mount=type=bind,source=stages/50-x264.sh,target=/srv/stage.sh `
	/srv/build.sh

FROM layer-45 AS layer-50-x265

RUN --mount=type=cache,target=/root/.cache `
	--mount=type=bind,source=stages/50-x265.sh,target=/srv/stage.sh `
	/srv/build.sh

FROM layer-45 AS layer-50-zimg

RUN --mount=type=cache,target=/root/.cache `
	--mount=type=bind,source=stages/50-zimg.sh,target=/srv/stage.sh `
	/srv/build.sh

FROM layer-45 AS layer-50

COPY --from=layer-50-amf "${PREFIX}/." "$PREFIX"
COPY --from=layer-50-nvenc "${PREFIX}/." "$PREFIX"
COPY --from=layer-50-lame "${PREFIX}/." "$PREFIX"
COPY --from=layer-50-onevpl "${PREFIX}/." "$PREFIX"
COPY --from=layer-50-opus "${PREFIX}/." "$PREFIX"
COPY --from=layer-50-soxr "${PREFIX}/." "$PREFIX"
COPY --from=layer-50-svt-av1 "${PREFIX}/." "$PREFIX"
COPY --from=layer-50-theora "${PREFIX}/." "$PREFIX"
COPY --from=layer-50-vpx "${PREFIX}/." "$PREFIX"
COPY --from=layer-50-vulkan "${PREFIX}/." "$PREFIX"
COPY --from=layer-50-x264 "${PREFIX}/." "$PREFIX"
COPY --from=layer-50-x265 "${PREFIX}/." "$PREFIX"
COPY --from=layer-50-zimg "${PREFIX}/." "$PREFIX"

#--

FROM layer-00 AS layer-99-protoc

ADD https://raw.githubusercontent.com/protocolbuffers/protobuf/v25.0/LICENSE '/srv/protoc/LICENSE'

RUN --mount=type=cache,target=/root/.cache `
	--mount=type=bind,source=stages/99-protoc.sh,target=/srv/stage.sh `
	/srv/build.sh

FROM layer-00 AS layer-99-pdfium

RUN --mount=type=cache,target=/root/.cache `
	--mount=type=bind,source=stages/99-pdfium.sh,target=/srv/stage.sh `
	/srv/build.sh

FROM layer-00 AS layer-99-yolo

RUN --mount=type=cache,target=/root/.cache `
	--mount=type=bind,source=stages/99-yolov8.sh,target=/srv/stage.sh `
	/srv/build.sh

FROM layer-20 AS layer-99-onnx

RUN --mount=type=cache,target=/root/.cache `
	--mount=type=bind,source=stages/99-onnx.sh,target=/srv/stage.sh `
	/srv/build.sh

FROM layer-50 AS layer-99-ffmpeg

RUN --mount=type=cache,target=/root/.cache `
	--mount=type=bind,source=stages/99-ffmpeg.sh,target=/srv/stage.sh `
	/srv/build.sh

FROM layer-45 AS layer-99-heif

COPY --from=layer-99-ffmpeg "${OUT}/." "$PREFIX"

RUN --mount=type=cache,target=/root/.cache `
	--mount=type=bind,source=stages/99-heif.sh,target=/srv/stage.sh `
	/srv/build.sh

FROM layer-00 AS layer-99

COPY --from=layer-99-heif "${OUT}/." "$OUT"
COPY --from=layer-99-heif "${PREFIX}/srv/." "${OUT}/srv"
COPY --from=layer-99-heif "${PREFIX}/licenses/." "${OUT}/licenses"

COPY --from=layer-99-protoc "${OUT}/." "$OUT"
COPY --from=layer-99-protoc "${PREFIX}/licenses/." "${OUT}/licenses"

COPY --from=layer-99-pdfium "${OUT}/." "$OUT"
COPY --from=layer-99-pdfium "${PREFIX}/licenses/." "${OUT}/licenses"

COPY --from=layer-99-yolo "${OUT}/." "$OUT"

COPY --from=layer-99-onnx "${OUT}/." "$OUT"
COPY --from=layer-99-onnx "${PREFIX}/srv/." "${OUT}/srv"
COPY --from=layer-99-onnx "${PREFIX}/licenses/." "${OUT}/licenses"

COPY --from=layer-99-ffmpeg "${OUT}/." "$OUT"
COPY --from=layer-99-ffmpeg "${PREFIX}/srv/." "${OUT}/srv"
COPY --from=layer-99-ffmpeg "${PREFIX}/licenses/." "${OUT}/licenses"

# Remove build only files from output
RUN rm -rf "${OUT}/share" "${OUT}/lib/pkgconfig" "${OUT}/lib/cmake"
RUN find "${OUT}"  \( -name '*.def' -o -name '*.dll.a' \) -delete

# Move .lib files to the lib folder (Windows target only)
RUN if [ -d "${OUT}/bin" ]; then find "${OUT}/bin" -name '*.lib' -exec install -Dt ../lib/ -m a-rwx,u+rw,g+r,o+r {} + ; fi

# Copy .lib to .dll.a (Windows target only)
RUN find "$OUT/lib" -name '*.lib' -exec `
	sh -euxc 'for _file in "$@"; do cp "$_file" "$(dirname "$_file")/lib$(basename "$_file" .lib).dll.a"; done' sh {} +

# Strip debug symbols and ensure any .so, .dll, .dylib has the execution flag set
# Strip must run before patchelf
# https://github.com/NixOS/patchelf/issues/507
RUN --mount=type=cache,target=/root/.cache `
	echo 'strip -S "$@" && chmod +x "$@"' >/srv/stage.sh `
	&& find "$OUT" -type f \( -name '*.so' -o -name '*.so.*' -o -name '*.dll' -o -name '*.dylib' \) -exec /srv/build.sh {} +

# Ensure all .so files have the correct rpaths (Linux target only)
RUN find "$OUT" -type f \( -name '*.so' -o -name '*.so.*' \) -exec patchelf --set-rpath '$ORIGIN' {} \;

# Remove non executable files from bin folder
RUN if [ -d "${OUT}/bin" ]; then find "${OUT}/bin" -type f -not -executable -delete; fi

# Remove empty directories
RUN find "$OUT" -type d -delete 2>/dev/null || true

# Ensure correct file permissions
RUN find "${OUT}" -type f -exec chmod u+rw,g+r,g-w,o+r,o-w {} +

# Create macOS Frameworks from the built libs (Darwin target only)
ARG VERSION
ENV VERSION="${VERSION:-0.0.0}"
RUN --mount=type=cache,target=/root/.cache `
	--mount=type=bind,source=scripts/create-framework.sh,target=/srv/stage.sh `
	/srv/build.sh

# Compress source code backup of the built libraries
RUN cd "${OUT}/srv" && env XZ_OPT='-T0 -7' bsdtar -cJf ../src.tar.xz *
RUN rm -rf "${OUT}/srv"

#--

FROM scratch

ARG OUT

COPY --from=layer-99 "${OUT:?}/." /out
