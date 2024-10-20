#!/usr/bin/env bash

set -euo pipefail

if ! { [ "$#" -gt 1 ] && [ -n "$1" ] && [ -n "$2" ]; }; then
  echo "Usage: $0 <URL> <DIR NAME> <STRIP>" >&2
  exit 1
fi

if [ -e "$2" ] && ! [ -d "$2" ]; then
  echo "<DIR NAME> must be a valid directory path" >&2
  exit 1
fi

case "${3:-}" in
  '')
    set -- "$1" "$2" 0
    ;;
  *[0-9]*) ;;
  *)
    echo "<STRIP> must be a valid number" >&2
    exit 1
    ;;
esac

mkdir -p "$2"

_url="$1"
_cache="/root/.cache/_curl_tar/$(md5sum - <<<"$_url" | awk '{ print $1 }')"

mkdir -p "$(dirname "$_cache")"

if ! [ -s "$_cache" ]; then
  curl --proto '=https' --tlsv1.2 --ciphers "${CIPHERSUITES:?Missing curl ciphersuite}" --silent --show-error --fail --location "$_url" >"$_cache"
fi

trap 'rm -rf "$_cache"' ERR

if [ "$3" -eq 0 ]; then
  if [ -n "${4:-}" ]; then
    set -- -C "$2" "${4:-}"
  else
    set -- -C "$2"
  fi
else
  if [ -n "${4:-}" ]; then
    set -- --strip-component="$3" -C "$2" "${4:-}"
  else
    set -- --strip-component="$3" -C "$2"
  fi
fi

bsdtar -xf "$_cache" --no-acls --no-xattrs --no-same-owner --no-mac-metadata --no-same-permissions "$@"
