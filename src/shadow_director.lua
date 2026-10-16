-- Probe/production shadow for all/director.lua
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

local function save_dir()
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
  return best or p or "./"
end

local SAVE = save_dir()

local function wf(name, txt)
  local f = io.open(SAVE .. name, "wb")
  if f then f:write(txt) f:close() end
end

local function blob(path)
  local f = io.open(path, "rb")
  if not f then return nil, "cannot open " .. path end
  local s = f:read("*a")
  f:close()
  local chunk, err = loadstring(s, path)
  if not chunk then return nil, "loadstring: " .. tostring(err) end
  return chunk
end

local origval
local chunk, cerr = blob(SAVE .. "_orig/all_director.luac")
if not chunk then
  wf("_kr6_shadow_err_all_director_lua.txt", "blob failed: " .. tostring(cerr) .. "\n")
else
  local ok, v = pcall(chunk, ...)
  if ok then origval = v
  else wf("_kr6_shadow_err_all_director_lua.txt", "original errored: " .. tostring(v) .. "\n") end
end

-- optional trainer
local trainer = blob(SAVE .. "_kr6trainer.lua")
if trainer then pcall(trainer, "all/director.lua", origval) end

-- probe first if present, else full meter
local probe = blob(SAVE .. "_kr6dmg_probe.lua")
if probe then
  pcall(probe, "all/director.lua", origval)
else
  local meter = blob(SAVE .. "_kr6dmg.lua")
  if meter then pcall(meter, "all/director.lua", origval) end
end

return origval
