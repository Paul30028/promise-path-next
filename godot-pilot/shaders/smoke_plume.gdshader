shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

uniform vec3 smoke_color : source_color = vec3(0.92, 0.89, 0.84);
uniform float opacity : hint_range(0.0, 1.0) = 0.36;

void fragment() {
	vec2 uv = UV;
	float t = TIME * 0.55;
	float sway = sin(uv.y * 6.0 - t * 2.2) * 0.14;
	float x_dist = abs((uv.x - 0.5) + sway) * 2.0;
	float width = mix(0.28, 0.85, 1.0 - uv.y);
	float core = smoothstep(width, 0.0, x_dist);
	float wisp = sin(uv.y * 14.0 - t * 3.5 + uv.x * 7.0) * 0.25 + 0.75;
	float v_fade = smoothstep(0.0, 0.22, uv.y) * smoothstep(1.0, 0.18, uv.y);
	ALBEDO = smoke_color;
	ALPHA = clamp(core * wisp * v_fade * opacity, 0.0, 0.55);
}
