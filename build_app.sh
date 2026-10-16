#!/bin/zsh
set -e

APP_NAME="Find Any File"
BUNDLE_DIR="$PWD/$APP_NAME.app"
CONTENTS_DIR="$BUNDLE_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "1. Release modunda derleniyor..."
swift build -c release

echo "2. .app paketi oluşturuluyor..."
rm -rf "$BUNDLE_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

cp ".build/release/FindAnyFile" "$MACOS_DIR/FindAnyFile"
chmod +x "$MACOS_DIR/FindAnyFile"

cat > "$CONTENTS_DIR/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>tr</string>
    <key>CFBundleExecutable</key>
    <string>FindAnyFile</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.umutdemir.findanyfile</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Find Any File</string>
    <key>CFBundleDisplayName</key>
    <string>Find Any File</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>3.0.0</string>
    <key>CFBundleVersion</key>
    <string>300</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

echo "3. Uygulama ikonu üretiliyor..."
swift - << 'SWIFT_ICON'
import AppKit

let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()

guard let ctx = NSGraphicsContext.current?.cgContext else { exit(1) }

// Modern macOS Squircle Background
let rect = CGRect(x: 80, y: 80, width: 864, height: 864)
let path = CGPath(roundedRect: rect, cornerWidth: 195, cornerHeight: 195, transform: nil)
ctx.addPath(path)
ctx.clip()

let colorSpace = CGColorSpaceCreateDeviceRGB()
let colors = [
    CGColor(red: 0.08, green: 0.35, blue: 0.95, alpha: 1.0),
    CGColor(red: 0.25, green: 0.12, blue: 0.75, alpha: 1.0)
] as CFArray
if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0]) {
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 80, y: 944), end: CGPoint(x: 944, y: 80), options: [])
}

// Folder card graphic inside icon
let folderRect = CGRect(x: 230, y: 290, width: 460, height: 360)
let folderPath = CGPath(roundedRect: folderRect, cornerWidth: 44, cornerHeight: 44, transform: nil)
ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.22))
ctx.addPath(folderPath)
ctx.fillPath()

// Magnifying glass circle
ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.96))
ctx.setLineWidth(54)
ctx.strokeEllipse(in: CGRect(x: 340, y: 360, width: 300, height: 300))

// Magnifying glass handle
ctx.setLineCap(.round)
ctx.move(to: CGPoint(x: 595, y: 405))
ctx.addLine(to: CGPoint(x: 735, y: 265))
ctx.strokePath()

// Lightning bolt inside lens
ctx.setFillColor(CGColor(red: 1.0, green: 0.82, blue: 0.2, alpha: 1.0))
ctx.move(to: CGPoint(x: 505, y: 605))
ctx.addLine(to: CGPoint(x: 430, y: 495))
ctx.addLine(to: CGPoint(x: 490, y: 495))
ctx.addLine(to: CGPoint(x: 470, y: 410))
ctx.addLine(to: CGPoint(x: 555, y: 525))
ctx.addLine(to: CGPoint(x: 495, y: 525))
ctx.closePath()
ctx.fillPath()

image.unlockFocus()

if let tiff = image.tiffRepresentation,
   let rep = NSBitmapImageRep(data: tiff),
   let pngData = rep.representation(using: .png, properties: [:]) {
    try? pngData.write(to: URL(fileURLWithPath: "/tmp/faf_icon_1024.png"))
}
SWIFT_ICON

ICONSET_DIR="/tmp/AppIcon.iconset"
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

sips -z 16 16     /tmp/faf_icon_1024.png --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
sips -z 32 32     /tmp/faf_icon_1024.png --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
sips -z 32 32     /tmp/faf_icon_1024.png --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
sips -z 64 64     /tmp/faf_icon_1024.png --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
sips -z 128 128   /tmp/faf_icon_1024.png --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
sips -z 256 256   /tmp/faf_icon_1024.png --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -z 256 256   /tmp/faf_icon_1024.png --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
sips -z 512 512   /tmp/faf_icon_1024.png --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips -z 512 512   /tmp/faf_icon_1024.png --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
cp /tmp/faf_icon_1024.png "$ICONSET_DIR/icon_512x512@2x.png"

iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns"
rm -rf "$ICONSET_DIR" /tmp/faf_icon_1024.png

codesign --force --deep --sign - "$BUNDLE_DIR" 2>/dev/null || true

echo "✅ Başarıyla oluşturuldu: $BUNDLE_DIR"

