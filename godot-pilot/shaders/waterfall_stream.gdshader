shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;

uniform vec3 water_tint : source_color = vec3(0.45, 0.78, 0.80);
uniform vec3 foam_tint : source_color = vec3(0.95, 0.98, 0.97);

void fragment() {
	float flow_v = UV.y - TIME * 1.85;
	float streak1 = sin(UV.x * 28.0 + sin(flow_v * 6.0) * 1.2) * 0.5 + 0.5;
	float streak2 = sin(UV.x * 52.0 - flow_v * 14.0) * 0.5 + 0.5;
	float foam = smoothstep(0.35, 0.88, streak1 * 0.65 + streak2 * 0.55);
	float edge_fade = smoothstep(0.0, 0.20, UV.x) * smoothstep(1.0, 0.80, UV.x);
	float top_bot = smoothstep(0.0, 0.12, UV.y) * smoothstep(1.0, 0.88, UV.y);
	ALBEDO = mix(water_tint, foam_tint, foam * 0.82);
	EMISSION = foam_tint * foam * 0.12;
	ROUGHNESS = 0.25;
	ALPHA = clamp((0.42 + foam * 0.48) * edge_fade * top_bot, 0.0, 0.92);
}
