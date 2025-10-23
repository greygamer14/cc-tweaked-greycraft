-- modules/monitor.lua — robust monitor handler for local + wired modem monitors
-- config.monitor:
--   side = "auto" | <side> | <remote name>
--   text_scale = number | nil
local log = require("libs.log")
local M = {}

local desiredSide   -- from config ("auto" or specific)
local customScale   -- numeric or nil
local mon           -- wrapped monitor peripheral
local monName       -- name of current monitor (side or remote id)
local running = false

-- ---------- helpers ----------
local function centerWrite(api, y, text)
  local w = select(1, api.getSize())
  local x = math.max(1, math.floor((w - #text) / 2) + 1)
  api.setCursorPos(x, y)
  api.write(text)
end

local function draw()
  if not mon then return end
  local w, h = mon.getSize()
  mon.clear()
  centerWrite(mon, 1, "== GreyCraft ==")
  centerWrite(mon, math.max(3, math.floor(h/2)-1), "Modular CC:Tweaked")
  centerWrite(mon, math.max(4, math.floor(h/2)+1), "Status: RUNNING")
  centerWrite(mon, h, ("[%s  %dx%d]"):format(monName or "?", w, h))
end

local function setScaleForSize()
  if not mon then return end
  if customScale then mon.setTextScale(customScale); return end
  local w, h = mon.getSize()
  local s
  if w >= 60 and h >= 20 then s = 1
  elseif w >= 40 and h >= 14 then s = 1.5
  elseif w >= 30 and h >= 10 then s = 2
  else s = 2.5 end
  mon.setTextScale(s)
end

local function wrapMonitor(name)
  if not peripheral.isPresent(name) or peripheral.getType(name) ~= "monitor" then
    return false, "not a monitor"
  end
  local wrapped = peripheral.wrap(name)
  if not wrapped then return false, "wrap failed" end
  mon = wrapped
  monName = name
  setScaleForSize()
  local w, h = mon.getSize()
  local kind = (name:match("^monitor_%d+$") and "wired") or "local"
  log.info("Monitor attached (%s): %s [%dx%d]", kind, name, w, h)
  draw()
  return true
end

local function findAnyMonitor()
  -- search all visible peripherals (includes wired)
  for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "monitor" then
      local ok = select(1, wrapMonitor(name))
      if ok then return true end
    end
  end
  -- fallback using peripheral.find (returns first monitor)
  local name, obj = peripheral.find("monitor")
  if obj then
    mon = obj
    monName = peripheral.getName and peripheral.getName(obj) or "unknown"
    setScaleForSize()
    log.info("Monitor attached (wired find): %s", monName)
    draw()
    return true
  end
  return false
end

local function ensureMonitor()
  if mon and monName and peripheral.isPresent(monName)
     and peripheral.getType(monName) == "monitor" then
    return true
  end
  if desiredSide and desiredSide ~= "auto" then
    local ok = select(1, wrapMonitor(desiredSide))
    if ok then return true end
  end
  if findAnyMonitor() then return true end
  mon, monName = nil, nil
  return false
end

-- ---------- lifecycle ----------
function M.init(cfg)
  cfg = cfg or {}
  desiredSide = cfg.side or "auto"
  customScale = cfg.text_scale

  if not peripheral or not peripheral.getNames then
    return false, "peripheral API unavailable"
  end

  if ensureMonitor() then
    draw()
    return true
  else
    log.warn("No monitor found (side=%s). Waiting for attach…", tostring(desiredSide))
    return true
  end
end

function M.start()
  running = true
  -- Run the redraw loop in its own thread
  parallel.waitForAny(function()
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
    local name = p1
    if peripheral.getType(name) == "monitor" then
      if desiredSide == "auto" or desiredSide == name or not mon then
        local ok, err = wrapMonitor(name)
        if not ok then
          log.warn("monitor attach wrap failed on %s: %s", name, tostring(err))
        end
      end
    end
  elseif ev == "peripheral_detach" then
    local name = p1
    if name == monName then
      log.warn("Monitor %s detached.", name)
      mon, monName = nil, nil
    end
  elseif ev == "monitor_resize" then
    if p1 == monName then
      setScaleForSize()
      draw()
    end
  end
end

return M
