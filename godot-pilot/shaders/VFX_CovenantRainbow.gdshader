shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform float opacity : hint_range(0.0, 0.85) = 0.62;
varying float height;
void vertex() { height = VERTEX.y; }
vec3 spectrum(float t) {
 vec3 colors[7] = vec3[7](vec3(.92,.26,.24),vec3(.96,.58,.22),vec3(.98,.86,.32),vec3(.34,.78,.42),vec3(.28,.66,.92),vec3(.38,.44,.86),vec3(.68,.40,.84));
 float p = clamp(t,0.0,1.0)*6.0;
 int i = min(int(floor(p)),5);
 return mix(colors[i],colors[i+1],smoothstep(0.0,1.0,p-float(i)));
}
void fragment() {
 float edge = smoothstep(0.0,.24,UV.y)*smoothstep(0.0,.24,1.0-UV.y);
 float ends = smoothstep(0.0,.14,UV.x)*smoothstep(0.0,.14,1.0-UV.x);
 float ground_fade = smoothstep(0.0, 5.0, height);
 float mist = .92 + .08*sin(UV.x*18.0 + TIME*.14)*sin(UV.y*6.0+TIME*.09);
 ALBEDO = mix(spectrum(UV.y),vec3(.96,.94,.88),.14);
 ALPHA = min(.68, opacity * edge * ends * ground_fade * mist);
}
