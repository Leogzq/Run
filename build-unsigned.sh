#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build
archive="$(mktemp -d "${TMPDIR:-/tmp}/routelab.XXXXXXXX")"
trap 'rm -rf "$archive"' EXIT
xcodebuild -version
xcodebuild -project RouteLab.xcodeproj -scheme RouteLab -configuration Release \
  -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath "$archive/DerivedData" CODE_SIGNING_ALLOWED=NO build
app="$archive/DerivedData/Build/Products/Release-iphoneos/RouteLab.app"
test -s "$app/RouteLab"
plutil -lint "$app/Info.plist"
mkdir -p "$archive/Payload"
ditto "$app" "$archive/Payload/RouteLab.app"
(cd "$archive" && zip -q -r RouteLab-unsigned.ipa Payload)
unzip -tq "$archive/RouteLab-unsigned.ipa"
mv -f "$archive/RouteLab-unsigned.ipa" build/
