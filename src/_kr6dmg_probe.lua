-- KR6 DPS probe — validate inject / damage sample / visible draw.
-- NEVER touches slot_*.lua / global.lua / settings.lua / cache.lua.
local virt, mod = ...

local FORBIDDEN = {
  ["slot_1.lua"] = true, ["slot_2.lua"] = true, ["slot_3.lua"] = true,
  ["global.lua"] = true, ["settings.lua"] = true, ["cache.lua"] = true,
  ["steam_autocloud.vdf"] = true,
}

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

local SAVE
local function save_dir()
  if SAVE then return SAVE end
  local lfs = type(love) == "table" and love.filesystem
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
  SAVE = best or p or "./"
  return SAVE
end

local function safe_name(name)
  local base = tostring(name):match("([^/\\]+)$") or tostring(name)
  if FORBIDDEN[base] then return nil end
  if base:match("^slot_%d+%.lua$") then return nil end
  return base
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

local function log(line)
  append("_kr6dmg_probe.log", os.date("%H:%M:%S") .. " " .. tostring(line) .. "\n")
end

local S = _G.__kr6dmg_probe
if type(S) ~= "table" then
  S = {
    hooks = {}, wrap = {}, health = false,
    samples = 0, last_hb = 0, banner = true, drew = false,
  }
  _G.__kr6dmg_probe = S
end
S.mod = (type(mod) == "table") and mod or S.mod

local function game_mod(name)
  local ok, m = pcall(require, name)
  if ok and type(m) == "table" then return m end
  m = package.loaded[name]
  if type(m) == "table" then return m end
  return nil
end

local function tpl_guess(name)
  local n = tostring(name or "")
  if n == "" then return nil end
  local power = n:match("^bullet_(power_.+)$") or n:match("^(power_.+)$")
  if power then
    return "spell", power:gsub("_control$", ""):gsub("_dmg$", ""):gsub("_hit$", "")
  end
  local hero = n:match("^(hero_[a-z0-9]+)") or n:match("^bullet_(hero_[a-z0-9]+)")
  if hero then return "hero", hero end
  local tw = n:match("^tower_([a-z0-9_]+)")
  if tw then
    tw = tw:gsub("_lvl%d+.*$", "")
    if tw ~= "holder" and tw ~= "build_animation" then return "tower", tw end
  end
  local tb = n:match("^bullet_([a-z0-9_]+)_lvl%d+")
  if tb then return "tower", tb end
  local simple = n:match("^bullet_([a-z][a-z0-9]*)$")
  if simple and simple ~= "power" then return "hero", "hero_" .. simple end
  return nil
end

