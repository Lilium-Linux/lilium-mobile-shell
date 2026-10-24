-- Independent mobile configuration; the desktop init/config are not loaded.
return {
    pane = "mobile-flat", -- Lua selects overview chrome; mobile-corners supplies the mask.
    profile = os.getenv("SOLIUM_MOBILE_PROFILE") or "auto",
    -- How much slower than the iPad the flights to and from an icon run: 1 is
    -- the iPad's timing, 1.6 is a third slower to the eye.
    pace = tonumber(os.getenv("SOLIUM_MOBILE_PACE")) or 1,
    status = 32,
    navigation = 0, -- Temporary Surface test: no navigation bar or reserved strip.
    motion = { duration = 420, easing = "outCubic" },
    quick = { duration = 180, easing = "outCubic" },
    -- The swipe up from the bottom, held: once the finger is past the commit
    -- distance and has stayed within `slop` logical pixels, never faster than
    -- `speed` pixels a second, for `ms` milliseconds, Recents opens while the
    -- finger is still down, as on an Android phone. A flick never holds.
    hold = { ms = 200, speed = 150, slop = 16 },
    -- The back swipe, inward from the left or right edge of the screen in its
    -- vertical middle `band` (80 %): it starts within `edge` logical pixels
    -- of the edge, and goes back when let go past `commit` of the screen's
    -- width, or flung inward faster than `fling` pixels a second once past
    -- `fling_min` pixels. Flung back towards the edge faster than `retreat`
    -- pixels a second, it is cancelled.
    back = { edge = 24, band = 0.8, commit = 1 / 12, fling = 900, fling_min = 16, retreat = 300 },
}
