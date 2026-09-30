import fs from 'node:fs';
import assert from 'node:assert/strict';
import {checkResourceOrder} from './check_tscn_resource_order.mjs';

// 사용자 승인한 전면 동선 개편. 파일 쓰기 대신 패치를 출력해 원본 보관 후 apply_patch로 적용한다.
const root='scenes/world_2_클로드/stage_2-9.tscn';
const kit='res://scenes/지형/하수도/',obj='res://scenes/집/스마트월드_장애물/';
const refs={world:['Script','res://scripts/스마트월드/하강수로_월드.gd'],core:['Script','res://scripts/스마트월드/페인트_코어.gd'],
 point:['Script','res://addons/rmsmartshape/shapes/point.gd'],array:['Script','res://addons/rmsmartshape/shapes/point_array.gd'],mesh:['Script','res://addons/rmsmartshape/shapes/mesh.gd'],
 black:['PackedScene',kit+'하수도_기본지형_검정.tscn'],white:['PackedScene',kit+'하수도_기본지형_흰색.tscn'],
 ledgeBlack:['PackedScene',kit+'하수도_공중선반_검정.tscn'],ledgeWhite:['PackedScene',kit+'하수도_공중선반_흰색.tscn'],
 player:['PackedScene','res://scenes/player/Player.tscn'],exit:['PackedScene',obj+'연결통로.tscn'],lift:['PackedScene',obj+'움직이는발판.tscn'],
 pool:['PackedScene',obj+'웅덩이.tscn'],water:['PackedScene',obj+'유체.tscn'],lever:['PackedScene',obj+'제어레버.tscn'],
 button:['Script','res://scripts/스마트월드/압력버튼.gd'],group:['Script','res://scripts/스마트월드/폭포_수문묶음.gd'],
 grate:['Script','res://scripts/스마트월드/통과플랫폼.gd'],checkpoint:['PackedScene','res://scenes/장애물/체크포인트.tscn'],saw:['PackedScene','res://scenes/장애물/회전톱.tscn']};
export const terrain=[],devices=[],jumps=[];
const nodes=[],subs=[],editables=[];
const vec=p=>`Vector2(${p.join(', ')})`,packed=p=>`PackedVector2Array(${p.flat().join(', ')})`;
const poly=(name,points,color=1,options={})=>terrain.push({name,points,color,...options});
const box=(name,l,t,r,b,color=1,options={})=>poly(name,[[l,t],[r,t],[r,b],[l,b]],color,options);
// 연속된 발판은 하나의 윤곽으로 묶는다. 공중 선반 밑면은 부서진 실루엣, 상면은 정확한 착지선이다.
function ledge(name,l,y,r,color=1,options={}){
 poly(name,[[l,y],[r,y],[r,y+16],[r-32,y+64],[l+48,y+80],[l,y+32]],color,{ledge:true,...options});
}
function node(name,parent,type,props='',instance=null,groups=[]){
 const full=parent===null?'.':parent==='.'?name:`${parent}/${name}`;
 assert(!nodes.some(n=>n.full===full),full);
 nodes.push({full,text:`[node name="${name}"${type?` type="${type}"`:''}${parent===null?'':` parent="${parent}"`}${groups.length?` groups=${JSON.stringify(groups)}`:''}${instance?` instance=ExtResource("${instance}")`:''}]\n${props}`});
}
function device(name,id,x,y,props=''){devices.push({name,id,x,y,props});}

// 아래층 갈림길: 흰 경사의 버튼 지름길 / 물받이와 밸브를 지나는 검정 우회길.
poly('A_출발_낮은수로_동쪽경사',[[0,3072],[1024,3072],[1024,3456],[2944,3456],[3712,3072],[4352,3072],[4352,3968],[0,3968]]);
poly('B_흰_조작실_진입경사',[[1152,3024],[1792,2688],[2048,2688],[2048,2784],[1792,2800],[1152,3136]],2,{ledge:true});
ledge('B_검정_버튼발코니',2176,2688,2560);
ledge('B_지름길_승강기참',2688,2688,3200);
box('B_지름길문',2944,2176,3072,2688,1,{gate:true});
box('C_승강기_집수바닥',4352,3328,4736,3968);
box('C_동쪽_기계벽',4736,768,5120,3968);

