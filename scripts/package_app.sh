#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG="${1:-release}"
APP="$ROOT/build/MeNote.app"

cd "$ROOT"

swift build -c "$CONFIG"

BIN="$(swift build -c "$CONFIG" --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN/menote" "$APP/Contents/MacOS/MeNote"
cp "$ROOT/logo.png" "$APP/Contents/Resources/logo.png"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>MeNote</string>
    <key>CFBundleDisplayName</key>
    <string>MeNote</string>
    <key>CFBundleIdentifier</key>
    <string>app.menote.menote</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>MeNote</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
PLIST

ICON_SRC="$ROOT/logo.png"
ICNS="$APP/Contents/Resources/AppIcon.icns"
ICONSET="$ROOT/build/AppIcon.iconset"

if [[ -f "$ICON_SRC" ]]; then
    if [[ ! -f "$ICNS" || "$ICON_SRC" -nt "$ICNS" ]]; then
        rm -rf "$ICONSET"
        mkdir -p "$ICONSET"
        for s in 16 32 128 256 512; do
            sips -z "$s" "$s" "$ICON_SRC" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
            d=$((s * 2))
            sips -z "$d" "$d" "$ICON_SRC" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
        done
        iconutil -c icns "$ICONSET" -o "$ICNS"
    fi
fi

codesign --force --sign - "$APP" >/dev/null 2>&1 || true

echo "Packaged: $APP"
