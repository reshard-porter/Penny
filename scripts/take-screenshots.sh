#!/usr/bin/env bash
# Captures App Store–style screenshots of every main screen in the iOS Simulator.
# Usage: scripts/take-screenshots.sh <simulator-udid> <path/to/Penny.app> [output-dir]
set -euo pipefail

UDID="$1"
APP="$2"
OUT="${3:-docs/screenshots}"
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist")
mkdir -p "$OUT"

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b
xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 \
  --cellularMode active --cellularBars 4 --wifiBars 3 --dataNetwork wifi || true
xcrun simctl install "$UDID" "$APP"

shoot() {
  local name="$1"; shift
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl launch "$UDID" "$BUNDLE_ID" -PennyScreenshotMode YES "$@" >/dev/null
  sleep 7
  xcrun simctl io "$UDID" screenshot --type=png "$OUT/$name.png" >/dev/null
  echo "Saved $OUT/$name.png"
}

for appearance in light dark; do
  xcrun simctl ui "$UDID" appearance "$appearance"
  shoot "$appearance-1-overview" -PennyStartTab 0
  shoot "$appearance-1b-overview-more" -PennyStartTab 0 -PennyScroll more
  shoot "$appearance-1c-overview-end" -PennyStartTab 0 -PennyScroll end
  shoot "$appearance-2-activity" -PennyStartTab 1
  shoot "$appearance-3-budgets" -PennyStartTab 2 -PennyPlanSegment budgets
  shoot "$appearance-4-goals" -PennyStartTab 2 -PennyPlanSegment goals
  shoot "$appearance-5-insights" -PennyStartTab 3
  shoot "$appearance-5b-insights-more" -PennyStartTab 3 -PennyScroll more
  shoot "$appearance-5c-insights-end" -PennyStartTab 3 -PennyScroll end
  shoot "$appearance-6-settings" -PennyStartTab 4
  shoot "$appearance-7-add" -PennyStartTab 0 -PennyOpenEditor YES
  shoot "$appearance-8-onboarding" -PennyShowOnboarding YES
done
xcrun simctl ui "$UDID" appearance light
