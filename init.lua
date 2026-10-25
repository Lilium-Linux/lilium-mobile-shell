-- Lilium Mobile: the phone and tablet shell, as a Solium configuration.
-- This directory is the configuration (`~/.config/solium`): Solium puts it
-- first on `package.path`, loads scenes and pane styles from `qml/` and effect
-- folders from `effects/`. All policy is Lua; the scenes hold controls, never
-- copies of windows.
sol.qml({ renderer = os.getenv("SOLIUM_MOBILE_SOFTWARE") == "1" and "software" or "auto" })
sol.session({ systemd = false, autostart = false })
sol.pane(require("mobile.config").pane or "mobile-flat")
sol.loading({ scene = "mobile", decorated = true, reserves_a_slot = true, fade = 160, patience = 10000 })
sol.auto_reload({ automatic = false })
sol.focus_mode({ click = true, follow = false, clear_on_empty_click = false, after_close = {} })
-- Notifications: Solium serves them, and the shell draws them as banners
-- under the status bar (mobile/Banners.qml) and as a list on the lock sheet.
-- Declared first, so the banners are over the rest of the shell. A Solium
-- without `sol.notifications` (#346) has neither.
if sol.notifications then
    local config = require("mobile.config")
    sol.notifications({ serve = true })
    sol.surface("mobile-banners", { scene = "mobile/Banners.qml", layer = "overlay", on = "primary",
        interactive = true, properties = { statusTop = config.status, tablet = config.profile ~= "phone" } })
end
-- Audio from PipeWire itself (#347), for the Control Center's slider.
if sol.audio then
    sol.audio({})
end
local mobile = require("mobile.policy")
mobile.apply()

-- Testing touch: a whole-screen overlay of the finger (mobile/Finger.qml) and a
-- log line per touch event, only with SOLIUM_MOBILE_FINGER=1.
if os.getenv("SOLIUM_MOBILE_FINGER") == "1" then
    sol.surface("touch-finger", { scene = "mobile/Finger.qml", layer = "overlay", on = "primary",
        interactive = false, properties = { down = false, phase = "ready" } })
    local active = {}
    sol.on("touch", function(e)
        if e.kind == "down" then active[e.slot] = true end
        local count = 0
        for _ in pairs(active) do count = count + 1 end
        sol.log(string.format("SURFACE_TOUCH kind=%s slot=%d x=%.2f y=%.2f target=%s control=%s window=%s time=%d active=%d",
            e.kind, e.slot, e.x, e.y, e.target, tostring(e.control), tostring(e.window), e.time, count))
        if e.kind == "up" or e.kind == "cancel" then active[e.slot] = nil end
    end)
end
return mobile
