shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

uniform vec3 smoke_color : source_color = vec3(0.78, 0.75, 0.69);
uniform float opacity : hint_range(0.0, 1.0) = 0.20;

void fragment() {
    vec2 uv = UV;
    float h = 1.0 - uv.y;
    float t = TIME * 0.42;
    float sway = sin(h * 8.0 - t) * 0.16 * h + h * 0.13;
    float x_dist = abs(uv.x - 0.5 - sway) * 2.0;
    float width = mix(0.14, 0.66, h);
    float core = 1.0 - smoothstep(0.0, width, x_dist);
    float wisp = 0.65 + sin(h * 18.0 - t * 2.5 + uv.x * 8.0) * 0.20;
    float fade = smoothstep(0.0, 0.10, h) * (1.0 - smoothstep(0.46, 1.0, h));
    ALBEDO = smoke_color;
    ALPHA = core * core * wisp * fade * opacity;
}
