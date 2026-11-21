shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

uniform vec3 shadow_color : source_color = vec3(0.08, 0.05, 0.02);
uniform float opacity : hint_range(0.0, 1.0) = 0.48;

void fragment() {
	float d = length((UV - vec2(0.5)) * 2.0);
	float falloff = smoothstep(1.0, 0.15, d);
	ALBEDO = shadow_color;
	ALPHA = falloff * falloff * opacity;
}
