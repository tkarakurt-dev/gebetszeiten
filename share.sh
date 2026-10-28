#!/bin/bash
# Baut eine universelle Version (Apple-Chip + Intel) und packt sie als ZIP zum Verschicken
set -e
cd "$(dirname "$0")"
FLAGS=(-O -swift-version 5 -Xlinker -platform_version -Xlinker macos -Xlinker 13.0 -Xlinker 26.0
       -Xcc -ivfsoverlay -Xcc vfs-overlay.yaml -vfsoverlay vfs-overlay.yaml
       -framework AppKit -framework SwiftUI -framework ServiceManagement -framework CoreLocation)
OUT=Gebetszeiten-Mac
rm -rf "$OUT" && mkdir -p "$OUT/tmp"
swiftc -target arm64-apple-macos13.0 "${FLAGS[@]}" -o "$OUT/tmp/arm64" main.swift
swiftc -target x86_64-apple-macos13.0 "${FLAGS[@]}" -o "$OUT/tmp/x86_64" main.swift
APP="$OUT/Gebetszeiten.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Info.plist "$APP/Contents/Info.plist"
cp Gebetszeiten.icns cities.json "$APP/Contents/Resources/"
lipo -create "$OUT/tmp/arm64" "$OUT/tmp/x86_64" -output "$APP/Contents/MacOS/Gebetszeiten"
codesign --force --sign - "$APP"
cat > "$OUT/So installierst du die App.txt" <<'TXT'
Gebetszeiten für den Mac (IGMG, Stadt per Standort oder Auswahl)

1. Gebetszeiten.app in den Ordner "Programme" ziehen.
2. Programm "Terminal" öffnen (Spotlight: Cmd + Leertaste, "Terminal"),
   diese Zeile einfügen und Enter drücken:

   xattr -dr com.apple.quarantine /Applications/Gebetszeiten.app

   Danach startet die App per Doppelklick ganz normal.
   (Ohne Terminal: App einmal doppelklicken, Meldung schließen, dann
   Systemeinstellungen > Datenschutz & Sicherheit > unter "Apps erlauben von"
   auf "Dennoch öffnen" klicken. Der Knopf erscheint nur direkt nach dem
   Startversuch.)
3. Die App erscheint oben rechts in der Menüleiste (Mond-Symbol).
   Klick darauf zeigt alle Zeiten. Unter "Einstellungen" kannst du
   "Bei Anmeldung starten" einschalten.

Läuft ab macOS 13, Liquid-Glass-Optik ab macOS 26.
TXT
rm -rf "$OUT/tmp"
ditto -c -k --sequesterRsrc --keepParent "$OUT" Gebetszeiten.zip
rm -rf "$OUT"
echo "fertig: $(pwd)/Gebetszeiten.zip"
