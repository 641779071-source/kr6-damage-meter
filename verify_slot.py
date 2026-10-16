import re, os
p = os.path.join(os.environ["APPDATA"], "kingdom_rush_genesis", "slot_1.lua")
t = open(p, encoding="utf-8").read()
stars = [int(x) for x in re.findall(r'\["stars"\]\s*=\s*(\d+)', t)]
print("path", p)
print("size", os.path.getsize(p))
print("star fields", stars, "sum", sum(stars))
m = re.search(r'\["YOURE_AN_ALL_STAR"\]\s*=\s*(\d+)', t)
print("ALL_STAR", m.group(1) if m else None)
m = re.search(r'\["last_stars"\]\s*=\s*(\d+)', t)
print("last_stars", m.group(1) if m else None)
print("level keys", len(re.findall(r'\n\t\t\[(\d+)\] = \{', t)))
