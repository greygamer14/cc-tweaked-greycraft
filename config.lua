-- config.lua (default)
return {
  modules = { "monitors", "launcher", "updater" },

  monitors = {
    -- Try these names first if present; otherwise auto-pick any monitor
    prefer = { "monitor_0", "left" },
    -- text_scale = 1.5,  -- uncomment to force a scale
  },

  launcher = {
    -- text_scale = 2,    -- optional launcher override
    entries = {
      { label = "Door Control", kind = "program", target = "scripts/door_button" },
      -- later you can add: { label="Door (Module)", kind="module", target="door" },
      { label = "Run Updater",  kind = "module",  target = "updater" }
    }
  },

  updater = {
    manifest_url = "https://raw.githubusercontent.com/greygamer14/cc-tweaked-greycraft/main/manifest.json",
    auto_check   = true
  }
}
