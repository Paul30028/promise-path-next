shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform float wind_strength = 0.065;
uniform float wind_speed = 2.1;

void vertex() {
	// Pinned along top edge (UV.y = 0), billowing gently toward bottom fringe (UV.y = 1)
	float weight = UV.y * UV.y;
	float wave = sin(TIME * wind_speed + UV.x * 5.0 + UV.y * 3.5) * wind_strength * weight;
	VERTEX.z += wave;
	VERTEX.x += wave * 0.25;
}

void fragment() {
	vec4 tex = texture(albedo_tex, UV);
	// Boost jewel-like Tekhelet cobalt-blue & pomegranate-red tapestry contrast
	vec3 col = tex.rgb;
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	ALBEDO = mix(vec3(luma), col, 1.32) * 1.12;
	ROUGHNESS = 0.86;
	METALLIC = 0.0;
}
