#!/bin/bash
# Baut eine universelle Version (Apple-Chip + Intel) und packt sie als ZIP zum Verschicken
set -e
cd "$(dirname "$0")"
FLAGS=(-O -swift-version 5 -Xlinker -platform_version -Xlinker macos -Xlinker 13.0 -Xlinker 26.0
       -Xcc -ivfsoverlay -Xcc vfs-overlay.yaml -vfsoverlay vfs-overlay.yaml
       -framework AppKit -framework SwiftUI -framework ServiceManagement -framework CoreLocation)
OUT=Gebetszeiten-Mac
rm -rf "$OUT" && mkdir -p "$OUT/tmp"
swiftc -target arm64-apple-macos13.0 "${FLAGS[@]}" -o "$OUT/tmp/arm64" main.swift strings.swift
swiftc -target x86_64-apple-macos13.0 "${FLAGS[@]}" -o "$OUT/tmp/x86_64" main.swift strings.swift
APP="$OUT/Gebetszeiten.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Info.plist "$APP/Contents/Info.plist"
cp Gebetszeiten.icns cities.json "$APP/Contents/Resources/"
lipo -create "$OUT/tmp/arm64" "$OUT/tmp/x86_64" -output "$APP/Contents/MacOS/Gebetszeiten"
codesign --force --sign - "$APP"
cat > "$OUT/So installierst du die App.txt" <<'TXT'
GEBETSZEITEN FÜR DEN MAC
IGMG-Gebetszeiten, Countdown und Kerahat-Zeiten in der Menüleiste.
Läuft ab macOS 13 (Liquid-Glass-Optik ab macOS 26), auf Apple-Chip und Intel.


SCHRITT 1: App in "Programme" ziehen
------------------------------------
Gebetszeiten.app in den Ordner "Programme" ziehen.
Ist dort schon eine ältere Version: vorher beenden (Mond-Symbol oben
rechts anklicken, unten auf den Ein/Aus-Knopf) und dann "Ersetzen" wählen.


SCHRITT 2: Freigeben (nur beim ersten Mal)
------------------------------------------
macOS blockiert die App beim ersten Start, weil sie nicht aus dem
App Store kommt. Wähle EINEN der beiden Wege:

WEG A: Mit Terminal (klappt immer, dauert 10 Sekunden)
  1. Cmd + Leertaste drücken, "Terminal" tippen, Enter.
  2. Diese Zeile einfügen und Enter drücken:

     xattr -dr com.apple.quarantine /Applications/Gebetszeiten.app

  3. Terminal schließen und die App per Doppelklick starten.

WEG B: Ohne Terminal
  1. Gebetszeiten in "Programme" doppelklicken.
     Es kommt eine Meldung, dass die App nicht geöffnet werden kann.
     Auf "Fertig" klicken.
  2. Sofort danach: Systemeinstellungen > Datenschutz & Sicherheit
     öffnen und ganz nach unten scrollen.
  3. Unter "Sicherheit" steht jetzt: "Gebetszeiten wurde blockiert".
     Daneben auf "Dennoch öffnen" klicken und mit Passwort oder
     Touch ID bestätigen.
  Wichtig: Der Knopf "Dennoch öffnen" erscheint nur kurz nach dem
  Startversuch. Ist er nicht da, Schritt 1 wiederholen.
  Steht in der Meldung "beschädigt", geht nur Weg A.


SCHRITT 3: Loslegen
-------------------
- Oben rechts in der Menüleiste erscheint ein Mond mit Countdown.
- Beim ersten Start fragt macOS nach dem Standort: "Erlauben" klicken.
  Die App nimmt dann die nächste IGMG-Stadt. Stadt selbst wählen:
  oben links im Fenster auf den Stadtnamen klicken.
- Einstellungen (Knopf unten im Fenster):
  Namen Türkisch / Arabisch / Deutsch (z. B. Akşam oder Maghrib),
  Länge der Kerahat-Zeiten, "Bei Anmeldung starten" (empfohlen).


UPDATES
-------
Ab Version 1.1 aktualisiert sich die App selbst. Nichts zu tun.
TXT
rm -rf "$OUT/tmp"
ditto -c -k --sequesterRsrc --keepParent "$OUT" Gebetszeiten.zip
rm -rf "$OUT"
echo "fertig: $(pwd)/Gebetszeiten.zip"
