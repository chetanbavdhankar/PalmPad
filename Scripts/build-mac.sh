#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_root="$project_root/.build/mac"
app_path="$project_root/Build/PalmPad Mac.app"
xcodebuild -project "$project_root/PalmPad.xcodeproj" -scheme PalmPadMac \
  -configuration Release -derivedDataPath "$build_root" CODE_SIGNING_ALLOWED=NO build
mkdir -p "$project_root/Build"
ditto "$build_root/Build/Products/Release/PalmPad Mac.app" "$app_path"
codesign --force --sign - --identifier com.palmpad.mac "$app_path"
codesign --verify --deep --strict "$app_path"
printf 'Built: %s\n' "$app_path"
