return {
  modules = { "monitors", "launcher", "door", "updater" },

  monitors = {
    prefer = { "monitor_0", "left" },
  },

  launcher = {
    entries = {
      { label = "Door Control", kind = "module", target = "door" },
      { label = "Run Updater",  kind = "module", target = "updater" },
    }
  },

  door = {
    side_index = 1,     -- start with "back"
    text_scale = 2      -- optional; tweak to your monitor
  },

  updater = {
    manifest_url = "https://raw.githubusercontent.com/greygamer14/cc-tweaked-greycraft/main/manifest.json",
    auto_check = true
  }
}
