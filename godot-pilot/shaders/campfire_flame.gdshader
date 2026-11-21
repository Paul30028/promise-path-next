shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

void fragment() {
	vec2 uv = UV;
	float t = TIME * 4.2;
	// Tapered organic flame silhouette
	float x_centered = abs(uv.x - 0.5) * 2.0;
	float wave = sin(uv.y * 12.0 - t) * 0.14 * (1.0 - uv.y);
	float width_profile = pow(clamp(uv.y, 0.0, 1.0), 0.65) * (1.0 - smoothstep(0.75, 1.0, uv.y) * 0.3);
	float mask = 1.0 - smoothstep(width_profile * 0.55, width_profile + 0.15, abs(x_centered + wave));
	float vertical = smoothstep(0.0, 0.25, uv.y) * (1.0 - smoothstep(0.7, 1.0, uv.y));
	float alpha = clamp(mask * vertical, 0.0, 1.0);
	if (alpha < 0.06) {
		discard;
	}
	vec3 core = vec3(1.0, 0.92, 0.45);
	vec3 mid = vec3(1.0, 0.46, 0.08);
	vec3 tip = vec3(0.75, 0.14, 0.02);
	vec3 col = mix(tip, mid, smoothstep(0.1, 0.55, uv.y));
	col = mix(col, core, smoothstep(0.45, 0.85, uv.y) * (1.0 - x_centered));
	ALBEDO = col * 1.45;
	ALPHA = alpha * 0.92;
}
