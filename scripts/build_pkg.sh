#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VERSION="3.0.0"
IDENTIFIER="app.menote.menote"
APP_NAME="Menote"
APP_PATH="$ROOT/build/$APP_NAME.app"
# pkgbuild/productbuild can crash with a BOM buffer overflow when run on
# ExFAT/FAT volumes (e.g. external drives). Stage packaging in a local temp
# directory and copy the result back to preserve the final location.
TMP_ROOT="$(mktemp -d /tmp/menote-pkg.XXXXXX)"
PKG_DIR="$TMP_ROOT/pkg"
COMPONENT_PKG="$PKG_DIR/${APP_NAME}.pkg"
DISTRIBUTION_XML="$PKG_DIR/Distribution"
FINAL_PKG="$ROOT/build/${APP_NAME}-${VERSION}.pkg"
BUILD_NUMBER_FILE="$ROOT/.menote-build-number"

cd "$ROOT"

# Read current build number; determine next build number (do NOT persist yet)
if [[ -f "$BUILD_NUMBER_FILE" ]]; then
    BUILD_NUMBER=$(<"$BUILD_NUMBER_FILE")
else
    BUILD_NUMBER=0
fi
BUILD_NUMBER=$((BUILD_NUMBER + 1))

echo "========================================"
echo "Building Menote"
echo "Version: $VERSION"
echo "Build:   $BUILD_NUMBER"
echo "========================================"

# Build the app (passes VERSION and BUILD_NUMBER to package_app.sh)
VERSION="$VERSION" BUILD_NUMBER="$BUILD_NUMBER" "$SCRIPT_DIR/package_app.sh" release

# Verify .app Info.plist contains correct values
PLIST="$APP_PATH/Contents/Info.plist"
ACTUAL_VERSION=$(defaults read "$PLIST" CFBundleShortVersionString)
ACTUAL_BUILD=$(defaults read "$PLIST" CFBundleVersion)

if [[ "$ACTUAL_VERSION" != "$VERSION" ]]; then
    echo "ERROR: CFBundleShortVersionString mismatch: expected $VERSION, got $ACTUAL_VERSION"
    exit 1
fi
if [[ "$ACTUAL_BUILD" != "$BUILD_NUMBER" ]]; then
    echo "ERROR: CFBundleVersion mismatch: expected $BUILD_NUMBER, got $ACTUAL_BUILD"
    exit 1
fi

# Clean and create pkg directory
rm -rf "$PKG_DIR"
mkdir -p "$PKG_DIR"

# Stage the app on a local filesystem to avoid BOM crashes on ExFAT/FAT volumes.
# The project tree (including build/Menote.app) lives on an ExFAT volume that
# has no POSIX permission storage, so every packaged file is presented as 0700.
# If left as-is, the installer restores those 0700 modes with root ownership,
# producing an /Applications/Menote.app that the user cannot access or launch.
# ditto + explicit chmod normalizes modes on the local (APFS) staged copy.
STAGED_APP="$TMP_ROOT/$APP_NAME.app"
ditto "$APP_PATH" "$STAGED_APP"

# Normalize permissions: dirs and executable bits 0755, other files 0644.
find "$STAGED_APP" -type d -exec chmod 755 {} +
find "$STAGED_APP" -type f -exec chmod 644 {} +
chmod 755 "$STAGED_APP/Contents/MacOS/Menote"

# Create component package
pkgbuild \
    --component "$STAGED_APP" \
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

# Create final product archive (into the temp dir to avoid the BOM crash)
TMP_FINAL_PKG="$PKG_DIR/${APP_NAME}-${VERSION}.pkg"
productbuild \
    --distribution "$DISTRIBUTION_XML" \
    --package-path "$PKG_DIR" \
    "$TMP_FINAL_PKG"

# Verify .pkg exists
if [[ ! -f "$TMP_FINAL_PKG" ]]; then
    echo "ERROR: Package not created"
    exit 1
fi

# Copy the finished package back to the project build directory
cp "$TMP_FINAL_PKG" "$FINAL_PKG"
rm -rf "$TMP_ROOT"

# Persist the build number only after full success
echo "$BUILD_NUMBER" > "$BUILD_NUMBER_FILE"

echo "========================================"
echo "Build successful"
echo "Menote $VERSION ($BUILD_NUMBER)"
echo "Package: $FINAL_PKG"
echo "========================================"
