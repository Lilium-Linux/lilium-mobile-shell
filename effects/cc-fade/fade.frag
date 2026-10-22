// The blurred backdrop at `amount`: over the sharp picture beneath it, the
// two mix.
vec4 sol_effect(vec2 uv) {
    return sol_tex(uv) * clamp(p_amount, 0.0, 1.0);
}