// 중앙 큰 빈 공간을 두고 외곽의 두 승강기가 같은 조작실로 합류한다.
ledge('D_중앙_밸브회랑',2560,1664,3200);
ledge('D_동쪽_합류회랑',3584,1664,4352);
ledge('D_칠해서_만드는다리',2176,1664,2384,0,{ghost:true});
ledge('D_실패_집수받침',2048,2176,2688);
// 흰색 램프 한 덩어리로 서쪽 상승 방향을 읽게 한다. 반복되는 평행 복도를 만들지 않는다.
poly('E_흰_서쪽_상행램프',[[128,1024],[256,1024],[1536,1664],[2048,1664],[2048,1856],[128,1856]],2);
box('D_배수연동_수문',1536,1152,1664,1664,2,{gate:true});
// 램프 끝의 짧은 수직 연결은 같은 흰색이고 머리가 통과하는 얇은 상면이다.
for(let j=1;j<=4;j++)box(`E_흰_정비격자${j}`,128,1024-j*112,320,1040-j*112,2,{ledge:true,oneWay:true});

// 마지막 횡단은 높이·색이 바뀌는 짧은 선반. 아래 램프와 머리 공간을 공유하지 않는다.
ledge('F_상단_검정_출발',480,576,1408);
ledge('F_상단_톱_관찰대',1536,480,2560);
ledge('F_상단_흰_방류턱',2688,576,3328,2);
ledge('F_검정_출구참',3456,576,4352);

// 외곽 2048px는 그림 여유다. 실제 통행 경계는 0~5120, 천장128, 바닥3968로 유지한다.
box('외곽_왼벽',-2048,-1920,0,6016,1,{exterior:true});
box('외곽_오른벽',5120,-1920,7168,6016,1,{exterior:true});
box('외곽_천장',0,-1920,5120,128,1,{exterior:true});
box('외곽_바닥',0,3968,5120,6016,1,{exterior:true});

device('B_버튼_지름길열기','button',2400,2712,'"폭" = 128.0\n"작동방식" = 1\n"누름_가능_그룹" = PackedStringArray("player")\n"대상들" = Array[NodePath]([NodePath("../../지형/B_지름길문")])\n"대상_이동량들" = Array[Vector2]([Vector2(0, -2560)])\n"이동속도" = 800.0');
device('B_지름길승강기','lift',3392,1680,'"크기" = Vector2(384, 32)\n"이동방향" = 1\n"이동거리" = 1024.0\n"왕복시간" = 5.0\n"필요횟수" = 1');
device('C_외곽승강기','lift',4544,1680,'"크기" = Vector2(384, 32)\n"이동방향" = 1\n"이동거리" = 1408.0\n"왕복시간" = 5.0\n"필요횟수" = 1');
device('C_흰_차단수','water',4096,2304,'"색" = 1\n"크기" = Vector2(512, 768)\n"낙하_받아줌" = false');
device('C_외곽밸브','lever',3744,3008,'"반응반경" = 80.0\n"대상_유체" = NodePath("../C_흰_차단수")\n"시작_켜짐" = true');
device('D_흰_사격차단수','water',2304,1088,'"색" = 1\n"크기" = Vector2(512, 576)\n"낙하_받아줌" = false');
device('D_배수묶음','group',0,0,'"유체들" = Array[NodePath]([NodePath("../D_흰_사격차단수")])\n"수문" = NodePath("../../지형/D_배수연동_수문")\n"열림_이동량" = Vector2(0, -1536)\n"수문_속도" = 768.0');
device('D_중앙밸브','lever',2848,1600,'"반응반경" = 80.0\n"대상_유체" = NodePath("../D_배수묶음")\n"시작_켜짐" = true');
for(const [name,x,y,w,h] of [['A_회색_완충수',1920,3456,1408,128],['C_승강기_완충수',4544,3328,384,512],['D_회색_실패물받이',2368,2176,640,128]])
 device(name,'pool',x,y,`"색" = 2\n"크기" = Vector2(${w}, ${h})\n"낙하_받아줌" = true\n"페인트_지움" = false`);
