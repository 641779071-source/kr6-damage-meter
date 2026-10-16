#!/usr/bin/env python3
"""Offline check of template-name heuristics used by _kr6dmg.lua classify_template."""
import re
import sys

CASES = [
    ("bullet_power_rain_of_fire", "spell", "power_rain_of_fire"),
    ("power_rain_of_fire", "spell", "power_rain_of_fire"),
    ("bullet_archers_lvl1", "tower", "archers"),
    ("bullet_mages_lvl3", "tower", "mages"),
    ("bullet_bolin", "hero", "hero_bolin"),
    ("hero_bolin", "hero", "hero_bolin"),
    ("tower_archers_lvl2", "tower", "archers"),
    ("bullet_hero_bolin", "hero", "hero_bolin"),
]


def classify_template(name: str):
    n = name or ""
    if not n:
        return None
    m = re.match(r"^bullet_(power_.+)$", n) or re.match(r"^(power_.+)$", n)
    if m:
        power = re.sub(r"_(control|dmg|hit)$", "", m.group(1))
        return "spell", power
    m = re.match(r"^(hero_[a-z0-9]+)", n) or re.match(r"^bullet_(hero_[a-z0-9]+)", n)
    if m:
        return "hero", m.group(1)
    m = re.match(r"^tower_([a-z0-9_]+)", n)
    if m:
        tw = re.sub(r"_lvl\d+.*$", "", m.group(1))
        tw = re.sub(r"_level_\d+.*$", "", tw)
        if tw not in ("holder", "build_animation"):
            return "tower", tw
    m = re.match(r"^bullet_([a-z0-9_]+)_lvl\d+", n)
    if m:
        return "tower", m.group(1)
    m = re.match(r"^bullet_([a-z][a-z0-9]*)$", n)
    if m and m.group(1) != "power":
        return "hero", "hero_" + m.group(1)
    return None


def main():
    bad = 0
    for name, want_cat, want_key in CASES:
        got = classify_template(name)
        if got != (want_cat, want_key):
            print("FAIL", name, "got", got, "want", (want_cat, want_key))
            bad += 1
        else:
            print("OK  ", name, "->", got)
    if bad:
        print("%d failed" % bad)
        return 1
    print("all %d cases passed" % len(CASES))
    return 0


if __name__ == "__main__":
    sys.exit(main())
