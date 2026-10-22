// The window's own pixels and their blur, mixed by how far the Control
// Center is open.
vec4 sol_effect(vec2 uv) {
    return mix(sol_self(uv), sol_tex(uv), clamp(p_amount, 0.0, 1.0));
}
