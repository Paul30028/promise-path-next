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

	// Macro non-repeating sunlit hillside variation
	float macro = sin(world_pos.x * 0.19) * cos(world_pos.z * 0.23) * 0.07 + sin((world_pos.x + world_pos.z) * 0.11) * 0.05;

	// Soften mud cracks into warm packed Mediterranean golden-ochre footpath earth
	vec3 raw_dirt = texture(dirt_albedo, uv * 1.15).rgb;
	vec3 c_dirt = mix(vec3(0.68, 0.49, 0.30), raw_dirt, 0.58) * vec3(1.18, 0.96, 0.68);
	// Vibrant sun-drenched Mediterranean olive-emerald meadow grass!
	vec3 c_grass = texture(grass_albedo, uv).rgb * vec3(0.70, 1.12, 0.36);
	// Crisp sun-bleached Canaanite ivory-cream limestone
	vec3 c_rock = texture(rock_albedo, uv * 0.78).rgb * vec3(1.38, 1.32, 1.16);

	vec3 n_dirt = texture(dirt_normal, uv * 1.15).rgb;
	vec3 n_grass = texture(grass_normal, uv).rgb;
	vec3 n_rock = texture(rock_normal, uv * 0.78).rgb;

	vec3 base_albedo = c_dirt * w.r + c_grass * w.g + c_rock * w.b;
	float baked_ao = clamp(COLOR.a, 0.42, 1.0);
	float height_ao = clamp(0.88 + world_pos.y * 0.07, 0.82, 1.05);
	ALBEDO = base_albedo * (0.86 + macro) * baked_ao * height_ao;
	NORMAL_MAP = normalize(n_dirt * w.r + n_grass * w.g + n_rock * w.b);
	NORMAL_MAP_DEPTH = mix(0.85, 1.30, w.g + w.b);
	float wet = smoothstep(0.75, 0.52, baked_ao) * smoothstep(0.35, -0.05, world_pos.y);
	ROUGHNESS = mix(mix(0.95, 0.86, w.b), 0.28, wet);
	METALLIC = 0.0;
}
