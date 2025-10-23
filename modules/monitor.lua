-- modules/monitors.lua
-- Headless monitor discovery (local + wired). Keeps a live set and a "primary".
-- config.monitors:
--   prefer = { "monitor_0", "left" }   -- optional priority list
--   text_scale = nil|number            -- default scale to apply when (re)binding

local M = {}

-- gentle logger (works even if libs/log.lua is missing)
local log = (function()
  local ok, m = pcall(require, "libs.log")
  if ok then return m end
  return { info=print, warn=printError, error=printError }
end)()

local prefer = {}
local text_scale
local set = {}         -- name -> true
local primaryName      -- current chosen name
local primaryObj       -- wrapped peripheral

local function listMonitors()
  local names = {}
  if peripheral.getNames then
    for _, n in ipairs(peripheral.getNames()) do
      if peripheral.getType(n) == "monitor" then table.insert(names, n) end
    end
  end
  return names
end

local function wrap(name)
  if not name then return nil end
  if not peripheral.isPresent(name) then return nil end
  if peripheral.getType(name) ~= "monitor" then return nil end
  return peripheral.wrap(name)
end

local function pickPrimary()
  -- 1) honor prefer list
  for _, n in ipairs(prefer) do
    if set[n] then return n end
  end
  -- 2) otherwise first available by name
  for n,_ in pairs(set) do return n end
  return nil
end

local function applyScale(obj)
  if not obj then return end
  if text_scale then obj.setTextScale(text_scale); return end
  -- fallback heuristic
  local w = select(1, obj.getSize())
  if w >= 60 then obj.setTextScale(1)
  elseif w >= 40 then obj.setTextScale(1.5)
  elseif w >= 30 then obj.setTextScale(2)
  else obj.setTextScale(2.5) end
end

local function rebindPrimary()
  local newName = pickPrimary()
  if newName ~= primaryName then
    primaryName = newName
    primaryObj  = wrap(newName)
    if primaryObj then
      applyScale(primaryObj)
      local kind = (newName and newName:match("^monitor_%d+$")) and "wired" or "local"
      log.info(("[monitors] bound %s monitor: %s"):format(kind, tostring(newName)))
    else
      log.warn("[monitors] no monitor bound")
    end
  else
    -- same name; ensure object still valid
    if primaryName and not primaryObj then
      primaryObj = wrap(primaryName)
      if primaryObj then applyScale(primaryObj) end
    end
  end
end

-- public API
function M.get()         return primaryObj end
function M.getName()     return primaryName end
function M.all()         local t={} for n,_ in pairs(set) do table.insert(t,n) end return t end
function M.setPreferred(names)
  prefer = names or {}
  rebindPrimary()
end

-- lifecycle
function M.init(cfg)
  cfg = cfg or {}
  prefer     = cfg.prefer or prefer
  text_scale = cfg.text_scale

  -- seed set from current peripherals
  for _, n in ipairs(listMonitors()) do set[n] = true end
  rebindPrimary()
  return true
end

function M.start() end
function M.stop()  end

-- events
function M.onEvent(ev, p1)
  if ev == "peripheral" then
    local n = p1
    if peripheral.getType(n) == "monitor" then
      set[n] = true
      rebindPrimary()
    end
  elseif ev == "peripheral_detach" then
    local n = p1
    if set[n] then
      set[n] = nil
      if n == primaryName then
        primaryName, primaryObj = nil, nil
        rebindPrimary()
      end
    end
  elseif ev == "monitor_resize" then
    if p1 == primaryName and primaryObj then
      applyScale(primaryObj)
    end
  end
end

return M
