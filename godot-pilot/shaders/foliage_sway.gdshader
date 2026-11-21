shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha, diffuse_burley;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform vec3 tint_bottom : source_color = vec3(0.45, 0.50, 0.28);
uniform vec3 tint_top : source_color = vec3(0.95, 0.96, 0.78);
uniform float wind_strength = 0.08;
uniform float wind_speed = 1.8;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float sway_weight = 1.0 - UV.y;
	float sway = sin(TIME * wind_speed + wp.x * 0.7 + wp.z * 0.5) * wind_strength * sway_weight;
	VERTEX.x += sway;
	VERTEX.z += sway * 0.6;
}

void fragment() {
	vec4 tex = texture(albedo_tex, UV);
	if (tex.a < 0.42) {
		discard;
	}
	float grad = clamp(1.0 - UV.y, 0.0, 1.0);
	vec3 col = tex.rgb * mix(tint_bottom, tint_top, grad);
	ALBEDO = col;
	ROUGHNESS = 0.88;
	METALLIC = 0.0;
	NORMAL = vec3(0.0, 1.0, 0.0);
}
