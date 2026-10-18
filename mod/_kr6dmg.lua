-- Kingdom Rush Genesis — damage meter (tower / hero / spell)
-- Colors 0-255. Official i18n names via _(). F7 hot-reload. F8/F9/F10.
-- Never writes slot_*.lua / global.lua / settings.lua / cache.lua.
local virt, mod = ...

local FORBIDDEN = {
  ["slot_1.lua"] = true, ["slot_2.lua"] = true, ["slot_3.lua"] = true,
  ["global.lua"] = true, ["settings.lua"] = true, ["cache.lua"] = true,
  ["steam_autocloud.vdf"] = true,
}

local GEN = (type(_G.__kr6dmg_gen) == "number" and _G.__kr6dmg_gen or 0) + 1
_G.__kr6dmg_gen = GEN

local function ansi_path(p)
  if type(jit) ~= "table" or jit.os ~= "Windows" then return nil end
  local ok, ffi = pcall(require, "ffi")
  if not ok then return nil end
  pcall(ffi.cdef, "int MultiByteToWideChar(unsigned int, unsigned long, const char*, int, void*, int);")
  pcall(ffi.cdef, "int WideCharToMultiByte(unsigned int, unsigned long, const void*, int, char*, int, const char*, int*);")
  local n = ffi.C.MultiByteToWideChar(65001, 0, p, -1, nil, 0)
  if n <= 0 then return nil end
  local w = ffi.new("wchar_t[?]", n)
  if ffi.C.MultiByteToWideChar(65001, 0, p, -1, w, n) <= 0 then return nil end
  local m = ffi.C.WideCharToMultiByte(0, 0, w, -1, nil, 0, nil, nil)
  if m <= 0 then return nil end
  local a = ffi.new("char[?]", m)
  if ffi.C.WideCharToMultiByte(0, 0, w, -1, a, m, nil, nil) <= 0 then return nil end
  return ffi.string(a, m - 1)
end

local function usable(p)
  local f = io.open(p .. "_kr6_probe.tmp", "wb")
  if not f then return false end
  f:close()
  os.remove(p .. "_kr6_probe.tmp")
  return true
end

local SAVE_DIR
local function save_dir()
  if SAVE_DIR then return SAVE_DIR end
  local lfs = (type(love) == "table") and love.filesystem
  local p
  if lfs and lfs.getSaveDirectory then
    local ok, d = pcall(lfs.getSaveDirectory)
    if ok and type(d) == "string" and d ~= "" then p = (d:gsub("/+$", "")) .. "/" end
  end
  local best = (p and usable(p)) and p or nil
  if not best and p then
    local a = ansi_path(p)
    if a and usable(a) then best = a end
  end
  if not best then
    local base = os.getenv("APPDATA")
    if base then best = base .. "/kingdom_rush_genesis/" end
  end
  SAVE_DIR = best or p or "./"
  return SAVE_DIR
end

local function safe_name(name)
  local base = tostring(name):match("([^/\\]+)$") or tostring(name)
  if FORBIDDEN[base] then return nil end
  if base:match("^slot_%d+%.lua$") then return nil end
  return base
end

local function wf(name, txt)
  local base = safe_name(name)
  if not base then return false end
  local f = io.open(save_dir() .. base, "wb")
  if not f then return false end
  f:write(txt)
  f:close()
  return true
end

local function append(name, text)
  local base = safe_name(name)
  if not base then return false end
  local f = io.open(save_dir() .. base, "ab")
  if not f then return false end
  f:write(text)
  f:close()
  return true
end

local function record_err(where, err)
  append("_kr6dmg_err.txt", tostring(where) .. ": " .. tostring(err) .. "\n")
end

-- Keep stats across hot-reload when possible.
local S = _G.__kr6dmg
if type(S) ~= "table" then
  S = {
    panel_open = true,
    last_key = nil,
    last_key_t = 0,
    level_key = nil,
    totals = { tower = {}, hero = {}, spell = {}, other = {} },
    hits = { tower = {}, hero = {}, spell = {}, other = {} },
    grand = 0,
    samples = 0,
    skipped_enemy = 0,
    msg = "",
    msg_ts = 0,
    font = nil,
    font_path = nil,
    name_cache = {},
    -- 淘金矮人黄金
    miner_gold_seen = {},
    miner_gold_session = 0,
    miner_gold_live = 0,
    miner_gold_towers = 0,
    miner_gold_ticks = 0,
    miner_dumped = false,
  }
  _G.__kr6dmg = S
end
S.mod = (type(mod) == "table") and mod or S.mod
S.virt = tostring(virt or S.virt or "all/director.lua")
S.gen = GEN
S.drew = false
if type(S.totals) ~= "table" then
  S.totals = { tower = {}, hero = {}, spell = {}, other = {} }
end
if type(S.hits) ~= "table" then
  S.hits = { tower = {}, hero = {}, spell = {}, other = {} }
end
S.name_cache = type(S.name_cache) == "table" and S.name_cache or {}
S.miner_gold_seen = type(S.miner_gold_seen) == "table" and S.miner_gold_seen or {}
S.miner_gold_session = tonumber(S.miner_gold_session) or 0
S.miner_gold_live = tonumber(S.miner_gold_live) or 0
S.miner_gold_towers = tonumber(S.miner_gold_towers) or 0
S.miner_gold_ticks = tonumber(S.miner_gold_ticks) or 0

local function note(msg)
  S.msg = tostring(msg)
  S.msg_ts = os.time()
end

local function reset_stats()
  S.totals = { tower = {}, hero = {}, spell = {}, other = {} }
  S.hits = { tower = {}, hero = {}, spell = {}, other = {} }
  S.grand = 0
  S.samples = 0
  S.skipped_enemy = 0
  S.name_cache = {}
  S.miner_gold_seen = {}
  S.miner_gold_session = 0
  S.miner_gold_live = 0
  S.miner_gold_towers = 0
  S.miner_gold_ticks = 0
  S.miner_dumped = false
end

local function add_stat(cat, key, amount)
  if type(amount) ~= "number" or amount <= 0 then return end
  if type(key) ~= "string" or key == "" then key = "unknown" end
  local t = S.totals[cat]
  local h = S.hits[cat]
  if not t then
    cat = "other"
    t = S.totals.other
    h = S.hits.other
  end
  t[key] = (t[key] or 0) + amount
  h[key] = (h[key] or 0) + 1
  S.grand = S.grand + amount
  S.samples = S.samples + 1
end

local function store_of()
  local g = _G.game
  if type(g) == "table" then
    if type(g.store) == "table" then return g.store end
    if type(g.simulation) == "table" and type(g.simulation.store) == "table" then
      return g.simulation.store
    end
  end
  local d = _G.director
  if type(d) == "table" and type(d.active_item) == "table" and type(d.active_item.store) == "table" then
    return d.active_item.store
  end
  return nil
end

local function game_mod(name)
  local ok, m = pcall(require, name)
  if ok and type(m) == "table" then return m end
  m = package.loaded[name]
  if type(m) == "table" then return m end
  return nil
end

-- Official game translation via global _() from i18n.
local function i18n(key)
  if type(key) ~= "string" or key == "" then return nil end
  local tr = rawget(_G, "_")
  if type(tr) ~= "function" then
    local ok, i18n_mod = pcall(require, "i18n")
    if ok and type(i18n_mod) == "table" then
      tr = i18n_mod.translate or i18n_mod.t or rawget(_G, "_")
    end
  end
  if type(tr) ~= "function" then return nil end
  local ok, s = pcall(tr, key)
  if not ok or type(s) ~= "string" or s == "" or s == key then return nil end
  return s
end

