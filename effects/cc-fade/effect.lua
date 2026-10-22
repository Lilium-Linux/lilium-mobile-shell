-- Behind the Control Center over the home screen: what is behind it (the
-- wallpaper and the launcher, `effects.xray.layers`) blurred, and drawn at
-- `amount` over the sharp picture, so the blur follows the finger and the
-- Control Center's spring rather than popping in.
return {
    api = 1,
    inputs = { "backdrop" },
    params = {
        amount = { 0, min = 0, max = 1 },
        passes = { 3, min = 1, max = 5, int = true },
        offset = { 2.5, min = 0 },
    },
    reach = function(p) return math.ceil(p.offset * 2 ^ (p.passes + 1)) end,
    stages = function(p)
        return {
            { "use", "blur", passes = p.passes, offset = p.offset },
            { "pass", "fade.frag" },
        }
    end,
}
