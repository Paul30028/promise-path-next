shader_type spatial;
render_mode specular_schlick_ggx;

uniform sampler2D grass_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D boulder_albedo : source_color, filter_linear_mipmap, repeat_enable;

uniform float wetness : hint_range(0.0, 1.0) = 0.0;

varying vec3 v_world_pos;
varying vec3 v_world_nrm;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

vec3 triplanar_sample(sampler2D tex, vec3 wp, vec3 wn, float scale) {
	vec3 b = pow(abs(wn), vec3(4.0));
	b /= max(b.x + b.y + b.z, 0.0001);
	vec3 tx = texture(tex, wp.zy * scale).rgb;
	vec3 ty = texture(tex, wp.xz * scale).rgb;
	vec3 tz = texture(tex, wp.xy * scale).rgb;
	return tx * b.x + ty * b.y + tz * b.z;
}

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 wn = normalize(v_world_nrm);
	float slope = 1.0 - clamp(wn.y, 0.0, 1.0);

	// Macro + micro fBM noise for natural organic Mediterranean grass/earth/gravel patches
	float macro_n = fbm(v_world_pos.xz * 0.055);
	float detail_n = fbm(v_world_pos.xz * 0.28);

	// Triplanar rock & strata for steep cliff faces (zero UV stretching!)
	vec3 rock_tex = triplanar_sample(rock_albedo, v_world_pos, wn, 0.14);
	vec3 cliff_tex = triplanar_sample(boulder_albedo, v_world_pos, wn, 0.11);
	float strata = 0.85 + 0.15 * sin(v_world_pos.y * 3.8 + macro_n * 3.2);
	vec3 cliff_col = mix(rock_tex, cliff_tex, 0.5) * vec3(0.92, 0.86, 0.78) * strata;

	// Real 2K grass & dirt PBR blending on gentle slopes
	vec3 g_tex = texture(grass_albedo, v_world_pos.xz * 0.18).rgb * vec3(0.86, 0.92, 0.76);
	vec3 d_tex = texture(dirt_albedo, v_world_pos.xz * 0.16).rgb * vec3(0.95, 0.88, 0.78);
	float valley_lush = 1.0 - smoothstep(-28.0, -8.0, v_world_pos.x);
	float forest_lush = smoothstep(10.0, 26.0, v_world_pos.x);
	float grass_mask = smoothstep(0.26, 0.66, macro_n + valley_lush * 0.34 + forest_lush * 0.30) * (1.0 - smoothstep(0.14, 0.32, slope));
	// Keep central shipyard clearing warmer compacted earth/gravel
	float yard_clear = (1.0 - smoothstep(4.5, 13.5, length(v_world_pos.xz - vec2(1.0, 1.5))));
	grass_mask *= (1.0 - yard_clear * 0.78);

	vec3 flat_col = mix(d_tex, g_tex, grass_mask) * (0.88 + 0.24 * detail_n);

	// Blend flat ground -> steep stratified limestone cliff
	float cliff_mask = smoothstep(0.18, 0.42, slope);
	vec3 final_albedo = mix(flat_col, cliff_col, cliff_mask);

	// Wetness darkening & post-rain glossy sheen (Ararat / Flood!)
	float puddle_n = smoothstep(0.56, 0.74, fbm(v_world_pos.xz * 0.22)) * (1.0 - cliff_mask);
	float wet_amt = wetness * (0.45 + 0.55 * puddle_n);
	final_albedo *= mix(1.0, 0.58, wet_amt);

	ALBEDO = final_albedo;
	ROUGHNESS = mix(mix(0.92, 0.82, cliff_mask), 0.14, wet_amt);
	METALLIC = mix(0.0, 0.18, wet_amt * puddle_n);

	vec3 n_samp = texture(rock_normal, v_world_pos.xz * 0.22).rgb;
	NORMAL_MAP = n_samp;
	NORMAL_MAP_DEPTH = mix(0.75, 0.18, wet_amt * puddle_n);
}
