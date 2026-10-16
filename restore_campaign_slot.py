#!/usr/bin/env python3
"""Rebuild slot_1.lua to a full campaign clear (18 stages x 3 stars).

Does NOT invent Iron/Heroic/Impossible clears unless --all-modes.
Keeps existing heroes/powers/towers/upgrades from the current slot.
Backs up the current file first.
"""
from __future__ import annotations

import argparse
import os
import re
import shutil
import time

DEFAULT_SLOT = os.path.join(
    os.environ.get("APPDATA", ""), "kingdom_rush_genesis", "slot_1.lua"
)
CAMPAIGN_LEVELS = 18
STARS_PER_LEVEL = 3


def load_lua_table(path: str) -> str:
    return open(path, "r", encoding="utf-8").read()


def replace_or_insert_levels(src: str, n_levels: int, stars: int, difficulty: int) -> str:
    # Build levels block matching game style
    lines = ['\t["levels"] = {']
    for i in range(1, n_levels + 1):
        lines.append(f"\t\t[{i}] = {{")
        lines.append(f"\t\t\t[1] = {difficulty};")
        lines.append(f'\t\t\t["stars"] = {stars};')
        lines.append("\t\t};")
    lines.append("\t};")
    block = "\n".join(lines)

    pat = re.compile(r'\t\["levels"\]\s*=\s*\{.*?\n\t\};', re.S)
    if not pat.search(src):
        raise SystemExit("error: cannot find levels block in slot")
    return pat.sub(block, src, count=1)


def set_counter(src: str, key: str, value: int) -> str:
    pat = re.compile(rf'(\["{re.escape(key)}"\]\s*=\s*)\d+')
    if pat.search(src):
        return pat.sub(rf"\g<1>{value}", src, count=1)
    # insert into achievement_counters
    pat2 = re.compile(r'(\["achievement_counters"\]\s*=\s*\{)')
    if pat2.search(src):
        return pat2.sub(
            rf'\1\n\t\t["{key}"] = {value};', src, count=1
        )
    return src


def set_last_stars(src: str, value: int) -> str:
    pat = re.compile(r'(\["last_stars"\]\s*=\s*)\d+')
    if pat.search(src):
        # keep last_stars BELOW real total so game can grant unlocks
        return pat.sub(rf"\g<1>{value}", src, count=1)
    return src


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--slot", default=DEFAULT_SLOT)
    ap.add_argument("--levels", type=int, default=CAMPAIGN_LEVELS)
    ap.add_argument("--difficulty", type=int, default=1,
                    help="campaign difficulty flag written as levels[i][1]")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    if not os.path.isfile(args.slot):
        raise SystemExit("error: slot not found: %s" % args.slot)

    src = load_lua_table(args.slot)
    total = args.levels * STARS_PER_LEVEL
    out = replace_or_insert_levels(src, args.levels, STARS_PER_LEVEL, args.difficulty)
    out = set_counter(out, "YOURE_AN_ALL_STAR", total)
    # leave last_stars low so in-game reward path can fire
    out = set_last_stars(out, 0)

    bak = args.slot + ".bak_%s" % time.strftime("%Y%m%d_%H%M%S")
    print("slot   :", args.slot)
    print("backup :", bak)
    print("levels :", args.levels, "x", STARS_PER_LEVEL, "=", total, "stars")

    if args.dry_run:
        print("dry-run: not writing")
        print(out[:800])
        return

    shutil.copy2(args.slot, bak)
    with open(args.slot, "w", encoding="utf-8", newline="\n") as f:
        f.write(out)
    print("written. Restart the game. If Steam Cloud prompts, choose LOCAL file.")


if __name__ == "__main__":
    main()
