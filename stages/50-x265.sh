#!/usr/bin/env -S bash -euo pipefail

echo "Download x265..."
mkdir -p x265

# renovate: depName=https://bitbucket.org/multicoreware/x265_git.git
_commit='f3c5fbaffaf54b5f79aa8983d59f1b0232d5eccf'

# Need to use master, because the latest release doesn't support optmized aarch64 and it is from 2021
curl_tar "https://bitbucket.org/multicoreware/x265_git/get/${_commit}.tar.bz2" x265 1

# Remove some superfluous files
rm -rf x265/{doc,build}

# Handbreak patches
for patch in \
  'https://github.com/HandBrake/HandBrake/raw/9c9cf41/contrib/x265/A03-sei-length-crash-fix.patch' \
  'https://github.com/HandBrake/HandBrake/raw/9c9cf41/contrib/x265/A05-memory-leaks.patch'; do
  curl "$patch" | patch -F5 -lp1 -d x265 -t
done

# Backup source
bak_src 'x265'

cd x265

# Force cmake to use x265Version.txt instead of querying git or hg
sed -i '/set(X265_TAG_DISTANCE/a set(GIT_ARCHETYPE "1")' source/cmake/Version.cmake

echo "Build x265..."

common_config=(
  -DENABLE_PIC=On
  -DENABLE_ASSEMBLY=On
  -DENABLE_CLI=Off
  -DENABLE_TESTS=Off
  -DENABLE_SHARED=Off
  -DENABLE_SVT_HEVC=Off
  -DCMAKE_ASM_NASM_FLAGS=-w-macro-params-legacy
)

mkdir 8bit 10bit 12bit

cmake -S source -B 12bit \
  "${common_config[@]}" \
  -DMAIN12=On \
  -DEXPORT_C_API=Off \
  -DHIGH_BIT_DEPTH=On

ninja -C 12bit -j"$(nproc)"

cmake -S source -B 10bit \
  "${common_config[@]}" \
  -DEXPORT_C_API=Off \
  -DHIGH_BIT_DEPTH=On

ninja -C 10bit -j"$(nproc)"

cmake -S source -B 8bit \
  "${common_config[@]}" \
  -DEXTRA_LIB='x265_main10.a;x265_main12.a' \
  -DLINKED_10BIT=On \
  -DLINKED_12BIT=On \
  -DEXTRA_LINK_FLAGS=-L. \
  -DENABLE_HDR10_PLUS=On

ninja -C 8bit -j"$(nproc)"

cd 8bit

# Combine all three into libx265.a
ln -s ../12bit/libx265.a libx265_main12.a
ln -s ../10bit/libx265.a libx265_main10.a
mv libx265.a libx265_main.a

# Must use llvm ar due to mri-script
llvm-ar-16 -M <<EOF
CREATE libx265.a
ADDLIB libx265_main.a
ADDLIB libx265_main10.a
ADDLIB libx265_main12.a
SAVE
END
EOF

ninja install

sed -ri 's/^(Libs.private:.*)$/\1 -lstdc++/' "${PREFIX}/lib/pkgconfig/x265.pc"
