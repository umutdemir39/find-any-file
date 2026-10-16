#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

APP_NAME="Find Any File"
APP_BUNDLE="${APP_NAME}.app"
DMG_NAME="Find-Any-File-macOS-arm64.dmg"
VOL_NAME="Find Any File"
STAGING_DIR="/tmp/faf_dmg_staging_$$"
RW_DMG="/tmp/faf_rw_$$.dmg"
FINAL_DMG="${1:-${DIR}/${DMG_NAME}}"

echo "=========================================="
echo "💿 Building Find Any File DMG Installer..."
echo "=========================================="

# 1. Generate Retina DMG background artwork
echo "🎨 Generating DMG background artwork..."
swift generate_dmg_background.swift

# 2. Build Find Any File.app
./build_app.sh

# Embed dmg-background.tiff inside the app bundle Resources
cp "dmg-background.tiff" "${APP_BUNDLE}/Contents/Resources/dmg-background.tiff"
codesign --force --deep --sign - "${APP_BUNDLE}"

# 3. Clean any previously mounted volume with same name
if [ -d "/Volumes/${VOL_NAME}" ]; then
    hdiutil detach "/Volumes/${VOL_NAME}" -force >/dev/null 2>&1 || true
fi
rm -rf "${STAGING_DIR}" "${RW_DMG}" "${FINAL_DMG}"

# 4. Prepare staging directory (ONLY Find Any File.app and Applications symlink)
mkdir -p "${STAGING_DIR}"
cp -R "${APP_BUNDLE}" "${STAGING_DIR}/"
ln -s /Applications "${STAGING_DIR}/Applications"

# 5. Create read-write DMG
hdiutil create \
    -volname "${VOL_NAME}" \
    -srcfolder "${STAGING_DIR}" \
    -ov \
    -format UDRW \
    -fs HFS+ \
    "${RW_DMG}" >/dev/null

rm -rf "${STAGING_DIR}"

# 6. Mount read-write DMG
MOUNT_OUTPUT=$(hdiutil attach -readwrite -noverify -noautoopen "${RW_DMG}")
DEV_NAME=$(echo "${MOUNT_OUTPUT}" | egrep '^/dev/' | sed 1q | awk '{print $1}')
MOUNT_DIR="/Volumes/${VOL_NAME}"

echo "📐 Applying custom Finder layout & drag-to-install background..."

# Remove any filesystem metadata folders before configuring Finder
rm -rf "${MOUNT_DIR}/.fseventsd" "${MOUNT_DIR}/.Trashes" 2>/dev/null || true

# Configure Finder window via AppleScript
osascript <<EOF
tell application "Finder"
    tell disk "${VOL_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 120, 860, 548}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 104
        set text size of theViewOptions to 13
        set background picture of theViewOptions to POSIX file "${MOUNT_DIR}/${APP_BUNDLE}/Contents/Resources/dmg-background.tiff"
        set position of item "${APP_BUNDLE}" of container window to {180, 176}
        set position of item "Applications" of container window to {480, 176}
        update without registering applications
        delay 2
        close
    end tell
end tell
EOF

rm -rf "${MOUNT_DIR}/.fseventsd" "${MOUNT_DIR}/.Trashes" 2>/dev/null || true
sync

# 7. Detach and convert to compressed read-only DMG
hdiutil detach "${DEV_NAME}" -force >/dev/null
hdiutil convert "${RW_DMG}" -format UDZO -imagekey zlib-level=9 -ov -o "${FINAL_DMG}" >/dev/null
rm -f "${RW_DMG}"

echo "=========================================="
echo "✅ Styled DMG Installer ready:"
echo "👉 ${FINAL_DMG}"
echo "=========================================="

