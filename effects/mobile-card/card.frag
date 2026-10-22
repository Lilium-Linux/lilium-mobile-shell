// A card: the window (`sol_content`) cut round to `p_radius` capture pixels,
// on a soft shadow drawn here from the same rounded shape, so the two always
// agree at the corners (`p_px` capture pixels to one physical screen pixel,
// `p_dpr` physical pixels to a logical one; `p_shadow` how much of it, 0 to 1).
//
// Near the card the captured pixels outside the rounded shape are not used:
// the capture is taken smaller than the window while the card is small, and
// filtering smears the window's edge a texel outward, which would stand as a
// square outline past each rounded corner. Further out, what the pane's
// layers paint (the title above) is drawn as it is.
vec4 sol_effect(vec2 uv) {
    vec4 colour = sol_tex(uv);
    vec2 size = sol_content.zw * sol_box_px;
    vec2 at = sol_to_content(uv);
    float px = max(p_px, 0.01);
    // One logical screen pixel, in the capture's pixels.
    float lpx = px * max(p_dpr, 0.25);
    // Out to where the shadow fades: 14 logical pixels.
    vec2 reach = vec2(14.0 * lpx);
    if (any(lessThan(at, -reach)) || any(greaterThan(at, size + reach))) return colour;
    // A card opening into its window (`sol.present_from` from the card) is
    // relaxed toward progress 0 as it lands: corners and shadow go with it.
    float card_ness = sol_clamped;
    float radius = min(p_radius * card_ness, 0.5 * min(size.x, size.y));
    float edge = sol_sdf_rrect(at, size, vec4(radius)) / px;
    vec4 card = colour * clamp(0.5 - edge, 0.0, 1.0);
    // The shadow: 3 logical pixels lower, fading over 12.
    float fall = sol_sdf_rrect(at - vec2(0.0, 3.0 * lpx), size, vec4(radius)) / lpx;
    float shade = 0.22 * p_shadow * card_ness * (1.0 - smoothstep(-2.0, 12.0, fall));
    return card + vec4(0.0, 0.0, 0.0, shade) * (1.0 - card.a);
}
