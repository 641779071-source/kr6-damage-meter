import datetime
import hashlib
import os
import re

save = os.path.join(os.environ["APPDATA"], "kingdom_rush_genesis")
files = {
    "current": os.path.join(save, "slot_1.lua"),
    "bak_old": os.path.join(save, "slot_1.lua.bak_20261013_004105"),
}

for label, p in files.items():
    print("====", label, "====")
    if not os.path.isfile(p):
        print("MISSING", p)
        continue
    st = os.stat(p)
    t = open(p, encoding="utf-8", errors="replace").read()
    stars = [int(x) for x in re.findall(r'\["stars"\]\s*=\s*(\d+)', t)]
    allstar = re.search(r'\["YOURE_AN_ALL_STAR"\]\s*=\s*(\d+)', t)
    last = re.search(r'\["last_stars"\]\s*=\s*(\d+)', t)
    gems = re.search(r'\["gems"\]\s*=\s*(\d+)', t)
    ver = re.search(r'\["version_string"\]\s*=\s*"([^"]+)"', t)
    print("size     ", st.st_size)
    print("mtime    ", datetime.datetime.fromtimestamp(st.st_mtime))
    print("sha1     ", hashlib.sha1(t.encode("utf-8")).hexdigest()[:16])
    print("stars    ", stars, "sum=", sum(stars))
    print("ALL_STAR ", allstar.group(1) if allstar else None)
    print("last_star", last.group(1) if last else None)
    print("gems     ", gems.group(1) if gems else None)
    print("version  ", ver.group(1) if ver else None)
    print()

# probe files should exist; slot should only change with game play
probe_log = os.path.join(save, "_kr6dmg_probe.log")
print("==== verdict helpers ====")
print("probe log exists:", os.path.isfile(probe_log))
if os.path.isfile(probe_log):
    print("probe log mtime:", datetime.datetime.fromtimestamp(os.stat(probe_log).st_mtime))
cur = files["current"]
if os.path.isfile(cur):
    # Does probe source ever mention writing slot?
    probe = os.path.join(os.path.dirname(__file__), "src", "_kr6dmg_probe.lua")
    src = open(probe, encoding="utf-8").read()
    mentions = [line.strip() for line in src.splitlines() if "slot" in line.lower()]
    print("probe.lua lines mentioning slot:")
    for line in mentions:
        print(" ", line)
