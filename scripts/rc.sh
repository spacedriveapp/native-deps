#!/usr/bin/env bash

set -euo pipefail

case "${TARGET:?TARGET envvar is required to be defined}" in
  *windows-gnu)
    _win_include="${SYSROOT:?SYSROOT envvar is required to be defined}/lib/libc/include/any-windows-any"
    ;;
  *)
    echo "Only valid on windows targets" >&2
    exit 1
    ;;
esac

_name="$(basename "$0")"
case "$_name" in
  rc)
    # Work-around meson not recognising able to find llvm-rc
    if [ "$1" = '/?' ]; then
      echo 'LLVM Resource Converter'
    fi

    set -- /D __GNUC__ /I "$_win_include" "$@"
    ;;
  windres)
    set -- --define=__GNUC__ --include-dir="$_win_include" "$@"
    ;;
  *)
    echo "Script name must be rc or windres" >&2
    exit 1
    ;;
esac

exec "/usr/bin/llvm-${_name}-16" "$@"
