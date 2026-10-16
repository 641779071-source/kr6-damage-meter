# -*- coding: utf-8 -*-
import re
path = r"D:\cursor项目\kr6-extract\output\zh-Hans.lua"
text = open(path, encoding="utf-8", errors="replace").read()
pairs = dict(re.findall(r'\b([A-Z][A-Z0-9_]*)\s*=\s*"([^"]*)"', text))
for k in sorted(pairs):
    if re.match(r"^TOWER_[A-Z0-9]+_NAME$", k) or re.match(r"^HERO_[A-Z0-9]+_NAME$", k) or re.match(r"^POWER_[A-Z0-9_]+_NAME$", k):
        if "_SKILL_" in k or "_TALENT_" in k or re.search(r"_L\d", k):
            continue
        print(k + "=" + pairs[k])
