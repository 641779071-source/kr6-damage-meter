# -*- coding: utf-8 -*-
import re
text = open(r"D:\cursor项目\kr6-extract\output\zh-Hans.lua", encoding="utf-8", errors="replace").read()
pairs = dict(re.findall(r'\b([A-Z][A-Z0-9_]*)\s*=\s*"([^"]*)"', text))
out = []
for k, v in sorted(pairs.items()):
    if "NIVUS" in k or "纽维" in v:
        out.append("%s=%s" % (k, v))
    if k.startswith("HERO_") and k.endswith("_NAME"):
        if any(x in k for x in ("SKILL", "TALENT", "ULT", "STAGE", "DESCRIPTION")):
            continue
        out.append("%s=%s" % (k, v))
path = r"D:\cursor项目\kr6-damage-meter\scripts\hero_names.txt"
open(path, "w", encoding="utf-8").write("\n".join(out))
print("wrote", len(out), "lines")
