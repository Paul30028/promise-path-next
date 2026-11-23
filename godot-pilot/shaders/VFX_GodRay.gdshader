shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform vec4 ray_color : source_color = vec4(1.0, 0.84, 0.48, 1.0);
uniform float intensity : hint_range(0.0, 1.0) = 0.28;

void fragment() {
	// Soft Fresnel edge fade so cylinder edges dissolve into air (zero hard geometric cone border!)
	float ndotv = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float edge_fade = pow(clamp(ndotv, 0.0, 1.0), 2.2);
	// Smooth vertical fade at both sky entry and ground contact
	float top_fade = smoothstep(0.0, 0.25, UV.y);
	float bot_fade = smoothstep(0.0, 0.35, 1.0 - UV.y);
	// Subtle drifting atmospheric dust streaks
	float streak = 0.82 + 0.18 * sin(UV.x * 24.0 + TIME * 0.25) * cos(UV.y * 8.0 - TIME * 0.15);
	ALBEDO = ray_color.rgb;
	ALPHA = intensity * edge_fade * top_fade * bot_fade * streak;
}
