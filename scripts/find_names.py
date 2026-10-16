# -*- coding: utf-8 -*-
import re
path = r"D:\cursor项目\kr6-extract\output\zh-Hans.lua"
text = open(path, encoding="utf-8", errors="replace").read()
pairs = dict(re.findall(r'\b([A-Z][A-Z0-9_]*)\s*=\s*"([^"]*)"', text))
need = ("NIVUS", "DRAKKAN", "REINFORCE", "SHADOW", "PRIEST", "TREE", "CLONE", "ARCHER")
for k in sorted(pairs):
    if any(n in k for n in need) and ("_NAME" in k or "MENUBOTTOM" in k):
        if "_DESC" in k or "_NOTE" in k:
            continue
        print("%s=%s" % (k, pairs[k]))
