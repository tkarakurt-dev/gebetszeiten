#!/bin/bash
# Veröffentlicht eine neue Version als GitHub-Release (mit Download-Zähler) und
# aktualisiert release/latest.json für die Auto-Update-Funktion.
# Vorher in Info.plist CFBundleVersion (+1) und CFBundleShortVersionString erhöhen.
# Braucht ein GitHub-Token im Schlüsselbund (einmalig, siehe README-Abschnitt in release.sh unten).
# Aufruf: ./release.sh "Was ist neu (ein Satz)"
set -e
cd "$(dirname "$0")"
REPO=tkarakurt-dev/gebetszeiten
NOTES="${1:-Neue Version}"
BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" Info.plist)
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Info.plist)
LAST=$(python3 -c "import json;print(json.load(open('release/latest.json'))['build'])" 2>/dev/null || echo 0)
if [ "$BUILD" -le "$LAST" ]; then echo "CFBundleVersion ($BUILD) muss größer sein als die veröffentlichte ($LAST)"; exit 1; fi

# Token einmalig ablegen mit:
#   security add-generic-password -a tkarakurt-dev -s gebetszeiten-github -w
# (oder in Schlüsselbundverwaltung bzw. der App "Passwörter" unter dem Namen gebetszeiten-github)
TOKEN=$(security find-generic-password -s gebetszeiten-github -w 2>/dev/null \
     || security find-internet-password -s gebetszeiten-github -w 2>/dev/null \
     || security find-generic-password -l gebetszeiten-github -w 2>/dev/null \
     || security find-internet-password -l gebetszeiten-github -w 2>/dev/null) || {
    echo "Kein GitHub-Token im Schlüsselbund (Name gebetszeiten-github)."; exit 1; }
api() { curl -sS -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github+json" "$@"; }

./share.sh
mkdir -p release
mv Gebetszeiten.zip release/Gebetszeiten.zip
SHA=$(shasum -a 256 release/Gebetszeiten.zip | cut -d' ' -f1)

# 1. Release anlegen und ZIP hochladen (erst danach zeigt latest.json darauf)
TAG="v$VERSION"
BODY=$(python3 -c 'import json,sys;print(json.dumps({"tag_name":sys.argv[1],"name":"Gebetszeiten "+sys.argv[2],"body":sys.argv[3],"target_commitish":"main"}))' "$TAG" "$VERSION" "$NOTES")
RID=$(api -X POST "https://api.github.com/repos/$REPO/releases" -d "$BODY" | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d.get("id") or "");sys.exit(0 if d.get("id") else print(d,file=sys.stderr) or 1)')
api -X POST -H "Content-Type: application/zip" --data-binary @release/Gebetszeiten.zip \
    "https://uploads.github.com/repos/$REPO/releases/$RID/assets?name=Gebetszeiten.zip" >/dev/null
ASSET="https://github.com/$REPO/releases/download/$TAG/Gebetszeiten.zip"
curl -sfLI "$ASSET" >/dev/null || { echo "Release-Datei nicht abrufbar: $ASSET"; exit 1; }

# 2. Update-Hinweis für die Apps
python3 - "$BUILD" "$VERSION" "$SHA" "$NOTES" "$ASSET" <<'PY'
import json, sys
b, v, sha, notes, url = sys.argv[1:6]
json.dump({"build": int(b), "version": v, "url": url, "sha256": sha, "notes": notes},
          open("release/latest.json", "w"), ensure_ascii=False, indent=2)
PY
# Die ZIP bleibt zusätzlich im Repo, damit alte Download-Links weiter funktionieren
git add -A
git commit -m "Version $VERSION ($BUILD): $NOTES"
git push origin main
echo "veröffentlicht: Version $VERSION (Build $BUILD)"
echo "Download-Link (wird gezählt): https://github.com/$REPO/releases/latest/download/Gebetszeiten.zip"
