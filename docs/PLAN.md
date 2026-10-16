# KR6 DPS 统计 — 方向与验证

## 结论（已验证）

| 项 | 结论 |
|----|------|
| 引擎 | LÖVE + LuaJIT，脚本在 fused exe 尾部 zip |
| 注入 | 覆盖存档目录 `all/director.lua`（与 kr6-trainer 同路），**不改游戏安装目录** |
| 伤害采样点 | `systems.health.on_update` 处理完 `store.damage_queue` 后读 `damage_applied` + `source_id` |
| 归因 | tower / hero / user_power（及 soldier.tower_id、aura/mod.source_id 回跳） |
| **上次面板看不见的根因** | 游戏 `setColor` 用 **0–255**；我们用了 **0–1** → 背景/文字几乎全透明 |
| 存档安全 | 模组**只写** `all/director.lua`、`_kr6dmg*.lua`、`_orig/`、诊断/CSV；**永不写** `slot_*.lua` / `global.lua` / `settings.lua` / `cache.lua` |

## 与 opensteamtool

- 云同步管的是 `slot*.lua`；模组文件不在 AutoCloud 规则里。
- 探针/正式版都加写保护：禁止 `io.open` 打开 slot/global/settings/cache。

## 验证阶段（probe）

1. 注入：启动后写 `_kr6dmg_probe.log` heartbeat  
2. 伤害：进关打怪后 log 出现 `DMG cat=... key=... amt=...`  
3. 绘制：右上角亮黄条 + `KR6 DMG OK`（0–255 色）  
4. 确认无改动 `slot_1.lua` 的 mtime（除游戏自己存档外）

## 正式版（2026-10-13 已写入并部署）

- 粒度：塔类型 / 英雄 / 法术  
- F8 面板、F9 CSV、F10 清零、换关重置并可选导出  
- 色值全程 0–255，无圆角 rect  
- 归因：`bullet.source_id` / `xp_dest_id` 回跳 + 模板名启发式  
- 待用户重启进关确认 `_kr6dmg.log` 中 cat 已分三类  

```bat
python install.py --game-dir "D:\steam\steamapps\common\Kingdom Rush Genesis"
python test_classify.py
```

