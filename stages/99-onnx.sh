#!/usr/bin/env -S bash -euo pipefail

echo "Download onnx..."
mkdir -p onnx

# renovate: datasource=github-releases depName=microsoft/onnxruntime
_tag='1.17.3'

case "$TARGET" in
  *windows*)
    # We just download the MS pre-compiled binaries which include the DirectML backend and are most likely better optimized than what we can build
    curl_tar "https://www.nuget.org/api/v2/package/Microsoft.ML.OnnxRuntime.DirectML/${_tag}" onnx 0

    mkdir -p "$OUT"/{bin,lib,include}

    mv onnx/build/native/include "${OUT}/include/onnxruntime"

    case "${TARGET%%-*}" in
      x86_64)
        cd onnx/runtimes/win-x64/native
        ;;
      aarch64)
        cd onnx/runtimes/win-arm64/native
        ;;
    esac

    mv onnxruntime.dll "${OUT}/bin/"
    mv onnxruntime.lib "${OUT}/lib/"

    exit 0
    ;;
esac

curl_tar "https://github.com/microsoft/onnxruntime/archive/refs/tags/v${_tag}.tar.gz" onnx 1

# Patch to only include execinfo.h on supported environments
sed -i 's/defined(__ANDROID__)/defined(__ANDROID__) \&\& (defined(__APPLE__) || defined(__GLIBC__) || defined(PLATFORM_IS_BSD))/g' onnx/onnxruntime/core/platform/posix/stacktrace.cc

# Remove unused components
rm -r onnx/{.*,requirements*.txt,*.py,cgmanifests,dockerfiles,objectivec,*.png,rust,samples,java,docs,orttraining,js,csharp,winml,onnxruntime/{wasm,test,tool,python,core/flatbuffers/ort_flatbuffers_py,contrib_ops/{js,rocm,cuda}}}

# Backup source
bak_src 'onnx'

mkdir -p onnx/build
cd onnx/build

echo "Build onnx..."

# Enable caching cmake downloaded deps
mkdir -p "/root/.cache/onnx_deps/${TARGET}"
ln -sf "/root/.cache/onnx_deps/${TARGET}" _deps

args=(
  -DCMAKE_TLS_VERIFY=On
  -DBUILD_PKGCONFIG_FILES=Off
  -Donnxruntime_USE_XNNPACK=On
  -Donnxruntime_BUILD_SHARED_LIB=On
  -Donnxruntime_CROSS_COMPILING=On
  -Donnxruntime_ENABLE_LTO="$([ "${LTO:-1}" -eq 1 ] && echo On || echo Off)"
  -DONNX_CUSTOM_PROTOC_EXECUTABLE=/usr/bin/protoc
  -DPython_EXECUTABLE=/usr/bin/python3
  -DPYTHON_EXECUTABLE=/usr/bin/python3
  -Donnxruntime_RUN_ONNX_TESTS=Off
  -Donnxruntime_USE_MPI=Off
  -Donnxruntime_USE_TELEMETRY=Off
  -DOnnxruntime_GCOV_COVERAGE=Off
  -Donnxruntime_BUILD_MS_EXPERIMENTAL_OPS=Off
  -Donnxruntime_BUILD_JAVA=Off
  -Donnxruntime_BUILD_OBJC=Off
  -Donnxruntime_BUILD_UNIT_TESTS=Off
  -Donnxruntime_BUILD_NODEJS=Off
  -Donnxruntime_BUILD_CSHARP=Off
  -Donnxruntime_BUILD_BENCHMARKS=Off
  -Donnxruntime_BUILD_APPLE_FRAMEWORK=Off
  -Donnxruntime_ENABLE_PYTHON=Off
  -Donnxruntime_ENABLE_MEMORY_PROFILE=Off
  -Donnxruntime_ENABLE_TRAINING=Off
  -Donnxruntime_GENERATE_TEST_REPORTS=Off
  -DFETCHCONTENT_QUIET=Off
  -DNSYNC_ENABLE_TESTS=Off
  -Dprotobuf_BUILD_TESTS=Off
  -Dprotobuf_BUILD_PROTOBUF_BINARIES=Off
  -Dprotobuf_BUILD_PROTOC_BINARIES=Off
  -DFLATBUFFERS_BUILD_TESTS=Off
  -DFLATBUFFERS_INSTALL=Off
  -DFLATBUFFERS_BUILD_FLATC=Off
  -DCPUINFO_BUILD_TOOLS=Off
  -DCPUINFO_BUILD_UNIT_TESTS=Off
  -DCPUINFO_BUILD_MOCK_TESTS=Off
  -DCPUINFO_BUILD_BENCHMARKS=Off
  -DCPUINFO_BUILD_PKG_CONFIG=Off
  -DEIGEN_BUILD_PKGCONFIG=Off
)

case "$TARGET" in
  *darwin*)
    args+=(
      -Donnxruntime_USE_COREML=On
    )
    # Allow deprecated usage of ATOMIC_VAR_INIT by https://github.com/google/nsync
    export CXXFLAGS="${CXXFLAGS} -D_LIBCPP_DISABLE_DEPRECATION_WARNINGS"
    ;;
esac

# WARNING: Must not set Shared Library to On, or else it will fail to build. This is already handled above by onnx custom argument.
env PREFIX="$OUT" cmake "${args[@]}" ../cmake

case "$TARGET" in
  *linux*)
    # Fix google_nsync trying to compile C code as C++, which zig does not support
    sed -i 's/foreach (s IN ITEMS ${NSYNC_COMMON_SRC} ${NSYNC_OS_CPP_SRC})/foreach (s IN ITEMS ${NSYNC_COMMON_SRC} ${NSYNC_OS_CPP_SRC})\nget_filename_component(sle ${s} NAME_WLE)/g' _deps/google_nsync-src/CMakeLists.txt
    sed -i 's/cpp\/${s}/cpp\/${sle}.cc/g' _deps/google_nsync-src/CMakeLists.txt

    # Regenerate build files after cmake patches
    env PREFIX="$OUT" cmake "${args[@]}" ../cmake
    ;;
esac

ninja -j"$(nproc)"

ninja install
