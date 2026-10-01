#!/usr/bin/env bash
# Local ad-hoc build only: never quits, installs over, or launches another app.
set -euo pipefail
trap 'echo "Fork build failed at line $LINENO: $BASH_COMMAND" >&2' ERR
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
APP="$PWD/dist/MetaWhisp-Fork.app"
if [ -e "$APP" ]; then
    echo "Refusing to overwrite $APP; move the previous artifact before rebuilding." >&2
    exit 1
fi
swift package resolve
bash scripts/prepare-fork-dependencies.sh
swift build -c release
BUILD_DIR="$(swift build -c release --show-bin-path)"
CONTENTS="$APP/Contents"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources" "$CONTENTS/Frameworks"
cp "$BUILD_DIR/MetaWhisp" "$CONTENTS/MacOS/MetaWhisp"
cp Resources/Info.plist "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleDisplayName MetaWhisp Fork' "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleName MetaWhisp Fork' "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :MetaWhispDisableUpdates bool true' "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :SUEnableAutomaticChecks false' "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c 'Delete :SUFeedURL' "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c 'Delete :SUPublicEDKey' "$CONTENTS/Info.plist"
cp Resources/AppIcon.icns "$CONTENTS/Resources/"
cp LICENSE "$CONTENTS/Resources/MetaWhisp-LICENSE.txt"
cp Resources/AppIcon.png Resources/mw_menubar.png Resources/mw_menubar@2x.png "$CONTENTS/Resources/"
ditto Resources/Sounds "$CONTENTS/Resources/Sounds"
cp Resources/shrek-pill.mov "$CONTENTS/Resources/"
# The checked-in dependency patch uses the standard, code-signed resource path.
ditto "$BUILD_DIR/swift-transformers_Hub.bundle" "$CONTENTS/Resources/swift-transformers_Hub.bundle"
ditto "$BUILD_DIR/Sparkle.framework" "$CONTENTS/Frameworks/Sparkle.framework"
install_name_tool -add_rpath '@executable_path/../Frameworks' "$CONTENTS/MacOS/MetaWhisp"

# SPM does not compile mlx-swift's runtime Metal library. Keep the generated
# intermediates in .build for diagnosis; only the linked library is shipped.
METAL_SOURCE="$PWD/.build/checkouts/mlx-swift/Source/Cmlx/mlx-generated/metal"
METAL_BUILD="$(mktemp -d "$PWD/.build/fork-metal.XXXXXX")"
for source in "$METAL_SOURCE"/*.metal; do
    name="$(basename "${source%.metal}")"
    xcrun -sdk macosx metal -c "$source" -I "$METAL_SOURCE" -o "$METAL_BUILD/$name.air"
done
xcrun -sdk macosx metallib "$METAL_BUILD"/*.air -o "$CONTENTS/MacOS/mlx.metallib"
chmod -R u+w "$APP"
xattr -cr "$APP"
codesign --force --sign - "$CONTENTS/MacOS/mlx.metallib"
codesign --force --sign - --identifier com.metawhisp.app \
    --entitlements Resources/MetaWhisp.entitlements "$APP"
bash scripts/verify-fork-bundle.sh "$APP"
echo "Built $APP (ad-hoc signed, not notarized, not installed)."
