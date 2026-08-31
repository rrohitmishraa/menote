#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG="${1:-release}"
APP="$ROOT/build/Menote.app"

# Accept VERSION and BUILD_NUMBER from environment (set by build_pkg.sh)
VERSION="${VERSION:-3.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"

cd "$ROOT"

swift build -c "$CONFIG"

BIN="$(swift build -c "$CONFIG" --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN/menote" "$APP/Contents/MacOS/Menote"
cp "$ROOT/logo.png" "$APP/Contents/Resources/logo.png"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Menote</string>
    <key>CFBundleDisplayName</key>
    <string>Menote</string>
    <key>CFBundleIdentifier</key>
    <string>app.menote.menote</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>Menote</string>
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
    <key>UTExportedTypeDeclarations</key>
    <array>
        <dict>
            <key>UTTypeIdentifier</key>
            <string>app.menote.menote</string>
            <key>UTTypeDescription</key>
            <string>Menote Document</string>
            <key>UTTypeConformsTo</key>
            <array>
                <string>public.plain-text</string>
            </array>
            <key>UTTypeTagSpecification</key>
            <dict>
                <key>public.filename-extension</key>
                <array>
                    <string>menote</string>
                </array>
            </dict>
        </dict>
    </array>
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
