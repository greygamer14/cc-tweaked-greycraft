-- modules/updater.lua — simple HTTP updater using a manifest JSON
-- config.updater = { manifest_url="...", auto_check=true/false }
local log = require("libs.log")
local M = {}
local cfg

local function get(url)
  local ok, h = pcall(http.get, url)
  if not ok or not h then return nil, "HTTP GET failed: "..tostring(url) end
  local data = h.readAll(); h.close()
  if not data or #data == 0 then return nil, "Empty response for "..url end
  return data
end

local function writeIfChanged(path, data)
  local same = false
  if fs.exists(path) then
    local f = fs.open(path, "r"); local cur = f.readAll(); f.close()
    same = (cur == data)
  end
  if same then return false end
  local dir = fs.getDir(path); if dir ~= "" then fs.makeDir(dir) end
  local f = fs.open(path, "w"); f.write(data); f.close()
  return true
end

local function apply(manifest)
  local changed = 0
  for _, item in ipairs(manifest.files or {}) do
    local data, err = get(item.url)
    if not data then
      log.error("Failed to fetch %s: %s", item.url, err)
    else
      if writeIfChanged(item.path, data) then
        log.info("Updated %s", item.path)
        changed = changed + 1
      else
        log.info("Up-to-date %s", item.path)
      end
    end
  end
  return changed
end

local function loadManifest(url)
  local raw, err = get(url)
  if not raw then return nil, err end
  local ok, man = pcall(textutils.unserialiseJSON, raw)
  if not ok or type(man) ~= "table" then return nil, "Bad JSON manifest" end
  return man
end

function M.init(moduleCfg)
  cfg = moduleCfg or {}
  if not http then
    return false, "HTTP API disabled"
  end
  if not cfg.manifest_url then
    return false, "manifest_url not set"
  end
  return true
end

function M.auto()
  if not cfg or not cfg.auto_check then return end
  local man, err = loadManifest(cfg.manifest_url)
  if not man then log.error("Updater: %s", err); return end
  log.info("Updater: checking version %s …", tostring(man.version or "?"))
  local changed = apply(man)
  if changed > 0 then
    log.warn("Updater: %d file(s) changed. Rebooting…", changed)
    sleep(0.4)
    os.reboot()
  else
    log.info("Updater: no changes.")
  end
end

-- Expose manual check: `modules.updater.check()`
function M.check()
  local man, err = loadManifest(cfg.manifest_url)
  if not man then log.error("Updater: %s", err); return end
  local changed = apply(man)
  if changed > 0 then
    log.warn("Updater: %d file(s) changed. Rebooting…", changed)
    sleep(0.4)
    os.reboot()
  else
    log.info("Updater: no changes.")
  end
end

return M
