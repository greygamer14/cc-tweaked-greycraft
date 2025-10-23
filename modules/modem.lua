-- modules/modem.lua — unified modem handler (wired + wireless)
local log = require("libs.log")
local M = {}

local modem     -- peripheral object
local modemName -- side or network ID
local running = false
local nodeID

-- ---------- helpers ----------
local function findModem()
  for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "modem" then
      local wrapped = peripheral.wrap(name)
      if wrapped then
        modem = wrapped
        modemName = name
        log.info("Modem detected: %s (%s)", name, wrapped.isWireless and "wireless" or "wired")
        return true
      end
    end
  end
  return false
end

local function ensureModem()
  if modem and peripheral.isPresent(modemName) then
    return true
  end
  modem = nil; modemName = nil
  return findModem()
end

local function pack(data)
  if type(data) == "table" then
    return textutils.serializeJSON(data)
  else
    return tostring(data)
  end
end

local function unpack(data)
  local ok, t = pcall(textutils.unserializeJSON, data)
  if ok and type(t) == "table" then return t end
  return data
end

-- ---------- public API ----------
function M.init(cfg)
  cfg = cfg or {}
  nodeID = cfg.node_id or ("NODE-" .. os.getComputerID())
  if not findModem() then
    log.warn("No modem found — waiting for attach…")
  end
  return true
end

function M.start()
  running = true
  -- nothing long-running yet
end

function M.stop()
  running = false
end

-- send to a specific target ID or channel
function M.send(target, data)
  if not ensureModem() then
    log.error("No modem available for send()")
    return false
  end
  local payload = { id=nodeID, target=target, data=data }
  local ok = modem.transmit(tonumber(target) or 0, os.getComputerID(), pack(payload))
  if ok ~= nil then log.info("Sent packet to %s", tostring(target)) end
  return ok
end

-- broadcast on a “tag” channel (simple group message)
function M.broadcast(tag, data)
  if not ensureModem() then
    log.error("No modem available for broadcast()")
    return false
  end
  local payload = { id=nodeID, tag=tag, data=data }
  modem.transmit(0, os.getComputerID(), pack(payload))
  log.info("Broadcast tag=%s", tostring(tag))
  return true
end

-- receive next modem_message matching filter
-- filter can be a function(payload) -> true/false
function M.receive(filter, timeout)
  local timer
  if timeout then timer = os.startTimer(timeout) end
  while true do
    local ev, side, ch, rch, msg, dist = os.pullEvent()
    if ev == "modem_message" then
      local payload = unpack(msg)
      if not filter or filter(payload) then
        return payload, side, ch, dist
      end
    elseif ev == "timer" and p1 == timer then
      return nil, "timeout"
    elseif ev == "terminate" then
      error("Terminated", 0)
    end
  end
end

-- ---------- events ----------
function M.onEvent(ev, p1)
  if ev == "peripheral" and peripheral.getType(p1) == "modem" then
    log.info("Modem attached: %s", p1)
    findModem()
  elseif ev == "peripheral_detach" and p1 == modemName then
    log.warn("Modem %s detached", p1)
    modem = nil; modemName = nil
  end
end

function M.info()
  return { name="modem", version="1.0", type=(modem and (modem.isWireless() and "wireless" or "wired") or "none") }
end

return M
