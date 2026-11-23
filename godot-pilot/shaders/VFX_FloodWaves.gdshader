shader_type spatial;
render_mode cull_disabled;

uniform vec3 deep_color : source_color = vec3(0.05, 0.11, 0.16);
uniform vec3 crest_color : source_color = vec3(0.16, 0.27, 0.33);
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
	float ripple = 0.5 + 0.5 * sin(v_world_xz.x * 1.4 + TIME * 1.8) * cos(v_world_xz.y * 1.2 - TIME * 1.3);
	float foam = smoothstep(0.55, 0.92, crest * 0.78 + ripple * 0.28);
	vec3 col = mix(deep_color, crest_color, crest);
	col = mix(col, foam_color, foam * 0.65);
	ALBEDO = col;
	ROUGHNESS = mix(0.14, 0.45, foam);
	METALLIC = 0.22;
	ALPHA = 0.94;
}
