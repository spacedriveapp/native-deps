#!/usr/bin/env -S bash -euo pipefail

case "$TARGET" in
  *darwin*)
    export UNSUPPORTED=1
    exit 1
    ;;
esac

echo "Download shaderc..."
mkdir -p shaderc/third_party/{glslang,spirv-headers,spirv-tools}

# All the version for the main package and third-party deps must match what is here:
# https://github.com/google/shaderc/blob/known-good/known_good.json
curl_tar 'https://github.com/google/shaderc/archive/refs/tags/v2023.8.tar.gz' shaderc 1

sed -ie 's|#!/usr/bin/env python|#!/usr/bin/env python3|' shaderc/utils/update_build_version.py

# Thrid party deps
curl_tar 'https://github.com/KhronosGroup/glslang/archive/a91631b.tar.gz' shaderc/third_party/glslang 1
cp -a shaderc/third_party/glslang/LICENSE.txt shaderc/LICENSE.glslang

curl_tar 'https://github.com/KhronosGroup/SPIRV-Headers/archive/1c6bb27.tar.gz' shaderc/third_party/spirv-headers 1
cp -a shaderc/third_party/spirv-headers/LICENSE shaderc/LICENSE.spirv-headers

curl_tar 'https://github.com/KhronosGroup/SPIRV-Tools/archive/f0cc85e.tar.gz' shaderc/third_party/spirv-tools 1
cp -a shaderc/third_party/spirv-tools/LICENSE shaderc/LICENSE.spirv-tools

sed -i '/add_subdirectory(test)/d' shaderc/third_party/spirv-tools/CMakeLists.txt
sed -i '/add_subdirectory(tools)/d' shaderc/third_party/spirv-tools/CMakeLists.txt
sed -i '/add_subdirectory(examples)/d' shaderc/third_party/spirv-tools/CMakeLists.txt

# Remove some superfluous files
rm -rf shaderc/{.github,android_test,build_overrides,examples,kokoro}
rm -rf shaderc/third_party/glslang/{.github,Test,build_overrides,gtests,kokoro,ndk_test}
rm -rf shaderc/third_party/spirv-headers/{.github,tests,tools}
rm -rf shaderc/third_party/spirv-tools/{.github,android_test,build_overrides,docs,examples,kokoro,test,tools}

# Backup source
bak_src 'shaderc'

mkdir -p shaderc/build
cd shaderc/build

echo "Build shaderc..."
cmake \
  -DSPIRV_SKIP_TESTS=On \
  -DENABLE_EXCEPTIONS=On \
  -DSHADERC_SKIP_TESTS=On \
  -DSHADERC_SKIP_EXAMPLES=On \
  -DSPIRV_SKIP_EXECUTABLES=On \
  -DSPIRV_TOOLS_BUILD_STATIC=On \
  -DSHADERC_SKIP_COPYRIGHT_CHECK=On \
  -DENABLE_PCH=Off \
  -DBUILD_TESTS=Off \
  -DENABLE_CTEST=Off \
  -DBUILD_TESTING=Off \
  -DSPIRV_CHECK_CONTEXT=Off \
  -DENABLE_GLSLANG_BINARIES=Off \
  ..

ninja -j"$(nproc)"

ninja install

echo "Libs: -lstdc++" >>"${PREFIX}/lib/pkgconfig/shaderc_static.pc"
echo "Libs: -lstdc++" >>"${PREFIX}/lib/pkgconfig/shaderc_combined.pc"

# Ensure whomever links against shaderc uses the combined version,
# which is a static library containing libshaderc and all of its dependencies.
ln -sf shaderc_combined.pc "$PREFIX"/lib/pkgconfig/shaderc.pc
