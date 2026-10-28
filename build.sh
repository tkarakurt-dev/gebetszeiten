#!/bin/bash
set -e
cd "$(dirname "$0")"
APP="Gebetszeiten.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Info.plist "$APP/Contents/Info.plist"
cp Gebetszeiten.icns cities.json "$APP/Contents/Resources/"
swiftc -O -swift-version 5 -target arm64-apple-macos13.0 -Xlinker -platform_version -Xlinker macos -Xlinker 13.0 -Xlinker 26.0 -Xcc -ivfsoverlay -Xcc vfs-overlay.yaml -vfsoverlay vfs-overlay.yaml \
  -o "$APP/Contents/MacOS/Gebetszeiten" main.swift strings.swift -framework AppKit -framework SwiftUI -framework ServiceManagement -framework CoreLocation
codesign --force --sign - "$APP" >/dev/null 2>&1
echo "fertig: $APP"
if [ -w /Applications ]; then DEST=/Applications; else mkdir -p "$HOME/Applications"; DEST="$HOME/Applications"; fi
pkill -x Gebetszeiten 2>/dev/null || true
rm -rf "$DEST/$APP" && cp -R "$APP" "$DEST/" && echo "installiert: $DEST/$APP"