device('A_우회길_톱','saw',2704,3408,'"반지름" = 32.0\n"이동거리" = 192.0\n"왕복시간" = 3.6');
device('F_출구전_톱','saw',2208,432,'"반지름" = 32.0\n"이동거리" = 192.0\n"왕복시간" = 3.6');
// 승강기가 내려가도 중앙 횡단이 끊기지 않는 고정 단방향 상부참.
device('D_중앙_고정참','grate',3392,1672,'"크기" = Vector2(384, 16)\n"필요횟수" = 1');
for(let j=1;j<=4;j++)device(`D_실패복귀_격자${j}`,'grate',2496,2184-j*112,'"크기" = Vector2(96, 16)\n"필요횟수" = 1');

node('stage_2-9',null,'Node2D',`script = ExtResource("world")\n"스테이지_이름" = "2-9 · 돌아오는 물길 — 순환 펌프실"\n"시작_위치_방식" = 0\n"시작_위치" = Vector2(512, 3072)\n"카메라_리밋" = Rect2(0, 128, 5120, 3840)\n"카메라_줌" = 1.0\n"치명_낙하거리" = 1500.0\n"낙사_y" = 4096.0\n"안전구역들" = Array[Rect2]([Rect2(384, 3064, 512, 16), Rect2(2240, 2680, 256, 16), Rect2(2624, 1656, 448, 16), Rect2(3584, 3064, 192, 16), Rect2(512, 568, 768, 16), Rect2(3520, 568, 640, 16)])\nmetadata/design_version = "loop_v2"\nmetadata/validation = "2026-09-22 전면 개편. 정적 검사만 수행, 엔진 로드/주행 미실행."`);
node('페인트코어','.','Node','script = ExtResource("core")\n"최대_탄약" = 12',null,['페인트코어']);
node('지형','.','Node2D');
for(const [i,t] of terrain.entries()){
 const xs=t.points.map(p=>p[0]),ys=t.points.map(p=>p[1]);
 const origin=[(Math.min(...xs)+Math.max(...xs))/2,(Math.min(...ys)+Math.max(...ys))/2];
 const local=t.points.map(p=>p.map((v,j)=>v-origin[j])),closed=[...local,local[0]];
 for(const [j,p] of closed.entries())subs.push(`[sub_resource type="Resource" id="t${i}p${j}"]\nresource_local_to_scene = true\nscript = ExtResource("point")\nposition = ${vec(p)}`);
 subs.push(`[sub_resource type="Resource" id="t${i}"]\nresource_local_to_scene = true\nscript = ExtResource("array")\n_points = {${closed.map((_,j)=>`${j}: SubResource("t${i}p${j}")`).join(', ')}}\n_point_order = PackedInt32Array(${closed.map((_,j)=>j).join(', ')})\n_constraints = {Vector2i(0, ${local.length}): 15}\n_next_key = ${closed.length}`);
 const id=t.ledge?(t.color===2?'ledgeWhite':'ledgeBlack'):(t.color===2?'white':'black');
 node(t.name,'지형',null,`position = ${vec(origin)}\n"시작상태" = ${t.color}\n"칠하기_허용" = true\n"칠하기_방식" = 0\n"필요횟수_수동" = 1\n${t.ghost?'"무색일때_통과" = true\n"전체_색칠_최대긴변" = 1024.0\n"유령_반투명도" = 0.42\n':''}_points = SubResource("t${i}")\n_meshes = Array[ExtResource("mesh")]([])\ncollision_size = 0.0\ncollision_offset = 0.0`,id);
 node('CollisionPolygon2D',`지형/${t.name}/StaticBody2D`,null,`polygon = ${packed(local)}${t.oneWay?'\none_way_collision = true\none_way_collision_margin = 4.0':''}`);
 editables.push(`지형/${t.name}`);
}
node('장치','.','Node2D');
for(const [i,d] of devices.entries()){
 const type={button:'AnimatableBody2D',group:'Node2D',grate:'StaticBody2D'}[d.id];
 node(d.name,'장치',type??null,`position = Vector2(${d.x}, ${d.y})\n${type?`script = ExtResource("${d.id}")\n`:''}${d.props}`,type?null:d.id);
 if(d.id==='grate'){
  const size=d.props.match(/"크기" = (Vector2\([^)]+\))/)[1];
  subs.push(`[sub_resource type="RectangleShape2D" id="grate${i}"]\nsize = ${size}`);
  node('충돌',`장치/${d.name}`,'CollisionShape2D',`shape = SubResource("grate${i}")\none_way_collision = true\none_way_collision_margin = 4.0`);
 }
}
// 배관 표시에는 충돌 없는 선을 쓴다. 실제 흐름은 위의 NodePath만이 제어한다.
// 새 배관 프리팹을 대체하지 않으며, 버튼/수문 연결을 보여 주는 가는 기계식 케이블이다.
node('연결표시','.','Node2D');
for(const [name,pts] of [['버튼_문_케이블',[[2400,2632],[2400,2528],[3008,2528]]],['밸브_수문_케이블',[[2848,1536],[2848,1376],[1600,1376]]]])
 node(name,'연결표시','Line2D',`z_index = -1\npoints = ${packed(pts)}\nwidth = 4.0\ndefault_color = Color(0.35, 0.39, 0.4, 0.6)`);
