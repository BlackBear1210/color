"""흰물 디자인의 동일 셰이더를 브라우저에서도 볼 수 있게 포장한다. 이미지 편집 없음."""
from pathlib import Path
import base64
import json

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/textures/obstacles/liquid/white_modular_v2'
shader = (ROOT / 'shaders/white_water_modular_v2.gdshader').read_text(encoding='utf-8')
body = shader[shader.index('float band('):shader.index('void vertex()')]
# Godot와 WebGL에서 동일한 함수 본문을 써 미리보기만 다른 그림이 되는 일을 막는다.
fragment = '''#version 300 es
precision highp float;
uniform sampler2D flow_texture;
uniform sampler2D splash_texture;
uniform sampler2D brick_texture;
uniform bool impact;
uniform vec2 extent;
uniform int kind;
uniform float speed;
uniform float tile_size;
uniform float back_depth;
uniform float corner_inset;
uniform float pool_right_inset;
uniform int pool_tone;
uniform int water_tone;
uniform float clock_time;
uniform vec2 viewport_size;
out vec4 result;
''' + body + '''
void main() {
vec2 p = vec2(gl_FragCoord.x, viewport_size.y - gl_FragCoord.y);
p -= vec2((viewport_size.x - extent.x)*0.5, 24.0);
vec4 ink = water(p, clock_time);
float margin = kind < 3 ? 150.0 : 0.0;
float bottom = kind < 3 ? 32.0 : 0.0;
if(p.x < -margin || p.x > extent.x+margin || p.y < (kind == 3 ? -back_depth : 0.0) || p.y > extent.y+bottom) ink.a=0.0;
vec2 screen=vec2(gl_FragCoord.x,viewport_size.y-gl_FragCoord.y);
vec3 brick=texture(brick_texture,mirror_uv(screen/256.0)).rgb;
vec3 bg=brick*0.45+vec3(0.085);
float ground = kind==4 ? extent.y-5.0 : extent.y;
if(p.y>ground+3.0) bg=brick*0.9;
if(abs(p.y-ground-3.0)<1.0) bg=vec3(0.26);
bg*=0.82+0.18*sin(screen.x/viewport_size.x*3.14159265);
if(kind==3 && (p.x<0.0 || p.x>extent.x-min(pool_right_inset,extent.x*0.75)*clamp(p.y/extent.y,0.0,1.0)) && p.y>-back_depth) {
    bg=brick*0.9;
    if(p.y<0.0) bg=brick+vec3(0.10);
}
result = vec4(mix(bg,ink.rgb,ink.a),1.0);
}
'''
png = base64.b64encode((OUT / 'flow_white.png').read_bytes()).decode()
splash_png=base64.b64encode((OUT/'splash_white.png').read_bytes()).decode()
brick_png=base64.b64encode((ROOT/'assets/textures/smartshape/sewer_masonry_v02/black/fill.png').read_bytes()).decode()
html = '''<!doctype html><html lang="ko"><meta charset="utf-8"><title>흰 물 · 실제 셰이더 미리보기</title>
<style>body{margin:24px;background:#18191b;color:#eee;font:16px sans-serif}h1{font-size:24px}p{color:#bbb}main{display:grid;grid-template-columns:repeat(3,1fr);gap:16px}section{background:#252629;border:1px solid #444;border-radius:8px;padding:12px}canvas{width:100%;height:auto;aspect-ratio:540/320;object-fit:contain}label{display:block;font-size:13px;margin:8px 0}input{width:65%}button{padding:8px 20px}small{color:#aaa}#errors{color:#ff8b8b;white-space:pre-wrap}@media(max-width:1000px){main{grid-template-columns:repeat(2,1fr)}}</style>
<h1>흰 물 v2 · 물살과 착수 물보라</h1><p>실제 하수도 벽돌과 비교 · 흐르는 물결 / 흩어지는 가장자리 / 착수 거품. 충돌 없는 시각 부품입니다.</p>
<button id="pause">일시정지</button> <small>수면 뒤깊이 4px · 끝 모따기 3px · 노드 Scale 1</small><pre id="errors"></pre><main></main>
<script>
const fragment=__SHADER_SOURCE__;
const imageURL=IMAGE_URL;
const splashURL=__SPLASH_URL__;
const brickURL=__BRICK_URL__;
const titles=['01 가는 물줄기','02 넓은 물막','03 배관 출수','04 수면과 웅덩이','05 충돌 물보라','06 잔물과 물방울'];
const sizes=[[48,240],[260,240],[110,230],[384,64],[160,80],[56,240]];
const vertex='#version 300 es\\nin vec2 pos;void main(){gl_Position=vec4(pos,0.,1.);}';
let stopped=false,time=0,last=0; const entries=[];
document.querySelector('#pause').onclick=()=>{stopped=!stopped;document.querySelector('#pause').textContent=stopped?'재생':'일시정지'};
function error(s){document.querySelector('#errors').textContent+=s+'\\n';throw Error(s)}
Promise.all([imageURL,splashURL,brickURL].map(src=>new Promise((resolve,reject)=>{const im=new Image();im.onload=()=>resolve(im);im.onerror=reject;im.src=src}))).then(images=>{
titles.forEach((title,k)=>{
const s=document.createElement('section');s.innerHTML='<b>'+title+'</b><canvas width="540" height="320"></canvas><label>너비 <input type="range" min="8" max="500" value="'+sizes[k][0]+'"><output></output></label><label>높이 <input type="range" min="8" max="280" value="'+sizes[k][1]+'"><output></output></label>';document.querySelector('main').append(s);
const sliders=[...s.querySelectorAll('input')];sliders.forEach(e=>{e.oninput=()=>e.nextElementSibling.textContent=e.value+'px';e.oninput()});
const gl=s.querySelector('canvas').getContext('webgl2');if(!gl)error('WebGL2 unavailable');
function compile(type,src){const sh=gl.createShader(type);gl.shaderSource(sh,src);gl.compileShader(sh);if(!gl.getShaderParameter(sh,gl.COMPILE_STATUS))error(gl.getShaderInfoLog(sh));return sh}
const prog=gl.createProgram();gl.attachShader(prog,compile(gl.VERTEX_SHADER,vertex));gl.attachShader(prog,compile(gl.FRAGMENT_SHADER,fragment));gl.linkProgram(prog);if(!gl.getProgramParameter(prog,gl.LINK_STATUS))error(gl.getProgramInfoLog(prog));gl.useProgram(prog);
const buffer=gl.createBuffer();gl.bindBuffer(gl.ARRAY_BUFFER,buffer);gl.bufferData(gl.ARRAY_BUFFER,new Float32Array([-1,-1,1,-1,-1,1,-1,1,1,-1,1,1]),gl.STATIC_DRAW);const pos=gl.getAttribLocation(prog,'pos');gl.enableVertexAttribArray(pos);gl.vertexAttribPointer(pos,2,gl.FLOAT,false,0,0);
images.forEach((img,unit)=>{const tex=gl.createTexture();gl.activeTexture(gl.TEXTURE0+unit);gl.bindTexture(gl.TEXTURE_2D,tex);gl.texImage2D(gl.TEXTURE_2D,0,gl.RGBA,gl.RGBA,gl.UNSIGNED_BYTE,img);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MIN_FILTER,gl.LINEAR);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MAG_FILTER,gl.LINEAR);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_S,gl.CLAMP_TO_EDGE);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_T,gl.CLAMP_TO_EDGE)});
const loc=n=>gl.getUniformLocation(prog,n);gl.uniform1i(loc('kind'),k);gl.uniform1f(loc('pool_right_inset'),k===3?64:0);gl.uniform1i(loc('pool_tone'),1);gl.uniform1i(loc('water_tone'),1);gl.uniform1i(loc('flow_texture'),0);gl.uniform1i(loc('splash_texture'),1);gl.uniform1i(loc('brick_texture'),2);gl.uniform1i(loc('impact'),1);gl.uniform1f(loc('speed'),390);gl.uniform1f(loc('tile_size'),128);gl.uniform1f(loc('back_depth'),4);gl.uniform1f(loc('corner_inset'),3);gl.uniform2f(loc('viewport_size'),540,320);
const tone=document.createElement('select');tone.setAttribute('aria-label','물 색');tone.innerHTML='<option value="1">흰색 물</option><option value="2">회색 물</option><option value="0">검정 물</option>';s.append(tone);tone.onchange=()=>{gl.uniform1i(loc('water_tone'),+tone.value);gl.uniform1i(loc('pool_tone'),+tone.value)};
entries.push({gl,sliders,extent:loc('extent'),clock:loc('clock_time')});
});window.previewReady=true;
function frame(now){if(last&&!stopped)time+=(now-last)/1000;last=now;entries.forEach(e=>{e.gl.uniform2f(e.extent,+e.sliders[0].value,+e.sliders[1].value);e.gl.uniform1f(e.clock,time);e.gl.drawArrays(e.gl.TRIANGLES,0,6)});requestAnimationFrame(frame)}requestAnimationFrame(frame);
}).catch(e=>error(String(e)));
</script></html>'''
html = html.replace('__SHADER_SOURCE__', json.dumps(fragment)).replace('IMAGE_URL', json.dumps('data:image/png;base64,'+png))
html=html.replace('__SPLASH_URL__',json.dumps('data:image/png;base64,'+splash_png)).replace('__BRICK_URL__',json.dumps('data:image/png;base64,'+brick_png))
# 좁은 앱 패널에서도 실제 물결을 볼 수 있게 지나치게 축소하지 않는다.
html=html.replace('</style>','@media(max-width:760px){main{grid-template-columns:1fr}}</style>')
(OUT/'preview.html').write_text(html,encoding='utf-8')
# 비교 씬만 새로 작성한다. 기존 스테이지는 재생성하지 않는다.
scene = '''[gd_scene load_steps=2 format=3]

[ext_resource type="PackedScene" path="res://scenes/장식/유체/흰물_디자인.tscn" id="1_water"]

[node name="흰물_디자인_비교" type="Node2D"]
'''
for i,(w,h) in enumerate([(48,240),(260,240),(110,230),(384,64),(160,80),(56,240)]):
    x,y=210+(i%3)*420,100+(i//3)*360
    scene+=f'\n[node name="Water_{i}" parent="." instance=ExtResource("1_water")]\nposition = Vector2({x}, {y})\n형태 = {i}\n크기 = Vector2({w}, {h})\n'
    scene+='흐름속도 = 390.0\n'
    if i==3: scene+='웅덩이_오른쪽_안쪽폭 = 64.0\n'
    scene+=f'\n[node name="Label_{i}" type="Label" parent="."]\noffset_left = {x-150}.0\noffset_top = {y-40}.0\ntext = "{i+1}. '+['가는 물줄기','넓은 물막','배관 출수','수면과 웅덩이','충돌 물보라','잔물과 물방울'][i]+'"\n'
(ROOT/'scenes/테스트/흰물_디자인_비교.tscn').write_text(scene,encoding='utf-8')
print('Created preview.html and comparison scene; no existing map changed.')
