#!/bin/bash
# Veröffentlicht eine neue Version für die Auto-Update-Funktion.
# Vorher in Info.plist CFBundleVersion (+1) und CFBundleShortVersionString erhöhen.
# Aufruf: ./release.sh "Was ist neu (ein Satz)"
set -e
cd "$(dirname "$0")"
NOTES="${1:-Neue Version}"
BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" Info.plist)
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Info.plist)
LAST=$(python3 -c "import json;print(json.load(open('release/latest.json'))['build'])" 2>/dev/null || echo 0)
if [ "$BUILD" -le "$LAST" ]; then echo "CFBundleVersion ($BUILD) muss größer sein als die veröffentlichte ($LAST)"; exit 1; fi

./share.sh
mkdir -p release
mv Gebetszeiten.zip release/Gebetszeiten.zip
SHA=$(shasum -a 256 release/Gebetszeiten.zip | cut -d' ' -f1)
python3 - "$BUILD" "$VERSION" "$SHA" "$NOTES" <<'PY'
import json, sys
b, v, sha, notes = sys.argv[1:5]
json.dump({"build": int(b), "version": v,
           "url": "https://raw.githubusercontent.com/tkarakurt-dev/gebetszeiten/main/release/Gebetszeiten.zip",
           "sha256": sha, "notes": notes}, open("release/latest.json", "w"), ensure_ascii=False, indent=2)
PY
git add -A
git commit -m "Version $VERSION ($BUILD): $NOTES"
git push origin main
echo "veröffentlicht: Version $VERSION (Build $BUILD)"
echo "Download-Link für neue Freunde: https://github.com/tkarakurt-dev/gebetszeiten/raw/main/release/Gebetszeiten.zip"
