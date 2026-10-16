#!/usr/bin/env python3
"""
kr6-damage-meter 卸载器。

只删伤害统计模组写入存档目录的文件，不动游戏存档。
若同时装了 kr6-trainer，卸载本模组时会保留 trainer 相关文件
（但会移除共用的 all/director.lua 覆盖桩 —— 需重装 trainer）。

    python uninstall.py
    python uninstall.py --dry-run
"""
import argparse
import os
import shutil
import sys

DEFAULT_IDENTITY = "kingdom_rush_genesis"

OUR_FILES = [
    "all/director.lua",
    "_kr6dmg.lua",
    "_kr6dmg_probe.lua",
    "_kr6dmg_boot.txt",
    "_kr6dmg_err.txt",
    "_kr6dmg_probe_boot.txt",
    "_kr6dmg_probe.log",
    "_kr6_shadow_err_all_director_lua.txt",
]
OUR_DIRS = ["_orig"]
OUR_PREFIXES = ("_kr6dmg", "damage_")
KEEP_PREFIXES = ("_kr6_slot_backup", "_kr6_global_backup", "_kr6trainer", "slot_")

PROTECTED = ("cache.lua", "global.lua", "settings.lua", "steam_autocloud.vdf")


def default_save_dir(identity):
    # 与 install.py 同一套规则：Windows 走 %APPDATA%，macOS 走 ~/Library/Application Support
    if sys.platform == "darwin":
        home = os.environ.get("HOME")
        if not home:
            sys.exit("error: HOME is not set; pass --save-dir explicitly")
        return os.path.join(home, "Library", "Application Support", identity)
    appdata = os.environ.get("APPDATA")
    if not appdata:
        sys.exit("error: APPDATA is not set; pass --save-dir explicitly")
    return os.path.join(appdata, identity)


def looks_like_save_dir(path):
    if not os.path.isdir(path):
        return False
    for name in os.listdir(path):
        if name in ("settings.lua", "global.lua", "cache.lua", "steam_autocloud.vdf"):
            return True
        if name.startswith("slot_") and name.endswith(".lua"):
            return True
    return False


def main():
    ap = argparse.ArgumentParser(description="Remove the KR6 trainer mod.")
    ap.add_argument("--save-dir")
    ap.add_argument("--identity", default=DEFAULT_IDENTITY)
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--force", action="store_true",
                    help="skip the 'does this look like the save dir' check")
    args = ap.parse_args()

    save_dir = args.save_dir or default_save_dir(args.identity)
    if not os.path.isdir(save_dir):
        sys.exit("nothing to do: %s does not exist" % save_dir)
    if not args.force and not looks_like_save_dir(save_dir):
        sys.exit("refusing to touch %s: it does not look like the game's save "
                 "directory (use --force to override)" % save_dir)

    victims = []
    kept = []
    for rel in OUR_FILES:
        p = os.path.join(save_dir, rel)
        if os.path.isfile(p):
            victims.append(p)
    for rel in OUR_DIRS:
        p = os.path.join(save_dir, rel)
        if os.path.isdir(p):
            victims.append(p)
    for name in sorted(os.listdir(save_dir)):
        if name in PROTECTED:
            continue
        if name.startswith(KEEP_PREFIXES):
            kept.append(name)
            continue
        if name.startswith(OUR_PREFIXES):
            p = os.path.join(save_dir, name)
            if p not in victims:
                victims.append(p)

    if not victims and not kept:
        print("nothing to remove - the mod does not appear to be installed here")
        print("(save dir: %s)" % save_dir)
        return

    print("save dir: %s" % save_dir)
    for p in victims:
        kind = "dir " if os.path.isdir(p) else "file"
        print("  %s %s" % (kind, os.path.relpath(p, save_dir)))
    if kept:
        print("\nkeeping (these are YOUR save backups, not the mod's files):")
        for name in kept:
            print("  file %s" % name)
    if args.dry_run:
        print("\ndry run: nothing deleted")
        return

    for p in victims:
        if os.path.isdir(p):
            shutil.rmtree(p)
        else:
            os.remove(p)
    # 覆盖桩的父目录如果空了就一并删掉
    all_dir = os.path.join(save_dir, "all")
    if os.path.isdir(all_dir) and not os.listdir(all_dir):
        os.rmdir(all_dir)
    print("\nremoved %d item(s). The game is back to stock." % len(victims))
    if kept:
        print("left %d save backup(s) in place." % len(kept))


if __name__ == "__main__":
    main()
