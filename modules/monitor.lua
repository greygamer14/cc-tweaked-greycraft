-- modules/monitor.lua — simple status UI that adapts to monitor size
local log = require("libs.log")
local M = {}

local mon, side
local running = false
local customScale

local function pickScale(w, h)
  -- If user set a scale in config, use it. Else choose a readable scale.
  if customScale then return customScale end
  -- Heuristic: keep ~30+ columns if possible
  for s = 0.5, 5, 0.5 do
    local cols = math.floor(w / s) -- not exact; monitors scale font, but heuristic works
  end
  -- Try coarse guess based on size:
  if w >= 60 and h >= 20 then return 1
  elseif w >= 40 and h >= 14 then return 1.5
  elseif w >= 30 and h >= 10 then return 2
  else return 2.5 end
end

local function centerWrite(api, y, text)
  local w, _ = api.getSize()
  local x = math.max(1, math.floor((w - #text) / 2) + 1)
  api.setCursorPos(x, y); api.write(text)
end

local function draw()
  if not mon then return end
  local w, h = mon.getSize()
  mon.clear()
  mon.setCursorPos(1,1)
  centerWrite(mon, 1, "== GreyCraft ==")
  centerWrite(mon, math.max(3, math.floor(h/2)-1), "Modular CC:Tweaked")
  centerWrite(mon, math.max(4, math.floor(h/2)+1), "Status: RUNNING")
  centerWrite(mon, h, ("[%s, %dx%d]"):format(side or "?", w, h))
end

function M.init(cfg)
  cfg = cfg or {}
  side = cfg.side or "left"
  customScale = cfg.text_scale -- may be nil
  if not peripheral or not peripheral.isPresent(side) then
    return false, "no monitor on side "..tostring(side)
  end
  if peripheral.getType(side) ~= "monitor" then
    return false, "peripheral on "..side.." is not a monitor"
  end
  mon = peripheral.wrap(side)
  local w, h = mon.getSize()
  local s = pickScale(w, h)
  mon.setTextScale(s)
  log.info("Monitor wrapped on %s, size %dx%d, scale %.1f", side, w, h, s)
  draw()
  return true
end

function M.start()
  running = true
  parallel.spawn(function()
    while running do
      draw()
      sleep(2)
    end
  end)
end

function M.stop()
  running = false
  if mon then mon.clear(); mon.setCursorPos(1,1); mon.write("Stopped.") end
end

function M.onEvent(ev, ...)
  if ev == "monitor_resize" then
    draw()
  end
end

return M
