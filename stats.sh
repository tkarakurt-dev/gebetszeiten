#!/bin/bash
# Zeigt die Downloads je Version (GitHub-Releases, öffentlich abrufbar, kein Token nötig).
# Gezählt wird jeder Download: neue Installationen über den Link und jedes Auto-Update.
curl -s "https://api.github.com/repos/tkarakurt-dev/gebetszeiten/releases?per_page=100" | python3 -c '
import json, sys
rel = json.load(sys.stdin)
if not isinstance(rel, list):
    print(rel); sys.exit(1)
total = 0
print("%-10s%-16s%10s" % ("Version", "veröffentlicht", "Downloads"))
for r in rel:
    n = sum(a["download_count"] for a in r["assets"])
    total += n
    print("%-10s%-16s%10d" % (r["tag_name"], r["published_at"][:10], n))
print("%-26s%10d" % ("Gesamt", total))
if rel:
    n = sum(a["download_count"] for a in rel[0]["assets"])
    print("\nNeueste Version %s: %d Downloads (Neuinstallationen + Auto-Updates)." % (rel[0]["tag_name"], n))
'
