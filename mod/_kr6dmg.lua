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
  aura_tree_attack_lvl1 = "异木守卫",
  aura_tree_attack_lvl2 = "异木守卫",
  aura_tree_attack_lvl3 = "异木守卫",
  aura_tree_attack_lvl4 = "异木守卫",
  stage_hazard = "关卡机制",
  aura_pillar_stage_09_damage = "关卡机制",
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
  elseif cat == "hero" then
    local h = raw:match("^hero_(.+)") or raw
    local u = upper_key(h)
    add("HERO_" .. u .. "_NAME")
    add("HERO_" .. u .. "_CLONE_NAME")
    -- stage heroes e.g. alleria
    add("HERO_STAGE_05_" .. u .. "_NAME")
    add("HERO_STAGE_15_" .. u .. "_NAME")
    add("HERO_STAGE_18_" .. u .. "_NAME")
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
    local u = upper_key(raw:gsub("^bullet_", ""):gsub("^soldier_", ""))
    add("ENEMY_" .. u .. "_NAME")
    add("SOLDIER_" .. u .. "_NAME")
    add("HERO_" .. u .. "_NAME")
    add("TOWER_" .. u .. "_NAME")
    add("POWER_" .. u .. "_NAME")
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
  -- last resort: if still ascii template, try parent token as tower/hero
  if not fb and raw:match("^[a-z0-9_]+$") then
    local base = raw:match("^aura_([a-z0-9]+)_") or raw:match("^bullet_([a-z0-9]+)_")
        or raw:gsub("_basic$", ""):gsub("_ult$", ""):gsub("_lvl%d+.*$", "")
    if base then
      fb = i18n("TOWER_" .. upper_key(base) .. "_NAME")
        or i18n("HERO_" .. upper_key(base) .. "_NAME")
        or i18n("POWER_" .. upper_key(base) .. "_NAME")
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
  -- crossbows_basic / knights_ult → base type
  t = t:gsub("_basic$", ""):gsub("_ult$", ""):gsub("_ultimate$", "")
      :gsub("_advanced$", ""):gsub("_lvl%d+.*$", ""):gsub("_level_%d+.*$", "")
  if t:find("reinforcement") then return nil end -- handled as spell elsewhere
  return t
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

local function normalize_hero_key(e)
  local n = tostring(e.template_name or "hero")
  return n:match("^(hero_[a-z0-9]+)") or n
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

  -- Enemy projectiles: bullet_shadow_archer → ENEMY_SHADOW_ARCHER_NAME
  do
    local after = n:match("^bullet_(.+)$")
    if after and not after:find("^power_") then
      local eu = upper_key(after)
      if i18n("ENEMY_" .. eu .. "_NAME") then
        return "skip_enemy", after
      end
    end
  end

  -- Stage controllers / allies: controller_stage_06_nivus, nivus_book
  if n:find("nivus") then
    return "hero", "hero_nivus"
  end
  do
    local ctrl = n:match("^controller_stage_%d+_([a-z0-9]+)")
    if ctrl then return "hero", "hero_" .. ctrl end
  end
  -- Stage props / hazards: aura_pillar_stage_09_damage → 关卡机制
  if n:find("pillar_stage") or n:find("^aura_pillar") or n:match("stage_%d+.*damage") then
    return "other", "stage_hazard"
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

  local hero = n:match("^(hero_[a-z0-9]+)") or n:match("^bullet_(hero_[a-z0-9]+)")
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
    if n:find("drakkan") or n:find("bolin") or n:find("hero")
       or n:find("gerald") or n:find("malik") or n:find("ignus")
       or n:find("oni") or n:find("alleria") or n:find("connor")
       or n:find("rhodes") or n:find("zefira") or n:find("illiana")
       or n:find("myriath") or n:find("ashbite") or n:find("nivus")
       or n:find("_skill") or n:find("_ult") then
      return "hero", "hero_" .. aura_hero
    end
  end
  local hero_from_aura = n:match("^aura_(hero_[a-z0-9]+)") or n:match("^mod_(hero_[a-z0-9]+)")
  if hero_from_aura then return "hero", hero_from_aura end
  hero_from_aura = n:match("^aura_([a-z0-9]+)_skill") or n:match("^aura_([a-z0-9]+)_ult")
      or n:match("^mod_([a-z0-9]+)_skill")
  if hero_from_aura then return "hero", "hero_" .. hero_from_aura end

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
  return cat, key
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

local function after_health(store)
  if type(store) ~= "table" then return end
  local lk = level_key_of(store)
  if lk and lk ~= S.level_key then
    if S.level_key and S.grand > 0 then pcall(export_csv) end
    S.level_key = lk
    reset_stats()
  elseif not S.level_key then
    S.level_key = lk
  end
  harvest_queue(store)
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
  -- invalidate name cache on reload so new i18n logic applies
  S.name_cache = {}
  S.font = nil
  wf("_kr6dmg_boot.txt",
    "virt=" .. tostring(S.virt) .. "\n" ..
    "gen=" .. tostring(GEN) .. "\n" ..
    "health=" .. tostring(H.health) .. "\n" ..
    "save=" .. save_dir() .. "\n" ..
    "hot_reload=F7\n")
end)
if not ok_boot then
  record_err("boot", err_boot)
end
