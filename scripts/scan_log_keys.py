# -*- coding: utf-8 -*-
import re, collections, glob, os
save = r"C:\Users\Administrator\AppData\Roaming\kingdom_rush_genesis"
log = os.path.join(save, "_kr6dmg.log")
text = open(log, encoding="utf-8", errors="replace").read()
idx = max(text.rfind("hot_reload"), 0)
chunk = text[idx:]
ctr = collections.Counter()
for line in chunk.splitlines():
    m = re.search(r"cat=(\S+) key=(\S+)", line)
    if m:
        ctr[(m.group(1), m.group(2))] += 1
print("LOG keys after last hot_reload:")
for (cat, key), c in sorted(ctr.items(), key=lambda x: -x[1]):
    print("%4d %s %s" % (c, cat, key))
print("\nCSV english names:")
csvs = sorted(glob.glob(os.path.join(save, "damage_*.csv")), key=os.path.getmtime, reverse=True)[:2]
for path in csvs:
    print("==", os.path.basename(path))
    for line in open(path, encoding="utf-8", errors="replace"):
        line = line.strip()
        if not line or line.startswith("category") or line.startswith("total"):
            continue
        parts = line.split(",")
        if len(parts) < 3:
            continue
        cat, key, name = parts[0], parts[1], parts[2]
        if re.fullmatch(r"[A-Za-z0-9_\-\.]+", name):
            print(" EN", cat, key, name)
