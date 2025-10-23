-- modules/monitor.lua — resilient monitor UI with auto-detect + hot-plug
-- config.monitor:
--   side = "auto" | "left" | "right" | "top" | "bottom" | "back" | "front" | "<wired name>"
--   text_scale = number (optional)
local log = require("libs.log")
local M = {}

local desiredSide   -- from config (may be "auto" or nil)
local customScale   -- from config
local mon           -- wrapped monitor peripheral (or nil)
local monSide       -- the side/name we're currently bound to (or nil)
local running = false

-- ---------- helpers ----------
local function centerWrite(api, y, text)
  local w, _ = api.getSize()
  local x = math.max(1, math.floor((w - #text) / 2) + 1)
  api.setCursorPos(x, y); api.write(text)
end

local function draw()
  if not mon then return end
  local w, h = mon.getSize()
  mon.clear()
  centerWrite(mon, 1, "== GreyCraft ==")
  centerWrite(mon, math.max(3, math.floor(h/2)-1), "Modular CC:Tweaked")
  centerWrite(mon, math.max(4, math.floor(h/2)+1), "Status: RUNNING")
  centerWrite(mon, h, ("[%s  %dx%d]"):format(monSide or "?", w, h))
end

local function setScaleForSize()
  if not mon then return end
  if customScale then
    mon.setTextScale(customScale)
    return
  end
  -- Heuristic: pick something readable for typical sizes
  local w, h = mon.getSize()
  local s
  if w >= 60 and h >= 20 then s = 1
  elseif w >= 40 and h >= 14 then s = 1.5
  elseif w >= 30 and h >= 10 then s = 2
  else s = 2.5
  end
  mon.setTextScale(s)
end

local function wrapMonitor(side)
  if not peripheral or not side then return false, "no peripheral/side" end
  if not peripheral.isPresent(side) then return false, "not present" end
  if peripheral.getType(side) ~= "monitor" then return false, "not a monitor" end
  local wrapped = peripheral.wrap(side)
  if not wrapped then return false, "wrap failed" end
  mon = wrapped
  monSide = side
  setScaleForSize()
  local w, h = mon.getSize()
  log.info("Monitor attached on %s (%dx%d)", side, w, h)
  draw()
  return true
end

local function findAnyMonitor()
  for _, side in ipairs(peripheral.getNames()) do
    if peripheral.getType(side) == "monitor" then
      local ok = select(1, wrapMonitor(side))
      if ok then return true end
    end
  end
  return false
end

local function ensureMonitor()
  -- If we already have one and it still exists, keep it.
  if mon and monSide and peripheral.isPresent(monSide)
     and peripheral.getType(monSide) == "monitor" then
    return true
  end
  -- Otherwise try to (re)acquire specifically requested side…
  if desiredSide and desiredSide ~= "auto" then
    local ok = select(1, wrapMonitor(desiredSide))
    if ok then return true end
  end
  -- …or auto-find any monitor.
  if peripheral and findAnyMonitor() then return true end
  -- No monitor found.
  mon = nil; monSide = nil
  return false
end

-- ---------- lifecycle ----------
function M.init(cfg)
  cfg = cfg or {}
  desiredSide = cfg.side or "auto"
  customScale = cfg.text_scale  -- may be nil

  if not peripheral or not peripheral.getNames then
    return false, "peripheral API unavailable"
  end

  if ensureMonitor() then
    draw()
    return true
  else
    log.warn("No monitor found (side=%s). Waiting for attach…", tostring(desiredSide))
    return true  -- init succeeds; we'll hot-plug later
  end
end

function M.start()
  running = true
  -- Passive refresher: redraw every couple seconds if we have a monitor.
  parallel.spawn(function()
    while running do
      if ensureMonitor() then draw() end
      sleep(2)
    end
  end)
end

function M.stop()
  running = false
  if mon then
    mon.clear()
    mon.setCursorPos(1,1)
    mon.write("Stopped.")
  end
end

-- ---------- events ----------
function M.onEvent(ev, p1, p2, p3)
  if ev == "peripheral" then
    -- A peripheral appeared. If it's our desired side (or we're auto),
    -- try to wrap it.
    local side = p1
    local typ  = peripheral.getType and peripheral.getType(side)
    if typ == "monitor" then
      if desiredSide == "auto" or desiredSide == side or not mon then
        local ok, err = wrapMonitor(side)
        if not ok then log.warn("monitor attach wrap failed on %s: %s", side, tostring(err)) end
      end
    end
  elseif ev == "peripheral_detach" then
    local side = p1
    if side == monSide then
      log.warn("Monitor on %s detached.", side)
      mon = nil; monSide = nil
    end
  elseif ev == "monitor_resize" then
    -- p1 is the side that resized (wired monitors also emit this)
    if p1 == monSide then
      setScaleForSize()
      draw()
    end
  end
end

return M