node('체크포인트','.','Node2D');
for(const [name,x,y] of [['시작',512,3072],['조작실',2304,2688],['외곽',3744,3072],['중앙',2912,1664],['상층',640,576],['출구앞',3712,576]])
 node(name,'체크포인트',null,`position = Vector2(${x}, ${y})`,'checkpoint');
node('출구통로','.',null,'position = Vector2(4352, 576)\n"높이" = 256.0\n"깊이" = 512.0\n"두께" = 96.0\n"암반_위" = 0.0\n"암반_아래" = 0.0\n"다음_씬" = "res://scenes/lobby/lobby.tscn"','exit');
node('끝도달_검사점','.','Marker2D','position = Vector2(4288, 576)');
node('Player','.',null,'position = Vector2(512, 3072)\n"점프_높이_칸" = 10.0\n"점프_거리_칸" = 20.0','player');
export const scene='[gd_scene format=3 uid="uid://836pohcx1wua"]\n\n'+Object.entries(refs).map(([id,[type,path]])=>`[ext_resource type="${type}" path="${path}" id="${id}"]`).join('\n')+'\n\n'+subs.join('\n\n')+'\n\n'+nodes.map(n=>n.text).join('\n\n')+'\n\n'+editables.map(p=>`[editable path="${p}"]`).join('\n')+'\n';
checkResourceOrder(scene,'2-9 loop_v2');
for(const [,p] of Object.values(refs))assert(fs.existsSync(p.slice(6)),p);
const existing=new Set(nodes.map(n=>n.full));
for(const n of nodes)for(const m of n.text.matchAll(/NodePath\("([^"]+)"\)/g)){
 const parts=n.full.split('/');for(const part of m[1].split('/')){if(part==='..')parts.pop();else if(part!=='.')parts.push(part);}
 assert(existing.has(parts.join('/')),`${n.full} → ${m[1]}`);
}
// 다른 파일을 절대 쓰지 않는다. 저장 전 정적 검사는 별도 test_stage29_loop_static.mjs가 담당한다.
if(process.argv.includes('--emit-patch'))console.log('*** Begin Patch\n*** Add File: '+root+'\n'+scene.trimEnd().split('\n').map(l=>'+'+l).join('\n')+'\n*** End Patch');
else if(process.argv.includes('--check')){assert.equal(fs.readFileSync(root,'utf8').replaceAll('\r\n','\n'),scene);console.log('stage_2-9 loop_v2: 저장 씬/설계 일치, 선언 순서/참조 통과 (엔진 미실행)');}
