shader_type spatial;
render_mode cull_disabled;

uniform vec3 deep_color : source_color = vec3(0.03, 0.08, 0.13);
uniform vec3 crest_color : source_color = vec3(0.10, 0.20, 0.26);
uniform vec3 foam_color : source_color = vec3(0.76, 0.83, 0.86);
uniform float wave_height = 0.45;
uniform float wave_speed = 1.4;

varying float v_height;
varying vec2 v_world_xz;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float w1 = sin(wp.x * 0.24 + TIME * wave_speed) * cos(wp.z * 0.19 + TIME * wave_speed * 0.85);
	float w2 = sin((wp.x * 0.42 - wp.z * 0.36) + TIME * wave_speed * 1.45) * 0.45;
	float h = (w1 + w2) * wave_height;
	VERTEX.y += h;
	v_height = h;
	v_world_xz = wp.xz;
}

void fragment() {
	float crest = smoothstep(0.12, wave_height * 1.15, v_height);
	// Domain-warped octaves at 2.5x, 4x and 6x the original ripple frequency.
	vec2 p = v_world_xz;
	vec2 warp = vec2(sin(p.y * 0.73 - TIME * 0.9), cos(p.x * 0.81 + TIME * 1.1)) * 0.42;
	vec2 q = p + warp;
	float ripple_1 = sin(q.x * 1.4 * 2.5 + q.y * 0.65 + TIME * 1.8);
	float ripple_2 = cos(q.y * 1.2 * 4.0 - q.x * 1.1 - TIME * 2.3);
	float ripple_3 = sin(q.x * 1.4 * 6.0 + q.y * 1.2 * 6.0 + TIME * 3.1);
	float choppy = ripple_1 * 0.55 + ripple_2 * 0.30 + ripple_3 * 0.15;
	float sharp_peaks = smoothstep(0.60, 0.92, choppy);
	float peak_gate = smoothstep(wave_height * 0.65, wave_height * 1.20, v_height);
	float lace = smoothstep(0.55, 0.94, 0.5 + 0.5 * ripple_3 * cos(q.y * 7.2 - TIME * 2.7));
	// Foam opacity is softly bounded at 0.38 and restricted to broken, sharp peaks.
	float foam = 0.38 * peak_gate * sharp_peaks * mix(0.18, 1.0, lace);
	vec3 col = mix(deep_color, crest_color, crest);
	col = mix(col, foam_color, foam);
	ALBEDO = col;
	ROUGHNESS = mix(0.14, 0.45, foam);
	METALLIC = 0.22;
	ALPHA = 0.94;
}