local function upper_key(s)
  return tostring(s or ""):upper():gsub("[^A-Z0-9]+", "_")
end

-- Official strings missing for some stage allies / odd keys → Chinese fallback.
local FALLBACK_ZH = {
  hero_nivus = "纽维斯",
  nivus = "纽维斯",
  nivus_book = "纽维斯",
  controller_stage_06_nivus = "纽维斯",
  reinforcement_base = "援军",
  reinforcements = "援军",
  power_reinforcements = "援军",
  bullet_drakkan_clone = "魔龙分身",
  hero_drakkan_clone = "魔龙分身",
  bullet_nivus_magic_missiles = "纽维斯",
  bullet_shadow_archer = "暗影弓手",
  crossbows_basic = "诅咒弩手",
  ranger = "精灵精英游侠",
  hero_ranger = "精灵精英游侠",
  ranger_skill_c_bounce_clone = "精灵精英游侠",
  templar_archer = "圣殿弓手",
  bullet_templar_archer = "圣殿弓手",
  ally_templar_archer = "圣殿弓手",
  soldier_stage_08_templar_archer = "圣殿弓手",
  stage_08_templar_swordsman = "圣殿剑士",
  ally_templar_swordsman = "圣殿剑士",
  soldier_stage_08_templar_swordsman = "圣殿剑士",
  mod_stage_08_templar = "圣殿骑士",
  ally_templar = "圣殿骑士",
  broken_stage_08 = "毁损的防御塔",
  aura_tree_attack_lvl1 = "异木守卫",
  aura_tree_attack_lvl2 = "异木守卫",
  aura_tree_attack_lvl3 = "异木守卫",
  aura_tree_attack_lvl4 = "异木守卫",
  stage_hazard = "关卡机制",
  aura_pillar_stage_09_damage = "关卡机制",
  -- 旧版正则把 hero_stage_05_alleria 截成 hero_stage；完整 key 走官方 i18n
  hero_stage = "关卡英雄",
  hero_stage_05_alleria = "艾莉瑞雅",
  hero_stage_15_lord_blackburn = "布莱克本领主",
  hero_stage_18_denas = "迪纳斯王子",
  -- 第16关树精盟友（无官方 TOWER_STAGE_16_* 键）
  stage_16_treant_killer = "嗜杀树精",
  stage_16_treant_attacker = "进攻树精",
  stage_16_treant_healer = "治愈树精",
  stage_16_treant_rooter = "缠根树精",
  tower_stage_16_treant_killer = "嗜杀树精",
  tower_stage_16_treant_attacker = "进攻树精",
  tower_stage_16_treant_healer = "治愈树精",
  tower_stage_16_treant_rooter = "缠根树精",
  bullet_stage_16_treant_killer_bomb = "嗜杀树精",
  bullet_stage_16_treant_attacker_bomb = "进攻树精",
  aura_stage_16_treant_attacker_bomb_damage = "进攻树精",
  aura_stage_16_treant_healer_heal = "治愈树精",
  aura_stage_16_treant_rooter_slow = "缠根树精",
  mod_stage_16_treant_killer_tangle = "嗜杀树精",
  mod_stage_16_treant_healer_heal = "治愈树精",
  mod_stage_16_treant_rooter_slow = "缠根树精",
}

-- Known tower stems: skill/aura templates must not be treated as heroes.
local TOWER_STEMS = {
  ranger = true, crossbows = true, knights = true, tree = true,
  light_priestess = true, priestess = true, archers = true, mages = true,
  engineers = true, barracks = true, dwarves = true, musketeers = true,
  arcane = true, sorcerer = true, assassin = true, templar = true,
  mechs = true, artillery = true, big_bertha = true, tesla = true,
  miners = true,
}

