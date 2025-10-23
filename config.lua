-- config.lua (GreyCraft Default Configuration)
return {
  modules = { "monitors", "launcher", "door", "updater" },

  monitors = {
    prefer = { "monitor_0", "left" },
    text_scale = nil
  },

  launcher = {
    text_scale = nil,
    entries = {
      { label = "Door Control", kind = "module", target = "door" },
      { label = "Run Updater",  kind = "module", target = "updater" }
    }
  },

  door = {
    -- defaults for your gantry door module
    monitor = "auto",     -- automatically bind monitor
    side_index = 1,       -- start on “back” redstone side
    text_scale = 2,       -- smaller = more text, larger = bigger buttons
  },

  updater = {
    manifest_url = "https://raw.githubusercontent.com/greygamer14/cc-tweaked-greycraft/main/manifest.json",
    auto_check = true
  }
}
