shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform vec3 shallow_color : source_color = vec3(0.32, 0.64, 0.62);
uniform vec3 deep_color : source_color = vec3(0.11, 0.34, 0.39);

void fragment() {
	float t = TIME * 1.4;
	float wave = sin(UV.x * 26.0 + t) * cos(UV.y * 22.0 - t * 0.85) * 0.5 + 0.5;
	float edge = length((UV - vec2(0.5)) * 2.0);
	vec3 col = mix(deep_color, shallow_color, clamp(edge * 0.85 + wave * 0.18, 0.0, 1.0));
	float foam = smoothstep(0.82, 0.98, edge + wave * 0.08);
	ALBEDO = mix(col, vec3(0.88, 0.94, 0.92), foam * 0.55);
	ROUGHNESS = 0.18;
	METALLIC = 0.05;
	ALPHA = 0.88;
}
