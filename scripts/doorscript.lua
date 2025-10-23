-- door_button.lua
-- GreyCraft Gantry Door Controller v2
-- by Greyson & Artemis ⚡

local monName = "monitor_0"   -- monitor name via modem
local sides = {"back", "right", "left", "front", "top", "bottom"}
local sideIndex = 1            -- current redstone output side

local monitor = peripheral.wrap(monName)
if not monitor then error("Monitor not found: " .. monName) end

local doorOpen = false

-- UI setup
monitor.setTextScale(2)
monitor.setBackgroundColor(colors.black)
monitor.setTextColor(colors.white)
monitor.clear()

local function getActiveSide()
  return sides[sideIndex]
end

local function drawUI()
  monitor.clear()
  local w, h = monitor.getSize()

  local openLabel = doorOpen and "[ CLOSE DOOR ]" or "[ OPEN DOOR ]"
  local changeLabel = "[ SIDE: " .. getActiveSide():upper() .. " ]"

  local openX = math.floor((w - #openLabel) / 2)
  local changeX = math.floor((w - #changeLabel) / 2)

  monitor.setCursorPos(openX, math.floor(h/2) - 1)
  monitor.write(openLabel)

  monitor.setCursorPos(changeX, math.floor(h/2) + 1)
  monitor.write(changeLabel)
end

local function toggleDoor()
  doorOpen = not doorOpen
  redstone.setOutput(getActiveSide(), doorOpen)
  print((doorOpen and "Door opening on " or "Door closing on ") .. getActiveSide())
  drawUI()
end

local function nextSide()
  -- Turn off redstone on the old side
  redstone.setOutput(getActiveSide(), false)
  sideIndex = (sideIndex % #sides) + 1
  print("Switched output to side: " .. getActiveSide())
  drawUI()
end

-- Initial state
redstone.setOutput(getActiveSide(), false)
drawUI()
print("Ready — tap monitor to toggle door or switch side.")

-- Main loop
while true do
  local ev, side, x, y = os.pullEvent()
  if ev == "monitor_touch" and side == monName then
    local w, h = monitor.getSize()
    local midY = math.floor(h/2)

    if y == midY - 1 then
      toggleDoor()
    elseif y == midY + 1 then
      nextSide()
    end

  elseif ev == "terminate" then
    monitor.clear()
    monitor.setCursorPos(1,1)
    monitor.write("Program stopped.")
    redstone.setOutput(getActiveSide(), false)
    break
  end
end
