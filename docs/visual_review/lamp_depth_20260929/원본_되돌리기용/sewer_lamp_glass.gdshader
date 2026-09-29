shader_type canvas_item;
render_mode unshaded;
void fragment() {
 vec2 p=(UV-0.5)*vec2(48.0,76.0);
 vec2 q=p/vec2(13.7,23.0);
 float radius=length(q);
 float alpha=1.0-smoothstep(-0.6,0.6,(radius-1.0)*13.7);
 // A recessed edge and an elongated bright core describe curved luminous glass.
 float core=exp(-dot(p/vec2(7.8,20.0),p/vec2(7.8,20.0)));
 float lip=smoothstep(0.78,1.0,radius);
 float glass=0.60+0.36*core-0.22*lip;
 COLOR=vec4(vec3(glass),alpha);
}
