-- modules/door.lua — GreyCraft Gantry Door (module, fancy UI)
-- config.door:
--   side_index = 1               -- 1..6 maps to {"back","right","left","front","top","bottom"}
--   text_scale = nil|number      -- optional override; else auto
--   prefer_monitor = nil|table   -- optional list passed to monitors module (if you want)

local C = colors
local M = {}

-- state/config
local cfg = {}
local monitor, monName
local sides = {"back","right","left","front","top","bottom"}
local sideIndex = 1
local doorOpen = false
local buttons = {}

-- light logger fallback
local log = (function()
  local ok, m = pcall(require, "libs.log"); if ok then return m end
  return { info=print, warn=printError, error=printError }
end)()

----------------------------------------------------------------
-- helpers
----------------------------------------------------------------
local function getActiveSide() return sides[sideIndex] end
local function setDoor(state)
  doorOpen = state
  redstone.setOutput(getActiveSide(), state)
  log.info("[door] %s on %s", state and "OPEN" or "CLOSE", getActiveSide())
end

local function centerWrite(api, y, text, col)
  local w = select(1, api.getSize())
  local x = math.max(1, math.floor((w - #text)/2)+1)
  api.setCursorPos(x, y)
  api.setTextColor(col or C.white)
  api.write(text)
end

local function drawBox(api, x1,y1,x2,y2, fill, border)
  paintutils.drawFilledBox(x1,y1,x2,y2, fill)
  for x=x1,x2 do
    api.setCursorPos(x,y1); api.setBackgroundColor(border); api.write(" ")
    api.setCursorPos(x,y2); api.setBackgroundColor(border); api.write(" ")
  end
  for y=y1,y2 do
    api.setCursorPos(x1,y); api.setBackgroundColor(border); api.write(" ")
    api.setCursorPos(x2,y); api.setBackgroundColor(border); api.write(" ")
  end
end

local function applyScale()
  if not monitor then return end
  if cfg.text_scale then monitor.setTextScale(cfg.text_scale); return end
  local w = select(1, monitor.getSize())
  if w >= 60 then monitor.setTextScale(1)
  elseif w >= 40 then monitor.setTextScale(1.5)
  elseif w >= 30 then monitor.setTextScale(2)
  else monitor.setTextScale(2.5) end
end

local function rebuildButtons()
  buttons = {}
  if not monitor then return end
  local w = select(1, monitor.getSize())
  local function make(label, y, widthFrac, colorFill, action)
    local bw = math.max(10, math.floor(w * widthFrac))
    local x1 = math.floor((w - bw)/2)+1
    local x2 = x1 + bw - 1
    local y1 = y
    local y2 = y + 2
    local b = {x1=x1,y1=y1,x2=x2,y2=y2,label=label,fill=colorFill,action=action}
    table.insert(buttons, b)
    return b
  end

  make(doorOpen and "[ CLOSE DOOR ]" or "[ OPEN DOOR ]", 8, 0.75, doorOpen and C.orange or C.green, function()
    setDoor(not doorOpen)
  end)
  make("[ CHANGE SIDE ]", 12, 0.75, C.blue, function()
    redstone.setOutput(getActiveSide(), false)
    sideIndex = (sideIndex % #sides) + 1
  end)
end

local function drawUI()
  if not monitor then return end
  local w,h = monitor.getSize()
  monitor.setBackgroundColor(C.black); monitor.clear()
  paintutils.drawFilledBox(1,1,w,3,C.gray)
  centerWrite(monitor, 2, "== GreyCraft Door ==", C.white)

  local pill = doorOpen and " OPEN " or " CLOSED "
  local pillCol = doorOpen and C.green or C.red
  local px1 = math.floor(w/2 - #pill/2)
  paintutils.drawFilledBox(px1,4,px1+#pill-1,4,pillCol)
  centerWrite(monitor, 4, pill, C.black)

  centerWrite(monitor, 6, ("OUT: %s"):format(getActiveSide():upper()), C.lightBlue)

  rebuildButtons()
  for _,b in ipairs(buttons) do
    drawBox(monitor, b.x1, b.y1, b.x2, b.y2, b.fill, C.lightGray)
    centerWrite(monitor, math.floor((b.y1+b.y2)/2), b.label, C.white)
  end

  centerWrite(monitor, h, "Tap buttons • top-left = Back", C.lightGray)
end

local function hitTest(x,y)
  for _,b in ipairs(buttons) do
    if x>=b.x1 and x<=b.x2 and y>=b.y1 and y<=b.y2 then return b end
  end
end

local function bindMonitor()
  local monModOk, monMod = pcall(require, "modules.monitors")
  if not monModOk then
    log.warn("[door] monitors module missing; showing on terminal")
    monitor, monName = nil, nil
    return
  end
  monitor, monName = monMod.get(), monMod.getName()
  if monitor then
    applyScale()
    drawUI()
  end
end

----------------------------------------------------------------
-- lifecycle
----------------------------------------------------------------
function M.info() return {name="door", version="1.0"} end

function M.init(conf)
  cfg = conf or {}
  sideIndex = math.max(1, math.min(#sides, tonumber(cfg.side_index or 1)))
  setDoor(false)   -- ensure off at boot
  bindMonitor()
  return true
end

function M.start()
  -- nothing long-running; we’re event-driven via onEvent
end

function M.stop()
  -- turn off output and clear UI
  redstone.setOutput(getActiveSide(), false)
  if monitor then monitor.setBackgroundColor(C.black); monitor.clear() end
end

----------------------------------------------------------------
-- events
----------------------------------------------------------------
function M.onEvent(ev, p1, p2, p3, p4)
  -- rebind monitor if monitors module changed it / hot-plug
  if ev == "peripheral" or ev == "peripheral_detach" then
    local monMod = require("modules.monitors")
    local api, name = monMod.get(), monMod.getName()
    if api ~= monitor then
      monitor, monName = api, name
      if monitor then applyScale(); drawUI() end
    end
    return
  elseif ev == "monitor_resize" and monitor and p1 == monName then
    applyScale(); drawUI()
    return
  end

  -- UI interactions
  if monitor and ev == "monitor_touch" and p1 == monName then
    -- top-left to “back” (let launcher/loader handle terminate)
    if p2<=2 and p3<=2 then
      os.queueEvent("terminate")  -- handed up to loader to stop this module
      return
    end
    local b = hitTest(p2, p3)
    if b then
      -- press flash
      drawBox(monitor, b.x1,b.y1,b.x2,b.y2, colors.combine(b.fill, C.gray), C.gray)
      centerWrite(monitor, math.floor((b.y1+b.y2)/2), b.label, C.white)
      sleep(0.08)
      b.action()
      drawUI()
    end
  end
end

return M
