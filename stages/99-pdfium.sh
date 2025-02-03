#!/usr/bin/env -S bash -euo pipefail

echo "Download pdfium..."
mkdir -p pdfium

# renovate: datasource=github-releases depName=bblanchon/pdfium-binaries versioning=semver-coerced
_tag='6996'
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
  x86_64-linux-android)
    _name='android-x64'
    ;;
  aarch64-linux-android)
    _name='android-arm64'
    ;;
  x86_64-darwin*)
    if [ "$OS_IPHONE" -eq 0 ]; then
      _name='mac-x64'
    elif [ "$OS_IPHONE" -eq 1 ]; then
      echo "There is no libpdfium pre-built for iOS x64" >&2
      export UNSUPPORTED=1
      exit 1
    else
      _name='ios-simulator-x64'
    fi
    ;;
  aarch64-darwin*)
    if [ "$OS_IPHONE" -eq 0 ]; then
      _name='mac-arm64'
    elif [ "$OS_IPHONE" -eq 1 ]; then
      _name='ios-device-arm64'
    else
      echo "There is no libpdfium pre-built for iOS simulator arm64" >&2
      export UNSUPPORTED=1
      exit 1
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
