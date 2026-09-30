shader_type canvas_item;
// Each metal part has its own rounded cross-section, not one flat oval normal.
float edge(float d) { return 1.0-smoothstep(-0.65,0.65,d); }
void fragment() {
 vec2 p=(UV-0.5)*vec2(48.0,76.0);
 vec2 r=vec2(14.5,24.0);
 float q=length(p/r);
 vec2 radial=normalize(p/(r*r)+vec2(0.00001));
 float distance_to_ring=(q-1.0)*14.5;
 float ring=edge(abs(distance_to_ring)-1.8);
 float inside=edge((q-1.0)*14.5+0.8);
 float bx=p.x-sign(p.x)*5.4;
 float by=p.y-sign(p.y)*8.5;
 float vertical=edge(abs(bx)-1.15)*inside;
 float horizontal=edge(abs(by)-1.25)*inside;
 float mount=edge(max(abs(p.x)-4.0,abs(p.y+30.0)-5.5));
 float cap=edge(max(abs(p.x)-7.0,abs(p.y+24.0)-2.5));
 float foot=edge(max(abs(p.x)-5.5,abs(p.y-24.0)-2.0));
 vec2 slope=radial*clamp(distance_to_ring/1.8,-0.98,0.98);
 if (vertical>0.5 && ring<0.5) { slope=vec2(clamp(bx/1.15,-0.98,0.98),0.0); }
 if (horizontal>0.5 && ring<0.5) { slope=vec2(0.0,clamp(by/1.25,-0.98,0.98)); }
 if (max(mount,max(cap,foot))>0.5) { slope=vec2(clamp(p.x/7.0,-0.95,0.95),0.0); }
 float crown=sqrt(max(0.02,1.0-dot(slope,slope)));
 NORMAL=normalize(vec3(slope.x,-slope.y,crown));
 float grit=fract(sin(dot(floor(p*2.0),vec2(127.1,311.7)))*43758.5453);
 // Dark iron separates the cage from luminous glass; reflections remain light-driven.
 float iron=0.085+0.025*grit;
 COLOR=vec4(vec3(iron),max(max(ring,max(vertical,horizontal)),max(mount,max(cap,foot))));
}
void light() {
 float diffuse=max(dot(NORMAL,LIGHT_DIRECTION),0.0);
 vec3 halfway=normalize(LIGHT_DIRECTION+vec3(0.0,0.0,1.0));
 float shine=pow(max(dot(NORMAL,halfway),0.0),18.0)*0.48;
 LIGHT=vec4((COLOR.rgb*diffuse+vec3(shine))*LIGHT_COLOR.rgb*LIGHT_ENERGY,LIGHT_COLOR.a);
}
