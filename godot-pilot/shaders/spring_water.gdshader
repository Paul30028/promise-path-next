shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform vec3 shallow_color : source_color = vec3(0.24, 0.56, 0.54);
uniform vec3 deep_color : source_color = vec3(0.06, 0.22, 0.28);
uniform vec3 caustic_color : source_color = vec3(0.58, 0.84, 0.80);

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float r = length(p);
	float t = TIME * 1.25;

	// Multi-layered Mediterranean spring ripples & caustics
	float w1 = sin(UV.x * 34.0 + t * 1.1) * cos(UV.y * 28.0 - t * 0.9);
	float w2 = sin((UV.x + UV.y) * 44.0 - t * 1.5) * cos((UV.x - UV.y) * 38.0 + t * 0.8);
	float caustic = smoothstep(0.25, 0.92, (w1 * 0.5 + w2 * 0.5) * 0.5 + 0.5);

	float depth_t = smoothstep(0.12, 0.92, r + w1 * 0.04);
	vec3 col = mix(deep_color, shallow_color, depth_t);
	col = mix(col, caustic_color, caustic * 0.26 * (1.0 - depth_t * 0.4));

	// Organic shoreline foam + waterfall splash foam near top-left entry
	float edge_foam = smoothstep(0.84, 0.97, r + w1 * 0.05);
	float splash_d = length(p - vec2(-0.34, -0.52));
	float splash_foam = smoothstep(0.42, 0.05, splash_d + w2 * 0.06);
	float foam = clamp(edge_foam * 0.65 + splash_foam * 0.85, 0.0, 1.0);

	ALBEDO = mix(col, vec3(0.90, 0.95, 0.93), foam);
	NORMAL_MAP = vec3(0.5 + w1 * 0.14, 0.5 + w2 * 0.14, 1.0);
	NORMAL_MAP_DEPTH = 0.55;
	ROUGHNESS = mix(0.22, 0.65, foam);
	SPECULAR = 0.28;
	METALLIC = 0.0;
	ALPHA = smoothstep(1.0, 0.86, r) * 0.92;
}
