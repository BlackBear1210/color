shader_type canvas_item;
render_mode unshaded;
uniform sampler2D body_frames : filter_linear, repeat_disable;
uniform sampler2D impact_frames : filter_linear, repeat_disable;
uniform vec2 extent = vec2(64.0,320.0);
uniform int water_tone = 1;
uniform bool impact = true;
uniform bool animate = true;
uniform float anim_time = 0.0;
uniform float phase = 0.0;
uniform float speed = 130.0;
uniform float inlet_ratio = 1.0;
uniform float inlet_height = 40.0;
uniform float flow_head = 100000.0;
uniform float flow_tail = -100000.0;
uniform sampler2D inlet_profile : filter_linear, repeat_disable;
uniform float inlet_depth = 0.0;
varying vec2 local_pos;
void vertex(){local_pos=VERTEX;}
vec4 over(vec4 a,vec4 b){float alpha=b.a+a.a*(1.0-b.a); return vec4((b.rgb*b.a+a.rgb*a.a*(1.0-b.a))/max(alpha,.0001),alpha);}
void fragment(){
 vec2 p=local_pos;
 // Approved 40% faster flow: apply once to the shared animation clock.
 // Existing per-water speed and frozen preview phase remain intact.
 float t=(animate ? anim_time*1.4 : 0.0)+phase;
 float frame=floor(mod(t*24.0*clamp(speed/130.0,.5,2.0),48.0));
 float half_w=extent.x*.5*mix(inlet_ratio,1.0,smoothstep(0.0,inlet_height,p.y));
 // The nozzle width is fixed from the first spill; only the leading front travels.
 // Wider sheets need visible but restrained contours at the game camera scale.
 float edge_scale=clamp(extent.x/80.0,1.0,3.2);
 float edge_offset=edge_scale*(1.8*sin(p.y*.025-t*6.0)+.7*sin(p.y*.059-t*9.0));
 // Keep the nozzle joint stable while the flow contours develop below it.
 edge_offset*=smoothstep(0.0,inlet_height,p.y);
 vec2 uv=vec2(.5+p.x/extent.x*(extent.x>=160.0 ? .94 : .50),p.y/extent.y);
 // The atlas already advects water detail downward. Keep its approved 1.4x clock;
 // an additional UV scroll would double the movement. Never scale the detail with the front.
 if(inlet_depth>0.0){uv.y=fract(uv.y);}
 vec2 cell=vec2(mod(frame,8.0),floor(frame/8.0));
 vec4 body=texture(body_frames,(cell+clamp(uv,vec2(.001),vec2(.999)))/vec2(8.0,6.0));
 float e=half_w+edge_offset-abs(p.x);
 body.a=smoothstep(-.6,.7,e)*step(-inlet_depth,p.y)*step(p.y,extent.y);
 if(p.y<0.0 && inlet_depth>0.0){
  vec2 mouth_uv=vec2(.5+p.x/extent.x,1.0+p.y/inlet_depth);
  body.a*=texture(inlet_profile,clamp(mouth_uv,vec2(.001),vec2(.999))).a;
 }
 if(extent.x>=160.0){
  for(int j=0;j<2;j++){
   float age=fract(t*.5+float(j)*.5);
   float gy=age*(extent.y+22.0)-11.0;
   float gx=(float(j)*2.0-1.0)*extent.x*.19;
   float hole=(1.0-smoothstep(.55,1.0,length(vec2((p.x-gx)/2.5,(p.y-gy)/8.0))))*sin(age*3.14159);
   body.a*=1.0-hole;
  }
 }
 float rim=exp(-pow((e-1.5)/1.2,2.0));
 body.rgb+=vec3(rim*(water_tone==0 ? .09 : .04));
 // A gently irregular travelling hem replaces a flat growing rectangle.
 // Its recess plus feathering stays inside the existing 6px collision buffer.
 float front_recess=0.0;
 if(inlet_depth>0.0){front_recess=max(0.0,2.2*pow(clamp(abs(p.x)/max(half_w,1.0),0.0,1.0),2.0)+.8*sin(p.x*.21-t*11.0));}
 body.a*=smoothstep(0.0,inlet_depth>0.0 ? 2.0 : 3.0,flow_head-front_recess-p.y)*smoothstep(0.0,3.0,p.y-flow_tail);
 vec4 result=body;
 for(int j=0;j<2;j++){
  float age=fract(t*.5+float(j)*.47);
  float side=float(j)*2.0-1.0;
  float dy=20.0+age*age*max(extent.y-40.0,1.0);
  float dx=side*(half_w+5.0+age*5.0);
  float alpha=(1.0-smoothstep(.7,1.2,length(vec2((p.x-dx)/1.3,(p.y-dy)/3.0))))*step(dy,flow_head)*step(flow_tail,dy);
  float value=water_tone==1 ? .94 : (water_tone==2 ? .55 : .16);
  result=over(result,vec4(vec3(value),alpha));
 }
 if(impact && flow_head>=extent.y-1.0 && flow_tail<extent.y-2.0 && p.y>extent.y-65.0){
  float dx=p.x; float sx=253.0+dx*8.0/max(extent.x*.5,1.0);
  if(abs(dx)>extent.x*.5){sx=253.0+sign(dx)*(8.0+(abs(dx)-extent.x*.5)/.28);}
  float sy=228.0+(p.y-extent.y)/.28;
  vec2 iu=vec2(sx,sy)/vec2(512.0,288.0);
  float fi=floor(mod(t*24.0,96.0));
  vec4 splash=texture(impact_frames,(vec2(mod(fi,8.0),floor(fi/8.0))+clamp(iu,vec2(.001),vec2(.999)))/vec2(8.0,12.0));
  splash.a*=step(0.0,iu.x)*step(iu.x,1.0)*step(0.0,iu.y)*step(iu.y,1.0);
  splash.a*=1.0-(1.0-smoothstep(10.0,16.0,abs(sx-253.0)))*(1.0-smoothstep(212.0,220.0,sy));
  splash.a*=.88*(1.0-smoothstep(extent.y+1.0,extent.y+3.0,p.y));
  if(water_tone==0){splash.rgb=mix(vec3(.045),vec3(.20),splash.r);}
  if(water_tone==2){splash.rgb=mix(vec3(.36),vec3(.58),splash.r);}
  result=over(result,splash);
  float film=(1.0-smoothstep(extent.x*.59,extent.x*.60,abs(dx)))*(1.0-smoothstep(0.0,2.0,abs(p.y-extent.y)));
  float value=water_tone==1 ? .94 : (water_tone==2 ? .52 : .12);
  result=over(result,vec4(vec3(value),film*.85));
 }
 COLOR=result;
}
