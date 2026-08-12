#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="F3 Lang Switch"
BUNDLE_ID="com.user.f3-lang-switch"
BUILD_DIR="$ROOT/.build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
SOURCES=(
  "$ROOT/Sources/F3LangSwitchApp.swift"
  "$ROOT/Sources/AppSettings.swift"
  "$ROOT/Sources/MissionControlRemapper.swift"
  "$ROOT/Sources/LaunchAgentHelper.swift"
  "$ROOT/Sources/SettingsWindow.swift"
)

echo "→ Compiling…"
mkdir -p "$BUILD_DIR/bin"
xcrun swiftc -O \
  -parse-as-library \
  -framework SwiftUI \
  -framework AppKit \
  -framework Carbon \
  -framework ApplicationServices \
  -framework ServiceManagement \
  -o "$BUILD_DIR/bin/F3LangSwitch" \
  "${SOURCES[@]}"

echo "→ Assembling .app…"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BUILD_DIR/bin/F3LangSwitch" "$APP_DIR/Contents/MacOS/F3LangSwitch"

cat > "$APP_DIR/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>F3LangSwitch</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.2.0</string>
  <key>CFBundleVersion</key>
  <string>3</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSHumanReadableCopyright</key>
  <string>Copyright © 2026</string>
</dict>
</plist>
EOF

codesign --force --deep --sign - "$APP_DIR" >/dev/null

if [[ -w /Applications ]]; then
  rm -rf "/Applications/$APP_NAME.app"
  cp -R "$APP_DIR" "/Applications/$APP_NAME.app"
  codesign --force --deep --sign - "/Applications/$APP_NAME.app" >/dev/null
  echo "→ Installed to /Applications"
else
  echo "→ Skipped: /Applications is not writable; app remains in $BUILD_DIR"
fi

echo "✓ Built: $APP_DIR"
