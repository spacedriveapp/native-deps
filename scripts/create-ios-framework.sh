#!/usr/bin/env bash

set -xeuo pipefail

case "$TARGET" in
  *darwin*)
    if [ "$OS_IPHONE" -eq 0 ]; then
      echo "macOS target uses another framework structure" >&2
      exit 0
    fi
    ;;
  *)
    echo "Framework creation is only for iOS" >&2
    exit 0
    ;;
esac

if [ -z "${VERSION:-}" ]; then
  VERSION="0.0.0"
fi

while IFS= read -r _lib; do
  _lib_name="$(basename "$_lib" | awk -F'.' '{print $1}' | sed -e 's/^lib//')"
  _framework="${OUT}/lib${_lib_name}.framework"

  mkdir -p "${_framework}"

  # Create universal single-arch library
  lipo -create "$_lib" -output "${_framework}/lib${_lib_name}"

  # Loop through each of the library's dependencies
  for _dep in $(otool -L "${_framework}/lib${_lib_name}" | tail -n+3 | awk '{print $1}'); do
    case "$_dep" in
      "${OUT}/lib/"*) # One of our built libraries
        # Change the dependency linker path so it loads it from the same directory as the library
        _dep_name="$(basename "$_dep" | awk -F'.' '{print $1}' | sed -e 's/^lib//')"
        install_name_tool -change "$_dep" "@rpath/lib${_dep_name}.framework/lib${_dep_name}" "${_framework}/lib${_lib_name}"
        ;;
      *) # Ignore system libraries
        continue
        ;;
    esac
  done

  # Update the library's own id
  if ! install_name_tool -id "@rpath/lib${_lib_name}.framework/lib${_lib_name}" "${_framework}/lib${_lib_name}"; then
    # Some libraries have a header pad too small, so use a relative path instead
    install_name_tool -id "./lib${_lib_name}" "$_lib"
  fi

  # Copy library headers to Framework
  mkdir -p "${_framework}/Headers"
  if [ -d "${OUT}/include/${_lib_name}" ]; then
    cp -r "${OUT}/include/${_lib_name}" "${_framework}/Headers/${_lib_name}"
  elif [ -d "${OUT}/include/lib${_lib_name}" ]; then
    cp -r "${OUT}/include/lib${_lib_name}" "${_framework}/Headers/lib${_lib_name}"
  fi

  # Create Info.plist
  cat <<EOF >"${_framework}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>lib${_lib_name}</string>
  <key>CFBundleIdentifier</key>
  <string>com.spacedrive.Lib${_lib_name}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>lib${_lib_name}</string>
  <key>CFBundlePackageType</key>
  <string>FMWK</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${VERSION}</string>
  <key>CFBundleSignature</key>
  <string>????</string>
  <key>MinimumOSVersion</key>
  <string>14.0</string>
  <key>CFBundleSupportedPlatforms</key>
  <array>
    <string>iPhoneOS</string>
  </array>
  <key>NSPrincipalClass</key>
  <string></string>
  <key>NSHumanReadableCopyright</key>
  <string>Copyright (c) 2021-present Spacedrive Technology Inc.</string>
</dict>
</plist>
EOF

  touch "${_framework}/LICENSE"
  for _file in "${PREFIX}/licenses/"*; do
    {
      echo "License for $(basename "$_file" | sed -e 's/\.[^.]*$//')"
      cat "$_file"
      printf "======================\n\n"
    } >>"${_framework}/LICENSE"
  done
done < <(find "${OUT}/lib" -type f -name '*.dylib')
