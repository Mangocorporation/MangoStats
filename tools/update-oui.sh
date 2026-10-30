#!/bin/zsh
# Refreshes Resources/oui.txt (device makers for the Network tab) from the IEEE registry.
set -euo pipefail
here=${0:A:h:h}
tmp=$(mktemp -d)
curl -sf -o "$tmp/oui.csv" https://standards-oui.ieee.org/oui/oui.csv
python3 -I - "$tmp/oui.csv" "$here/Resources/oui.txt" <<'PY'
import csv, sys
src, dst = sys.argv[1], sys.argv[2]
rows = {}
with open(src, encoding="utf-8", errors="replace") as f:
    for r in csv.DictReader(f):
        prefix = (r.get("Assignment") or "").strip().upper()
        name = " ".join((r.get("Organization Name") or "").split())
        if len(prefix) == 6 and name:
            rows[prefix] = name
with open(dst, "w", encoding="utf-8") as f:
    f.write("# IEEE MA-L (OUI) registry, https://standards-oui.ieee.org/oui/oui.csv, trimmed to prefix<TAB>maker.\n")
    for k in sorted(rows):
        f.write(f"{k}\t{rows[k]}\n")
print(f"{len(rows)} makers")
PY
rm -rf "$tmp"
