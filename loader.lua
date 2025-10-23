-- loader.lua — core bootstrap + event loop
local log = require("libs.log")

-- Auto-download default config.lua if missing
shell.setDir("/")  -- ensure we’re rooted
local CONFIG_PATH = "/config.lua"
local CONFIG_URL  = "https://raw.githubusercontent.com/greygamer14/cc-tweaked-greycraft/main/config.lua"

if not fs.exists(CONFIG_PATH) then
  print("[GreyCraft] No config.lua found — downloading default...")
  local h = http.get(CONFIG_URL)
  if h then
    local data = h.readAll(); h.close()
    local f = fs.open(CONFIG_PATH, "w"); f.write(data); f.close()
    print("[GreyCraft] Default config.lua installed.")
  else
    printError("[GreyCraft] Couldn’t download config.lua; continuing without it.")
  end
end

local config = require("config")
_G.config = config  -- (optional) so modules can read it from env if needed

local config = require("config")

local modules = {}

local function loadModules()
  modules = {}
  for _, name in ipairs(config.modules or {}) do
    local ok, mod = pcall(require, "modules." .. name)
    if not ok then
      log.error("Failed to require module %s: %s", name, tostring(mod))
    else
      modules[name] = mod
      log.info("Loaded module %s", name)
    end
  end
end

local function initModules()
  for name, mod in pairs(modules) do
    if type(mod.init) == "function" then
      local ok, a, b = pcall(mod.init, config[name] or {}, { config = config })
      if not ok then log.error("init %s error: %s", name, tostring(a))
      elseif a == false then log.warn("init %s returned false: %s", name, tostring(b or "")) end
    end
  end
end

local function startModules()
  for name, mod in pairs(modules) do
    if type(mod.start) == "function" then
      local ok, err = pcall(mod.start)
      if not ok then log.error("start %s error: %s", name, tostring(err)) end
    end
  end
end

local function stopModules()
  for name, mod in pairs(modules) do
    if type(mod.stop) == "function" then
      local ok, err = pcall(mod.stop)
      if not ok then log.error("stop %s error: %s", name, tostring(err)) end
    end
  end
end

-- Optional: auto-check updates on boot if updater module present
local function maybeAutoUpdate()
  if modules.updater and type(modules.updater.auto) == "function" then
    local ok, err = pcall(modules.updater.auto)
    if not ok then log.error("updater auto error: %s", tostring(err)) end
  end
end

-- Boot
log.info("Starting loader...")
loadModules()
initModules()
maybeAutoUpdate()
startModules()

-- Event loop
while true do
  local ev = { os.pullEventRaw() }
  local e = ev[1]
  if e == "terminate" then
    log.warn("Terminate received; stopping modules...")
    break
  end
  for name, mod in pairs(modules) do
    if type(mod.onEvent) == "function" then
      local ok, err = pcall(mod.onEvent, table.unpack(ev))
      if not ok then log.error("onEvent %s error: %s", name, tostring(err)) end
    end
  end
end

stopModules()
log.info("Loader exited cleanly.")
