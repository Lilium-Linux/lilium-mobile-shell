-- A window under the Control Center: its own pixels blurred under and round
-- the panel (`mask_*`, `soft`) and crossfaded with the sharp ones by `amount`,
-- which the shell moves with the finger and the Control Center's spring (0
-- sharp, 1 fully blurred). Solium's `blur` does the blurring; this only mixes,
-- so the blur never pops in at its smallest size.
return {
    api = 1,
    inputs = { "self" },
    params = {
        amount = { 0, min = 0, max = 1 },
        -- Where the panel is, as fractions of what the effect covers (0 to 1;
        -- a little past it is allowed), and how far the blur fades out past
        -- its edge, as a fraction of the width: only under and round the panel
        -- is anything blurred; the rest is dimmed by the scene, sharp.
        mask_x = { 0, min = -1, max = 2 },
        mask_y = { 0, min = -1, max = 2 },
        mask_w = { 1, min = 0, max = 3 },
        mask_h = { 1, min = 0, max = 3 },
        soft = { 0.05, min = 0.001, max = 1 },
        passes = { 4, min = 1, max = 5, int = true },
        offset = { 2, min = 0 },
    },
    reach = function(p) return math.ceil(p.offset * 2 ^ (p.passes + 1)) end,
    stages = function(p)
        return {
            { "use", "blur", passes = p.passes, offset = p.offset },
            { "pass", "mix.frag", uses = { "self" }, per_part = true },
        }
    end,
}
