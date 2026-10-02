#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
device="${1:-05935F76-8E02-4879-9251-9F3784FDAE80}"
app="/tmp/aiwardrobe-public/Build/Products/Debug-iphonesimulator/AIWardrobe.app"
xcrun simctl install "$device" "$app"
xcrun simctl ui "$device" appearance light
xcrun simctl ui "$device" content_size large
xcrun simctl status_bar "$device" override --time '9:41' --dataNetwork wifi --wifiMode active --wifiBars 3 --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
for language in en zh-Hans zh-Hant ja fr de es; do
  case "$language" in
    en) region=en_US;; zh-Hans) region=zh_CN;; zh-Hant) region=zh_TW;;
    ja) region=ja_JP;; fr) region=fr_FR;; de) region=de_DE;; es) region=es_ES;;
  esac
  mkdir -p "AppStore/Screenshots/$language"
  for tab in 0 1 2 3; do
    xcrun simctl terminate "$device" com.tinyworm.AIWardrobe.Public 2>/dev/null || true
    xcrun simctl launch "$device" com.tinyworm.AIWardrobe.Public -AppleLanguages "($language)" -AppleLocale "$region" -ui-tab "$tab"
    sleep 4
    xcrun simctl io "$device" screenshot "AppStore/Screenshots/$language/iphone-69-$tab.png"
    if [ "$(stat -f%z "AppStore/Screenshots/$language/iphone-69-$tab.png")" -lt 180000 ]; then
      sleep 5
      xcrun simctl io "$device" screenshot "AppStore/Screenshots/$language/iphone-69-$tab.png"
    fi
    test "$(stat -f%z "AppStore/Screenshots/$language/iphone-69-$tab.png")" -gt 180000
  done
done
xcrun simctl status_bar "$device" clear
