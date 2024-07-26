#!/usr/bin/env -S bash -euo pipefail

if [ "$OS_IPHONE" -ge 1 ]; then
  export UNSUPPORTED=1
  exit 1
fi

echo "Download pdfium..."
mkdir -p pdfium

# renovate: datasource=github-releases depName=bblanchon/pdfium-binaries versioning=semver-coerced
_tag='6611'
case "$TARGET" in
  x86_64-windows*)
    _name='win-x64'
    ;;
  aarch64-windows*)
    _name='win-arm64'
    ;;
  x86_64-linux-gnu)
    _name='linux-x64'
    ;;
  aarch64-linux-gnu)
    _name='linux-arm64'
    ;;
  x86_64-linux-musl)
    _name='linux-musl-x64'
    ;;
  aarch64-linux-musl)
    _name='linux-musl-arm64'
    ;;
  x86_64-darwin*)
    if [ "$OS_IPHONE" -ge 1 ]; then
      _name='ios-x64'
    else
      _name='mac-x64'
    fi
    ;;
  aarch64-darwin*)
    if [ "$OS_IPHONE" -ge 1 ]; then
      _name='ios-arm64'
    else
      _name='mac-arm64'
    fi
    ;;
esac

curl_tar "https://github.com/bblanchon/pdfium-binaries/releases/download/chromium/${_tag}/pdfium-${_name}.tgz" pdfium

# No src to backup here because we are downloading pre-compiled binaries

cd pdfium

# Install
mkdir -p "$OUT"/{bin,lib,include}
case "$TARGET" in
  *windows*)
    mv bin/* "${OUT}/bin"
    mv lib/pdfium.dll.lib lib/pdfium.lib
    ;;
esac
mv lib/* "${OUT}/lib/"
mv include "${OUT}/include/libpdfium"
