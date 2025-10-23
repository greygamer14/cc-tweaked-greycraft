-- GreyCraft Gantry Door Controller (fancy UI)
-- - Colored, bordered buttons w/ press animation
-- - OPEN/CLOSE toggle via redstone
-- - Cycle computer output side
-- - Auto-detect wired monitor if monName = "auto"

-------------------------------------------------
-- CONFIG
-------------------------------------------------
local monName = "auto"          -- "auto" or explicit name like "monitor_0"
local sides = {"back","right","left","front","top","bottom"}
local startSideIndex = 1        -- which side to start with
local textScale = nil           -- nil = auto; else number 0.5..5

-------------------------------------------------
-- STATE
-------------------------------------------------
local monitor
local doorOpen = false
local sideIndex = startSideIndex

-------------------------------------------------
-- UTILS
-------------------------------------------------
local function findAnyMonitor()
  if peripheral.find then
    local name, obj = peripheral.find("monitor")
    if obj then return name, obj end
  end
  for _, n in ipairs(peripheral.getNames()) do
    if peripheral.getType(n) == "monitor" then
      return n, peripheral.wrap(n)
    end
  end
end

local function pickScale(w, h)
  if textScale then return textScale end
  -- keep ~16-20 cols for nice buttons
  if w >= 60 then return 1
  elseif w >= 40 then return 1.5
  elseif w >= 30 then return 2
  elseif w >= 24 then return 2.5
  else return 3
  end
end

local function getActiveSide() return sides[sideIndex] end
local function setDoor(out) doorOpen = out; redstone.setOutput(getActiveSide(), out) end

-------------------------------------------------
-- DRAWING (fancy)
-------------------------------------------------
local C = colors
local function clamp(n,a,b) if n<a then return a elseif n>b then return b else return n end end

local function drawBox(x1,y1,x2,y2, fill, border)
  -- filled rect + single-pixel border
  paintutils.drawFilledBox(x1,y1,x2,y2, fill)
  for x=x1,x2 do
    monitor.setCursorPos(x,y1); monitor.setBackgroundColor(border); monitor.write(" ")
    monitor.setCursorPos(x,y2); monitor.setBackgroundColor(border); monitor.write(" ")
  end
  for y=y1,y2 do
    monitor.setCursorPos(x1,y); monitor.setBackgroundColor(border); monitor.write(" ")
    monitor.setCursorPos(x2,y); monitor.setBackgroundColor(border); monitor.write(" ")
  end
end

local function centerWrite(y, text, col)
  local w = select(1, monitor.getSize())
  local x = math.max(1, math.floor((w - #text)/2)+1)
  monitor.setCursorPos(x,y)
  monitor.setTextColor(col or C.white)
  monitor.write(text)
end

-- button registry
local buttons = {}
local function makeButton(label, y, widthFrac, colorFill, action)
  local w,h = monitor.getSize()
  local bw = math.max(10, math.floor(w * widthFrac))
  local x1 = math.floor((w - bw)/2)+1
  local x2 = x1 + bw - 1
  local y1 = y
  local y2 = y + 2
  local btn = {x1=x1,y1=y1,x2=x2,y2=y2,label=label,fill=colorFill,action=action}
  table.insert(buttons, btn)
  return btn
end

local function drawButton(btn, pressed)
  local border = pressed and C.gray or C.lightGray
  local fill   = pressed and colors.combine(btn.fill, C.gray) or btn.fill
  drawBox(btn.x1, btn.y1, btn.x2, btn.y2, fill, border)
  centerWrite(math.floor((btn.y1+btn.y2)/2), btn.label, C.white)
end

local function redraw()
  local w,h = monitor.getSize()
  monitor.setBackgroundColor(C.black)
  monitor.setTextColor(C.white)
  monitor.clear()

  -- title bar
  paintutils.drawFilledBox(1,1,w,3, C.gray)
  centerWrite(2, "== GreyCraft Gantry Door ==", C.white)

  -- status pill
  local pill = doorOpen and " OPEN " or " CLOSED "
  local pillCol = doorOpen and C.green or C.red
  local px1 = math.floor(w/2 - #pill/2)
  paintutils.drawFilledBox(px1,4,px1+#pill-1,4,pillCol)
  centerWrite(4, pill, C.black)

  -- current side (caption)
  local caption = ("OUT: %s"):format(getActiveSide():upper())
  centerWrite(6, caption, C.lightBlue)

  -- rebuild & draw buttons
  buttons = {}
  local b1 = makeButton(doorOpen and "[ CLOSE DOOR ]" or "[ OPEN DOOR ]", 8, 0.75, doorOpen and C.orange or C.green,
    function()
      setDoor(not doorOpen)
      redraw()
    end)

  local b2 = makeButton("[ CHANGE SIDE ]", 12, 0.75, C.blue,
    function()
      -- turn off old side before switching
      redstone.setOutput(getActiveSide(), false)
      sideIndex = (sideIndex % #sides) + 1
      redraw()
    end)

  drawButton(b1, false)
  drawButton(b2, false)

  -- footer
  centerWrite(h, "Tap a button. Ctrl+T to exit.", C.lightGray)
end

local function hitTest(x,y)
  for _,b in ipairs(buttons) do
    if x>=b.x1 and x<=b.x2 and y>=b.y1 and y<=b.y2 then return b end
  end
end

-------------------------------------------------
-- BOOTSTRAP
-------------------------------------------------
-- locate & prep monitor
do
  local name,obj = monName=="auto" and findAnyMonitor() or monName, (monName=="auto" and select(2, findAnyMonitor()) or peripheral.wrap(monName))
  if not obj then error("Monitor not found: "..tostring(name)) end
  monitor = obj
  local w,h = monitor.getSize()
  monitor.setTextScale(pickScale(w,h))
end

-- initial state
setDoor(false)
redraw()

-------------------------------------------------
-- LOOP
-------------------------------------------------
while true do
  local ev, p1, x, y = os.pullEvent()
  if ev == "monitor_touch" then
    -- any wired/local monitor name triggers, as long as it's THIS one
    local theseNames = { peripheral.getName and peripheral.getName(monitor) or nil }
    local isThis = (p1 == monName) or (theseNames[1] and p1 == theseNames[1])
    if isThis then
      local b = hitTest(x,y)
      if b then
        drawButton(b, true); sleep(0.08); drawButton(b, false)
        b.action()
      end
    end
  elseif ev == "monitor_resize" then
    -- adapt scale if size changes
    local w,h = monitor.getSize()
    monitor.setTextScale(pickScale(w,h))
    redraw()
  elseif ev == "terminate" then
    -- tidy
    redstone.setOutput(getActiveSide(), false)
    monitor.setBackgroundColor(C.black); monitor.clear()
    break
  end
end
