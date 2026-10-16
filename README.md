# kr6-damage-meter

非官方模组：给 Steam 版 *Kingdom Rush 6: Genesis TD* 做关卡伤害统计（塔 / 英雄 / 法术）。

- **不修改**游戏安装目录  
- 只往 LÖVE 存档目录写入覆盖文件（`all/director.lua` + `_kr6dmg.lua`）  
- 原始 `director` 字节码在安装时从**玩家本机** exe 提取，仓库不分发任何游戏代码  

与 Ironhide 无关。自行承担使用风险。

## 要求

- Windows（主要）或 macOS  
- 已安装 [Python 3](https://www.python.org/)  
- Steam 正版游戏  

## 安装

```bat
git clone https://github.com/641779071-source/kr6-damage-meter.git
cd kr6-damage-meter
python install.py --game-dir "D:\steam\steamapps\common\Kingdom Rush Genesis"
```

把 `--game-dir` 换成你的游戏目录。也可双击 `install.bat`（能自动找到游戏时）。

装完后**完全退出再开游戏**（第一次必须）。之后改模组可用游戏内 **F7** 热重载，或再跑一次 `install.py`。

## 使用

| 键 | 作用 |
|----|------|
| **F7** | 热重载模组（读存档目录里的 `_kr6dmg.lua`） |
| **F8** | 开关右侧伤害面板 |
| **F9** | 导出 CSV 到存档目录 |
| **F10** | 清空本关统计 |

- 进关后自动累计；面板尽量用游戏官方中文名  
- 换关时自动导出上一关 CSV 并重置  
- 文件位置：`%APPDATA%\kingdom_rush_genesis\`（macOS：`~/Library/Application Support/kingdom_rush_genesis/`）

## 卸载

```bat
python uninstall.py
```

或双击 `uninstall.bat`。只删模组文件，不动 `slot_*.lua` 存档。

## 与 kr6-trainer 共存

覆盖桩会顺带加载已存在的 `_kr6trainer.lua`。  
先装 trainer 再装本模组：重装本模组即可。  
卸载本模组后若还要用 trainer：需重装 trainer（共用 `all/director.lua`）。

## 原理（简）

挂接 `systems.health.on_update`，在引擎算完 `damage_applied` 后采样，再沿 `bullet.source_id` / 模板名归因到塔、英雄、法术。

## License

MIT — 见 [LICENSE](LICENSE)。
