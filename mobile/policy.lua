-- A single-display mobile session. Membership, navigation and layout have one
-- authority here. Home never closes a client; Recents transforms real panes.
local config = require("mobile.config")
local mobile = {}
local last_geometry
local presentations = {}
local pane_style = config.pane or "mobile-flat"
local swipe = { offset = 0, lift = 0, id = 0 }
local nav, home_exit
local K = require("kinetics")
local touch_config = { edge=36, travel=0.45, commit=0.34, fling=1000,
    deceleration=2400, window_ms=80, stale_ms=100, handle_width=52, elastic=0.18, home_progress=1.2, max_release_speed=4000,
    stiffness=300, damping=25, mass=1, tap=8 }
local pending_launch
local card_slots = {}
local dismissals = {}
local home_ids, home_targets = {}, {}
local fading = {}
local effects_loaded = false
-- Where each window was last drawn as a Recents card, by id: what it opens
-- out of, corners and shadow relaxing as it grows (card_shape).
local card_rects = {}
local home_serial = 0
local state = sol.keep("mobile.v1", {
    page = "home", previous = "home", active = 0, order = {},
    split = {}, ratio = 0.5, picker = 0, closing = {},
})
state.overview_offset = state.overview_offset or 0
state.launcher_icons = state.launcher_icons or {}
-- The flights to and from an icon, measured from the iPad (design-notes 19):
-- the size on a critically damped spring of response 0.35 s (omega 18), the
-- centre on a quicker one (omega 25), which puts it at 0.51 of the way when
-- the size is at 0.355, as the iPad's is; going home, the window opaque for
-- about half the way and all icon by the end.
local home_flight = {
    lead = { stiffness = 625, damping = 50 },
    size = { stiffness = 324, damping = 36 },
    -- Going home, the window's content fades inside its pane from about 55 %
    -- of the size's way to 90 %, showing the pane's icon layer behind it.
    client = { duration = 230, easing = { 0.7, 0, 0.9, 0.55 } },
    -- The pane itself goes only once it has landed on the launcher's icon,
    -- over the slot's own icon, which is back by then (`returns`).
    land = { duration = 520, easing = { 1, 0, 1, 0 } },
    -- When the slot's icon is back under the landing pane: it covers it from
    -- here, so the two never show at once and the pane's fade shows nothing.
    returns = 300,
    -- A launch shows the icon for its first 100 ms, then the window's content.
    reveal = { duration = 80, easing = "linear" },
    -- How far the wallpaper is dimmed behind an open application.
    dim = 0.45,
    -- How far the corners rise above the icon's through the middle of a
    -- flight, in logical pixels (the iPad's 40 recording pixels).
    corner_peak = 32,
}
-- `config.pace` stretches every flight evenly: each spring's frequency is
-- divided by it at the same damping ratio, and each duration multiplied.
local pace = math.max(0.25, config.pace or 1)
for _, timed in ipairs({ home_flight.client, home_flight.land, home_flight.reveal }) do
    timed.duration = math.floor(timed.duration * pace + 0.5)
end
home_flight.returns = math.floor(home_flight.returns * pace + 0.5)
-- The finger-driven springs (Recents, cards, a cancelled swipe) and the plain
-- page motions slow down with them. Not a card's dismissal: it must be off
-- screen inside the compositor's 190 ms closing phase.
local touch_spring = { stiffness = touch_config.stiffness / (pace * pace),
    damping = touch_config.damping / pace, mass = touch_config.mass }
local function paced(motion)
    return { duration = math.floor(motion.duration * pace + 0.5), easing = motion.easing }
end
local page_motion, quick_motion = paced(config.motion), paced(config.quick)
local function spring(settings, velocity)
    return { easing = { spring = { stiffness = settings.stiffness / (pace * pace),
        damping = settings.damping / pace, initial_velocity = velocity or 0 } } }
end
local launcher_icons = state.launcher_icons
state.settings = state.settings or { brightness = 1, dark = false, reduceMotion = false }
local pages = { home = true, apps = true, recents = true, app = true, shade = true }
if not pages[state.page] then state.page = "home" end

local function screen()
    local all = sol.monitors()
    for _, monitor in ipairs(all) do
        if monitor.primary then return monitor end
    end
    return all[1]
end

local function dimensions()
    local monitor = screen()
    local whole = monitor and (monitor.whole or monitor) or { x = 0, y = 0, w = 390, h = 844 }
    local tablet = config.profile == "tablet"
        or (config.profile ~= "phone" and math.min(whole.w, whole.h) >= 600)
    return whole, {
        x = whole.x, y = whole.y + config.status,
        w = whole.w, h = math.max(1, whole.h - config.status - config.navigation),
    }, tablet
end

-- The pane's shape on the way (effects/mobile-flight): narrowed toward the
-- icon and squared before it lands. Its progress runs on the present's own
-- timing, which a flight sets to the size's spring.
local function flight_shape(target)
    local _, area = dimensions()
    local monitor = screen()
    local scale = monitor and monitor.scale or 1
    return { effect = "mobile-flight", to = { x = target.x, y = target.y, w = target.w, h = target.h },
        land_x = math.min(1, target.w / area.w), land_y = math.min(1, target.h / area.h),
        radius = target.w / 4 * scale, peak = home_flight.corner_peak * scale }
end

-- A window growing out of its icon: centre ahead of size, the icon first.
local function from_icon(rect)
    -- In the icon's shape at first, relaxed to the plain window as it lands.
    return { x = rect.x, y = rect.y, w = rect.w, h = rect.h, client_opacity = 0,
        deform = flight_shape(rect),
        motion = { x = spring(home_flight.lead), y = spring(home_flight.lead),
            size = spring(home_flight.size), client_opacity = home_flight.reveal } }
end

-- Which window is flying to or from its icon, for the pane style's icon layer
-- (panes/mobile/Icon.qml), and which launcher slot it empties meanwhile.
local flight, flight_serial = nil, 0
local function start_flight(kind, key, window)
    flight_serial = flight_serial + 1
    flight = { kind = kind, key = (key or ""):gsub("%.desktop$", ""),
        title = window and window.title or "", appId = window and window.app_id or "" }
    sol.pane_values({ mobileFlight = flight })
end
local function end_flight()
    if flight then flight = nil; sol.pane_values({ mobileFlight = false }) end
end

local function promote(id)
    local out = { id }
    for _, other in ipairs(state.order) do
        if other ~= id then out[#out + 1] = other end
    end
    state.order = out
end

local function windows()
    local monitor = screen()
    local by_id, dialogs = {}, {}
    for _, window in ipairs(sol.windows()) do
        if (not monitor or window.monitor == monitor.name)
            and not window.leaving and not state.closing[window.id] then
            if window.modal then dialogs[#dialogs + 1] = window
            else by_id[window.id] = window end
        end
    end
    for id in pairs(presentations) do
        if not by_id[id] then presentations[id] = nil end
    end
    local ordered, held = {}, {}
    for _, id in ipairs(state.order) do
        if by_id[id] then
            ordered[#ordered + 1] = by_id[id]
            held[id] = true
        end
    end
    for _, window in ipairs(sol.windows()) do
        if by_id[window.id] and not held[window.id] then
            ordered[#ordered + 1] = window
            held[window.id] = true
        end
    end
    state.order = {}
    for _, window in ipairs(ordered) do state.order[#state.order + 1] = window.id end
    if not by_id[state.active] then state.active = ordered[1] and ordered[1].id or 0 end
    if #state.split == 2 and (not by_id[state.split[1]] or not by_id[state.split[2]]) then
        state.split = {}
    end
    if not by_id[state.picker] then state.picker = 0 end
    if state.page == "app" and state.active == 0 then state.page = "home" end
    return ordered, by_id, dialogs
end

local function rect(x, y, w, h)
    return { x = x, y = y, w = math.max(1, w), h = math.max(1, h) }
end

-- Keep the departing cards' exact rectangles and depth. These stay parked at
-- alpha zero until the next overview, including through client configures.
local function fade_recents()
    local page = state.page == "shade" and state.previous or state.page
    if page ~= "recents" then return end
    fading = {}
    for _, card in ipairs(card_slots) do fading[card.id] = card end
end

-- The effect folders the presents name, loaded before the first one plays.
-- No slot rules: a window's corners are its present's (mobile-card in
-- Recents and under the finger, mobile-flight to and from its icon), so a
-- window is cut round only while it is drawn as a card, at the size it is
-- drawn, and kept until it changes.
-- The Control Center (qml/mobile/ControlCenter.qml): its surface while it is
-- open or moving, nil once it has closed. `over_app`: opened over an
-- application, whose own pixels are then what is blurred. `panel` is where its
-- panel rests, in fractions of the screen, which the scene reports.
local control = nil
local control_release = 0
local control_amount = -1
local control_panel = { x = 0.7, y = 0, w = 0.3, h = 1, soft = 0.2 }

-- Every effects setting the shell gives: the folders its presents name, the
-- backdrop's layers (the wallpaper and the launcher), and while the Control
-- Center is open the blur under its panel at `amount`, 0 to 1. Re-sent as the
-- amount moves; Solium keeps every capture across a re-send that changes a
-- param alone (#305), so each step only runs the blur again.
local function shell_effects(amount)
    local rules = {}
    if control and amount > 0 then
        local whole, area = dimensions()
        local panel = control_panel
        if control.over_app then
            -- The panel's rectangle in the application's own pixels: it fills
            -- the area below the status bar.
            local function across(v) return (v * whole.w + whole.x - area.x) / area.w end
            local function down(v) return (v * whole.h + whole.y - area.y) / area.h end
            rules[1] = { match = { fullscreen = false }, part = "client", slot = "replace",
                effect = { "cc-blur", amount = amount, mask_x = across(panel.x), mask_y = down(panel.y),
                    mask_w = panel.w * whole.w / area.w, mask_h = panel.h * whole.h / area.h,
                    soft = (panel.soft or 0.2) * whole.w / area.w } }
        else
            rules[1] = { match = { surface = "mobile-control" }, part = "surface:mobile-control",
                slot = "behind", effect = { "cc-fade", amount = amount, mask_x = panel.x,
                    mask_y = panel.y, mask_w = panel.w, mask_h = panel.h, soft = panel.soft or 0.2 } }
        end
    end
    sol.effects({ rules = rules, load = { "mobile-flight", "mobile-card", "cc-blur", "cc-fade" },
        xray = { layers = { "background", "bottom" } } })
end

local function load_effects()
    if effects_loaded then return end
    effects_loaded = true
    shell_effects(0)
end

-- A window drawn at `rect` as a card with `radius` logical pixels of corner
-- on screen (effects/mobile-card). The radius is handed over in the
-- capture's pixels, which are the window's own at the monitor's scale, so
-- the corner is the same on screen at any card size, and blends with the
-- present's motion; `px` is the capture's pixels per physical screen pixel,
-- `dpr` the monitor's scale, and `shadow` how much of the card's shadow is
-- drawn.
local function card_shape(rect, area, radius, shadow)
    local monitor = screen()
    local scale = monitor and monitor.scale or 1
    local over = area.w / math.max(rect.w, 1)
    return { effect = "mobile-card", to = { x = rect.x, y = rect.y, w = rect.w, h = rect.h },
        radius = radius * scale * over, px = over, dpr = scale, shadow = shadow or 1 }
end

-- The Control Center's surface, with what it shows. Only what changed need be
-- given: a key left out keeps the value the scene last had.
local function control_show(properties)
    sol.surface("mobile-control", { scene = "mobile/ControlCenter.qml", layer = "overlay",
        on = "primary", interactive = true, properties = properties })
end

-- The shell's chrome (status bar, dock, dim) with some of its properties
-- changed, and nothing laid out again: what a slider or the status needs.
local function chrome_update(properties)
    sol.surface("mobile-shell", { scene = "mobile/Shell.qml", layer = "overlay", on = "primary",
        interactive = true, reserve = { top = config.status, bottom = config.navigation },
        properties = properties })
end

-- What the device says: read where it is quick, never on a gesture's path.
-- The battery and the backlight are sysfs files, read at once. Wi-Fi,
-- Bluetooth and the volume take commands that can stall for a tenth of a
-- second, so a command in the background writes them to a file
-- (`refresh_status`) and the shell reads the file.
local function read_file(path)
    local file = io.open(path)
    if not file then return nil end
    local text = file:read("*a")
    file:close()
    return text
end

local function first_line(command)
    local pipe = io.popen(command)
    if not pipe then return nil end
    local line = pipe:read("*l")
    pipe:close()
    return line
end

-- The battery and the backlight, each found once.
local battery_dir = first_line("ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -1")
local backlight_dir = first_line("ls -d /sys/class/backlight/* 2>/dev/null | head -1")
local status_file = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/lilium-mobile-status"
local status = { wifi = false, linked = false, bluetooth = false, volume = nil,
    media = "", title = "", artist = "" }
local airplane = false

-- A command the shell runs on the device: the volume, the backlight, a
-- radio, a screenshot. With LILIUM_MOBILE_DRY_RUN=1, logged and not run, so a
-- nested test on a desktop leaves that desktop's audio, screen and radios
-- alone.
local dry_run = os.getenv("LILIUM_MOBILE_DRY_RUN") == "1"
local function run(...)
    if dry_run then
        sol.log("lilium-mobile dry run: " .. table.concat({ ... }, " "))
        return
    end
    sol.run(...)
end

local function refresh_status()
    run("sh", "-c", [[
w=$(nmcli radio wifi 2>/dev/null)
l=$(nmcli -t -f TYPE,STATE device 2>/dev/null | grep -c '^wifi:connected$')
b=$(bluetoothctl show 2>/dev/null | awk '/Powered:/ {print $2; exit}')
v=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{print $2}')
m=$(playerctl status 2>/dev/null)
t=$(playerctl metadata title 2>/dev/null | tr -d '\n')
a=$(playerctl metadata artist 2>/dev/null | tr -d '\n')
printf 'wifi=%s\nlinked=%s\nbluetooth=%s\nvolume=%s\nmedia=%s\ntitle=%s\nartist=%s\n' \
    "$w" "$l" "$b" "$v" "$m" "$t" "$a" > "$0.tmp" && mv "$0.tmp" "$0"
]], status_file)
end

local function read_status()
    local text = read_file(status_file)
    if not text then return end
    local values = {}
    for key, value in text:gmatch("([%w_]+)=([^\n]*)") do values[key] = value end
    status.wifi = values.wifi == "enabled"
    status.linked = (tonumber(values.linked) or 0) > 0
    status.bluetooth = values.bluetooth == "yes"
    status.volume = tonumber(values.volume)
    status.media = (values.media == "Playing" or values.media == "Paused") and values.media or ""
    status.title = values.title or ""
    status.artist = values.artist or ""
end

local function device()
    local battery, charging = -1, false
    if battery_dir then
        battery = tonumber(read_file(battery_dir .. "/capacity")) or -1
        local state_word = read_file(battery_dir .. "/status") or ""
        charging = state_word:find("Charging") ~= nil or state_word:find("Full") ~= nil
    end
    local brightness = nil
    if backlight_dir then
        local now = tonumber(read_file(backlight_dir .. "/brightness"))
        local most = tonumber(read_file(backlight_dir .. "/max_brightness"))
        if now and most and most > 0 then brightness = now / most end
    end
    return { battery = battery, charging = charging, brightness = brightness }
end

-- Pixels of finger from closed to open: the distance the status bar's Wi-Fi
-- and battery travel to above the panel, so they stay under the finger.
local function control_travel(tablet) return tablet and 150 or 120 end

local function control_settings()
    local _, _, tablet = dimensions()
    local count = 0
    for _ in pairs(sol.windows()) do count = count + 1 end
    local here = device()
    return { pace = pace, travel = control_travel(tablet), reduceMotion = state.settings.reduceMotion,
        statusHeight = config.status,
        tablet = tablet, darkAppearance = state.settings.dark, splitActive = #state.split == 2,
        taskCount = count, battery = here.battery, charging = here.charging,
        brightness = (control and control.brightness) or here.brightness
            or (state.settings.brightness - 0.25) / 0.75,
        volume = status.volume or state.settings.volume or 0.5,
        wifi = status.wifi, wifiLinked = status.linked, bluetooth = status.bluetooth, airplane = airplane,
        mediaStatus = status.media, mediaTitle = status.title, mediaArtist = status.artist }
end

-- The status bar's Wi-Fi and battery. The Control Center's surface draws
-- them, always: at rest where the bar has them, and with the finger to above
-- its panel, so they are never handed between two scenes.
function mobile.apply_status()
    local here = device()
    local _, _, tablet = dimensions()
    control_show({ battery = here.battery, charging = here.charging, wifiLinked = status.linked,
        statusHeight = config.status, tablet = tablet, travel = control_travel(tablet), pace = pace })
end

local function control_begin()
    if control then return end
    control = { over_app = state.page == "app" }
    control_amount = -1
    read_status()
    refresh_status()
    local properties = control_settings()
    properties.dragging, properties.progress, properties.target = true, 0, 1
    control_show(properties)
end

-- The finger pulling it down: `progress` 0 closed to 1 open, rubber-banded
-- past 1, and `dx` pixels sideways since it went down.
local function control_drag(progress, dx)
    control_begin()
    local shown = progress <= 1 and progress or 1 + (progress - 1) * 0.25
    control_show({ dragging = true, progress = math.max(0, shown), fingerDx = dx or 0 })
end

-- Let go, or tapped open: the scene's spring takes it to `target` from
-- `velocity` (progress per second, the finger's own).
local function control_settle(target, velocity)
    control_begin()
    control.target = target
    control_release = control_release + 1
    control_show({ dragging = false, target = target, releaseVelocity = velocity or 0,
        release = control_release })
end

function mobile.control_open() control_settle(1, 0) end

local function control_gone()
    control = nil
    control_amount = -1
    shell_effects(0)
    if state.pending_screenshot then
        state.pending_screenshot = false
        run("sh", "-c", 'mkdir -p "$HOME/Pictures" && grim "$HOME/Pictures/Screenshot-$(date +%Y%m%d-%H%M%S).png"')
    end
    if state.pending_suspend then
        state.pending_suspend = false
        run("systemctl", "suspend")
    end
end

-- The backlight through logind, which lets the session's own user set it.
local function set_backlight(value)
    local most = tonumber(read_file(backlight_dir .. "/max_brightness")) or 0
    if most <= 0 then return end
    local level = math.max(math.floor(most * 0.02), math.floor(most * value + 0.5))
    run("sh", "-c", [[
session=$(busctl call org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager GetSession s "$XDG_SESSION_ID" 2>/dev/null | cut -d'"' -f2)
[ -n "$session" ] && busctl call org.freedesktop.login1 "$session" org.freedesktop.login1.Session SetBrightness ssu backlight "$0" "$1"
]], backlight_dir:match("[^/]+$"), tostring(level))
end

local function control_act(action, data)
    data = type(data) == "table" and data or {}
    if action == "mobile.control.progress" then
        -- The blur follows the scene's own progress, in 64 steps.
        local amount = math.floor(math.max(0, math.min(1, tonumber(data.value) or 0)) * 64 + 0.5) / 64
        if control and amount ~= control_amount then control_amount = amount; shell_effects(amount) end
    elseif action == "mobile.control.geometry" then
        control_panel = { x = tonumber(data.x) or 0.7, y = tonumber(data.y) or 0,
            w = tonumber(data.w) or 0.3, h = tonumber(data.h) or 1, soft = tonumber(data.soft) or 0.2 }
        if control and control_amount > 0 then shell_effects(control_amount) end
    elseif action == "mobile.control.refresh" then
        read_status()
        if control then control_show(control_settings()) end
        mobile.apply_status()
    elseif action == "mobile.control.closed" then control_gone()
    elseif action == "mobile.control.close" then control_settle(0, 0)
    elseif action == "mobile.control.brightness" then
        local value = math.max(0, math.min(1, tonumber(data.value) or 0))
        if backlight_dir then set_backlight(value)
        else mobile.setting({ key = "brightness", value = 0.25 + 0.75 * value }) end
        control.brightness = value
        control_show({ brightness = value })
    elseif action == "mobile.control.volume" then
        local volume = math.max(0, math.min(1, tonumber(data.value) or 0))
        status.volume = volume
        run("wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", string.format("%.2f", volume))
        control_show({ volume = volume })
    elseif action == "mobile.control.wifi" then
        status.wifi = not status.wifi
        run("nmcli", "radio", "wifi", status.wifi and "on" or "off")
        control_show({ wifi = status.wifi })
    elseif action == "mobile.control.bluetooth" then
        status.bluetooth = not status.bluetooth
        run("bluetoothctl", "power", status.bluetooth and "on" or "off")
        control_show({ bluetooth = status.bluetooth })
    elseif action == "mobile.control.airplane" then
        airplane = not airplane
        if airplane then
            run("sh", "-c", "nmcli radio all off; bluetoothctl power off")
        else
            run("sh", "-c", "nmcli radio wifi on; bluetoothctl power on")
        end
        status.wifi, status.bluetooth = not airplane, not airplane
        control_show({ airplane = airplane, wifi = status.wifi, bluetooth = status.bluetooth })
    elseif action == "mobile.control.setting" then
        mobile.setting(data)
        control_show(control_settings())
    elseif action == "mobile.control.media" then
        local verb = ({ play = "play-pause", next = "next", previous = "previous" })[data.act]
        if verb then
            run("playerctl", verb)
            if data.act == "play" then
                status.media = status.media == "Playing" and "Paused" or "Playing"
                control_show({ mediaStatus = status.media })
            end
            refresh_status()
        end
    elseif action == "mobile.control.screenshot" then
        state.pending_screenshot = true
        control_settle(0, 0)
    elseif action == "mobile.control.power" then
        state.pending_suspend = true
        control_settle(0, 0)
    elseif action == "mobile.control.home" then control_settle(0, 0); mobile.home()
    elseif action == "mobile.control.recents" then control_settle(0, 0); mobile.recents()
    elseif action == "mobile.control.split" then
        control_settle(0, 0)
        if #state.split == 2 then state.split = {}; mobile.apply()
        elseif state.active ~= 0 then mobile.recents() end
    elseif action == "mobile.control.reload" then sol.reload()
    end
end

local function hide(window, whole)
    if home_exit and home_exit.id == window.id then
        if not home_exit.applied then
            sol.animate(home_exit.motion)
            sol.present(window.id, home_exit.rect)
            home_exit.applied=true
            sol.animate(page_motion)
        end
        return
    end
    local card = fading[window.id]
    if card then
        sol.present(window.id, { x = card.x, y = card.y, w = card.w, h = card.h,
            z = card.z, opacity = 0 })
        return
    end
    if home_ids[window.id] then
        local target = home_targets[window.id]
        -- A window with no visible launcher icon falls down and shrinks out
        -- of view. Never send it sideways across the desktop.
        target = target or { x = whole.x + whole.w / 2 - 24,
            y = whole.y + whole.h + 24, w = 48, h = 48 }
        sol.present(window.id, { x = target.x, y = target.y, w = target.w, h = target.h, opacity = 0 })
        return
    end
    sol.present(window.id, {
        x = whole.x + whole.w + 32, y = whole.y + 64,
        w = math.max(1, whole.w * 0.88), h = math.max(1, whole.h * 0.88), opacity = 0,
    })
end

local function card_metrics(area, tablet)
    if tablet then
        local columns = area.w >= area.h and 3 or 2
        local rows = 2
        local cell_w = (area.w - 64 - (columns - 1) * 28) / columns
        local row_pitch = math.max(80, (area.h - 132) / rows)
        local h = math.max(24, math.min(cell_w * area.h / area.w, row_pitch - 60))
        return h * area.w / area.h, h, cell_w + 28, columns, row_pitch, cell_w
    end
    local w = math.min(area.w * 0.80, 540)
    return w, math.min(area.h * 0.79, w * area.h / math.max(1, area.w)), w * 0.64
end

local function strip_limit(area, count)
    local _, _, stride, columns = card_metrics(area, true)
    return math.max(0, (math.ceil(count / 2) - columns) * stride)
end

-- The launcher tile a window was launched from, by window id: a window still
-- loading has no application id yet, and some applications never set one that
-- matches their desktop file, so the launch remembers it.
local launch_keys = {}
local function app_key(window)
    local key = launch_keys[window.id] or window.app_id
    return (key:gsub("%.desktop$", ""))
end

function mobile.apply(motion)
    -- Loading a new Lua VM has no live snapshot yet. Keep its committed task
    -- state until restore/monitors supplies one; no snapshot is not no tasks.
    local ready = screen() ~= nil
    local whole, area, tablet = dimensions()
    local geometry = string.format("%s %dx%d", tablet and "tablet" or "phone", whole.w, whole.h)
    if ready and geometry ~= last_geometry then
        sol.log("mobile layout: " .. geometry)
        last_geometry = geometry
        presentations = {}
    end
    if ready and not tablet then state.split = {}; state.picker = 0 end
    local ordered, by_id, dialogs = {}, {}, {}
    if ready then ordered, by_id, dialogs = windows() end
    if tablet then state.overview_offset = math.max(-strip_limit(area, #ordered), math.min(0, state.overview_offset)) end
    local placed, cards = {}, {}
    sol.animate(state.settings.reduceMotion and { duration = 0 } or motion or page_motion)
    local content_page = state.page == "shade" and state.previous or state.page
    if content_page == "app" and not nav then home_exit=nil end
    load_effects()
    local wanted_style = (content_page == "recents" or nav) and "mobile" or "mobile-flat"
    if pane_style ~= wanted_style then
        pane_style = wanted_style
        sol.pane(wanted_style)
    end
    local card_w = card_metrics(area, tablet)
    sol.pane_values({ mobilePage = state.page, mobileHeaderScale = math.min(2.4, math.max(1, area.w / card_w * 0.8)) })
    card_slots = {}
    local focused_index = 1
    for index, window in ipairs(ordered) do
        if window.id == state.active then focused_index = index end
    end

    for index, window in ipairs(ordered) do
        local slot = area
        if #state.split == 2 and content_page == "app" then
            if window.id == state.split[1] then
                slot = rect(area.x, area.y, area.w * state.ratio - 5, area.h)
            elseif window.id == state.split[2] then
                slot = rect(area.x + area.w * state.ratio + 5, area.y,
                    area.w * (1 - state.ratio) - 5, area.h)
            end
        end
        sol.place(window.id, slot)
        local visible = content_page == "app" and (window.id == state.active
            or (#state.split == 2 and (window.id == state.split[1] or window.id == state.split[2])))
        if nav and window.id == state.active then
            local cw,ch=card_metrics(area,tablet)
            local p=nav.p
            local w,h=area.w+(cw-area.w)*p,area.h+(ch-area.h)*p
            -- The window follows the finger: the point first touched keeps its
            -- place in the shrinking window and moves 1:1 with the finger.
            local ax=math.max(0,math.min(1,(nav.x0-area.x)/area.w))
            local ay=math.max(0,math.min(1,(nav.y0-area.y)/area.h))
            nav.drawn={x=area.x+(nav.fx-nav.x0)+ax*(area.w-w),
                y=area.y+(nav.fy-nav.y0)+ay*(area.h-h),w=w,h=h}
            sol.present(window.id,{x=nav.drawn.x,y=nav.drawn.y,
                w=w,h=h,z=200,opacity=1,
                deform=card_shape(nav.drawn,area,30*math.max(0,math.min(1,p)),math.max(0,math.min(1,p)))})
            presentations[window.id]="navigation"
        elseif content_page == "recents" then
            local card_w, card_h, stride, columns, row_pitch, cell_w = card_metrics(area, tablet)
            local w, h, x, y
            if tablet then
                local column, row = math.floor((index - 1) / 2), (index - 1) % 2
                w, h = card_w, card_h
                x = area.x + 32 + column * stride + (cell_w - w) / 2
                    + state.overview_offset + swipe.offset
                y = area.y + 58 + row * row_pitch
            else
                local distance = index - focused_index + swipe.offset / stride
                local scale = math.max(0.86, 1 - math.abs(distance) * 0.045)
                w, h = card_w * scale, card_h * scale
                x = whole.x + (whole.w - w) / 2 + distance * stride
                y = area.y + (area.h - h) / 2 + math.abs(distance) * 8
            end
            y = y + (window.id == swipe.id and swipe.lift or 0)
            local card = rect(x, y, w, h)
            card.id = window.id
            card.selected = window.id == state.active
            card.z = index -- right cards always overlap left cards; browsing never changes depth
            cards[#cards + 1] = card
            card_slots[#card_slots + 1] = card
            sol.present(window.id, { x = x, y = y, w = w, h = h,
                z = card.z, opacity = 1, deform = card_shape(card, area, 30) })
            card_rects[window.id] = { x = x, y = y, w = w, h = h }
            presentations[window.id] = "recents"
        elseif visible then
            fading[window.id] = nil
            -- Repeated layout/configure events must not cancel the entry
            -- transition started by open after its initial placement.
            if presentations[window.id] == "recents" and card_rects[window.id] then
                -- Out of its card: the card's corners and shadow relax to
                -- none as it grows, rather than going at once.
                local from = card_rects[window.id]
                sol.present_from(window.id, { x = from.x, y = from.y, w = from.w, h = from.h,
                    deform = card_shape(from, area, 30) })
            elseif presentations[window.id] ~= "app" then sol.present_clear(window.id) end
            presentations[window.id] = "app"
            placed[window.id] = slot
        else
            -- A client configure can update the placement beneath a parked
            -- pane. Reassert its hidden transform on every layout pass.
            hide(window, whole)
            presentations[window.id] = "hidden"
        end
    end

    for _, window in ipairs(dialogs) do
        local parent = placed[window.parent]
        if parent then
            local w, h = math.min(window.w, parent.w - 24), math.min(window.h, parent.h - 24)
            sol.place(window.id, rect(parent.x + (parent.w - w) / 2,
                parent.y + (parent.h - h) / 2, w, h))
            sol.present_clear(window.id)
        else hide(window, whole) end
    end

    sol.surface("mobile-wallpaper", {
        scene = "mobile/Wallpaper.qml", layer = "background", on = "primary",
        properties = { dark = state.settings.dark, overview = content_page == "recents",
            dim = content_page == "app" and home_flight.dim * (nav and math.max(0, 1 - nav.p) or 1) or 0,
            dragging = nav ~= nil },
    })
    local properties = {
        gestureActive = nav ~= nil, navigationProgress = nav and nav.p or 0,
        emptiedKey = flight and flight.key or "", emptiedSerial = flight_serial,
        draggedKey = nav and by_id[state.active] and app_key(by_id[state.active]) or "",
        emptiedMs = flight and (flight.kind == "home" and home_flight.returns or math.floor(133 * pace + 0.5)) or 0,
        page = state.page, tablet = tablet, cards = cards, taskCount = #ordered,
        activeId = state.active, splitActive = #state.split == 2, pickingSplit = state.picker ~= 0,
        statusHeight = config.status, navigationHeight = config.navigation, homeRequest = home_serial,
        shadeBackground = state.previous, brightness = state.settings.brightness,
        darkAppearance = state.settings.dark, reduceMotion = state.settings.reduceMotion,
    }
    -- The icon grid is drawn below windows, so a window dragged home stays in
    -- front of it; the rest of the shell is drawn above them.
    properties.part = "home"
    sol.surface("mobile-home", {
        scene = "mobile/Shell.qml", layer = "bottom", on = "primary", interactive = true,
        properties = properties,
    })
    local chrome = {}
    for key, value in pairs(properties) do chrome[key] = value end
    chrome.part = "chrome"
    sol.surface("mobile-shell", {
        scene = "mobile/Shell.qml", layer = "overlay", on = "primary", interactive = true,
        reserve = { top = config.status, bottom = config.navigation },
        properties = chrome,
    })
    -- Declared after the chrome, so it is drawn above it.
    mobile.apply_status()
    -- The grab keeps keys and clicks on real Recents thumbnails from leaking
    -- into their clients. Home needs none: its windows are drawn at opacity
    -- zero, which owns no pixel, and the icon grid below the windows is only
    -- reached without a grab.
    sol.grab_input(state.page == "recents" or state.page == "shade")
    if state.page ~= "app" then sol.bind("escape", mobile.back)
    else sol.unbind("escape") end
    sol.status(tablet and "mobile · tablet" or "mobile · phone")
end

local function reset_swipe() swipe = { offset = 0, lift = 0, id = 0 } end


local function icon_target(window, whole)
    local icon = launcher_icons[app_key(window)]
    if not icon or icon.screen_w ~= whole.w or icon.screen_h ~= whole.h then return end
    return rect(whole.x + icon.x, whole.y + icon.y, icon.size, icon.size)
end

function mobile.home()
    pending_launch = nil
    reset_swipe()
    local ordered = windows()
    local whole = dimensions()
    local previous = state.page == "shade" and state.previous or state.page
    fade_recents()
    home_ids, home_targets = {}, {}
    for _, window in ipairs(ordered) do
        if previous == "app" and window.id == state.active then
            home_ids[window.id] = true
            local target = icon_target(window, whole)
            home_targets[window.id] = target
            -- Pressed rather than swiped: the same flight into the icon, from
            -- where the window stands, sent once (as a swipe's is).
            if target and not home_exit and not state.settings.reduceMotion then
                local _, area = dimensions()
                local from = area
                home_exit = { id = window.id, motion = spring(home_flight.size),
                    rect = { x = target.x, y = target.y, w = target.w, h = target.h, opacity = 0,
                        client_opacity = 0, z = 200, deform = flight_shape(target),
                        motion = { x = spring(home_flight.lead), y = spring(home_flight.lead),
                            size = spring(home_flight.size), client_opacity = home_flight.client,
                            opacity = home_flight.land } } }
                start_flight("home", app_key(window), window)
            end
        end
    end
    home_serial = home_serial + 1
    state.page = "home"; state.picker = 0
    mobile.apply()
end

function mobile.recents()
    end_flight()
    home_exit=nil
    fading = {}
    if state.page ~= "recents" and state.page ~= "shade" then state.overview_offset = 0 end
    home_ids, home_targets = {}, {}
    reset_swipe()
    if state.page ~= "recents" and state.page ~= "shade" then state.previous = state.page end
    state.page = "recents"; state.picker = 0
    mobile.apply()
end

function mobile.back()
    reset_swipe()
    if state.picker ~= 0 then state.picker = 0
    elseif state.page == "shade" then state.page = state.previous
    elseif state.page == "recents" then
        if state.previous == "app" then fade_recents(); state.page = "app"
        else mobile.home(); return end
    else mobile.home(); return end
    if state.page == "home" then mobile.home(); return end
    mobile.apply()
    if state.page == "app" and state.active ~= 0 then sol.focus(state.active) end
end

function mobile.select(id)
    end_flight()
    home_exit=nil
    fade_recents()
    home_ids, home_targets = {}, {}
    reset_swipe()
    local _, by_id = windows()
    if not by_id[id] or state.picker == id then return end
    if state.picker ~= 0 and state.picker ~= id then
        state.split = { state.picker, id }; state.picker = 0
    elseif #state.split == 2 and id ~= state.split[1] and id ~= state.split[2] then
        state.split = {}
    end
    state.active = id; state.page = "app"; promote(id)
    mobile.apply()
    sol.focus(id)
end

function mobile.cycle(by, motion)
    reset_swipe()
    local ordered = windows()
    if #ordered == 0 then return end
    local current = 1
    for index, window in ipairs(ordered) do if window.id == state.active then current = index end end
    state.active = ordered[math.max(1, math.min(#ordered, current + by))].id
    mobile.apply(motion or quick_motion)
end

-- Capture the icon at release, in monitor-local coordinates, before spawning.
-- A launch result consumes this origin once; keyboard launches have no icon.
local function remember_origin(data)
    local origin = data and data.origin
    pending_launch = nil
    if type(origin) ~= "table" then return end
    local x, y, size = tonumber(origin.x), tonumber(origin.y), tonumber(origin.size)
    local whole = dimensions()
    if not x or not y or not size or x ~= x or y ~= y or size ~= size then return end
    if size < 16 or size > 160 or x < 0 or y < 0 or x + size > whole.w + 1 or y + size > whole.h + 1 then return end
    pending_launch = { rect = rect(whole.x + x, whole.y + y, size, size), desktop = data.id }
    -- Named before the application is started, so the loading window's icon
    -- layer has the icon from its first frame.
    if not state.settings.reduceMotion then start_flight("launch", data.id) end
end

-- An application already running answers its tile with its own window,
-- brought back out of the icon -- also while it is still flying home -- rather
-- than a second copy of it.
local function running(key)
    local ordered = windows()
    for _, window in ipairs(ordered) do
        if app_key(window) == key then return window end
    end
end
local function reopen(window, key)
    local origin = pending_launch
    pending_launch = nil
    mobile.select(window.id)
    if origin and not state.settings.reduceMotion then
        start_flight("relaunch", key, window)
        mobile.apply()
        sol.animate(spring(home_flight.size))
        sol.present_from(window.id, from_icon(origin.rect))
    end
end

-- A setting from the shade or the Control Center: brightness, appearance,
-- motion.
function mobile.setting(data)
    if data.key == "brightness" then
        -- Drawn as a dim over the screen where there is no backlight to set:
        -- the chrome alone changes, nothing is laid out again.
        state.settings.brightness = math.max(0.25, math.min(1, tonumber(data.value) or 1))
        chrome_update({ brightness = state.settings.brightness })
        return
    elseif data.key == "dark" then state.settings.dark = not state.settings.dark
    elseif data.key == "reduceMotion" then state.settings.reduceMotion = not state.settings.reduceMotion
    end
    mobile.apply(quick_motion)
end

local function act(action, data)
    data = type(data) == "table" and data or {}
    local id = math.tointeger(tonumber(data.id))
    if action == "mobile.icons" then
        if tonumber(data.epoch) ~= home_serial or (state.page ~= "home" and state.page ~= "apps") then return end
        local whole = dimensions()
        if tonumber(data.w) ~= whole.w or tonumber(data.h) ~= whole.h then return end
        local icons = {}
        if type(data.items) == "table" then
            for key, icon in pairs(data.items) do
                if type(key) == "string" and type(icon) == "table" then
                    local x, y, size = tonumber(icon.x), tonumber(icon.y), tonumber(icon.size)
                    if x and y and size and size >= 16 and size <= 160 and x >= 0 and y >= 0
                        and x + size <= whole.w + 1 and y + size <= whole.h + 1 then
                        icons[key:gsub("%.desktop$", "")] = { x = x, y = y, size = size,
                            screen_w = whole.w, screen_h = whole.h }
                    end
                end
            end
        end
        launcher_icons = icons
        state.launcher_icons = icons
        local ordered = windows()
        for _, window in ipairs(ordered) do
            if home_ids[window.id] then home_targets[window.id] = icon_target(window, whole) end
        end
        mobile.apply()
    elseif action == "mobile.home" then mobile.home()
    elseif action == "mobile.back" then mobile.back()
    elseif action == "mobile.recents" then mobile.recents()
    elseif action == "mobile.apps" then state.page = "apps"; mobile.apply()
    elseif action == "mobile.shade" then
        -- The status bar's tap: the Control Center, as the corner pull opens it.
        mobile.control_open()
    elseif action == "mobile.select" and id then mobile.select(id)
    elseif action == "mobile.previous" then mobile.cycle(-1)
    elseif action == "mobile.next" then mobile.cycle(1)
    elseif action == "mobile.desktop" and type(data.id) == "string" then
        remember_origin(data)
        local key = data.id:gsub("%.desktop$", "")
        local window = running(key)
        if window then reopen(window, key); return end
        local origin = pending_launch
        sol.act("apps.launch", { id = data.id }, function(ok)
            if not ok and pending_launch == origin then pending_launch = nil end
        end)
    elseif action == "mobile.close" and id then
        local _, by_id = windows()
        if by_id[id] then sol.close(id) end
    elseif action == "mobile.split" and id then
        local _, _, tablet = dimensions()
        local ordered, by_id = windows()
        if tablet and by_id[id] and #ordered > 1 then state.picker = id; mobile.apply() end
    elseif action == "mobile.swipe.begin" and state.page == "recents" then
        reset_swipe()
        local whole, area = dimensions()
        local x, y = (tonumber(data.x) or 0) + whole.x, (tonumber(data.y) or 0) + whole.y
        local top
        for _, card in ipairs(card_slots) do
            if x >= card.x and x <= card.x + card.w and y >= card.y - 80 * card.w / area.w and y <= card.y + card.h
                and (not top or card.z > top.z) then top = card end
        end
        swipe.id = top and top.id or 0
    elseif action == "mobile.swipe.move" and state.page == "recents" then
        local dx, dy = tonumber(data.dx) or 0, tonumber(data.dy) or 0
        if math.abs(dy) > math.abs(dx) and dy < 0 then swipe.lift = dy; swipe.offset = 0
        else
            local ordered = windows()
            local _, area, tablet = dimensions()
            local _, _, stride = card_metrics(area, tablet)
            local current = 1
            for index, window in ipairs(ordered) do if window.id == state.active then current = index end end
            if tablet then
                swipe.offset = math.max(-strip_limit(area, #ordered) - state.overview_offset - 32,
                    math.min(-state.overview_offset + 32, dx))
            else
                swipe.offset = math.max(-(#ordered - current) * stride - 40,
                    math.min((current - 1) * stride + 40, dx))
            end
            swipe.lift = 0
        end
        mobile.apply({ duration = 0 })
    elseif action == "mobile.swipe.end" and state.page == "recents" then
        local _, area, tablet = dimensions()
        local _, _, stride = card_metrics(area, tablet)
        local offset, lift, selected = swipe.offset, swipe.lift, swipe.id
        reset_swipe()
        if lift < -85 and selected ~= 0 then
            for _, card in ipairs(card_slots) do
                if card.id == selected then dismissals[selected] = card; break end
            end
            sol.close(selected)
        elseif math.abs(offset) < 8 and math.abs(lift) < 8 and data.tap then
            if selected ~= 0 then mobile.select(selected) else mobile.home() end
        elseif tablet then
            local ordered = windows()
            local velocity = state.settings.reduceMotion and 0 or math.max(-2, math.min(2, tonumber(data.velocity) or 0))
            state.overview_offset = math.max(-strip_limit(area, #ordered),
                math.min(0, state.overview_offset + offset + velocity * 150))
            mobile.apply(paced({ duration = 320, easing = "outCubic" }))
        else mobile.cycle(math.floor(-offset / stride + 0.5)) end
    elseif action == "mobile.setting" then
        mobile.setting(data)
    elseif action == "mobile.reload" then sol.reload()
    elseif action == "mobile.unsplit" then state.split = {}; mobile.apply()
    elseif action == "mobile.ratio" then
        state.ratio = state.ratio >= 0.59 and 0.4 or state.ratio + 0.1; mobile.apply()
    end
end

sol.on("surface", function(surface, action, data)
    if surface == "mobile-shell" or surface == "mobile-home" then act(action, data)
    elseif surface == "mobile-control" then control_act(action, data) end
end)
sol.on("open", function(id)
    local _, by_id = windows()
    local _, area = dimensions()
    -- A delayed, unrelated window must not inherit a previous icon.
    local origin = pending_launch
    local window = by_id[id]
    local matches = window and origin and origin.desktop and (window.app_id == ""
        or window.app_id == origin.desktop or window.app_id .. ".desktop" == origin.desktop)
    if matches then
        launch_keys[id] = origin.desktop:gsub("%.desktop$", "")
        if not state.settings.reduceMotion then start_flight("launch", origin.desktop) end
    end
    if by_id[id] then
        state.active = id; state.page = "app"; state.split = {}; state.picker = 0; promote(id)
    end
    mobile.apply()
    if by_id[id] then
        if matches then
            if not state.settings.reduceMotion then sol.animate(spring(home_flight.size)) end
            sol.present_from(id, state.settings.reduceMotion and origin.rect or from_icon(origin.rect))
            pending_launch = nil
        else
            sol.present_from(id, { x = area.x + area.w * 0.04, y = area.y + area.h * 0.04,
                w = area.w * 0.92, h = area.h * 0.92, opacity = 0 })
        end
    end
end)
sol.on("focus", function(id)
    if state.page == "app" and state.active ~= id then
        local _, by_id = windows()
        if by_id[id] then state.active = id; promote(id); mobile.apply(quick_motion) end
    end
end)
sol.on("activate", function(id, why)
    -- Only a launch the compositor matched, never an unsolicited activation.
    if why == "launch" then
        local origin = pending_launch
        pending_launch = nil
        mobile.select(id)
        if origin then
            local _, by_id = windows()
            if not state.settings.reduceMotion and by_id[id] then
                -- An application already running answers with its window,
                -- which grows out of the icon as a new one does.
                start_flight("relaunch", origin.desktop, by_id[id])
                mobile.apply()
            end
            if not state.settings.reduceMotion then sol.animate(spring(home_flight.size)) end
            sol.present_from(id, state.settings.reduceMotion and origin.rect or from_icon(origin.rect))
        end
    end
end)
sol.on("closing", function(id)
    local card = dismissals[id]
    state.closing[id] = true
    mobile.apply()
    if card then
        local whole = dimensions()
        -- Native close requests are delivered after the compositor's 190 ms
        -- closing phase. Land off-screen before that, with no on-screen fade.
        sol.animate({ duration = state.settings.reduceMotion and 0 or 180, easing = "outCubic" })
        sol.present(id, { x = card.x, y = whole.y - card.h - 48,
            w = card.w, h = card.h, z = card.z, opacity = 1 })
    end
end)
sol.on("close", function(id)
    dismissals[id] = nil; home_ids[id] = nil; home_targets[id] = nil; fading[id] = nil
    launch_keys[id] = nil
    card_rects[id] = nil
    state.closing[id] = nil -- close's snapshot marks the departing pane leaving
    mobile.apply()
    if state.page == "app" and state.active ~= 0 then sol.focus(state.active) end
end)
sol.on("refused", function(id)
    dismissals[id] = nil; state.closing[id] = nil; mobile.apply()
end)
sol.on("layout", function() mobile.apply(quick_motion) end)
sol.on("monitors", function() mobile.apply({ duration = 0 }) end)
sol.on("restore", function() mobile.apply({ duration = 0 }) end)

sol.bind("super+h", mobile.home)
sol.bind("super+space", mobile.recents)
sol.bind("super+a", function() act("mobile.apps") end)
sol.bind("super+b", mobile.back)
sol.bind("super+bracketleft", function() mobile.cycle(-1) end)
sol.bind("super+bracketright", function() mobile.cycle(1) end)
sol.bind("super+r", function() act("mobile.ratio") end)
sol.bind("super+u", function() act("mobile.unsplit") end)
sol.bind("super+shift+s", function()
    local ordered = windows()
    local _, _, tablet = dimensions()
    if tablet and #ordered >= 2 then
        state.split = { ordered[1].id, ordered[2].id }; state.page = "app"; mobile.apply()
    end
end)
sol.bind("super+shift+r", function() sol.reload() end)
sol.bind("super+shift+q", function() sol.quit() end)

-- Touch controller for the Surface test configuration. All recognition and animation decisions live here.
local gesture
-- The touch overlay (mobile/Finger.qml) is for testing touch: a whole-screen
-- layer drawn again on every event, so only with SOLIUM_MOBILE_FINGER=1.
local show_finger = os.getenv("SOLIUM_MOBILE_FINGER") == "1"
local function finger(e)
    if not show_finger then return end
    local whole=dimensions()
    local k=gesture and gesture.k
    sol.surface("touch-finger", {scene="mobile/Finger.qml",layer="overlay",on="primary",interactive=false,
        properties={down=e.kind~="up" and e.kind~="cancel",px=e.x-whole.x,py=e.y-whole.y,
            vx=k and k.vx or 0,vy=k and k.vy or 0,ax=k and k.ax or 0,ay=k and k.ay or 0,
            phase=gesture and gesture.kind or "client/control"}})
end
local function release(e,cancelled)
    local g=gesture
    if not g then return end
    local vx,vy=g.k:release(e.time)
    vx=math.max(-touch_config.max_release_speed,math.min(touch_config.max_release_speed,vx))
    vy=math.max(-touch_config.max_release_speed,math.min(touch_config.max_release_speed,vy))
    g.k.vx=vx;g.k.vy=vy
    sol.log(string.format("TOUCH_RELEASE kind=%s vx=%.2f vy=%.2f ax=%.2f ay=%.2f cancel=%s",
        g.kind,vx,vy,g.k.ax,g.k.ay,tostring(cancelled)))
    if g.kind=="control" then
        -- Open past a third of the way or flung down; shut when flung up.
        local _,_,tablet=dimensions()
        local travel=control_travel(tablet)
        local p=(e.y-g.y)/travel
        local pv=vy/travel
        local open=not cancelled and pv>-1.5 and (p>0.35 or pv>1.5)
        control_settle(open and 1 or 0,pv)
        return
    end
    if g.kind=="home-swipe" then
        local _,area=dimensions()
        local p=(g.y-e.y)/(area.h*touch_config.travel)
        if not cancelled and p>=touch_config.commit and -vy<touch_config.fling then mobile.recents() end
        return
    end
    if g.kind=="navigation" then
        local whole,area,tablet=dimensions()
        local p=nav.p
        g.drawn=nav.drawn
        local pv=-vy/(area.h*touch_config.travel)
        if nav.raw<0 or nav.raw>1 then pv=pv*touch_config.elastic end
        nav=nil
        if config.navigation > 0 and not cancelled and math.abs(e.x-g.x)<touch_config.tap and math.abs(e.y-g.y)<touch_config.tap then
            mobile.home()
        elseif cancelled or (p<touch_config.commit and -vy<touch_config.fling) then
            mobile.apply(K.spring(pv,-p,touch_spring))
        elseif -vy>=touch_config.fling then
            local ordered,by_id=windows()
            local window=by_id[state.active]
            local target=window and icon_target(window,whole)
                or {x=whole.x+whole.w/2-24,y=whole.y+whole.h+24,w=48,h=48}
            local rect={x=target.x,y=target.y,w=target.w,h=target.h,opacity=0,z=200}
            local drawn=g.drawn
            if drawn and not state.settings.reduceMotion then
                -- The iPad's close: the centre leads the size and carries the
                -- flick's speed on each axis, so the path curves the way the
                -- throw went; the window stays opaque until late and is gone
                -- into its icon by the end (design-notes 19, items 9 and 14).
                local function share(velocity,from,to)
                    local remaining=to-from
                    return math.abs(remaining)>0.5 and velocity/remaining or 0
                end
                local fx=share(vx,drawn.x+drawn.w/2,target.x+target.w/2)
                local fy=share(vy,drawn.y+drawn.h/2,target.y+target.h/2)
                rect.client_opacity=0
                rect.deform=flight_shape(target)
                rect.motion={
                    x=spring(home_flight.lead,fx),
                    y=spring(home_flight.lead,fy),
                    size=spring(home_flight.size),
                    client_opacity=home_flight.client,
                    opacity=home_flight.land,
                }
                if window then start_flight("home",app_key(window),window) end
            end
            home_exit={id=state.active,motion=state.settings.reduceMotion and {duration=0}
                or spring(home_flight.size),
                rect=rect}
            mobile.home()
        else
            reset_swipe();state.previous="app";state.page="recents"
            mobile.apply(K.spring(pv,1-p,touch_spring))
        end
    else
        local dx,dy=swipe.offset,swipe.lift
        local selected=swipe.id
        local _,area,tablet=dimensions()
        local _,_,stride=card_metrics(area,tablet)
        if cancelled then reset_swipe();mobile.apply(K.spring(0,1,touch_spring))
        elseif math.abs(e.x-g.x)<touch_config.tap and math.abs(e.y-g.y)<touch_config.tap then
            reset_swipe();if selected~=0 then mobile.select(selected) else mobile.home() end
        elseif dy< -85 and selected~=0 then
            for _,card in ipairs(card_slots) do
                if card.id==selected then dismissals[selected]=card;break end
            end
            reset_swipe();sol.close(selected)
        elseif tablet then
            local ordered=windows()
            local projected=dx+vx*math.abs(vx)/(2*touch_config.deceleration)
            local target=math.max(-strip_limit(area,#ordered),math.min(0,state.overview_offset+projected))
            local remaining=target-state.overview_offset-dx
            state.overview_offset=target
            reset_swipe();mobile.apply(K.spring(vx,remaining,touch_spring))
        else
            local ordered=windows()
            local current=1
            for i,w in ipairs(ordered) do if w.id==state.active then current=i end end
            local projected=dx+vx*math.abs(vx)/(2*touch_config.deceleration)
            local target=math.max(1,math.min(#ordered,current+math.floor(-projected/stride+0.5)))
            -- All card positions translate by the same horizontal track.
            local remaining=(current-target)*stride-dx
            mobile.cycle(target-current,K.spring(vx,remaining,touch_spring))
        end
    end
end
sol.on("touch",function(e)
    if e.kind=="down" and not gesture and e.target~="blocked" then
        local whole,area,tablet=dimensions()
        local dock_width=math.min(whole.w-64,420)
        local dock=tablet and e.x>=whole.x+(whole.w-dock_width)/2
            and e.x<=whole.x+(whole.w+dock_width)/2
            and e.y>=area.y+area.h-106 and e.y<=area.y+area.h-14
        local kind
        local at_handle=e.y>=whole.y+whole.h-touch_config.edge
            and math.abs(e.x-(whole.x+whole.w/2))<=touch_config.handle_width/2
        -- The top edge's right half pulls the Control Center down, from any
        -- page but Recents.
        local at_corner=e.y<whole.y+math.max(24,config.status) and e.x>whole.x+whole.w*0.55
        if at_corner and not control and state.page~="recents" and state.page~="shade" then kind="control"
        elseif state.page=="app" and at_handle then kind="navigation"
        -- From the home screen the same swipe, held, opens Recents; there is
        -- no window to follow, so nothing moves until it is let go.
        elseif (state.page=="home" or state.page=="apps") and at_handle then kind="home-swipe"
        elseif state.page=="recents" and not e.control and not dock and e.y>=area.y and e.y<area.y+area.h then kind="recents" end
        if kind then
            sol.touch(e.slot,{action="capture"})
            gesture={slot=e.slot,kind=kind,x=e.x,y=e.y,k=K.new(touch_config)}
            gesture.k:sample(e.time,e.x,e.y)
            if kind=="control" then control_drag(0)
            elseif kind=="navigation" then nav={p=0,raw=0,x0=e.x,y0=e.y,fx=e.x,fy=e.y};mobile.apply({duration=0})
            else
                reset_swipe()
                local top
                for _,c in ipairs(card_slots) do
                    if e.x>=c.x and e.x<=c.x+c.w and e.y>=c.y and e.y<=c.y+c.h
                        and (not top or c.z>top.z) then top=c end
                end
                swipe.id=top and top.id or 0
            end
        end
    elseif gesture and e.slot==gesture.slot then
        if e.kind=="motion" then
            local g=gesture
            g.k:sample(e.time,e.x,e.y)
            if g.kind=="home-swipe" then finger(e);return end
            if g.kind=="control" then
                local _,_,tablet=dimensions()
                control_drag((e.y-g.y)/control_travel(tablet),e.x-g.x);finger(e);return
            end
            local _,area=dimensions()
            if g.kind=="navigation" then
                nav.fx,nav.fy=e.x,e.y
                nav.raw=(g.y-e.y)/(area.h*touch_config.travel)
                nav.p=nav.raw
                if nav.raw<0 then nav.p=nav.raw*touch_config.elastic
                elseif nav.raw>1 then nav.p=1+(nav.raw-1)*touch_config.elastic end
            else
                local dx,dy=e.x-g.x,e.y-g.y
                if math.abs(dy)>math.abs(dx) and dy<0 then swipe.lift=dy;swipe.offset=0
                else swipe.offset=dx;swipe.lift=0 end
            end
            mobile.apply({duration=0})
        elseif e.kind=="up" or e.kind=="cancel" then
            release(e,e.kind=="cancel")
            finger(e);gesture=nil;return
        end
    end
    finger(e)
end)

-- Wi-Fi, Bluetooth and the volume, read in the background from the start, so
-- the first pull already has them.
refresh_status()

return mobile
