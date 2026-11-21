shader_type canvas_item;

uniform float strength : hint_range(0.0, 1.0) = 0.28;
uniform float softness : hint_range(0.1, 1.0) = 0.55;

void fragment() {
	vec2 d = (UV - vec2(0.5)) * vec2(1.15, 1.0);
	float dist = length(d);
	float vig = smoothstep(0.45, 0.45 + softness, dist);
	COLOR = vec4(0.07, 0.04, 0.015, vig * strength);
}
