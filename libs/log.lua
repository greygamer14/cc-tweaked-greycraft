-- libs/log.lua — tiny logger
local M = {}

local function ts()
  local t = os.time()
  return textutils.formatTime(t, true)
end

local function fmt(s, ...)
  local ok, msg = pcall(string.format, s, ...)
  return ok and msg or (s .. " " .. table.concat({...}, " "))
end

function M.info(s, ...)  print(("[%-8s] [INFO]  %s"):format(ts(), fmt(s, ...))) end
function M.warn(s, ...)  print(("[%-8s] [WARN]  %s"):format(ts(), fmt(s, ...))) end
function M.error(s, ...) printError(("[%-8s] [ERROR] %s"):format(ts(), fmt(s, ...))) end

return M
