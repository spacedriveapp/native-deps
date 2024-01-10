#!/usr/bin/env -S bash -euo pipefail

case "$TARGET" in
  *linux-gnu)
    ;;
  *)
    export UNSUPPORTED=1
    exit 1
    ;;
esac

echo "Download gcompat..."
mkdir -p gcompat

cd gcompat
curl -JO 'https://gitlab.alpinelinux.org/api/v4/projects/5/packages/generic/v2.14.0/x86_64/apk.static'

chmod +x apk.static

./apk.static \
  --arch "${TARGET%%-*}" \
  -X 'http://dl-cdn.alpinelinux.org/alpine/edge/main/' \
  -U --allow-untrusted --root "$(pwd)" --initdb \
  add gcompat

# Remove unused components
find . -type d -name 'apk' -exec rm -r {} +
find . -name '*.so*' -not -wholename './lib/*' -exec mv -n -t lib {} + || true
rm -r lib64 usr/lib apk.static
find . -empty -type d -delete

# Adjust rpath to use $ORIGIN
find lib -type f -name '*.so*' -exec patchelf --set-rpath "\$ORIGIN" {} \;

# Remove musl and ld-musl, as that is always included by the OS
rm lib/ld-musl-x86_64.so.1 lib/libc.musl-x86_64.so.1
# Copy gcompat and it's dependencies to the output directory
mv "lib" "${OUT}/gcompat"
