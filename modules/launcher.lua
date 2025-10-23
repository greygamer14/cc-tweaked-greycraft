-- modules/launcher.lua
-- GreyCraft Launcher: draws a menu on the chosen monitor from modules/monitors.
-- config.launcher:
--   text_scale = nil|number           -- optional override (applied on top)
--   entries = {
--     { label="Door (Script)",  kind="program", target="scripts/door_button" },
--     { label="Door (Module)",  kind="module",  target="door" },
--   }

local M = {}
local C = colors

local cfg = {}
local monApi   -- wrapped monitor
local monName
local buttons = {}

local log = (function()
  local ok, m = pcall(require, "libs.log")
  if ok then return m end
  return { info=print, warn=printError, error=printError }
end)()

-- helpers
local function centerWrite(api, y, text, col)
  local w = select(1, api.getSize())
  local x = math.max(1, math.floor((w - #text)/2)+1)
  api.setCursorPos(x, y)
  api.setTextColor(col or C.white)
  api.write(text)
end

local function drawButton(api, x1, y1, x2, y2, label, fill)
  paintutils.drawFilledBox(x1, y1, x2, y2, fill or C.gray)
  api.setBackgroundColor(fill or C.gray)
  centerWrite(api, math.floor((y1+y2)/2), label, C.white)
end

local function hitTest(x,y)
  for _,b in ipairs(buttons) do
    if x>=b.x1 and x<=b.x2 and y>=b.y1 and y<=b.y2 then return b end
  end
end

local function applyScale()
  if not monApi then return end
  if cfg.text_scale then monApi.setTextScale(cfg.text_scale) end
end

local function rebuildButtons()
  buttons = {}
  local w,h = monApi.getSize()
  local y = 5
  for i, entry in ipairs(cfg.entries or {}) do
    local label = entry.label or entry.target or ("Item "..i)
    local bw = math.max(12, math.floor(w*0.8))
    local x1 = math.floor((w - bw)/2) + 1
    local x2 = x1 + bw - 1
    local y1 = y
    local y2 = y1 + 2
    table.insert(buttons, {x1=x1,y1=y1,x2=x2,y2=y2,entry=entry})
    y = y + 3
  end
  table.insert(buttons, {quit=true, x1=2, y1=h-2, x2=w-1, y2=h, entry={label="[ EXIT ]"}})
end

local function drawMenu()
  if not monApi then return end
  local w,h = monApi.getSize()
  monApi.setBackgroundColor(C.black); monApi.clear()
  paintutils.drawFilledBox(1,1,w,3,C.gray)
  centerWrite(monApi, 2, "== GreyCraft Launcher ==", C.white)
  rebuildButtons()
  for _,b in ipairs(buttons) do
    drawButton(monApi, b.x1, b.y1, b.x2, b.y2, b.entry.label or "[ item ]", b.quit and C.red or C.blue)
  end
end

local function drawWaiting()
  -- minimal fallback UI when no monitor is present
  term.setBackgroundColor(C.black); term.clear()
  term.setCursorPos(1,1)
  print("Launcher: no monitor found.")
  print("Attach a local or wired monitor; launcher will bind automatically.")
end

-- lifecycle
function M.init(conf, env)
  cfg = conf or {}
  -- ask the monitors module for the current monitor
  local ok, monMod = pcall(require, "modules.monitors")
  if not ok then return false, "monitors module not available" end

  monApi  = monMod.get()
  monName = monMod.getName()
  if not monApi then
    drawWaiting()
    return true
  end
  applyScale()
  return true
end

function M.start()
  if monApi then drawMenu() else drawWaiting() end
end

function M.stop()
  if monApi then monApi.setBackgroundColor(C.black); monApi.clear() end
end

-- event handling
function M.onEvent(ev, p1, p2, p3, p4)
  -- react when monitors module rebinds (via peripheral attach/detach)
  if ev == "peripheral" or ev == "peripheral_detach" or ev == "monitor_resize" then
    local monMod = require("modules.monitors")
    local newApi, newName = monMod.get(), monMod.getName()
    if newApi ~= monApi then
      monApi, monName = newApi, newName
      if monApi then applyScale(); drawMenu() else drawWaiting() end
      return
    end
    if ev == "monitor_resize" and p1 == monName and monApi then
      applyScale(); drawMenu()
      return
    end
  end

  -- menu interaction
  if monApi and ev == "monitor_touch" and p1 == monName then
    local b = hitTest(p2, p3)
    if not b then return end
    if b.quit then
      os.queueEvent("terminate")
      return
    end
    local e = b.entry
    if e.kind == "module" then
      local ok, mod = pcall(require, "modules."..e.target)
      if not ok then centerWrite(monApi, 4, "Load error: "..tostring(mod), C.red); sleep(1.2); drawMenu(); return end
      if type(mod.init)=="function" then pcall(mod.init, (cfg[e.target] or {}), {config = _G.config or {}}) end
      if type(mod.start)=="function" then
        local ok2, err2 = pcall(mod.start)
        if not ok2 then centerWrite(monApi, 4, "Start error: "..tostring(err2), C.red); sleep(1.2) end
      end
      -- hand off control: while module runs, launcher just sits; tap top-left to exit
      -- (module can choose to handle touches; exiting is up to your loader terminate)
    elseif e.kind == "program" then
      -- run program; when it returns, redraw menu
      shell.run(e.target)
      if monApi then drawMenu() end
    end
  end
end

return M
