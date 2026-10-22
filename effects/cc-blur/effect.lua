-- A window under the Control Center: its own pixels blurred, crossfaded with
-- the sharp ones by `amount`, which the shell moves with the finger and the
-- Control Center's spring (0 sharp, 1 fully blurred). Solium's `blur` does the
-- blurring; this only mixes, so the blur never pops in at its smallest size.
return {
    api = 1,
    inputs = { "self" },
    params = {
        amount = { 0, min = 0, max = 1 },
        passes = { 3, min = 1, max = 5, int = true },
        offset = { 2.5, min = 0 },
    },
    reach = function(p) return math.ceil(p.offset * 2 ^ (p.passes + 1)) end,
    stages = function(p)
        return {
            { "use", "blur", passes = p.passes, offset = p.offset },
            { "pass", "mix.frag", uses = { "self" }, per_part = true },
        }
    end,
}
