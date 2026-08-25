#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VERSION="1.0.0"
IDENTIFIER="app.menote.menote"
APP_NAME="Menote"
APP_PATH="$ROOT/build/$APP_NAME.app"
PKG_DIR="$ROOT/build/pkg"
COMPONENT_PKG="$PKG_DIR/${APP_NAME}.pkg"
DISTRIBUTION_XML="$PKG_DIR/Distribution"
FINAL_PKG="$ROOT/build/${APP_NAME}-${VERSION}.pkg"

cd "$ROOT"

# Build the app first
"$SCRIPT_DIR/package_app.sh" release

# Clean and create pkg directory
rm -rf "$PKG_DIR"
mkdir -p "$PKG_DIR"

# Create component package
pkgbuild \
    --component "$APP_PATH" \
    --install-location "/Applications" \
    --identifier "$IDENTIFIER" \
    --version "$VERSION" \
    "$COMPONENT_PKG"

# Create distribution XML
cat > "$DISTRIBUTION_XML" <<'DIST'
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
    <title>Menote</title>
    <organization>app.menote</organization>
    <domains enable_localSystem="true" enable_currentUserHome="true" enable_anywhere="false"/>
    <options customize="never" require-scripts="false" rootVolumeOnly="false"/>
    <installation-check script="pm_install_check();"/>
    <script>
    function pm_install_check() {
        if (!(system.compareVersions(system.version.ProductVersion, '13.0') >= 0)) {
            my.result.title = 'Installation Failed';
            my.result.message = 'Menote requires macOS 13.0 or later.';
            my.result.type = 'Fatal';
            return false;
        }
        return true;
    }
    </script>
    <pkg-ref id="app.menote.menote">#Menote.pkg</pkg-ref>
    <choices-outline>
        <line choice="default">
            <line choice="app.menote.menote"/>
        </line>
    </choices-outline>
    <choice id="default" title="Menote" description="A simple note-taking app for your notch.">
        <pkg-ref id="app.menote.menote"/>
    </choice>
    <choice id="app.menote.menote" title="Menote" description="Menote Application" start_selected="true" start_enabled="true" start_visible="true">
        <pkg-ref id="app.menote.menote"/>
    </choice>
</installer-gui-script>
DIST

# Create final product archive
productbuild \
    --distribution "$DISTRIBUTION_XML" \
    --package-path "$PKG_DIR" \
    "$FINAL_PKG"

echo "Created installer: $FINAL_PKG"