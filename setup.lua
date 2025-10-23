-- setup.lua — Modular CC:Tweaked bootstrapper (tailored for @greygamer14/cc-tweaked-greycraft)
-- Usage on a CC computer: save as 'setup', then run: setup

local function println(...) print(table.concat({...}," ")) end
local function errln(...) printError(table.concat({...}," ")) end

if not http then
  errln("HTTP API is disabled. Enable it in the CC:Tweaked config and retry.")
  return
end

local function prompt(label, default)
  io.write((default and (label.." ["..default.."]: ") or (label..": ")))
  local s = read()
  if s == "" or s == nil then return default end
  return s
end

local function yesno(label, default)
  local def = default and "Y/n" or "y/N"
  while true do
    io.write(label.." ("..def.."): ")
    local s = (read() or ""):lower()
    if s == "" then return default
    elseif s == "y" or s == "yes" then return true
    elseif s == "n" or s == "no" then return false end
  end
end

local function ensureDir(path)
  if not fs.exists(path) then fs.makeDir(path) end
end

local function backupIfExists(path)
  if fs.exists(path) then
    local bak = path..".bak"
    local i = 1
    while fs.exists(bak) do i = i + 1; bak = path..".bak"..i end
    fs.move(path, bak)
    println("• Backed up", path, "->", bak)
  end
end

local function download(url, dest)
  local ok, res = pcall(http.get, url)
  if not ok or not res then return false, "HTTP GET failed for "..url end
  local data = res.readAll(); res.close()
  if not data or #data == 0 then return false, "Empty response for "..url end
  backupIfExists(dest)
  ensureDir(fs.getDir(dest))
  local f = fs.open(dest,"w"); f.write(data); f.close()
  println("✓ Wrote", dest)
  return true
end

println("== Modular CC:Tweaked Setup (GreyCraft) ==")

-- Defaults pointed at your repo
local gh_user   = prompt("GitHub username", "greygamer14")
local gh_repo   = prompt("Repository name", "cc-tweaked-greycraft")
local gh_branch = prompt("Branch", "main")

local function raw_url(path)
  return ("https://raw.githubusercontent.com/%s/%s/%s/%s"):format(gh_user, gh_repo, gh_branch, path)
end

-- Catalog (you can expand this later)
local catalog = {
  { key="loader",  desc="Core loader (bootstrap + event loop)",
    files={{src="loader.lua", dst="loader.lua"}}, default=true },
  { key="log",     desc="Logging helper (libs/log.lua)",
    files={{src="libs/log.lua", dst="libs/log.lua"}}, default=true },
  { key="monitor", desc="Monitor UI (modules/monitor.lua)",
    files={{src="modules/monitor.lua", dst="modules/monitor.lua"}}, default=true,
    configurator=function()
      local side = prompt("Monitor side", "left")
      local scale = tonumber(prompt("Text scale (auto=blank, else 0.5–5)", "")) or nil
      return { side = side, text_scale = scale }
    end
  },
  { key="updater", desc="HTTP updater (modules/updater.lua) + manifest",
    files={{src="modules/updater.lua", dst="modules/updater.lua"}}, default=true,
    configurator=function()
      local manifestURL = prompt("Manifest URL", raw_url("manifest.json"))
      local auto = yesno("Check for updates on boot?", true)
      return { manifest_url = manifestURL, auto_check = auto }
    end
  },
}

println("\nAvailable components:")
for i,item in ipairs(catalog) do
  println(("  %2d) [%s] %s"):format(i, item.default and "x" or " ", item.desc))
end
println("\nSelect by number (comma-separated), or press Enter for defaults.")
io.write("Your selection: ")
local selLine = read() or ""

local selected = {}
if selLine == "" then
  for i,item in ipairs(catalog) do if item.default then table.insert(selected, i) end end
else
  for token in selLine:gmatch("[^,%s]+") do
    local idx = tonumber(token); if idx and catalog[idx] then table.insert(selected, idx) end
  end
  if #selected == 0 then errln("No valid selection; aborting."); return end
end

ensureDir("modules"); ensureDir("libs")

local chosenModules, perConfig = {}, {}
for _,idx in ipairs(selected) do
  local item = catalog[idx]
  println("\nInstalling:", item.desc)
  for _,f in ipairs(item.files) do
    local ok, msg = download(raw_url(f.src), f.dst)
    if not ok then errln("!! "..msg.."\nAborting setup."); return end
  end
  for _,f in ipairs(item.files) do
    local modName = f.dst:match("^modules/(.+)%.lua$")
    if modName then
      table.insert(chosenModules, modName)
      if item.configurator then perConfig[modName] = item.configurator() or {} end
    end
  end
end

-- Build config.lua
local cfg = {
  modules = chosenModules,
  _meta = { github_user = gh_user, github_repo = gh_repo, github_branch = gh_branch }
}
for k,v in pairs(perConfig) do cfg[k] = v end

local function serialize(value, indent)
  indent = indent or 0
  local t = type(value)
  if t == "string" then return string.format("%q", value)
  elseif t == "number" or t == "boolean" or t == "nil" then return tostring(value)
  elseif t == "table" then
    local out = {"{\n"}; local pad = string.rep("  ", indent+1)
    local n = #value
    for i=1,n do table.insert(out, pad..serialize(value[i], indent+1)..",\n") end
    for k,v in pairs(value) do if type(k)~="number" then table.insert(out, pad..k.." = "..serialize(v, indent+1)..",\n") end end
    table.insert(out, string.rep("  ", indent).."}")
    return table.concat(out)
  end
  return "nil"
end

local cfgText = "-- Generated by setup.lua\nreturn "..serialize(cfg).."\n"
backupIfExists("config.lua")
local f = fs.open("config.lua","w"); f.write(cfgText); f.close()
println("\n✓ config.lua written.")
println("\nAll set! Run your program with:  loader")
println("Re-run this installer anytime with:  setup")
