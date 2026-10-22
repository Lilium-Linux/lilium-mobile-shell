// The blurred backdrop at `amount`, only under and round the panel: it fades
// out over `soft` past the panel's rectangle, and over the sharp picture
// beneath it the two mix.
vec4 sol_effect(vec2 uv) {
    vec2 inside = clamp(uv, vec2(p_mask_x, p_mask_y), vec2(p_mask_x + p_mask_w, p_mask_y + p_mask_h));
    vec2 aspect = vec2(1.0, sol_box_px.y / max(sol_box_px.x, 1.0));
    float away = length((uv - inside) * aspect);
    float under = 1.0 - smoothstep(0.0, p_soft, away);
    return sol_tex(uv) * clamp(p_amount, 0.0, 1.0) * under;
}
