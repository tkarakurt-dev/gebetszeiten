#!/bin/bash
# Legt das GitHub-Token für release.sh im Anmelde-Schlüsselbund ab.
# Fragt es über ein verdecktes Mac-Eingabefenster ab, damit es nirgends sichtbar wird.
TOKEN=$(osascript -e 'text returned of (display dialog "GitHub-Token für Gebetszeiten einfügen (Cmd+V):" default answer "" with hidden answer with title "Gebetszeiten" buttons {"Abbrechen", "Speichern"} default button "Speichern")' 2>/dev/null)
if [ -z "$TOKEN" ]; then echo "Abgebrochen, nichts gespeichert."; exit 1; fi
case "$TOKEN" in
    github_pat_*|ghp_*) ;;
    *) echo "Das sieht nicht nach einem GitHub-Token aus (sollte mit github_pat_ beginnen). Nichts gespeichert."; exit 1 ;;
esac
security add-generic-password -U -a tkarakurt-dev -s gebetszeiten-github -w "$TOKEN" && echo "TOKEN GESPEICHERT"
