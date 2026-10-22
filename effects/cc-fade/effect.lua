-- Behind the Control Center over the home screen: what is behind it (the
-- wallpaper and the launcher, `effects.xray.layers`) blurred, and drawn at
-- `amount` over the sharp picture, so the blur follows the finger and the
-- Control Center's spring rather than popping in.
return {
    api = 1,
    inputs = { "backdrop" },
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
            { "pass", "fade.frag" },
        }
    end,
}
