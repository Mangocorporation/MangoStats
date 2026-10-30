#!/usr/bin/env python3 -I
# Lists UI text without a pt-BR translation (S-051). Run from the repo root:
#   tools/l10n-missing.py
# Keys come from a clean compile (SwiftUI's own keys: an incremental build skips
# unchanged files and misses theirs) plus the literals passed to L10n.t/f and kit parts.
import glob, json, os, re, shutil, subprocess, sys, tempfile
out = tempfile.mkdtemp()
scratch = os.path.expanduser("~/Library/Developer/MangoStats/l10n-build")
shutil.rmtree(scratch, ignore_errors=True)
subprocess.run(["swift", "build", "--scratch-path", scratch, "--product", "MangoStats",
                "-Xswiftc", "-emit-localized-strings", "-Xswiftc", "-emit-localized-strings-path", "-Xswiftc", out],
               check=True, stdout=subprocess.DEVNULL)
keys = set()
for p in glob.glob(out + "/*.stringsdata"):
    if "KitGallery" in p: continue
    for entries in json.load(open(p)).get("tables", {}).values():
        keys.update(e["key"] for e in entries)
literal = re.compile(r'"((?:[^"\\]|\\.)*)"')
shown = re.compile(r'(L10n\.[tf]\(|CardHeader\(|InfoRow\(|DetailRow\(|Eyebrow\(|LivePill\(|HeroValue\(|node\(|sortButton\(|'
                   r'message\(|link\(|credit\(|legend\(|eyebrow:|title:|detail:|label:|unit:|text:|tagline:|body:|case \.[a-zA-Z]+: )')
for p in glob.glob("Sources/**/*.swift", recursive=True):
    if any(x in p for x in ["KitGallery", "Snapshot", "SelfTest", "SMC", "Helper", "StatusData.swift"]): continue
    for line in open(p):
        s = line.strip()
        if s.startswith("//") or not shown.search(s): continue
        code = s.split(" // ")[0]
        for m in literal.finditer(code):
            k = m.group(1)
            if "L10n.f(" in code and code[:m.start()].endswith(", "): continue  # a value filled in, not a key
            if "\\(" not in k and re.search(r"[A-Za-z]{2}", k): keys.add(k.replace('\\"', '"'))
table = json.loads(subprocess.run(["plutil", "-convert", "json", "-o", "-", "Resources/pt-BR.lproj/Localizable.strings"],
                                  capture_output=True, text=True, check=True).stdout)
# SF Symbol names, product names, and units stay as they are.
same = re.compile(r"[a-z0-9]+(\.[a-z0-9]+)+|[a-z]+|MangoStats|MangoCorp|MacBook Pro|Sparkle \(MIT\)|\d.*Hz|Wi-Fi \d|")
missing = sorted(k for k in keys if k not in table and not same.fullmatch(k))
for k in missing: print(k)
print(f"{'PASS' if not missing else 'FAIL'} l10n: {len(missing)} missing of {len(keys)} keys")
sys.exit(1 if missing else 0)
