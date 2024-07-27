#!/usr/bin/env -S bash -euo pipefail

# OpenCL is only available on iOS through a private framework
if [ "$OS_IPHONE" -ge 1 ]; then
  export UNSUPPORTED=1
  exit 1
fi

echo "Download opencl headers..."

mkdir -p opencl-headers

curl_tar 'https://github.com/KhronosGroup/OpenCL-Headers/archive/refs/tags/v2023.12.14.tar.gz' opencl-headers 1

# Remove some superfluous files
rm -rf opencl-headers/{.github,tests}

# Backup source
bak_src 'opencl-headers'

# Install
mkdir -p "${PREFIX}/include"
mv 'opencl-headers/CL' "${PREFIX}/include/"
