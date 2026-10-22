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
}
