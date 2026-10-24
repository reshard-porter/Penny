#!/usr/bin/env bash
# Builds a signed Penny.ipa on your Mac, ready to install on your iPhone.
#
#   scripts/make-signed-ipa.sh                 # auto-detects your team
#   scripts/make-signed-ipa.sh ABCDE12345      # or pass your Team ID
#   scripts/make-signed-ipa.sh ABCDE12345 com.yourname.penny --install
#
# Works with a free Apple ID (personal team) and with a paid developer account.
# Before the first run: open Penny.xcodeproj once, pick your Team under
# Signing & Capabilities, and run the app on your connected iPhone (⌘R) so
# Xcode registers the device and creates a provisioning profile.
#
# Output: build/Penny.ipa  (plus build/Penny.xcarchive)
# --install also installs it on the first connected iPhone (Xcode 15+).
set -euo pipefail
cd "$(dirname "$0")/.."

INSTALL=0
ARGS=()
for arg in "$@"; do
  if [ "$arg" = "--install" ]; then INSTALL=1; else ARGS+=("$arg"); fi
done
TEAM_ID="${ARGS[0]:-${TEAM_ID:-}}"
BUNDLE_ID="${ARGS[1]:-${BUNDLE_ID:-com.reshardporter.penny}}"

say() { printf '\033[1;32m▸ %s\033[0m\n' "$*"; }
fail() { printf '\033[1;31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

command -v xcodebuild >/dev/null || fail "Xcode isn't installed (or run: sudo xcode-select -s /Applications/Xcode.app)."

if [ -z "$TEAM_ID" ]; then
  # The Team ID is the OU field of your "Apple Development" certificate.
  TEAM_ID=$(security find-certificate -a -c "Apple Development" -p 2>/dev/null \
    | openssl x509 -noout -subject 2>/dev/null \
    | sed -nE 's/.*OU ?= ?([A-Z0-9]{10}).*/\1/p' | head -1 || true)
  [ -n "$TEAM_ID" ] || fail "Couldn't find your Team ID. Pass it: scripts/make-signed-ipa.sh YOURTEAMID
   (Xcode → Settings → Accounts → select your team, or developer.apple.com → Membership.)"
  say "Using team $TEAM_ID"
fi

# iCloud Drive/Finder attributes break code signing.
xattr -cr . 2>/dev/null || true
rm -rf build/Penny.xcarchive build/export build/Penny.ipa
mkdir -p build

say "Archiving Penny (Release) for iPhone…"
xcodebuild archive \
  -project Penny.xcodeproj -scheme Penny -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/Penny.xcarchive \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
  CODE_SIGN_STYLE=Automatic \
  | { command -v xcbeautify >/dev/null && xcbeautify || cat; }

APP=build/Penny.xcarchive/Products/Applications/Penny.app
[ -d "$APP" ] || fail "Archive failed — see the errors above."

export_with() {
  local method="$1"
  cat > build/ExportOptions.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>${method}</string>
  <key>teamID</key><string>${TEAM_ID}</string>
  <key>signingStyle</key><string>automatic</string>
  <key>compileBitcode</key><false/>
  <key>stripSwiftSymbols</key><true/>
  <key>thinning</key><string>&lt;none&gt;</string>
</dict>
</plist>
PLIST
  xcodebuild -exportArchive \
    -archivePath build/Penny.xcarchive \
    -exportOptionsPlist build/ExportOptions.plist \
    -exportPath build/export \
    -allowProvisioningUpdates >build/export.log 2>&1
}

say "Exporting signed IPA…"
if export_with debugging || export_with development; then
  mv build/export/*.ipa build/Penny.ipa
else
  # Free personal teams can't always use Xcode's export step. The archived app is
  # already signed with your development certificate and profile, so package it directly.
  say "Export step unavailable for this team; packaging the signed app from the archive instead."
  rm -rf build/ipa && mkdir -p build/ipa/Payload
  cp -R "$APP" build/ipa/Payload/
  (cd build/ipa && zip -qry ../Penny.ipa Payload)
fi

codesign --verify --deep --strict "$APP" && say "Signature verified."
codesign -dv "$APP" 2>&1 | grep -E "Authority=|TeamIdentifier=" | head -2 || true

if [ "$INSTALL" = 1 ]; then
  DEVICE=$(xcrun devicectl list devices 2>/dev/null | awk '/iPhone/ && /(available|connected)/ {for(i=1;i<=NF;i++) if ($i ~ /^[0-9A-F-]{25,}$/) {print $i; exit}}')
  [ -n "$DEVICE" ] || fail "No connected iPhone found. Plug it in, unlock it and trust this Mac."
  say "Installing on $DEVICE…"
  xcrun devicectl device install app --device "$DEVICE" "$APP"
fi

say "Done: $(pwd)/build/Penny.ipa"
echo "Install it with Finder (drag onto your iPhone), Apple Configurator, or:"
echo "  xcrun devicectl device install app --device <iPhone-id> build/Penny.ipa"
