#!/bin/bash
# Builds a distributable build/Deflow-<version>.dmg: Developer ID signed app, drag-to-Applications layout.
# Notarizes and staples when NOTARY_PROFILE names a notarytool keychain profile:
#   xcrun notarytool store-credentials deflow --apple-id <id> --team-id <team>   (one time)
#   NOTARY_PROFILE=deflow ./scripts/make-dmg.sh
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/build-app.sh --release
APP=build/Deflow.app
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")
IDENTITY=${SIGN_IDENTITY:-$(security find-identity -v -p codesigning | awk '/Developer ID Application/ {print $2; exit}')}
DMG=build/Deflow-$VERSION.dmg
STAGE=build/dmg-stage
RW=build/Deflow-rw.dmg
VOL=/Volumes/Deflow

# Stage: app, Applications shortcut, retina-aware background.
rm -rf "$STAGE" "$RW" "$DMG"
mkdir -p "$STAGE/.background"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
BIN="$APP/Contents/MacOS/Deflow"
"$BIN" --render-dmg-bg "$PWD/build/dmg-bg.png"
"$BIN" --render-dmg-bg "$PWD/build/dmg-bg@2x.png" --2x
sips -s dpiWidth 144 -s dpiHeight 144 "build/dmg-bg@2x.png" >/dev/null
tiffutil -cathidpicheck build/dmg-bg.png "build/dmg-bg@2x.png" -out "$STAGE/.background/bg.tiff" >/dev/null 2>&1

[ -d "$VOL" ] && hdiutil detach "$VOL" -quiet || true
hdiutil create -srcfolder "$STAGE" -volname Deflow -fs HFS+ -format UDRW -ov "$RW" >/dev/null
hdiutil attach "$RW" -readwrite -noverify -noautoopen >/dev/null

# Window layout. Needs Finder automation permission; without it the DMG still works, just unstyled.
osascript <<'OSA' || echo "warning: Finder layout skipped (plain DMG)" >&2
with timeout of 45 seconds
    tell application "Finder"
        tell disk "Deflow"
            open
            delay 1
            set w to container window
            set current view of w to icon view
            set toolbar visible of w to false
            set statusbar visible of w to false
            try
                set pathbar visible of w to false
            end try
            set bounds of w to {200, 160, 860, 608}
            set opts to icon view options of w
            set arrangement of opts to not arranged
            set icon size of opts to 112
            set text size of opts to 13
            set background picture of opts to file ".background:bg.tiff"
            set position of item "Deflow.app" of w to {170, 205}
            set position of item "Applications" of w to {490, 205}
            update without registering applications
            -- Finder only persists window geometry on a close/reopen cycle.
            close
            open
            delay 1
            set bounds of container window to {200, 160, 860, 608}
            delay 2
            close
        end tell
    end tell
end timeout
OSA

# Wait for Finder to flush the layout to disk before unmounting.
for _ in 1 2 3 4 5 6 7 8 9 10; do [ -s "$VOL/.DS_Store" ] && break; sleep 1; done
sync
hdiutil detach "$VOL" -quiet || hdiutil detach "$VOL" -force -quiet

# Window managers that auto-tile new windows overwrite the size Finder saves, so pin it in the
# saved layout directly: same-length rewrite of the WindowBounds string, mounted where Finder can't see it.
hdiutil attach "$RW" -readwrite -noverify -noautoopen -nobrowse >/dev/null
python3 - "$VOL/.DS_Store" <<'PY'
import re, sys
path = sys.argv[1]
data = open(path, "rb").read()
def pin(m):
    want = b"{{200, 160}, {660, 452}}"
    pad = len(m.group(0)) - len(want)
    if pad < 0:
        return m.group(0)
    return want.replace(b"}, {", b"}," + b" " * (pad + 1) + b"{")
data, n = re.subn(rb"\{\{-?[\d.]+, -?[\d.]+\}, \{[\d.]+, [\d.]+\}\}", pin, data)
open(path, "wb").write(data)
print(f"pinned window bounds in {n} place(s)")
PY
sync
hdiutil detach "$VOL" -quiet || hdiutil detach "$VOL" -force -quiet
hdiutil convert "$RW" -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null
rm -rf "$RW" "$STAGE"
codesign --force --timestamp --sign "$IDENTITY" "$DMG"

if [ -n "${NOTARY_PROFILE:-}" ]; then
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG"
    echo "Built, notarized and stapled $DMG"
else
    echo "Built $DMG (signed, NOT notarized: other Macs will show a Gatekeeper warning)"
fi
