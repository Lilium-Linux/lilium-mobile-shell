-- A window drawn as a card (Recents, or following the finger into it): its
-- own shape, its corners cut round in screen pixels by card.frag. A present's
-- deform, so the corners travel with the window, blend with its motion, and
-- the window is captured at the size it is drawn and kept until it changes,
-- rather than cut by a slot rule at its full size on every commit.
--
-- The policy gives the radius in the capture's own pixels (on-screen radius
-- times the window's width over the card's), `px`, the capture's pixels per
-- physical screen pixel, for the edge's antialiasing, `dpr`, the monitor's
-- scale, for the shadow's size in logical pixels, and `shadow`, how much of
-- the card's shadow card.frag draws.
return {
    api = 1,
    grid = { 1, 1 },
    params = {
        radius = { 0, min = 0, max = 4096 },
        px = { 1, min = 0.01, max = 64 },
        -- The monitor's scale: the shadow is sized in logical pixels.
        dpr = { 1, min = 0.25, max = 8 },
        -- How much of the card's shadow is drawn, 0 to 1.
        shadow = { 0, min = 0, max = 1 },
    },
    frag = "card.frag",
    mesh = function(t, cols, rows, out)
        local f = t.from
        local n = 0
        for r = 0, rows do
            for c = 0, cols do
                local u, v = sol_grid(t, c, r)
                out[n + 1] = f.x + u * f.w
                out[n + 2] = f.y + v * f.h
                n = n + 2
            end
        end
    end,
}
