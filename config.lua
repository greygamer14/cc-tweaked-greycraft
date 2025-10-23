-- config.lua
return {
  modules = {
    "monitor",
    "updater",
    "modem"
  },

  monitor = {
    side = "auto",
    text_scale = nil
  },

  updater = {
    manifest_url = "https://raw.githubusercontent.com/greygamer14/cc-tweaked-greycraft/main/manifest.json",
    auto_check   = true
  },

  modem = {
    node_id = "GREY-001"
  }
}