local function resolve(store, id, depth, seen)
  depth = depth or 0
  seen = seen or {}
  if depth > 8 or id == nil then return nil, "other", "unknown" end
  if seen[id] then return nil, "other", "unknown" end
  seen[id] = true
  local e = store.entities and store.entities[id]
  if type(e) ~= "table" then return nil, "other", "unknown" end
  if e.user_power or (type(e.template_name) == "string" and e.template_name:find("^power_")) then
    local k = e.template_name or ("power_" .. tostring(e.user_power and e.user_power.power_id))
    return e, "spell", tostring(k)
  end
  if e.hero then
    local n = tostring(e.template_name or "hero")
    return e, "hero", (n:match("^(hero_[a-z0-9]+)") or n)
  end
  if e.tower and e.tower.type and e.tower.type ~= "holder" and e.tower.type ~= "build_animation" then
    return e, "tower", tostring(e.tower.type)
  end
  local parents = {}
  local function push(x) if x ~= nil then parents[#parents + 1] = x end end
  if type(e.bullet) == "table" then
    push(e.bullet.source_id); push(e.bullet.xp_dest_id); push(e.bullet.from_id)
  end
  if e.soldier then push(e.soldier.tower_id) end
  if e.modifier then push(e.modifier.source_id) end
  if e.aura then push(e.aura.source_id) end
  if e.spell then push(e.spell.source_id) end
  push(e.owner_id); push(e.source_id)
  for i = 1, #parents do
    local re, cat, key = resolve(store, parents[i], depth + 1, seen)
    if re and cat ~= "other" then return re, cat, key end
  end
  local gc, gk = tpl_guess(e.template_name)
  if gc then return e, gc, gk end
  return e, "other", tostring(e.template_name or "unknown")
end

local function harvest(store)
  local q = store.damage_queue
  if type(q) ~= "table" then return end
  for i = 1, #q do
    local d = q[i]
    if type(d) == "table" then
      local amt = d.damage_applied
      if type(amt) == "number" and amt > 0 and not d.__kr6probe then
        d.__kr6probe = true
        local _, cat, key = resolve(store, d.xp_dest_id or d.source_id)
        if cat == "other" and d.source_id and d.source_id ~= d.xp_dest_id then
          _, cat, key = resolve(store, d.source_id)
        end
        S.samples = S.samples + 1
        if S.samples <= 40 or S.samples % 25 == 0 then
          log(string.format("DMG#%d cat=%s key=%s amt=%.0f src=%s xp=%s",
            S.samples, cat, key, amt, tostring(d.source_id), tostring(d.xp_dest_id)))
        end
      end
    end
  end
end

local function install_health()
  if S.health then return true end
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
  S.health = true
  rawset(h, "on_update", function(self, dt, ts, store, ...)
    local a, b, c, d = orig(self, dt, ts, store, ...)
    pcall(function()
      if type(store) == "table" then harvest(store) end
    end)
    return a, b, c, d
  end)
  S.hooks[#S.hooks + 1] = "health.on_update"
  log("health hook OK")
  return true
end

-- 0-255 colors (this game's convention). Plain rect. ASCII only.
local function draw_banner()
  if not S.banner then return end
  if type(love) ~= "table" or type(love.graphics) ~= "table" then return end
  local g = love.graphics
  local w = 280
  local h = 56
  local x = 12
  local y = 12
  if g.getWidth then
    local ok, gw = pcall(g.getWidth)
    if ok and type(gw) == "number" then x = gw - w - 12 end
  end
  g.push()
  -- reset scissor/canvas if possible
  pcall(function() if g.setCanvas then g.setCanvas() end end)
  pcall(function() if g.setScissor then g.setScissor() end end)
  g.setColor(255, 220, 0, 230)
  g.rectangle("fill", x, y, w, h)
  g.setColor(0, 0, 0, 255)
  g.print("KR6 DMG OK  samples=" .. tostring(S.samples), x + 10, y + 10)
  g.print("F8 hide banner  (probe)", x + 10, y + 30)
  g.setColor(255, 255, 255, 255)
  g.pop()
end

local function wrap(owner, key, tag)
  if type(owner) ~= "table" then return false end
  local orig = rawget(owner, key)
  if type(orig) ~= "function" or S.wrap[tag] then return false end
  S.wrap[tag] = true
  rawset(owner, key, function(...)
    local a, b, c, d = orig(...)
    pcall(function()
      if not S.health then install_health() end
      local now = os.clock()
      if now - (S.last_hb or 0) > 2 then
        S.last_hb = now
        log("hb samples=" .. S.samples .. " health=" .. tostring(S.health))
      end
    end)
    return a, b, c, d
  end)
  S.hooks[#S.hooks + 1] = tag
  return true
end

pcall(function()
  if type(love) == "table" then
    if type(love.timer) == "table" then wrap(love.timer, "step", "timer.step") end
    if type(love.graphics) == "table" then
      local orig = rawget(love.graphics, "present")
      if type(orig) == "function" and not S.wrap.present then
        S.wrap.present = true
        rawset(love.graphics, "present", function(...)
          pcall(draw_banner)
          return orig(...)
        end)
        S.hooks[#S.hooks + 1] = "present"
      end
    end
    if type(love.handlers) == "table" and type(love.handlers.keypressed) == "function"
       and not S.wrap.key then
      local orig = love.handlers.keypressed
      S.wrap.key = true
      love.handlers.keypressed = function(key, ...)
        if tostring(key):lower() == "f8" then
          S.banner = not S.banner
          log("banner=" .. tostring(S.banner))
        end
        return orig(key, ...)
      end
    end
  end
  local m = S.mod
  if type(m) == "table" and type(rawget(m, "draw")) == "function" and not S.wrap.ddraw then
    local od = rawget(m, "draw")
    S.wrap.ddraw = true
    rawset(m, "draw", function(...)
      local a, b, c, d = od(...)
      pcall(draw_banner)
      return a, b, c, d
    end)
  end
end)

pcall(install_health)
log("boot virt=" .. tostring(virt) .. " hooks=" .. table.concat(S.hooks, ","))
append("_kr6dmg_probe_boot.txt",
  "ok\nsave=" .. save_dir() .. "\nhooks=" .. table.concat(S.hooks, ",") .. "\n")
