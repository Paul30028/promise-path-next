shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D grass_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D grass_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float uv_scale = 0.22;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = world_pos.xz * uv_scale;
	vec3 w = COLOR.rgb;
	float sum = max(w.r + w.g + w.b, 0.001);
	w /= sum;

	vec3 c_dirt = texture(dirt_albedo, uv).rgb;
	vec3 c_grass = texture(grass_albedo, uv).rgb;
	vec3 c_rock = texture(rock_albedo, uv * 0.8).rgb;

	vec3 n_dirt = texture(dirt_normal, uv).rgb;
	vec3 n_grass = texture(grass_normal, uv).rgb;
	vec3 n_rock = texture(rock_normal, uv * 0.8).rgb;

	vec3 base_albedo = c_dirt * w.r + c_grass * w.g + c_rock * w.b;
	// Subtle warm golden-hour contrast & ambient occlusion darkening in valleys
	float ao = clamp(0.84 + world_pos.y * 0.08, 0.78, 1.0);
	ALBEDO = base_albedo * 0.80 * ao;
	NORMAL_MAP = normalize(n_dirt * w.r + n_grass * w.g + n_rock * w.b);
	NORMAL_MAP_DEPTH = 1.15;
	ROUGHNESS = mix(0.95, 0.87, w.b);
	METALLIC = 0.0;
}
