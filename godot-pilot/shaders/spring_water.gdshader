shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform vec3 shallow_color : source_color = vec3(0.10, 0.35, 0.37);
uniform vec3 deep_color : source_color = vec3(0.02, 0.11, 0.16);
uniform vec3 caustic_color : source_color = vec3(0.32, 0.60, 0.60);

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float r = length(p);
	float t = TIME * 1.25;

	float w1 = sin(UV.x * 36.0 + t * 1.1) * cos(UV.y * 30.0 - t * 0.9);
	float w2 = sin((UV.x + UV.y) * 48.0 - t * 1.5) * cos((UV.x - UV.y) * 40.0 + t * 0.8);
	float caustic = smoothstep(0.32, 0.92, (w1 * 0.5 + w2 * 0.5) * 0.5 + 0.5);

	float depth_t = smoothstep(0.10, 0.94, r + w1 * 0.04);
	vec3 col = mix(deep_color, shallow_color, depth_t);
	col = mix(col, caustic_color, caustic * 0.34 * (1.0 - depth_t * 0.35));

	float edge_foam = smoothstep(0.85, 0.97, r + w1 * 0.05);
	float splash_d = length(p - vec2(-0.34, -0.52));
	float splash_foam = smoothstep(0.42, 0.05, splash_d + w2 * 0.06);
	float foam = clamp(edge_foam * 0.58 + splash_foam * 0.88, 0.0, 1.0);

	ALBEDO = mix(col, vec3(0.92, 0.97, 0.96), foam);
	NORMAL_MAP = vec3(0.5 + w1 * 0.16, 0.5 + w2 * 0.16, 1.0);
	NORMAL_MAP_DEPTH = 0.65;
	ROUGHNESS = mix(0.14, 0.62, foam);
	SPECULAR = 0.42;
	METALLIC = 0.02;
	ALPHA = smoothstep(1.0, 0.86, r) * 0.94;
}
