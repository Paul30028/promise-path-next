shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

void fragment() {
	vec2 uv = UV;
	float t = TIME * 4.2;
	float x_centered = abs(uv.x - 0.5) * 2.0;
	float wave = sin(uv.y * 12.0 - t) * 0.14 * (1.0 - uv.y);
	float width_profile = pow(clamp(uv.y, 0.0, 1.0), 0.72) * (1.0 - smoothstep(0.75, 1.0, uv.y) * 0.35);
	float mask = 1.0 - smoothstep(width_profile * 0.45, width_profile + 0.12, abs(x_centered + wave));
	float vertical = smoothstep(0.0, 0.22, uv.y) * (1.0 - smoothstep(0.72, 1.0, uv.y));
	float alpha = clamp(mask * vertical, 0.0, 1.0);
	if (alpha < 0.08) {
		discard;
	}
	vec3 core = vec3(1.0, 0.88, 0.32);
	vec3 mid = vec3(0.98, 0.38, 0.05);
	vec3 tip = vec3(0.68, 0.10, 0.01);
	vec3 col = mix(tip, mid, smoothstep(0.08, 0.52, uv.y));
	col = mix(col, core, smoothstep(0.45, 0.85, uv.y) * (1.0 - x_centered * 0.85));
	ALBEDO = col * 1.15;
	ALPHA = alpha * 0.90;
}
