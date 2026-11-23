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
		p *= 2.07;
		a *= 0.5;
	}
	return v;
}

// Dual-scale rotated anti-tiling sampler: completely eliminates repetitive grid/mud-crack tiling!
vec3 sample_notile(sampler2D tex, vec2 uv, float scale1, float scale2) {
	vec2 r_uv = vec2(uv.x * 0.78 - uv.y * 0.62, uv.x * 0.62 + uv.y * 0.78);
	vec3 a = texture(tex, uv * scale1).rgb;
	vec3 b = texture(tex, r_uv * scale2).rgb;
	float m = fbm(uv * 0.045);
	return mix(a, b, smoothstep(0.25, 0.75, m));
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

	float macro_n = fbm(v_world_pos.xz * 0.025);
	float mid_n = fbm(v_world_pos.xz * 0.09);
	float detail_n = fbm(v_world_pos.xz * 0.34);

	// Rich deep warm Mediterranean earth & sandstone tones (calibrated for ACES + SDFGI raking sun!)
	vec3 g_tex = sample_notile(grass_albedo, v_world_pos.xz, 0.11, 0.042) * vec3(0.56, 0.66, 0.42);
	vec3 d_tex = sample_notile(dirt_albedo, v_world_pos.xz, 0.095, 0.036) * vec3(0.62, 0.52, 0.40);
	vec3 gravel_tex = sample_notile(rock_albedo, v_world_pos.xz, 0.13, 0.055) * vec3(0.58, 0.52, 0.44);

	// Triplanar stratified cliff limestone on steep slopes
	vec3 rock_tex = triplanar_sample(rock_albedo, v_world_pos, wn, 0.09);
	vec3 cliff_tex = triplanar_sample(boulder_albedo, v_world_pos, wn, 0.07);
	float strata = 0.80 + 0.20 * sin(v_world_pos.y * 2.4 + macro_n * 4.0);
	vec3 cliff_col = mix(rock_tex, cliff_tex, 0.5) * vec3(0.76, 0.68, 0.58) * strata;

	// Natural biome distribution: rocky dirt trail/yard around Ark, lush meadow grass across hills & valley
	vec3 earth_mix = mix(d_tex, gravel_tex, smoothstep(0.30, 0.72, mid_n));
	float yard_dist = length((v_world_pos.xz - vec2(0.0, 12.0)) * vec2(0.45, 1.0));
	float yard_clear = 1.0 - smoothstep(10.0, 26.0, yard_dist);
	float grass_mask = smoothstep(0.24, 0.66, macro_n + 0.18) * (1.0 - smoothstep(0.14, 0.32, slope));
	grass_mask *= (1.0 - yard_clear * 0.68);

	vec3 flat_col = mix(earth_mix, g_tex, grass_mask) * (0.84 + 0.32 * detail_n);
	float cliff_mask = smoothstep(0.18, 0.42, slope);
	vec3 final_albedo = mix(flat_col, cliff_col, cliff_mask);

	// Wet post-rain darkening & glossy puddle sheen
	float puddle_n = smoothstep(0.52, 0.72, fbm(v_world_pos.xz * 0.14)) * (1.0 - cliff_mask);
	float wet_amt = wetness * (0.42 + 0.58 * puddle_n);
	final_albedo *= mix(1.0, 0.52, wet_amt);

	ALBEDO = final_albedo;
	ROUGHNESS = mix(mix(0.90, 0.80, cliff_mask), 0.12, wet_amt);
	METALLIC = mix(0.0, 0.20, wet_amt * puddle_n);

	vec3 n1 = texture(rock_normal, v_world_pos.xz * 0.14).rgb;
	vec3 n2 = texture(rock_normal, v_world_pos.xz * 0.045 + vec2(0.3, 0.7)).rgb;
	NORMAL_MAP = normalize(mix(n1, n2, 0.45));
	NORMAL_MAP_DEPTH = mix(0.85, 0.20, wet_amt * puddle_n);
}
