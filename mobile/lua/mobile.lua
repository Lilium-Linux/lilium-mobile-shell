-- Mobile entry point: SOLIUM_LUA_INIT=.../lua/mobile.lua.
-- All mobile policy is Lua; the scene contains controls, never window copies.
sol.qml({ renderer = os.getenv("SOLIUM_MOBILE_SOFTWARE") == "1" and "software" or "auto" })
sol.session({ systemd = false, autostart = false })
sol.pane(require("mobile.config").pane or "mobile-flat")
sol.loading({ scene = "mobile", decorated = true, reserves_a_slot = true, fade = 160, patience = 10000 })
sol.auto_reload({ automatic = false })
sol.focus_mode({ click = true, follow = false, clear_on_empty_click = false, after_close = {} })
local mobile = require("mobile.policy")
mobile.apply()
return mobile
