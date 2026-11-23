shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform float opacity : hint_range(0.0, 0.38) = 0.38;
varying float height;
void vertex() { height = VERTEX.y; }
vec3 spectrum(float t) {
 vec3 colors[7] = vec3[7](vec3(.76,.32,.29),vec3(.86,.56,.29),vec3(.88,.78,.42),vec3(.43,.67,.47),vec3(.36,.61,.72),vec3(.41,.45,.68),vec3(.62,.46,.67));
 float p = clamp(t,0.0,1.0)*6.0;
 int i = min(int(floor(p)),5);
 return mix(colors[i],colors[i+1],smoothstep(0.0,1.0,p-float(i)));
}
void fragment() {
 float edge = smoothstep(0.0,.22,UV.y)*smoothstep(0.0,.22,1.0-UV.y);
 float ends = smoothstep(0.0,.16,UV.x)*smoothstep(0.0,.16,1.0-UV.x);
 float vertical = smoothstep(0.0,3.0,height)*(1.0-smoothstep(12.0,16.0,height));
 float mist = .91 + .09*sin(UV.x*19.0 + TIME*.12)*sin(UV.y*7.0+TIME*.08);
 ALBEDO = mix(spectrum(UV.y),vec3(.87,.86,.78),.24);
 ALPHA = min(.38,opacity*edge*ends*vertical*mist);
}
