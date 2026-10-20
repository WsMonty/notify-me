#!/bin/sh
set -e
cd "$(dirname "$0")"
APP=NotifyMe.app
VERSION=$(git describe --tags --always 2>/dev/null || echo dev)
mkdir -p $APP/Contents/MacOS $APP/Contents/Resources
# app icon from icon/icon.png (regenerate the png with: swift icon/make-icon.swift)
ICONSET=/tmp/NotifyMe.iconset
rm -rf $ICONSET && mkdir $ICONSET
for s in 16 32 128 256 512; do
  sips -z $s $s icon/icon.png --out $ICONSET/icon_${s}x${s}.png >/dev/null
  sips -z $((s*2)) $((s*2)) icon/icon.png --out $ICONSET/icon_${s}x${s}@2x.png >/dev/null
done
iconutil -c icns $ICONSET -o $APP/Contents/Resources/AppIcon.icns
# universal binary, macOS 14+ (ScreenCaptureKit screenshots)
swiftc -O -target arm64-apple-macos14.0 main.swift -o /tmp/NotifyMe-arm64
swiftc -O -target x86_64-apple-macos14.0 main.swift -o /tmp/NotifyMe-x86_64
lipo -create /tmp/NotifyMe-arm64 /tmp/NotifyMe-x86_64 -output $APP/Contents/MacOS/NotifyMe
cat > $APP/Contents/Info.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>local.notify-me</string>
  <key>CFBundleName</key><string>Notify Me</string>
  <key>CFBundleExecutable</key><string>NotifyMe</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
</dict></plist>
EOF
codesign --force -s - $APP
echo "Built $APP ($VERSION) — run: open $APP"
