#!/bin/bash
# Builds build/Deflow.app.
#   --install   copy to /Applications
#   --run       launch it
#   --release   sign with Developer ID + hardened runtime (what make-dmg.sh ships)
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=0.2.1
RELEASE=0
for arg in "$@"; do [ "$arg" = "--release" ] && RELEASE=1; done

swift build -c release
BIN="$(swift build -c release --show-bin-path)/Deflow"
APP=build/Deflow.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Deflow"

# App icon: the binary renders its own 1024px mark, then we cut the standard sizes.
ICONSET=build/AppIcon.iconset
rm -rf "$ICONSET" && mkdir -p "$ICONSET"
"$BIN" --render-icon "$PWD/build/icon-1024.png"
for size in 16 32 128 256 512; do
    sips -z $size $size build/icon-1024.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    sips -z $((size * 2)) $((size * 2)) build/icon-1024.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>dev.deflow.app</string>
    <key>CFBundleName</key><string>Deflow</string>
    <key>CFBundleDisplayName</key><string>Deflow</string>
    <key>CFBundleExecutable</key><string>Deflow</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$(date +%Y%m%d%H%M)</string>
    <key>LSMinimumSystemVersion</key><string>15.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

# A stable identity keeps Keychain access (the Google token) across rebuilds; ad-hoc re-prompts each build.
# Override with SIGN_IDENTITY=<hash or name>.
if [ "$RELEASE" = 1 ]; then
    IDENTITY=${SIGN_IDENTITY:-$(security find-identity -v -p codesigning | awk '/Developer ID Application/ {print $2; exit}')}
    [ -n "$IDENTITY" ] || { echo "No Developer ID Application identity found" >&2; exit 1; }
    codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
else
    # Prefer the same Developer ID as release builds: a different signer makes macOS re-ask for Keychain access.
    IDS=$(security find-identity -v -p codesigning)
    IDENTITY=${SIGN_IDENTITY:-$(echo "$IDS" | awk '/Developer ID Application/ {print $2; exit}')}
    IDENTITY=${IDENTITY:-$(echo "$IDS" | awk '/Apple Development/ {print $2; exit}')}
    codesign --force --sign "${IDENTITY:--}" "$APP"
fi
echo "Built $APP $VERSION (signed with ${IDENTITY:-ad-hoc})"

for arg in "$@"; do
    case "$arg" in
        --install)
            pkill -x Deflow 2>/dev/null || true
            rm -rf /Applications/Deflow.app
            cp -R "$APP" /Applications/Deflow.app
            APP=/Applications/Deflow.app
            echo "Installed $APP" ;;
        --run)
            pkill -x Deflow 2>/dev/null || true
            open "$APP" ;;
    esac
done
