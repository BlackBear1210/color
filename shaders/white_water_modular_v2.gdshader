shader_type canvas_item;
render_mode unshaded;
uniform sampler2D flow_texture : filter_linear, repeat_disable;
uniform sampler2D splash_texture : filter_linear, repeat_disable;
uniform bool impact = true;
uniform float pool_right_inset = 0.0;
uniform int pool_tone = 1;
uniform int water_tone = 1;
uniform vec2 extent = vec2(64.0, 320.0);
uniform int kind = 0;
uniform float speed = 130.0;
uniform float tile_size = 128.0;
uniform float back_depth = 4.0;
uniform float corner_inset = 3.0;
uniform float phase = 0.0;
uniform bool animate = true;
varying vec2 pixel;

float band(float distance_to_edge) {
    return smoothstep(0.0, 1.2, distance_to_edge);
}
vec2 mirror_uv(vec2 uv) {
    return 1.0 - abs(mod(uv, 2.0) - 1.0);
}
float detail(vec2 p) {
    vec2 uv=p/tile_size;
    float v=fract(uv.y);
    float x=mirror_uv(vec2(uv.x,0.0)).x;
    float weight=pow(sin(v*3.14159265),2.0);
    float a=texture(flow_texture,vec2(x,v)).r;
    float b=texture(flow_texture,vec2(x,fract(v+0.5))).r;
    return mix(b,a,weight);
}
float noise_wave(float y, float t) {
    return sin(y * 0.067 - t * 4.7) * 1.8 + sin(y * 0.193 - t * 9.1) * 0.8;
}
vec4 splash(vec2 p, float center, float ground, float width, float t) {
    float height = width * 0.18;
    // Skip expensive spray sampling outside the impact footprint.
    if (abs(p.x-center)>width*0.55 || p.y<ground-height || p.y>ground+3.0) {
        return vec4(0.0);
    }
    // Ballistic droplets replace the persistent upward-facing spray image.
    vec4 a=vec4(vec3(0.98),0.0);
    float drops=0.0;
    for(int i=0;i<12;i++) {
        float fi=float(i);
        float age=fract(t*(1.35+fi*0.047)+fi*0.618);
        float direction=mod(fi,2.0)*2.0-1.0;
        float start=width*(0.09+0.012*mod(fi,3.0));
        float reach=width*(0.27+0.022*mod(fi,4.0));
        float peak=height*(0.42+0.08*mod(fi,3.0));
        float tail=max(0.0,age-0.055);
        vec2 head=vec2(center+direction*(start+age*reach),ground-1.0-4.0*peak*age*(1.0-age));
        vec2 end=vec2(center+direction*(start+tail*reach),ground-1.0-4.0*peak*tail*(1.0-tail));
        vec2 segment=head-end;
        float u=clamp(dot(p-end,segment)/max(dot(segment,segment),0.001),0.0,1.0);
        float radius=0.65+0.15*mod(fi,3.0);
        float drop=1.0-smoothstep(radius,radius+0.7,length(p-end-segment*u));
        // Retain the descending half; fade only when it returns to the ground.
        float life=smoothstep(0.0,0.10,age)*(1.0-smoothstep(0.88,1.0,age));
        drops=max(drops,drop*life*0.88);
    }
    // Small irregular foam core anchors the stream without a horizontal sheet.
    vec2 core=vec2((p.x-center)/(width*0.21),(p.y-ground+1.0)/3.0);
    float foam=(1.0-smoothstep(0.45,1.0,length(core)));
    foam*=0.45+0.25*sin(p.x*0.31+t*11.0)*sin(p.x*0.19-t*7.0);
    a.a=max(max(a.a,drops),foam);
    // No repeating ground plane or visible rectangular lower edge.
    a.a*=1.0-smoothstep(ground,ground+3.0,p.y);
    return a;
}
vec4 over(vec4 under, vec4 front) {
    float alpha = front.a + under.a*(1.0-front.a);
    return vec4((front.rgb*front.a+under.rgb*under.a*(1.0-front.a))/max(alpha,0.0001),alpha);
}
vec4 water(vec2 p, float t) {
    float w = extent.x;
    // Ground top spans [collision_y-back_depth, collision_y].
    // Stop at its midpoint; the collision dimensions remain unchanged.
    float h = extent.y;
    if (impact && kind<=2) h=max(1.0,h-back_depth*0.5);
    float opacity = 0.0;
    float value = 0.9;
    if (kind == 0 || kind == 1) {
        float distort = noise_wave(p.y,t);
        float a = detail(vec2(p.x + distort, p.y - t * speed));
        float b = detail(vec2(p.x*1.6 + 41.0 - distort, p.y*0.83 - t * speed * 1.17));
        float edge_width = min(7.0,w*0.2);
        float left = noise_wave(p.y,t)*0.55;
        float right = noise_wave(p.y+39.0,t+2.1)*0.55;
        float d = min(p.x-left, w-p.x+right);
        float fringe = smoothstep(-edge_width,edge_width,d + (a-0.5)*edge_width*2.0);
        opacity = fringe * smoothstep(0.0,3.0,p.y) * (1.0-smoothstep(h-9.0,h+5.0,p.y));
        value = 0.63 + 0.36 * pow(mix(a,b,0.22),0.65);
        float foam = smoothstep(0.65,0.94,b) * smoothstep(h-50.0,h,p.y);
        value = mix(value,0.99,foam*0.45);
    } else if (kind == 2) {
        // A curved exit, with a fixed-size cross-section instead of a stretched sprite.
        float u = clamp(p.y / h, 0.0, 1.0);
        float radius = min(18.0, w * 0.18);
        float center = radius + (w - 2.0 * radius) * (1.0 - exp(-u * 4.0));
        center += noise_wave(p.y,t)*0.45;
        float a = detail(vec2(p.x-center+radius,p.y-t*speed));
        float d = radius - abs(p.x - center);
        opacity = smoothstep(-2.0,3.0,d+(a-0.5)*6.0) * step(0.0,p.y) * (1.0-smoothstep(h-8.0,h+4.0,p.y));
        value = 0.65 + 0.34 * pow(a,0.65);
    } else if (kind == 3) {
        float inset = corner_inset * clamp(-p.y / max(back_depth, 0.1), 0.0, 1.0);
        float slope = min(pool_right_inset,w*0.75) * clamp(p.y / h,0.0,1.0);
        float contact = min(p.x-inset,w-inset-p.x-slope);
        float small_wave = sin(p.x*0.07-t*2.4)*0.65+sin(p.x*0.19+t*1.7)*0.25;
        opacity = band(contact) * band(h - p.y);
        if (p.y < 0.0) {
            float waves = sin(p.x*0.13-t*3.1+p.y*2.7+sin(p.x*0.037+t*1.4));
            value = 0.77 + 0.22 * smoothstep(-0.5,0.85,waves);
            opacity *= band(p.y+back_depth-small_wave);
        } else {
            float a = detail(vec2(p.x*0.65+t*25.0+sin(p.y*0.08-t)*8.0,p.y*2.6+sin(p.x*0.04+t)*10.0));
            float soft_flow=sin(p.x*0.018+p.y*0.045-t*0.8+sin(p.x*0.009+t)*0.6);
            value=0.76+0.12*a+0.018*soft_flow;
            value+=0.065*exp(-p.y/6.0);
            value-=0.065*smoothstep(16.0,max(17.0,h),p.y);
            // Narrow wall meniscus and irregular contact shading, not a solid frame.
            float wet_edge=exp(-max(contact,0.0)/2.0);
            float floor_contact=exp(-max(h-p.y,0.0)/3.0);
            value-=wet_edge*(0.06+0.025*sin(p.y*.21-t*2.0));
            value-=floor_contact*(0.055+0.025*sin(p.x*.12+t));
            float rim=exp(-abs(p.y-1.5-small_wave)*1.1);
            value+=rim*(0.04+0.035*sin(p.x*.15-t*3.0));
        }
    } else if (kind == 4) {
        // The standalone preview uses the same falling droplets as the stream.
        opacity = 0.0;
        value = 0.98;
    } else {
        for (int i = 0; i < 4; i++) {
            float fi = float(i);
            float age = fract(t * 0.6 + fi * 0.25);
            vec2 center = vec2(w * 0.5 + sin(fi * 13.0) * min(w * 0.2, 9.0), age * age * (h + 12.0) - 6.0);
            float drop = 1.0 - smoothstep(1.2, 2.7, length((p - center) / vec2(0.8, 1.5)));
            opacity = max(opacity, drop);
        }
        value = 0.94;
    }
    vec4 result = vec4(vec3(clamp(value,0.0,1.0)),opacity);
    if (kind == 4) {
        result=over(result,splash(p,w*0.5,h-5.0,min(w,220.0),t));
    } else if (impact && (kind == 0 || kind == 1 || kind == 2)) {
        float center=w*0.5;
        if(kind==2) {
            float radius=min(18.0,w*0.18);
            center=radius+(w-2.0*radius)*(1.0-exp(-4.0));
        }
        if(w<160.0 || kind==2) {
            result=over(result,splash(p,center,h,min(240.0,max(w*3.0,120.0)),t));
        } else {
            float count=ceil(w/120.0);
            float spacing=w/count;
            float index=clamp(floor(p.x/spacing),0.0,count-1.0);
            result=over(result,splash(p,(index+0.5)*spacing,h,spacing*1.5,t+index*1.73));
        }
    }
    // Remap after compositing so foam and droplets match the body color.
    int tone_id=kind==3 ? pool_tone : water_tone;
    if(tone_id!=1) {
        float light=clamp(result.r,0.0,1.0);
        float tone=tone_id==2 ? 0.32+0.25*light : 0.018+0.17*light;
        result.rgb=vec3(tone);
    }
    return result;
}
void vertex() {
    pixel = VERTEX + vec2(extent.x * 0.5, 0.0);
}
void fragment() {
    COLOR = water(pixel, phase + (animate ? TIME : 0.0));
}
