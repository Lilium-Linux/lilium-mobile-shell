// The pane's corners on screen through a flight to or from its icon: none on
// the window at rest, rising to `peak` through the middle of the flight (the
// iPad's 40 to 50 recording pixels) and landing on the icon's own `radius`.
//
// The capture is the whole pane at its own size, and the warp draws it at the
// size the present has reached, squared toward the icon by this folder's
// mesh; so the size on screen is worked out here the way the present and the
// mesh work it out, from the flight's progress, and the corners are cut round
// in screen pixels whatever the scale is in each direction.
vec4 sol_effect(vec2 uv) {
    // The window inside the capture (`sol_content`), and a margin of 16 of
    // its pixels around it, cut round: the capture is taken as small as an
    // eighth while the window is small, and filtering smears its edge a
    // texel outward, which would stand as a square outline past the rounded
    // corners. What its layers paint further out flies with it uncut.
    vec4 colour = sol_tex(uv);
    vec2 box = sol_content.zw * sol_box_px;
    vec2 inside = (uv - sol_content.xy) / sol_content.zw;
    vec2 margin = 16.0 / max(box, vec2(1.0));
    if (any(lessThan(inside, -margin)) || any(greaterThan(inside, 1.0 + margin))) return colour;
    float p = sol_clamped;
    // Where the present has taken the size: from the pane's to the icon's.
    vec2 size = box * mix(vec2(1.0), vec2(p_land_x, p_land_y), p);
    // The mesh's squaring toward the icon's aspect, well ahead of the size.
    float aspect = size.x / max(size.y, 1e-6);
    float toward = (p_land_x * box.x) / max(p_land_y * box.y, 1e-6);
    float k = 1.0 - pow(1.0 - p, 3.0);
    float want = mix(aspect, toward, k);
    if (want < aspect) size.x = size.y * want; else size.y = size.x / max(want, 1e-6);
    float radius = mix(0.0, p_radius, p) + p_peak * sin(3.14159265 * p);
    radius = min(radius, 0.5 * min(size.x, size.y));
    float distance = sol_sdf_rrect(inside * size, size, vec4(radius));
    return colour * clamp(0.5 - distance, 0.0, 1.0);
}
