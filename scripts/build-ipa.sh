#!/bin/bash
set -euo pipefail

if [[ "${1:-}" == "--help" ]]; then
  echo "Usage: bash scripts/build-ipa.sh [output-directory]"
  echo "Builds Penny-unsigned.ipa on macOS with Xcode 16 or newer."
  echo "The resulting IPA must be signed before installation."
  exit 0
fi

if [[ $# -gt 1 ]]; then
  echo "Usage: bash scripts/build-ipa.sh [output-directory]" >&2
  exit 2
fi

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This build requires macOS and Xcode with the iOS SDK." >&2
  exit 1
fi

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
project_path="$project_dir/Penny.xcodeproj"

if [[ ! -d "$project_path" ]]; then
  echo "Penny.xcodeproj was not found beside the scripts directory." >&2
  exit 1
fi

if ! xcrun --sdk iphoneos --show-sdk-path >/dev/null 2>&1; then
  echo "Install full Xcode and select it with Xcode > Settings > Locations > Command Line Tools." >&2
  exit 1
fi

xcode_version="$(xcodebuild -version | awk '/^Xcode / { print $2; exit }')"
xcode_major="${xcode_version%%.*}"
if [[ ! "$xcode_major" =~ ^[0-9]+$ ]] || (( xcode_major < 16 )); then
  echo "Penny requires Xcode 16 or newer; selected version: $xcode_version" >&2
  exit 1
fi

output_dir="${1:-$project_dir/build/ipa}"
mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd)"
work_dir="$(mktemp -d "${TMPDIR:-/tmp}/penny-ipa.XXXXXX")"
trap 'rm -rf -- "$work_dir"' EXIT

echo "Archiving Penny for physical iOS devices using Xcode $xcode_version..."
xcodebuild \
  -project "$project_path" \
  -scheme Penny \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -archivePath "$work_dir/Penny.xcarchive" \
  -derivedDataPath "$work_dir/DerivedData" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY= \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=NO \
  archive 2>&1 | tee "$output_dir/build.log"

app_path="$work_dir/Penny.xcarchive/Products/Applications/Penny.app"
if [[ ! -d "$app_path" ]]; then
  echo "The archive did not contain Penny.app. See $output_dir/build.log." >&2
  exit 1
fi

executable="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$app_path/Info.plist")"
platform="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleSupportedPlatforms:0' "$app_path/Info.plist")"
if [[ "$platform" != "iPhoneOS" ]]; then
  echo "The archive is not a physical-device iOS build (platform: $platform)." >&2
  exit 1
fi
xcrun lipo -verify_arch arm64 "$app_path/$executable"

mkdir -p "$work_dir/package/Payload"
/usr/bin/ditto --norsrc --noextattr "$app_path" "$work_dir/package/Payload/Penny.app"
/usr/bin/ditto -c -k --norsrc --noextattr --keepParent \
  "$work_dir/package/Payload" "$work_dir/Penny-unsigned.ipa"
/usr/bin/unzip -tq "$work_dir/Penny-unsigned.ipa"
mv -f "$work_dir/Penny-unsigned.ipa" "$output_dir/Penny-unsigned.ipa"

echo "Created: $output_dir/Penny-unsigned.ipa"
echo "This IPA is unsigned. Sign it before installing it on an iPhone or iPad."
