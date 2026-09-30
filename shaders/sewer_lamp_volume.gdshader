shader_type canvas_item;
render_mode unshaded;
float ellipse(vec2 p, vec2 r) { return (length(p/r)-1.0)*min(r.x,r.y); }
float box(vec2 p, vec2 r) { vec2 q=abs(p)-r; return length(max(q,vec2(0.0)))+min(max(q.x,q.y),0.0); }
float mask(float d) { return 1.0-smoothstep(-0.6,0.6,d); }
float grain(vec2 p) { return fract(sin(dot(floor(p),vec2(127.1,311.7)))*43758.5453); }
vec4 over(vec4 a, float v, float opacity) {
 float alpha=opacity+a.a*(1.0-opacity);
 return vec4((vec3(v)*opacity+a.rgb*a.a*(1.0-opacity))/max(alpha,0.0001),alpha);
}
void fragment() {
 vec2 p=(UV-0.5)*vec2(88.0,110.0);
 float grit=(grain(p)-0.5)*0.045;
 vec4 c=vec4(0.0);
 // Cast and contact shadows sit behind the offset housing.
 float shadow=exp(-max(ellipse(p-vec2(7.0,6.0),vec2(22.0,34.0)),0.0)*0.22)*0.40;
 c=over(c,0.01,shadow);
 // Bolted backplate, with a narrow lit bevel and a dark right return.
 float plate=box(p-vec2(3.0,0.0),vec2(19.0,35.0))-2.0;
 float plate_v=0.12+grit+0.10*(1.0-smoothstep(-2.5,-0.5,plate));
 plate_v+=0.10*(1.0-smoothstep(0.0,3.0,abs(p.x+17.0)));
 c=over(c,plate_v,mask(plate));
 // Conduit enters the mount rather than ending in a flat antenna.
 float wire=box(p-vec2(3.0,-42.0),vec2(4.0,10.0));
 c=over(c,0.13+0.12*exp(-pow((p.x-1.0)/1.2,2.0)),mask(wire));
 for(int i=0;i<4;i++) {
  vec2 bolt=vec2((i==0||i==2)?-11.0:17.0,i<2?-29.0:29.0);
  vec2 q=p-bolt;
  c=over(c,0.035,mask(length(q)-3.0));
  c=over(c,0.25+0.13*clamp((-q.x-q.y)/3.0,-1.0,1.0),mask(length(q)-2.0));
  c=over(c,0.055,mask(box(q,vec2(1.3,0.35))));
 }
 // Rear casting is offset: visible thickness along right and lower edges.
 float rear=ellipse(p-vec2(4.0,2.0),vec2(18.0,29.0));
 c=over(c,0.10+grit,mask(rear));
 vec2 q=p-vec2(-2.0,-2.0);
 float housing=ellipse(q,vec2(18.0,29.0));
 vec2 n=q/vec2(18.0,29.0);
 float directional=clamp(dot(normalize(vec3(n,0.6)),normalize(vec3(-0.6,-0.8,0.9))),0.0,1.0);
 c=over(c,0.13+directional*0.30+grit,mask(housing));
 // Recess between metal rim and curved glass.
 float glass=ellipse(q,vec2(12.5,22.5));
 c=over(c,0.045,mask(glass-1.8));
 float core=exp(-dot(q/vec2(6.0,16.0),q/vec2(6.0,16.0)));
 float glass_v=0.42+0.40*core-0.10*clamp(q.x/12.5,0.0,1.0);
 glass_v+=0.15*exp(-pow((q.x+6.0)/1.5,2.0));
 c=over(c,glass_v,mask(glass));
 // Raised cage casts a displaced shadow onto the glass, then catches light on its left edge.
 float bars=min(abs(q.x),min(abs(q.x-7.5),abs(q.x+7.5)));
 float rings=min(abs(q.y-11.0),abs(q.y+11.0));
 float shifted=min(min(abs(q.x-1.5),min(abs(q.x-9.0),abs(q.x+6.0))),min(abs(q.y-12.5),abs(q.y+9.5)));
 c=over(c,0.18,mask(shifted-1.5)*mask(glass)*0.65);
 float cage=min(bars-1.4,rings-1.6);
 float sheen=0.12+0.25*exp(-pow((bars-0.7)/0.55,2.0))+grit;
 c=over(c,sheen,mask(cage)*mask(glass+0.3));
 COLOR=c;
}
