shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D grass_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D grass_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float uv_scale = 0.24;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = world_pos.xz * uv_scale;
	vec3 w = COLOR.rgb;
	float sum = max(w.r + w.g + w.b, 0.001);
	w /= sum;

	// Macro non-repeating terrain color breakup (eliminates tiling feel!)
	float macro = sin(world_pos.x * 0.19) * cos(world_pos.z * 0.23) * 0.08 + sin((world_pos.x + world_pos.z) * 0.11) * 0.06;

	vec3 c_dirt = texture(dirt_albedo, uv).rgb;
	vec3 c_grass = texture(grass_albedo, uv).rgb;
	vec3 c_rock = texture(rock_albedo, uv * 0.78).rgb;

	vec3 n_dirt = texture(dirt_normal, uv).rgb;
	vec3 n_grass = texture(grass_normal, uv).rgb;
	vec3 n_rock = texture(rock_normal, uv * 0.78).rgb;

	vec3 base_albedo = c_dirt * w.r + c_grass * w.g + c_rock * w.b;
	// Baked vertex AO in COLOR.a (darkens under tents, walls, altar & wet spring bank!)
	float baked_ao = clamp(COLOR.a, 0.42, 1.0);
	float height_ao = clamp(0.86 + world_pos.y * 0.07, 0.80, 1.04);
	ALBEDO = base_albedo * (0.78 + macro) * baked_ao * height_ao;
	NORMAL_MAP = normalize(n_dirt * w.r + n_grass * w.g + n_rock * w.b);
	NORMAL_MAP_DEPTH = 1.25;
	// Wet sheen near spring bank where baked_ao < 0.72 and low elevation
	float wet = smoothstep(0.75, 0.52, baked_ao) * smoothstep(0.35, -0.05, world_pos.y);
	ROUGHNESS = mix(mix(0.95, 0.86, w.b), 0.32, wet);
	METALLIC = 0.0;
}
