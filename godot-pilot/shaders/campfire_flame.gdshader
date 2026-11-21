shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

void fragment() {
    vec2 uv = UV;
    float h = 1.0 - uv.y;
    float t = TIME * 3.4;
    float sway = sin(h * 10.0 - t) * 0.065 * h + sin(h * 19.0 + t * 1.3) * 0.025;
    float x = abs(uv.x - 0.5 - sway) * 2.0;
    float width = mix(0.62, 0.025, pow(h, 0.85));
    width *= 0.88 + 0.12 * sin(h * 24.0 - t * 1.8);
    float mask = 1.0 - smoothstep(width * 0.30, width + 0.18, x);
    float vertical = smoothstep(0.0, 0.12, h) * (1.0 - smoothstep(0.72, 1.0, h));
    float alpha = mask * vertical;
    if (alpha < 0.015) { discard; }
    float core = (1.0 - smoothstep(0.04, 0.22, x)) * (1.0 - smoothstep(0.12, 0.48, h));
    vec3 col = mix(vec3(0.92, 0.19, 0.025), vec3(1.0, 0.49, 0.08), mask * (1.0 - h * 0.5));
    col = mix(col, vec3(1.0, 0.76, 0.26), core * 0.65);
    ALBEDO = col * 0.92;
    ALPHA = alpha * 0.72;
}
