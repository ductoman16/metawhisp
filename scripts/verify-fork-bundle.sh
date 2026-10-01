#!/usr/bin/env bash
set -euo pipefail
trap 'echo "Fork verification failed at line $LINENO: $BASH_COMMAND" >&2' ERR

APP="${1:?Usage: bash scripts/verify-fork-bundle.sh /path/to/MetaWhisp-Fork.app}"
PLIST="$APP/Contents/Info.plist"
test -x "$APP/Contents/MacOS/MetaWhisp"
test -s "$APP/Contents/MacOS/mlx.metallib"
test -s "$APP/Contents/Resources/AppIcon.icns"
test -s "$APP/Contents/Resources/shrek-pill.mov"
test -s "$APP/Contents/Resources/swift-transformers_Hub.bundle/gpt2_tokenizer_config.json"
test -d "$APP/Contents/Frameworks/Sparkle.framework"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$PLIST")" = com.metawhisp.app
test "$(/usr/libexec/PlistBuddy -c 'Print :MetaWhispDisableUpdates' "$PLIST")" = true
test "$(/usr/libexec/PlistBuddy -c 'Print :SUEnableAutomaticChecks' "$PLIST")" = false
if /usr/libexec/PlistBuddy -c 'Print :SUFeedURL' "$PLIST" >/dev/null 2>&1; then
    echo 'FAIL: fork must not contain the upstream update feed' >&2
    exit 1
fi
otool -l "$APP/Contents/MacOS/MetaWhisp" | grep -F '@executable_path/../Frameworks'
codesign --verify --deep --strict --verbose=2 "$APP"
echo 'PASS: fork bundle resources, update isolation, and signatures'
