-- A window flying into its launcher icon, or out of it: the shape of the pane
-- while `sol.present` carries its centre and size (policy.lua's flights).
--
-- Measured from iPad recordings:
--   * each row is pulled toward the icon's x, the rows nearest the icon the
--     most, so the near end is narrower than the far one -- 0.84 to 0.90 of it
--     through the middle of the flight, and square again at both ends;
--   * near the icon the shape is a square platter, though the window it came
--     from is not: the shape takes the icon's aspect well before the size has
--     arrived.
--
-- `t.from` is where the present draws the pane this pass and `t.to` the icon,
-- so this only reshapes what the present already moves. At progress 0 every
-- point is the window's own.
return {
    api = 1,
    grid = { 4, 24 },
    params = {
        -- How far the nearest row is pulled toward the icon at mid-flight.
        pinch = { 0.14, min = 0, max = 0.5 },
        -- The icon's size as a share of the pane's, across and down: where
        -- the present takes the size, for the corners (flight.frag).
        land_x = { 1, min = 0, max = 1 },
        land_y = { 1, min = 0, max = 1 },
        -- The corners on screen, in physical pixels: the icon's own at the
        -- end, and how far above that they rise through the middle.
        radius = { 0, min = 0, max = 512 },
        peak = { 0, min = 0, max = 512 },
    },
    frag = "flight.frag",
    mesh = function(t, cols, rows, out)
        local f, to = t.from, t.to
        local p = math.min(math.max(t.progress, 0), 1)
        -- The aspect, toward the icon's well ahead of the size.
        local aspect = f.w / math.max(f.h, 1e-9)
        local toward = to.w / math.max(to.h, 1e-9)
        local k = 1 - (1 - p) ^ 3
        local want = aspect + (toward - aspect) * k
        local w, h = f.w, f.h
        if want < aspect then w = h * want else h = w / math.max(want, 1e-9) end
        local cx, cy = f.x + f.w / 2, f.y + f.h / 2
        local x0, y0 = cx - w / 2, cy - h / 2
        -- The narrowing, toward the icon's x, strongest mid-flight.
        local pinch = t.pinch * math.sin(math.pi * p)
        local ix = to.x + to.w / 2
        local above = to.y + to.h / 2 < cy
        local n = 0
        for r = 0, rows do
            for c = 0, cols do
                local u, v = sol_grid(t, c, r)
                local near = above and (1 - v) or v
                local x = x0 + u * w
                out[n + 1] = x + (ix - x) * pinch * near
                out[n + 2] = y0 + v * h
                n = n + 2
            end
        end
    end,
}
