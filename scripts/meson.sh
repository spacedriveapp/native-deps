#!/usr/bin/env bash

set -xeuo pipefail

exec /opt/sysroot/bin/meson setup \
  --prefix="${PREFIX:?Prefix must be defined}" \
  --buildtype=minsize \
  --wrap-mode=nofallback \
  --cross-file=/srv/cross.meson \
  --default-library="${SHARED:-static}" \
  -Db_lto="$([ "${LTO:-1}" -eq 1 ] && echo true || echo false)" \
  -Db_staticpic=true \
  -Db_pie=true \
  "$@"