local function display_name(cat, key)
  local cache_k = tostring(cat) .. "|" .. tostring(key)
  local cached = S.name_cache[cache_k]
  if cached then return cached end

  local raw = tostring(key or "")
  local cands = {}
  local function add(k) if k and k ~= "" then cands[#cands + 1] = k end end

  if cat == "tower" then
    local u = upper_key(raw)
    add("TOWER_" .. u .. "_NAME")
    if u:sub(-1) == "S" then add("TOWER_" .. u:sub(1, -2) .. "_NAME")
    else add("TOWER_" .. u .. "S_NAME") end
    -- light_priestess also has TOWER_PRIESTESS_* keys in some locales
    if raw:find("priestess") then add("TOWER_LIGHT_PRIESTESS_NAME"); add("TOWER_PRIESTESS_1_NAME") end
    -- stage_14_armory / broken_stage_08
    local sn, rest = raw:match("^stage_(%d+)_(.+)$")
    if sn and rest then
      add("TOWER_STAGE_" .. sn .. "_" .. upper_key(rest) .. "_NAME")
      add("TOWER_STAGE_" .. sn .. "_BROKEN_" .. upper_key(rest) .. "_NAME")
    end
    local bsn = raw:match("^broken_stage_(%d+)$")
    if bsn then add("TOWER_BROKEN_NAME"); add("TOWER_STAGE_" .. bsn .. "_BROKEN_ARMORY_NAME") end
    if raw:find("broken") then add("TOWER_BROKEN_NAME") end
    if raw:find("templar_swordsman") or raw:find("templar_sworsdman") then
      add("SOLDIER_STAGE_08_TEMPLAR_SWORSDMAN_1_NAME")
    end
  elseif cat == "hero" then
    -- hero_stage_05_alleria → HERO_STAGE_05_ALLERIA_NAME
    local sn, srest = raw:match("^hero_stage_(%d+)_(.+)$")
    if sn and srest then
      add("HERO_STAGE_" .. sn .. "_" .. upper_key(srest) .. "_NAME")
    end
    local h = raw:match("^hero_(.+)") or raw:match("^ally_(.+)") or raw
    local u = upper_key(h)
    add("HERO_" .. u .. "_NAME")
    add("HERO_" .. u .. "_CLONE_NAME")
    -- bare alleria / denas / lord_blackburn
    add("HERO_STAGE_05_" .. u .. "_NAME")
    add("HERO_STAGE_15_" .. u .. "_NAME")
    add("HERO_STAGE_18_" .. u .. "_NAME")
    if raw:find("templar_swordsman") or raw:find("templar_sworsdman") then
      add("SOLDIER_STAGE_08_TEMPLAR_SWORSDMAN_1_NAME")
    end
  elseif cat == "spell" then
    local p = raw:gsub("^power_", "")
    local u = upper_key(p)
    add("POWER_" .. u .. "_NAME")
    add("POWER_" .. u .. "_MENUBOTTOM_NAME")
    if p:find("reinforcement") then
      add("POWER_REINFORCEMENTS_NAME")
      add("POWER_REINFORCEMENTS_MENUBOTTOM_NAME")
    end
  else
    -- other: try enemy / soldier / strip bullet_
    local u = upper_key(raw:gsub("^bullet_", ""):gsub("^soldier_", ""):gsub("^mod_", ""))
    add("ENEMY_" .. u .. "_NAME")
    add("SOLDIER_" .. u .. "_NAME")
    add("HERO_" .. u .. "_NAME")
    add("TOWER_" .. u .. "_NAME")
    add("POWER_" .. u .. "_NAME")
    local sn, rest = raw:match("stage_(%d+)_(.+)$")
    if sn and rest then
      add("TOWER_STAGE_" .. sn .. "_" .. upper_key(rest) .. "_NAME")
      add("SOLDIER_STAGE_" .. sn .. "_" .. upper_key(rest) .. "_1_NAME")
      add("SOLDIER_STAGE_" .. sn .. "_" .. upper_key(rest) .. "_NAME")
    end
  end

  for i = 1, #cands do
    local s = i18n(cands[i])
    if s then
      S.name_cache[cache_k] = s
      return s
    end
  end

  local fb = FALLBACK_ZH[raw] or FALLBACK_ZH[raw:gsub("^bullet_", "")] or FALLBACK_ZH[raw:gsub("^hero_", "hero_")]
  if not fb and raw:find("nivus") then fb = "纽维斯" end
  if not fb and raw:find("reinforcement") then fb = "援军" end
  if not fb and raw:find("drakkan") then fb = i18n("HERO_DRAKKAN_NAME") or "德拉坎" end
  if not fb and raw:find("tree") then fb = i18n("TOWER_TREE_NAME") or "异木守卫" end
  if not fb and raw:find("crossbow") then fb = i18n("TOWER_CROSSBOWS_NAME") or "诅咒弩手" end
  if not fb and raw:find("knight") then fb = i18n("TOWER_KNIGHTS_NAME") or "守卫骑士团" end
  if not fb and raw:find("priest") then fb = i18n("TOWER_LIGHT_PRIESTESS_NAME") or "光明女祭司" end
  if not fb and raw:find("ranger") then fb = i18n("TOWER_RANGER_NAME") or "精灵精英游侠" end
  if not fb and raw:find("miner") then fb = i18n("TOWER_MINERS_NAME") or "淘金矮人" end
  if not fb and raw:find("templar_archer") then fb = "圣殿弓手" end
  if not fb and (raw:find("templar_swordsman") or raw:find("templar_sworsdman")) then fb = "圣殿剑士" end
  if not fb and raw:find("templar") then fb = "圣殿骑士" end
  if not fb and raw:find("broken_stage") then fb = i18n("TOWER_BROKEN_NAME") or "毁损的防御塔" end
  if not fb and raw:find("broken") then fb = i18n("TOWER_BROKEN_NAME") or "毁损的防御塔" end
  if not fb and raw:find("armory") then fb = i18n("TOWER_STAGE_14_ARMORY_NAME") or "军械库" end
  if not fb and raw:find("blacksmith") then fb = i18n("TOWER_STAGE_14_BLACKSMITH_NAME") or "铁匠铺" end
  if not fb and raw:find("wizard") then fb = i18n("TOWER_WIZARD_NAME") or "魔法学会" end
  if not fb and raw:find("alleria") then fb = i18n("HERO_STAGE_05_ALLERIA_NAME") or "艾莉瑞雅" end
  if not fb and raw:find("blackburn") then fb = i18n("HERO_STAGE_15_LORD_BLACKBURN_NAME") or "布莱克本领主" end
  if not fb and raw:find("denas") then fb = i18n("HERO_STAGE_18_DENAS_NAME") or "迪纳斯王子" end
  if not fb and raw:find("hero_stage") then fb = "关卡英雄" end
  if not fb and raw:find("treant_killer") then fb = "嗜杀树精" end
  if not fb and raw:find("treant_attacker") then fb = "进攻树精" end
  if not fb and raw:find("treant_healer") then fb = "治愈树精" end
  if not fb and raw:find("treant_rooter") then fb = "缠根树精" end
  if not fb and raw:find("stage_%d+_treant") then fb = "关卡树精" end
  -- last resort: if still ascii template, try parent token as tower/hero
  if not fb and raw:match("^[a-z0-9_]+$") then
    local base = raw:match("^aura_([a-z0-9]+)_") or raw:match("^bullet_([a-z0-9]+)_")
        or raw:match("^mod_([a-z0-9]+)_") or raw:match("^(hero_stage_%d+_[a-z0-9_]+)")
        or raw:match("^hero_([a-z0-9]+)")
        or raw:match("^([a-z][a-z0-9]*)_skill")
        or raw:match("^(stage_%d+_[a-z0-9_]+)")
        or raw:gsub("_basic$", ""):gsub("_ult$", ""):gsub("_lvl%d+.*$", "")
    if base then
      local b = base:gsub("^hero_", "")
      local sn, srest = base:match("^hero_stage_(%d+)_(.+)$")
      if sn and srest then
        fb = i18n("HERO_STAGE_" .. sn .. "_" .. upper_key(srest) .. "_NAME")
      end
      if not fb then
        fb = i18n("TOWER_" .. upper_key(base) .. "_NAME")
          or i18n("HERO_" .. upper_key(b) .. "_NAME")
          or i18n("HERO_" .. upper_key(base) .. "_NAME")
          or i18n("POWER_" .. upper_key(base) .. "_NAME")
          or i18n("SOLDIER_" .. upper_key(base) .. "_1_NAME")
      end
    end
  end
  if fb then
    S.name_cache[cache_k] = fb
    return fb
  end

  S.name_cache[cache_k] = raw
  return raw
end

local function clean_tower_type(t)
  t = tostring(t or "")
  if t == "" or t == "holder" or t == "build_animation" then return nil end
  -- ranger_skill_c_bounce_clone / crossbows_basic / knights_ult → base type
  local stem = t:match("^([a-z][a-z0-9]*)_skill") or t:match("^([a-z][a-z0-9]*)_ult")
  if stem and (TOWER_STEMS[stem] or i18n("TOWER_" .. upper_key(stem) .. "_NAME")) then
    return stem
  end
  t = t:gsub("_basic$", ""):gsub("_ult$", ""):gsub("_ultimate$", "")
      :gsub("_advanced$", ""):gsub("_lvl%d+.*$", ""):gsub("_level_%d+.*$", "")
      :gsub("_skill_[a-z]_.*$", ""):gsub("_skill_.*$", "")
      :gsub("_bounce.*$", ""):gsub("_clone$", "")
  if t:find("reinforcement") then return nil end -- handled as spell elsewhere
  return t
end

local function as_tower_stem(name)
  local n = tostring(name or "")
  local stem = n:match("^([a-z][a-z0-9]*)")
  if not stem then return nil end
  if TOWER_STEMS[stem] or i18n("TOWER_" .. upper_key(stem) .. "_NAME") then
    return stem
  end
  return nil
end

local function normalize_tower_key(e)
  if type(e.tower) == "table" then
    local t = clean_tower_type(e.tower.type)
    if t then return t end
  end
  local n = tostring(e.template_name or "tower")
  n = n:gsub("^tower_", "")
  return clean_tower_type(n) or n:gsub("_lvl%d+.*$", ""):gsub("_level_%d+.*$", ""):gsub("_kr1$", "")
end

-- hero_stage_05_alleria 含下划线；旧正则 hero_[a-z0-9]+ 会截成 hero_stage
local function extract_hero_key(n)
  n = tostring(n or "")
  local core = n:match("^bullet_(.+)$") or n:match("^aura_(.+)$") or n:match("^mod_(.+)$") or n
  local stage = core:match("^(hero_stage_%d+_[a-z0-9_]+)")
  if stage then
    stage = stage:gsub("_skill.*$", ""):gsub("_ult.*$", ""):gsub("_clone.*$", "")
        :gsub("_attack.*$", ""):gsub("_basic.*$", "")
    return stage
  end
  return core:match("^(hero_[a-z0-9]+)")
end

local function normalize_hero_key(e)
  local n = tostring(e.template_name or "hero")
  return extract_hero_key(n) or n
end

local function normalize_spell_key(e)
  if type(e.user_power) == "table" and e.user_power.power_id ~= nil then
    return "power_" .. tostring(e.user_power.power_id)
  end
  local n = tostring(e.template_name or "spell")
  local base = n:match("^(?:bullet_)?(power_[a-z0-9_]+)") or n:match("^(power_[a-z0-9_]+)")
  if base then
    return base:gsub("_control$", ""):gsub("_dmg$", ""):gsub("_hit$", "")
  end
  return n
end

local function classify_template(name)
  local n = tostring(name or "")
  if n == "" then return nil end
  if n:find("^enemy_") then return "skip_enemy", n end

  -- Enemy projectiles / auras / mods:
  -- bullet_shadow_archer / aura_dark_sapper_death_explosion / mod_swamp_husk_poison
  do
    local after = n:match("^bullet_(.+)$") or n:match("^aura_(.+)$") or n:match("^mod_(.+)$")
    if after and not after:find("^power_") and not after:find("^tower_") and not after:find("^hero_") then
      local parts = {}
      for part in after:gmatch("[a-z0-9]+") do parts[#parts + 1] = part end
      local maxn = #parts
      if maxn > 6 then maxn = 6 end
      for len = maxn, 1, -1 do
        local cand = table.concat(parts, "_", 1, len)
        if i18n("ENEMY_" .. upper_key(cand) .. "_NAME") then
          return "skip_enemy", cand
        end
      end
    end
  end

  -- Stage controllers / allies: controller_stage_06_nivus, nivus_book
  if n:find("nivus") then
    return "hero", "hero_nivus"
  end
  -- Stage 08 templar allies
  if n:find("templar_archer") then
    return "hero", "ally_templar_archer"
  end
  if n:find("templar_swordsman") or n:find("templar_sworsdman") then
    return "hero", "ally_templar_swordsman"
  end
  if n:find("mod_stage_%d+_templar") or n:find("stage_%d+_templar") then
    if n:find("swordsman") or n:find("sworsdman") then
      return "hero", "ally_templar_swordsman"
    end
    if n:find("archer") then
      return "hero", "ally_templar_archer"
    end
    return "hero", "ally_templar_swordsman"
  end
  do
    local ctrl = n:match("^controller_stage_%d+_([a-z0-9]+)")
    if ctrl then return "hero", "hero_" .. ctrl end
  end
  -- 第16关树精盟友（须先于 stage_*damage 关卡机制判断）
  do
    local role = n:match("stage_16_treant_(killer|attacker|healer|rooter)")
    if role then
      return "tower", "stage_16_treant_" .. role
    end
  end
  -- Stage props / hazards: aura_pillar_stage_09_damage → 关卡机制
  if n:find("pillar_stage") or n:find("^aura_pillar")
     or (n:match("stage_%d+.*damage") and not n:find("treant")) then
    return "other", "stage_hazard"
  end
  -- broken_stage_08 / tower_broken → 毁损塔
  if n:find("broken_stage") or n:match("^broken_") then
    return "tower", "broken_stage_08"
  end
  -- stage special towers: stage_14_armory / tower_stage_14_armory
  do
    local st = n:match("^tower_(stage_%d+_[a-z0-9_]+)") or n:match("^(stage_%d+_[a-z0-9_]+)")
        or n:match("^bullet_(stage_%d+_[a-z0-9_]+)") or n:match("^aura_(stage_%d+_[a-z0-9_]+)")
        or n:match("^mod_(stage_%d+_[a-z0-9_]+)")
    if st then
      st = st:gsub("_lvl%d+.*$", ""):gsub("_level_%d+.*$", "")
          :gsub("_bomb.*$", ""):gsub("_heal.*$", ""):gsub("_slow.*$", "")
          :gsub("_tangle.*$", ""):gsub("_damage.*$", "")
      if st:find("templar") then
        if st:find("archer") then return "hero", "ally_templar_archer" end
        return "hero", "ally_templar_swordsman"
      end
      return "tower", st
    end
  end

  -- Reinforcements (power) often appear as tower.reinforcement_base / soldier_reinforcements_*
  if n:find("reinforcement") then
    return "spell", "power_reinforcements"
  end

  -- mod_bullet_power_rain_of_fire_burn / bullet_power_* / power_* → spell
  do
    local sp = n:match("(power_[a-z0-9_]+)")
    if sp then
      sp = sp:gsub("_burn$", ""):gsub("_control$", ""):gsub("_dmg$", ""):gsub("_hit$", "")
          :gsub("_effect$", ""):gsub("_dot$", ""):gsub("_aura$", "")
      return "spell", sp
    end
  end

  local hero = extract_hero_key(n)
  if hero then return "hero", hero end

  -- bullet_drakkan_clone / bullet_nivus_magic_missiles / bullet_bolin_xxx → hero_<name>
  do
    local h = n:match("^bullet_([a-z][a-z0-9]*)_")
    if h and h ~= "power" and h ~= "tower" and h ~= "enemy" and h ~= "shadow" then
      local hk = "hero_" .. h
      if i18n("HERO_" .. upper_key(h) .. "_NAME")
         or i18n("HERO_" .. upper_key(h) .. "_CLONE_NAME")
         or FALLBACK_ZH[hk] or FALLBACK_ZH[h]
         or h == "nivus" or h == "drakkan" or h == "bolin"
         or h == "gerald" or h == "malik" or h == "ignus" or h == "oni"
         or h == "connor" or h == "rhodes" or h == "zefira" or h == "illiana"
         or h == "myriath" or h == "ashbite" or h == "alleria" then
        return "hero", hk
      end
    end
  end

  -- Tower skill/aura/mod first: mod_ranger_skill_c_* / ranger_skill_c_bounce_clone
  do
    local tow = as_tower_stem(n:match("^aura_([a-z0-9_]+)") or n:match("^mod_([a-z0-9_]+)")
        or n:match("^bullet_([a-z0-9_]+)") or n)
    if tow and (n:find("_skill") or n:find("_bounce") or n:find("_attack") or n:find("_lvl")) then
      return "tower", tow
    end
  end

  -- aura_tree_attack_lvl2 → tower tree; aura_drakkan_skill_a → hero
  do
    local aura_tow = n:match("^aura_([a-z][a-z0-9]*)_attack")
        or n:match("^aura_([a-z][a-z0-9]*)_lvl")
    if aura_tow and aura_tow ~= "hero" and aura_tow ~= "enemy" then
      -- hero auras usually *_skill / *_ult; tower auras often *_attack
      if n:find("_attack") or i18n("TOWER_" .. upper_key(aura_tow) .. "_NAME") then
        return "tower", aura_tow
      end
    end
  end
  local aura_hero = n:match("^aura_([a-z][a-z0-9]*)_") or n:match("^mod_([a-z][a-z0-9]*)_")
  if aura_hero and aura_hero ~= "tower" and aura_hero ~= "enemy" then
    -- Prefer tower if stem is a tower (ranger_skill was wrongly hero before)
    local tow = as_tower_stem(aura_hero)
    if tow then return "tower", tow end
    if n:find("drakkan") or n:find("bolin") or n:find("hero")
       or n:find("gerald") or n:find("malik") or n:find("ignus")
       or n:find("oni") or n:find("alleria") or n:find("connor")
       or n:find("rhodes") or n:find("zefira") or n:find("illiana")
       or n:find("myriath") or n:find("ashbite") or n:find("nivus")
       or n:find("_skill") or n:find("_ult") then
      return "hero", "hero_" .. aura_hero
    end
  end
  local hero_from_aura = extract_hero_key(n:match("^aura_(.+)$") or n:match("^mod_(.+)$") or "")
  if hero_from_aura then return "hero", hero_from_aura end
  hero_from_aura = n:match("^aura_([a-z0-9]+)_skill") or n:match("^aura_([a-z0-9]+)_ult")
      or n:match("^mod_([a-z0-9]+)_skill")
  if hero_from_aura then
    local tow = as_tower_stem(hero_from_aura)
    if tow then return "tower", tow end
    return "hero", "hero_" .. hero_from_aura
  end

  -- bare ranger_skill_c_bounce_clone / crossbows_skill_*
  do
    local tow = as_tower_stem(n)
    if tow and (n:find("_skill") or n:find("_bounce") or n:find("_clone")) then
      return "tower", tow
    end
  end

  -- soldier_crossbows_ult / soldier_knights_xxx → tower
  local sol = n:match("^soldier_([a-z0-9_]+)")
  if sol then
    if sol:find("reinforcement") then return "spell", "power_reinforcements" end
    if sol:find("^nivus") then return "hero", "hero_nivus" end
    sol = clean_tower_type(sol) or sol:gsub("_ult.*$", ""):gsub("_lvl%d+.*$", ""):gsub("_%d+$", "")
    if sol ~= "" and not sol:find("^enemy") then
      return "tower", sol
    end
  end

  local tower_tpl = n:match("^tower_([a-z0-9_]+)")
  if tower_tpl then
    if tower_tpl:find("reinforcement") then return "spell", "power_reinforcements" end
    local cleaned = clean_tower_type(tower_tpl)
    if cleaned then return "tower", cleaned end
  end

  -- bare keys: reinforcement_base / crossbows_basic
  if n == "reinforcement_base" or n:find("^reinforcement") then
    return "spell", "power_reinforcements"
  end
  do
    local cleaned = clean_tower_type(n)
    if cleaned and cleaned ~= n and i18n("TOWER_" .. upper_key(cleaned) .. "_NAME") then
      return "tower", cleaned
    end
    if n:find("_basic$") or n:find("_ult$") then
      local base = clean_tower_type(n)
      if base then return "tower", base end
    end
  end

  local tower_bullet = n:match("^bullet_([a-z0-9_]+)_lvl%d+")
  if tower_bullet then return "tower", clean_tower_type(tower_bullet) or tower_bullet end

  local simple = n:match("^bullet_([a-z][a-z0-9]*)$")
  if simple and simple ~= "power" then
    return "hero", "hero_" .. simple
  end

  return nil
end

local function push_id(list, seen, id)
  if id == nil or seen[id] then return end
  seen[id] = true
  list[#list + 1] = id
end

local function collect_parent_ids(e)
  local ids, seen = {}, {}
  if type(e.bullet) == "table" then
    push_id(ids, seen, e.bullet.source_id)
    push_id(ids, seen, e.bullet.xp_dest_id)
    push_id(ids, seen, e.bullet.from_id)
  end
  if type(e.soldier) == "table" then
    push_id(ids, seen, e.soldier.tower_id)
  end
  if type(e.modifier) == "table" then
    push_id(ids, seen, e.modifier.source_id)
  end
  if type(e.aura) == "table" then
    push_id(ids, seen, e.aura.source_id)
    push_id(ids, seen, e.aura.xp_dest_id)
  end
  if type(e.spell) == "table" then
    push_id(ids, seen, e.spell.source_id)
  end
  push_id(ids, seen, e.owner_id)
  push_id(ids, seen, e.source_id)
  return ids
end

local function entity_category(e)
  if type(e) ~= "table" then return nil end
  if e.enemy then return "skip_enemy" end
  local tn = e.template_name
  if type(tn) == "string" and tn:find("^enemy_") then return "skip_enemy" end
  if e.user_power or (type(tn) == "string" and tn:find("^power_")) then
    return "spell"
  end
  if e.hero then return "hero" end
  if e.tower and e.tower.type and e.tower.type ~= "holder" and e.tower.type ~= "build_animation" then
    return "tower"
  end
  return nil
end

local function resolve_entity(store, id, depth, seen)
  depth = depth or 0
  seen = seen or {}
  if depth > 8 or id == nil then return nil end
  if seen[id] then return nil end
  seen[id] = true

  local e = store.entities and store.entities[id]
  if type(e) ~= "table" then return nil end

  local cat = entity_category(e)
  if cat == "skip_enemy" then return e, "skip_enemy" end
  if cat then return e, cat end

  local parents = collect_parent_ids(e)
  for i = 1, #parents do
    local re, rc = resolve_entity(store, parents[i], depth + 1, seen)
    if re and rc and rc ~= "other" then return re, rc end
  end

  return e, "other"
end

local function remap_key(cat, key, template_name)
  -- Post-fix: tower.type=reinforcement_base etc.
  local hc, hk = classify_template(tostring(key))
  if hc and hc ~= "other" then return hc, hk end
  if template_name then
    hc, hk = classify_template(template_name)
    if hc and hc ~= "other" then return hc, hk end
  end
  -- hero_ranger / hero_<tower> mis-tags → tower
  if cat == "hero" then
    local stem = tostring(key or ""):match("^hero_([a-z][a-z0-9]*)")
    if stem and as_tower_stem(stem) and not i18n("HERO_" .. upper_key(stem) .. "_NAME") then
      return "tower", stem
    end
  end
  if cat == "tower" then
    local k = tostring(key or "")
    -- 关卡盟友误记为塔
    if k:find("templar") then
      if k:find("archer") then return "hero", "ally_templar_archer" end
      return "hero", "ally_templar_swordsman"
    end
    local cleaned = clean_tower_type(key)
    if cleaned then return "tower", cleaned end
  end
  if cat == "other" then
    local k = tostring(key or "")
    if k:find("templar") then
      if k:find("archer") then return "hero", "ally_templar_archer" end
      return "hero", "ally_templar_swordsman"
    end
  end
  return cat, key
end

-- 热重载时把旧英文 key 合并进规范 key，面板立刻变中文
local function migrate_stat_keys()
  local moves = {
    { "tower", "stage_08_templar_swordsman", "hero", "ally_templar_swordsman" },
    { "tower", "broken_stage_08", "tower", "broken_stage_08" },
    { "other", "bullet_templar_archer", "hero", "ally_templar_archer" },
    { "other", "mod_stage_08_templar", "hero", "ally_templar" },
    { "tower", "ranger_skill_c_bounce_clone", "tower", "ranger" },
    { "hero", "hero_ranger", "tower", "ranger" },
    { "other", "bullet_drakkan_clone", "hero", "hero_drakkan" },
    { "other", "bullet_nivus_magic_missiles", "hero", "hero_nivus" },
    { "other", "mod_bullet_power_rain_of_fire_burn", "spell", "power_rain_of_fire" },
    { "other", "aura_pillar_stage_09_damage", "other", "stage_hazard" },
    { "tower", "reinforcement_base", "spell", "power_reinforcements" },
    { "other", "aura_stage_16_treant_attacker_bomb_damage", "tower", "stage_16_treant_attacker" },
    { "other", "bullet_stage_16_treant_killer_bomb", "tower", "stage_16_treant_killer" },
    { "other", "mod_stage_16_treant_killer_tangle", "tower", "stage_16_treant_killer" },
  }
  for i = 1, #moves do
    local fc, fk, tc, tk = moves[i][1], moves[i][2], moves[i][3], moves[i][4]
    local ft = S.totals[fc]
    local fh = S.hits[fc]
    if type(ft) == "table" and ft[fk] then
      local amt = ft[fk]
      local hits = (type(fh) == "table" and fh[fk]) or 0
      ft[fk] = nil
      if type(fh) == "table" then fh[fk] = nil end
      if not S.totals[tc] then S.totals[tc] = {} end
      if not S.hits[tc] then S.hits[tc] = {} end
      S.totals[tc][tk] = (S.totals[tc][tk] or 0) + amt
      S.hits[tc][tk] = (S.hits[tc][tk] or 0) + hits
    end
  end
  -- 敌方光环/修正不应留在【其他】
  do
    local drop = {
      "aura_dark_sapper_death_explosion",
      "mod_swamp_husk_poison",
      "bullet_shadow_archer",
      "bullet_dark_sapper",
    }
    local ot = S.totals.other
    local oh = S.hits.other
    if type(ot) == "table" then
      for i = 1, #drop do
        local k = drop[i]
        if ot[k] then
          S.skipped_enemy = (S.skipped_enemy or 0) + 1
          ot[k] = nil
          if type(oh) == "table" then oh[k] = nil end
        end
      end
      -- 扫一遍：仍是英文敌方模板的 other key 也清掉
      local kill = {}
      for k, _ in pairs(ot) do
        local hc = classify_template(tostring(k))
        if hc == "skip_enemy" then kill[#kill + 1] = k end
      end
      for i = 1, #kill do
        ot[kill[i]] = nil
        if type(oh) == "table" then oh[kill[i]] = nil end
      end
    end
  end
end

local function classify_damage(store, d)
  local prefer = { d.xp_dest_id, d.source_id }
  local last_e = nil
  for i = 1, #prefer do
    local id = prefer[i]
    if id ~= nil then
      local e, cat = resolve_entity(store, id)
      if e then last_e = e end
      if cat == "skip_enemy" then return "skip_enemy", "enemy" end
      if e and cat == "tower" then
        return remap_key("tower", normalize_tower_key(e), e.template_name)
      end
      if e and cat == "hero" then
        return remap_key("hero", normalize_hero_key(e), e.template_name)
      end
      if e and cat == "spell" then
        return remap_key("spell", normalize_spell_key(e), e.template_name)
      end
    end
  end

  if last_e then
    local hc, hk = classify_template(last_e.template_name)
    if hc == "skip_enemy" then return "skip_enemy", hk end
    if hc then return hc, hk end
    local n = tostring(last_e.template_name or "")
    if n ~= "" then
      return remap_key("other", n, n)
    end
  end
  return "other", "unknown"
end

local function level_key_of(store)
  if type(store) ~= "table" then return nil end
  return table.concat({
    tostring(store.level_name or store.level_idx or "?"),
    tostring(store.level_mode or "?"),
    tostring(store.level_difficulty or "?"),
  }, "|")
end

local function harvest_queue(store)
  local q = store.damage_queue
  if type(q) ~= "table" then return 0 end
  local n = 0
  for i = 1, #q do
    local d = q[i]
    if type(d) == "table" then
      local amt = d.damage_applied
      if type(amt) == "number" and amt > 0 and not d.__kr6dmg_counted then
        d.__kr6dmg_counted = true
        local cat, key = classify_damage(store, d)
        if cat == "skip_enemy" then
          S.skipped_enemy = (S.skipped_enemy or 0) + 1
        else
          add_stat(cat, key, amt)
          n = n + 1
          if S.samples <= 30 or S.samples % 50 == 0 then
            append("_kr6dmg.log", string.format(
              "%s DMG#%d cat=%s key=%s name=%s amt=%.0f src=%s\n",
              os.date("%H:%M:%S"), S.samples, cat, key,
              display_name(cat, key), amt, tostring(d.source_id)))
          end
        end
      end
    end
  end
  return n
end

local function sorted_rows(cat)
  local t = S.totals[cat] or {}
  local rows = {}
  for k, v in pairs(t) do
    rows[#rows + 1] = { key = k, dmg = v, hits = (S.hits[cat] and S.hits[cat][k]) or 0 }
  end
  table.sort(rows, function(a, b)
    if a.dmg == b.dmg then return a.key < b.key end
    return a.dmg > b.dmg
  end)
  return rows
end

local function export_csv()
  local store = store_of()
  local lk = S.level_key or (store and level_key_of(store)) or "unknown"
  local stamp = os.date("%Y%m%d_%H%M%S")
  local safe = tostring(lk):gsub("[^%w%-_]+", "_")
  local name = string.format("damage_%s_%s.csv", safe, stamp)
  local lines = { "category,key,name,damage,hits,percent" }
  local grand = S.grand
  if grand <= 0 then grand = 1 end
  for _, cat in ipairs({ "tower", "hero", "spell", "other" }) do
    for _, r in ipairs(sorted_rows(cat)) do
      local dn = display_name(cat, r.key):gsub(",", " ")
      lines[#lines + 1] = string.format("%s,%s,%s,%.0f,%d,%.2f",
        cat, r.key, dn, r.dmg, r.hits, (r.dmg / grand) * 100)
    end
  end
  lines[#lines + 1] = string.format("total,ALL,合计,%.0f,,100.00", S.grand)
  lines[#lines + 1] = string.format("gold,miners,淘金矮人,%.0f,%d,",
    S.miner_gold_session or 0, S.miner_gold_towers or 0)
  if wf(name, table.concat(lines, "\n") .. "\n") then
    note("已导出 " .. name)
    return name
  end
  note("导出失败")
  return nil
end

local function try_load_font(want_size)
  local size = want_size or 15
  local cands = {
    "_assets/kr6-desktop/fonts/NotoSansCJKsc-Regular.otf",
    "kr6-desktop/fonts/NotoSansCJKsc-Regular.otf",
    "/fonts/NotoSansCJKsc-Regular.otf",
    "fonts/NotoSansCJKsc-Regular.otf",
    "_assets/kr6-desktop/fonts/NotoSansCJKsc-Bold.otf",
    "_assets/all-desktop/fonts/NotoSansCJKjp-Regular.otf",
  }
  if S.font_path then
    local ok, f = pcall(love.graphics.newFont, S.font_path, size)
    if ok and f then return f end
  end
  for i = 1, #cands do
    local ok, f = pcall(love.graphics.newFont, cands[i], size)
    if ok and f then
      S.font_path = cands[i]
      return f
    end
  end
  local okc, cur = pcall(love.graphics.getFont)
  if okc and cur then
    local okg, has = pcall(cur.hasGlyphs, cur, "诅咒")
    if okg and has then return cur end
  end
  local ok, f = pcall(love.graphics.newFont, 14)
  if ok then return f end
  return nil
end

local function ensure_font()
  if S.font then return S.font end
  if type(love) ~= "table" or type(love.graphics) ~= "table" then return nil end
  S.font = try_load_font(15)
  return S.font
end

local function draw_panel()
  if not S.panel_open then return end
  if type(love) ~= "table" or type(love.graphics) ~= "table" then return end
  local g = love.graphics
  local font = ensure_font()
  if font then g.setFont(font) end

  local gw = 1280
  if g.getWidth then
    local ok, w = pcall(g.getWidth)
    if ok and type(w) == "number" then gw = w end
  end
  local panel_w = 380
  local x = gw - panel_w - 12
  local y = 12
  local line_h = 20
  local max_lines = 24
  local panel_h = 28 + max_lines * line_h

  g.push()
  pcall(function() if g.setCanvas then g.setCanvas() end end)
  pcall(function() if g.setScissor then g.setScissor() end end)

  g.setColor(0, 0, 0, 200)
  g.rectangle("fill", x, y, panel_w, panel_h)
  g.setColor(200, 170, 60, 255)
  g.rectangle("line", x, y, panel_w, panel_h)

  local cy = y + 8
  local function line(text, r, gg, b)
    g.setColor(r or 255, gg or 255, b or 255, 255)
    g.print(tostring(text), x + 10, cy)
    cy = cy + line_h
  end

  line("伤害统计  F7重载 F8开关 F9导出 F10清零", 255, 220, 100)
  line(string.format("合计: %.0f   次数: %d", S.grand, S.samples), 220, 220, 220)
  do
    local gname = i18n("TOWER_MINERS_NAME") or "淘金矮人"
    local sess = S.miner_gold_session or 0
    local live = S.miner_gold_live or 0
    local nt = S.miner_gold_towers or 0
    line(string.format("%s黄金（%d座）：本关共%.0f，本波共%.0f",
      gname, nt, sess, live), 255, 215, 80)
  end
  if S.level_key then line("关卡: " .. tostring(S.level_key), 180, 180, 180) end
  if S.msg ~= "" and (os.time() - (S.msg_ts or 0)) < 4 then
    line(S.msg, 140, 255, 140)
  end
  cy = cy + 4

  local drawn = 0
  local labels = {
    tower = { "【塔】", 120, 200, 255 },
    hero = { "【英雄】", 255, 180, 100 },
    spell = { "【法术】", 200, 140, 255 },
    other = { "【其他】", 160, 160, 160 },
  }
  for _, cat in ipairs({ "tower", "hero", "spell", "other" }) do
    local rows = sorted_rows(cat)
    if #rows > 0 then
      local lb = labels[cat]
      line(lb[1], lb[2], lb[3], lb[4])
      drawn = drawn + 1
      for i = 1, #rows do
        if drawn >= max_lines then break end
        local r = rows[i]
        local pct = S.grand > 0 and (r.dmg / S.grand * 100) or 0
        local dn = display_name(cat, r.key)
        line(string.format("  %s  %.0f  (%.1f%%)", dn, r.dmg, pct), 230, 230, 230)
        drawn = drawn + 1
      end
    end
    if drawn >= max_lines then break end
  end

  g.setColor(255, 255, 255, 255)
  g.pop()
end

local function is_miners_tower(e)
  -- 只认塔本体，不含 soldier_miners / controller
  if type(e) ~= "table" then return false end
  local tw = e.tower
  if type(tw) == "table" then
    local t = tostring(tw.type or "")
    if t == "miners" or t:find("^miners") then return true end
  end
  local n = tostring(e.template_name or "")
  return n:find("^tower_miners") ~= nil
end

local function is_miners_gold_source(e)
  if is_miners_tower(e) then return true end
  if type(e) ~= "table" then return false end
  local n = tostring(e.template_name or "")
  if n:find("tower_miners") then return true end
  -- generate_gold 信号源一般是塔实体自身
  if type(e.gold_generation) == "table" and type(e.tower) == "table" then
    return tostring(e.tower.type or ""):find("miner") ~= nil
  end
  return false
end

local function read_controller_gold(ctrl)
  if type(ctrl) ~= "table" then return 0 end
  return tonumber(ctrl.gold_accum) or 0
end

local function on_got_gold(a, b, c)
  -- 实测: signal.emit("got-gold", entity, amount)
  local src, amt
  if type(a) == "table" and type(b) == "number" then
    src, amt = a, b
  elseif type(a) == "number" then
    amt = a
  else
    amt = tonumber(b) or tonumber(c)
  end
  if type(amt) ~= "number" or amt <= 0 then return end

  -- 产出以塔上 gold_accum 轮询为准；信号只做核对日志，避免双计
  S._got_gold_log = (S._got_gold_log or 0) + 1
  local from_miner = src and is_miners_gold_source(src)
  if S._got_gold_log <= 20 or S._got_gold_log % 40 == 0 then
    append("_kr6dmg.log", string.format(
      "%s GOT_GOLD#%d %s +%.0f tpl=%s id=%s\n",
      os.date("%H:%M:%S"), S._got_gold_log,
      from_miner and "miner" or "other", amt,
      tostring(src and src.template_name), tostring(src and src.id)))
  end
end

local function install_gold_signal()
  -- 包装只装一次；具体逻辑走 __kr6dmg_api.on_got_gold，热重载可更新。
  if S._gold_signal_wrap then
    S._gold_signal = true
    return
  end
  local ok, signal = pcall(require, "hump.signal")
  if not ok or type(signal) ~= "table" or type(signal.register) ~= "function" then
    return
  end
  local function wrap(a, b, c)
    local api = _G.__kr6dmg_api
    if api and type(api.on_got_gold) == "function" then
      local okc, err = pcall(api.on_got_gold, a, b, c)
      if not okc then record_err("on_got_gold", err) end
    end
  end
  local ok2, err = pcall(signal.register, "got-gold", wrap)
  if ok2 then
    S._gold_signal_wrap = true
    S._gold_signal = true
  else
    record_err("gold_signal", err)
  end
end

local function dump_miner_fields(e)
  if S.miner_dumped then return end
  S.miner_dumped = true
  local keys = {}
  local function add_kv(prefix, tbl, depth)
    if type(tbl) ~= "table" or depth > 2 then return end
    for k, v in pairs(tbl) do
      local ks = tostring(k)
      local low = ks:lower()
      if low:find("gold") or low:find("mine") or low:find("miner") or low:find("coin")
         or low == "type" or low:find("accum") then
        if type(v) == "table" then
          keys[#keys + 1] = string.format("%s%s=<table>", prefix, ks)
          add_kv(prefix .. ks .. ".", v, depth + 1)
        else
          keys[#keys + 1] = string.format("%s%s=%s", prefix, ks, tostring(v))
        end
      end
    end
  end
  add_kv("", e, 0)
  table.sort(keys)
  append("_kr6dmg.log", os.date("%H:%M:%S") .. " MINER_DUMP id=" .. tostring(e.id)
    .. " tpl=" .. tostring(e.template_name)
    .. " " .. table.concat(keys, " ") .. "\n")
end

local function harvest_miner_gold(store)
  if type(store) ~= "table" or type(store.entities) ~= "table" then return end
  -- gold_accum 在全局 controller_miners_global_gold_cap 上（多塔共享），不能按塔相加。
  local towers = 0
  local ctrls = {} -- [ctrl_table] = true
  local rebase = not S._miner_rebased
  for _, e in pairs(store.entities) do
    if is_miners_tower(e) then
      towers = towers + 1
      dump_miner_fields(e)
      local ctrl = e.gold_cap_controller
      if type(ctrl) == "table" then ctrls[ctrl] = true end
    end
    local n = tostring(e.template_name or "")
    if n:find("controller_miners_global_gold_cap") or n:find("miners_gold_cap") then
      ctrls[e] = true
      if not S.miner_dumped then
        dump_miner_fields(e)
      end
    end
  end

  local live = 0
  local gained = 0
  local ci = 0
  for ctrl, _ in pairs(ctrls) do
    ci = ci + 1
    local g = read_controller_gold(ctrl)
    live = live + g
    -- 用 table 地址作稳定 key（同局内 controller 表不会换）
    local id = tostring(ctrl)
    local prev = S.miner_gold_seen[id]
    if prev == nil or rebase then
      S.miner_gold_seen[id] = g
    elseif g > prev then
      gained = gained + (g - prev)
      S.miner_gold_seen[id] = g
    elseif g < prev then
      S.miner_gold_seen[id] = g
    end
  end
  if rebase then S._miner_rebased = true end
  if gained > 0 then
    S.miner_gold_session = S.miner_gold_session + gained
    S.miner_gold_ticks = S.miner_gold_ticks + 1
    if S.miner_gold_ticks <= 20 or S.miner_gold_ticks % 10 == 0 then
      append("_kr6dmg.log", string.format(
        "%s GOLD#%d +%.0f session=%.0f live=%.0f towers=%d ctrls=%d\n",
        os.date("%H:%M:%S"), S.miner_gold_ticks, gained,
        S.miner_gold_session, live, towers, ci))
    end
  end
  S.miner_gold_live = live
  S.miner_gold_towers = towers
end

local function after_health(store)
  if type(store) ~= "table" then return end
  local lk = level_key_of(store)
  if lk and lk ~= S.level_key then
    if S.level_key and (S.grand > 0 or S.miner_gold_session > 0) then pcall(export_csv) end
    S.level_key = lk
    reset_stats()
  elseif not S.level_key then
    S.level_key = lk
  end
  harvest_queue(store)
  harvest_miner_gold(store)
end

local function hot_reload()
  local path = save_dir() .. "_kr6dmg.lua"
  local f = io.open(path, "rb")
  if not f then
    note("重载失败: 找不到文件")
    return false
  end
  local src = f:read("*a")
  f:close()
  local chunk, err = loadstring(src, path)
  if not chunk then
    note("重载失败: " .. tostring(err))
    record_err("hot_reload.load", err)
    return false
  end
  local ok, e = pcall(chunk, S.virt, S.mod)
  if not ok then
    note("重载失败: " .. tostring(e))
    record_err("hot_reload.run", e)
    return false
  end
  note("已热重载 gen=" .. tostring(_G.__kr6dmg_gen))
  append("_kr6dmg.log", os.date("%H:%M:%S") .. " hot_reload gen=" .. tostring(_G.__kr6dmg_gen) .. "\n")
  return true
end

local function poll_reload_flag()
  local now = os.clock()
  if S._reload_poll and (now - S._reload_poll) < 0.8 then return end
  S._reload_poll = now
  local flag = save_dir() .. "_kr6dmg_reload.flag"
  local f = io.open(flag, "rb")
  if not f then return end
  f:close()
  os.remove(flag)
  hot_reload()
end

-- expose for timer wrap
_G.__kr6dmg_poll_reload = poll_reload_flag

local function evt_time()
  local ok, t = pcall(function() return love.timer.getTime() end)
  if ok and type(t) == "number" then return t end
  return os.clock()
end

local function on_key(key)
  local t = evt_time()
  if S.last_key == key and S.last_key_t and (t - S.last_key_t) < 0.08 then
    return false
  end
  S.last_key, S.last_key_t = key, t
  key = tostring(key):lower()
  if key == "f7" then
    hot_reload()
    return true
  elseif key == "f8" then
    S.panel_open = not S.panel_open
    note(S.panel_open and "面板开" or "面板关")
    return true
  elseif key == "f9" then
    export_csv()
    return true
  elseif key == "f10" then
    reset_stats()
    note("本关统计已清零")
    return true
  end
  return false
end

local H = _G.__kr6dmg_hookstate
if type(H) ~= "table" then
  H = { health = false, wraps = {} }
  _G.__kr6dmg_hookstate = H
end

local function install_health_hook()
  if H.health then return true end
  local sys = game_mod("systems")
  if type(sys) ~= "table" then
    for k, v in pairs(package.loaded) do
      if type(k) == "string" and k:find("systems") and type(v) == "table"
         and type(v.health) == "table" and type(v.health.on_update) == "function" then
        sys = v
        break
      end
    end
  end
  local h = type(sys) == "table" and rawget(sys, "health") or nil
  local orig = type(h) == "table" and rawget(h, "on_update") or nil
  if type(orig) ~= "function" then return false end
  H.health = true
  H.health_orig = orig
  rawset(h, "on_update", function(self, dt, ts, store, ...)
    local a, b, c, d = orig(self, dt, ts, store, ...)
    local api = _G.__kr6dmg_api
    if api and type(api.after_health) == "function" then
      local ok, err = pcall(api.after_health, store)
      if not ok then record_err("health.on_update", err) end
    end
    return a, b, c, d
  end)
  note("伤害统计已挂载")
  return true
end

-- Stable API used by one-shot hooks (survives hot-reload).
local function draw_once()
  if S.drew then return end
  S.drew = true
  local ok, err = pcall(draw_panel)
  if not ok then record_err("draw_panel", err) end
end

local function on_frame()
  S.drew = false
  if not H.health then install_health_hook() end
  local poll = _G.__kr6dmg_poll_reload
  if type(poll) == "function" then pcall(poll) end
end

_G.__kr6dmg_api = {
  gen = GEN,
  after_health = after_health,
  draw = draw_once,
  on_key = on_key,
  on_frame = on_frame,
  on_got_gold = on_got_gold,
  panel_open = function() return S.panel_open end,
}

local function wrap_once(owner, key, tag, after)
  if type(owner) ~= "table" then return false end
  if H.wraps[tag] then return false end
  local orig = rawget(owner, key)
  if type(orig) ~= "function" then return false end
  H.wraps[tag] = true
  rawset(owner, key, function(...)
    local a, b, c, d = orig(...)
    pcall(after)
    return a, b, c, d
  end)
  return true
end

local function install_io()
  if type(love) ~= "table" then return end
  pcall(function()
    if type(love.timer) == "table" then
      wrap_once(love.timer, "step", "timer.step", function()
        local api = _G.__kr6dmg_api
        if api and type(api.on_frame) == "function" then pcall(api.on_frame) end
      end)
    end
    if type(love.graphics) == "table" then
      wrap_once(love.graphics, "present", "present", function()
        local api = _G.__kr6dmg_api
        if api and api.panel_open and api.panel_open() and type(api.draw) == "function" then
          pcall(api.draw)
        end
      end)
    end
  end)

  local m = S.mod
  if type(m) == "table" then
    pcall(function()
      if type(rawget(m, "draw")) == "function" and not H.wraps.director_draw then
        local od = rawget(m, "draw")
        H.wraps.director_draw = true
        rawset(m, "draw", function(...)
          local a, b, c, d = od(...)
          local api = _G.__kr6dmg_api
          if api and api.panel_open and api.panel_open() and type(api.draw) == "function" then
            pcall(api.draw)
          end
          return a, b, c, d
        end)
      end
      if type(rawget(m, "keypressed")) == "function" and not H.wraps.director_key then
        local okp = rawget(m, "keypressed")
        H.wraps.director_key = true
        rawset(m, "keypressed", function(...)
          local api = _G.__kr6dmg_api
          if api and type(api.on_key) == "function" then pcall(api.on_key, (...)) end
          return okp(...)
        end)
      end
    end)
  end

  pcall(function()
    if type(love.handlers) == "table" and type(love.handlers.keypressed) == "function"
       and not H.wraps.love_key then
      local orig = love.handlers.keypressed
      H.wraps.love_key = true
      love.handlers.keypressed = function(key, ...)
        local api = _G.__kr6dmg_api
        if api and type(api.on_key) == "function" then pcall(api.on_key, key) end
        return orig(key, ...)
      end
    end
  end)
end

local ok_boot, err_boot = pcall(function()
  install_io()
  install_health_hook()
  install_gold_signal()
  -- invalidate name cache on reload so new i18n logic applies
  S.name_cache = {}
  S.font = nil
  S.miner_dumped = false -- 热重载后重新 dump 嵌套 gold 字段
  -- 重载后按当前 gold_accum 重新挂基线；会话清零（避免旧版 4 倍误算残留）
  S.miner_gold_seen = {}
  S._miner_rebased = false
  S.miner_gold_session = 0
  S.miner_gold_ticks = 0
  S.miner_gold_live = 0
  pcall(migrate_stat_keys)
  wf("_kr6dmg_boot.txt",
    "virt=" .. tostring(S.virt) .. "\n" ..
    "gen=" .. tostring(GEN) .. "\n" ..
    "health=" .. tostring(H.health) .. "\n" ..
    "gold_signal=" .. tostring(S._gold_signal) .. "\n" ..
    "gold_wrap=" .. tostring(S._gold_signal_wrap) .. "\n" ..
    "miner_gold_session=" .. tostring(S.miner_gold_session) .. "\n" ..
    "save=" .. save_dir() .. "\n" ..
    "hot_reload=F7\n")
end)
if not ok_boot then
  record_err("boot", err_boot)
end
