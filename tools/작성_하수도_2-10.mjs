import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';

// Godot를 실행하지 않고 새 씬의 텍스트만 작성한다. 기본 실행은 읽기 전용 검산이다.
// 사용자가 편집한 2-9 등 다른 씬을 읽어 복제하거나 다시 저장하지 않는다.
const ROOT=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const DIR='scenes/world_2_클로드';
const TARGET=path.join(ROOT,DIR,'stage_2-10.tscn');
const kit='res://scenes/집/스마트 매쉬 assets/';
const parts='res://scenes/집/스마트월드_장애물/';
const refs={
  world:['Script','res://scripts/스마트월드/월드.gd'],
  core:['Script','res://scripts/스마트월드/페인트_코어.gd'],
  point:['Script','res://addons/rmsmartshape/shapes/point.gd'],
  points:['Script','res://addons/rmsmartshape/shapes/point_array.gd'],
  mesh:['Script','res://addons/rmsmartshape/shapes/mesh.gd'],
  black:['PackedScene',kit+'WALL_벽체/TEMPLATE_WALL_SOLID.tscn'],
  white:['PackedScene',kit+'WALL_벽체/TEMPLATE_WALL_SOLID_WHITE.tscn'],
  grate:['PackedScene',parts+'통과플랫폼.tscn'],
  bucket:['PackedScene',parts+'양동이.tscn'],
  water:['PackedScene',parts+'유체.tscn'],
  pipe:['PackedScene',kit+'PIPE_배관/TEMPLATE_PIPE_OPEN_GRAY.tscn'],
  button:['Script','res://scripts/스마트월드/압력버튼.gd'],
  sprayer:['PackedScene',parts+'페인트분사기.tscn'],
  saw:['PackedScene','res://scenes/장애물/회전톱.tscn'],
  spikes:['PackedScene','res://scenes/장애물/가시.tscn'],
  checkpoint:['PackedScene','res://scenes/장애물/체크포인트.tscn'],
  player:['PackedScene','res://scenes/player/Player.tscn'],
  exit:['PackedScene',parts+'연결통로.tscn'],
};
const terrain=[], devices=[], subs=[], nodes=[], route=[];
const WIDTH=6144, CENTER=3072;
const departures=[12288,10112,8192,6016,3840];
const arrivals=[10496,8576,6400,4224,2048];
const frame={left:-128,right:6272,top:1024,bottom:12672,padding:2048};
const vec=p=>`Vector2(${p.join(', ')})`;
const packed=p=>`PackedVector2Array(${p.flat().join(', ')})`;
const area=p=>p.reduce((s,a,i)=>{const b=p[(i+1)%p.length];return s+a[0]*b[1]-b[0]*a[1];},0)/2;
const rect=(l,t,r,b)=>[[l,t],[r,t],[r,b],[l,b]];
const mirror=p=>p.map(([x,y])=>[WIDTH-x,y]).reverse();
function poly(name,points,color=1,options={}){terrain.push({name,points,color,...options});}
function box(name,l,t,r,b,color=1,options={}){poly(name,rect(l,t,r,b),color,options);}
// 한 회랑의 평지·경사·평지는 점 목록으로 합친다. 그림처럼 플랫폼 하나당 SS2D 하나만 생성한다.
function ribbon(name,top,color=1,depth=192,options={}){
  poly(name,[...top,...top.toReversed().map(([x,y])=>[x,y+depth])],color,{top,...options});
}
function node(name,parent,type,props='',instance=null,groups=[]){
  const full=parent===null?'.':parent==='.'?name:`${parent}/${name}`;
  assert(!nodes.some(n=>n.full===full),`중복 노드: ${full}`);
  nodes.push({full,text:`[node name="${name}"${type?` type="${type}"`:''}${parent===null?'':` parent="${parent}"`}${groups.length?` groups=${JSON.stringify(groups)}`:''}${instance?` instance=ExtResource("${instance}")`:''}]\n${props}`});
}
function instance(name,id,x,y,props='',parent='장치'){
  devices.push({name,id,x,y,props,parent});
}

// 중앙에는 다음 합류점에서 아래로 내려오는 두꺼운 기둥을 둔다. 같은 x에서 점프만으로 등반할 수 없다.
box('출발_중앙기단',2816,departures[0],3328,frame.bottom);
for(let i=0;i<5;i++){
  const d=departures[i], a=arrivals[i], n=i+1;
  const outward=[[768,d-768],[1024,d-768],[2432,d],[2688,d]];
  const inward=i===1
    ?[[768,d-1152],[896,d-1152],[1664,a],[2688,a]]
    :[[768,d-1152],[1024,d-1152],[2432,a],[2688,a]];
  ribbon(`구역${n}_왼쪽_흰상행`,outward,2);
  // 양동이 방의 턱 위에도 머리 공간이 남도록 바로 위 회랑만 144px 두께로 둔다.
  ribbon(`구역${n}_오른쪽_검정상행`,mirror(outward),1,i===2?144:192);
  ribbon(`구역${n}_왼쪽_흰복귀`,inward,2);
  // 마지막 오른쪽 길은 출구 지붕으로 합류한다. 지붕 왼쪽으로 내려가 중앙 출구에 들어간다.
  const rightIn=i===4?[[768,d-1152],[896,d-1152],[2560,a-384],[2688,a-384]]:inward;
  // 양 끝의 턱도 같은 플랫폼의 점으로 만든다. 양동이가 아래 구역으로 떨어지는 것을 막는다.
  const rightTop=i===1
    ?[[3456,a-96],[3584,a-96],[3584,a],[4352,a],[4352,a-96],[4480,a-96],[4480,a],[5248,d-1152],[5376,d-1152]]
    :mirror(rightIn);
  ribbon(`구역${n}_오른쪽_검정복귀`,rightTop);
  box(`합류${n}_중앙차단기둥`,2816,a,3328,d-384);

  // 이 세 발판은 서로 떨어진 별개 발판이다. 회랑을 조각낸 것이 아니다.
  // 아래에서 뛸 때 머리가 다음 발판에 끼지 않도록 상면만 밟는 충돌로 설정한다.
  for(const [j,l,r] of [[1,448,640],[2,128,320],[3,448,640]]){
    const y=d-768-96*j;
    box(`구역${n}_왼쪽_반환발판${j}`,l,y,r,y+144,2,{oneWay:true});
    box(`구역${n}_오른쪽_반환발판${j}`,WIDTH-r,y,WIDTH-l,y+144,1,{oneWay:true});
  }
  route.push({zone:n,departure:d,arrival:a,left:'white',right:'black',turnRise:96,turnGap:128});
  if(i<4){
    // 합류점의 짧은 계단만 위로 뛰어넘는다. 그 위에는 중앙 차단기둥이 있어 다음 구역은 다시 좌우로 돌아야 한다.
    for(let j=1;j<=4;j++){
      const width=j===4?512:256;
      instance(`합류${n}_격자계단${j}`,'grate',CENTER,a-96*j+12,
        `"크기" = Vector2(${width}, 24)\n"필요횟수" = 1`,'중앙계단');
    }
  }
}

// 외곽은 안쪽 충돌 경계를 움직이지 않고 사방으로 2048px 연장한다. 모서리도 같은 꼭짓점을 공유한다.
const {left:L,right:R,top:T,bottom:B,padding:P}=frame;
box('외곽_왼벽',L-P,T,L,B,1,{role:'exterior'});
box('외곽_오른벽',R,T,R+P,B,1,{role:'exterior'});
box('외곽_천장',L-P,T-P,R+P,T,1,{role:'exterior'});
box('외곽_바닥',L-P,B,R+P,B+P,1,{role:'exterior'});

const workshop=arrivals[1];
// 문은 독립적으로 움직여야 하므로 별도 SS2D다. 물 찬 양동이가 버튼을 누르고 있는 동안만 위로 열린다.
box('양동이문_중앙덮개',2816,workshop-416,3328,workshop-256,1,{role:'door'});
instance('양동이_검정_운반','bucket',4256,workshop,
  `"색" = 0\n"채운뒤_밀수없음" = false\n"물참" = false\n"낙사_y" = ${frame.bottom-64}.0\n"밀기_속도" = 185.0`);
instance('급수_검정','water',4128,workshop-400,
  '"종류" = 0\n"색" = 0\n"켜짐" = true\n"크기" = Vector2(96, 400)');
instance('버튼_물찬양동이','button',3712,workshop+24,
  `script = ExtResource("button")\n"폭" = 160.0\n"높이" = 24.0\n"작동방식" = 0\n"누름_가능_그룹" = PackedStringArray("양동이")\n"대상들" = Array[NodePath]([NodePath("../../지형/양동이문_중앙덮개")])\n"대상_이동량들" = Array[Vector2]([Vector2(0, -640)])\n"이동속도" = 400.0`);
// 사격 방향은 수직, 탄낙차는 0으로 두어 지정한 평지에만 페인트가 명중한다.
for(const i of [0,3])instance(`분사기_${i+1}구역_발밑변색`,'sprayer',3584,departures[i]-304,
  `"각도" = 90.0\n"총구거리" = 32.0\n"탄속" = 560.0\n"탄낙차" = 0.0\n"발사간격" = 3.2\n"발사색" = 1\n"색_번갈아" = true\n"색_전환주기" = 6.4\n"위상" = ${i===0?'0.0':'3.2'}`);
// 톱은 분사기가 없는 검정 경로의 넓은 끝 평지에서만 움직인다. 범위를 넘으면 경사로 안전 지대다.
for(const i of [1,4])instance(`회전톱_${i+1}구역`,'saw',5200,departures[i]-816,
  '"반지름" = 36.0\n"이동거리" = 160.0\n"왕복시간" = 3.2');
for(const i of [2,4])instance(`가시_${i+1}구역`,'spikes',3584,departures[i],
  '"칸수" = 2\n"가시높이" = 20.0');

// Godot 메타데이터 이름은 ASCII 식별자만 사용한다. 설명 값은 편집하기 쉽게 한글로 남긴다.
node('stage_2-10',null,'Node2D',`script = ExtResource("world")
"스테이지_이름" = "2-10 · 갈라진 수직 수로"
"시작_위치" = Vector2(${CENTER}, ${departures[0]})
"카메라_리밋" = Rect2(${L}, ${T}, ${R-L}, ${B-T})
"카메라_줌" = 0.85
"낙사_y" = ${B-64}.0
metadata/design = "아래 중앙 → 위 중앙. 좌우 선택 5곳, 중앙 직통 차단, 승강기 0대."
metadata/validation = "Godot 실행 및 실제 주행 미실행. 정적 좌표·연결 확인."`);
node('페인트코어','.','Node','script = ExtResource("core")\n"최대_탄약" = 12',null,['페인트코어']);
node('지형','.','Node2D');

function pointArray(id,points,closed=true){
  const list=closed?[...points,points[0]]:points;
  list.forEach((pt,j)=>subs.push(`[sub_resource type="Resource" id="${id}p${j}"]\nresource_local_to_scene = true\nscript = ExtResource("point")\nposition = ${vec(pt)}`));
  subs.push(`[sub_resource type="Resource" id="${id}"]
resource_local_to_scene = true
script = ExtResource("points")
_points = {
${list.map((_,j)=>`${j}: SubResource("${id}p${j}")`).join(',\n')}
}
_point_order = PackedInt32Array(${list.map((_,j)=>j).join(', ')})
${closed?`_constraints = { Vector2i(0, ${points.length}): 15 }\n`:''}_next_key = ${list.length}`);
}
for(const [i,t] of terrain.entries()){
  const xs=t.points.map(p=>p[0]),ys=t.points.map(p=>p[1]);
  const origin=[(Math.min(...xs)+Math.max(...xs))/2,(Math.min(...ys)+Math.max(...ys))/2];
  const local=t.points.map(([x,y])=>[x-origin[0],y-origin[1]]);
  pointArray(`terrain${i}`,local);
  node(t.name,'지형',null,`position = ${vec(origin)}
"시작상태" = ${t.color}
"칠하기_허용" = true
"칠하기_방식" = 0
"위치별_판정" = true
"필요횟수_수동" = 1
_points = SubResource("terrain${i}")
_meshes = Array[ExtResource("mesh")]([])
collision_size = 0.0
collision_offset = 0.0
metadata/role = "${t.role||'플랫폼'}"`,t.color===2?'white':'black');
  // 인스턴스의 자식을 새로 만들거나 owner를 재지정하지 않고 기존 충돌 노드의 값만 덮어쓴다.
  node('CollisionPolygon2D',`지형/${t.name}/StaticBody2D`,null,
    `polygon = ${packed(local)}${t.oneWay?'\none_way_collision = true\none_way_collision_margin = 4.0':''}`);
}
node('장치','.','Node2D');
node('중앙계단','.','Node2D');
for(const d of devices){
  const isButton=d.id==='button';
  node(d.name,d.parent,isButton?'AnimatableBody2D':null,
    `position = Vector2(${d.x}, ${d.y})\n${d.props}`,isButton?null:d.id);
  if(d.id==='grate'){
    const width=Number(d.props.match(/Vector2\((\d+)/)[1]);
    const id=`grate${subs.length}`;
    subs.push(`[sub_resource type="RectangleShape2D" id="${id}"]\nsize = Vector2(${width}, 24)`);
    node('충돌',`${d.parent}/${d.name}`,'CollisionShape2D',
      `shape = SubResource("${id}")\none_way_collision = true\none_way_collision_margin = 4.0`);
  }
}
// 급수구는 프로젝트의 SS2D 배관 Template을 사용한다. 점 3개만 덮어써 ㄱ자 물길을 표시한다.
node('급수배관','장치',null,`position = Vector2(4128, ${workshop-400})`,'pipe');
pointArray('waterPipe',[[128,-176],[128,0],[0,0]],false);
node('경로','장치/급수배관',null,'_points = SubResource("waterPipe")');
node('시작_물_포트','장치/급수배관',null,'position = Vector2(128, -176)');
node('끝_물_포트','장치/급수배관',null,'position = Vector2(0, 0)');
node('체크포인트','.','Node2D');
node('출발','체크포인트',null,`position = Vector2(${CENTER}, ${departures[0]})`,'checkpoint');
for(let i=0;i<5;i++)node(`합류${i+1}`,'체크포인트',null,`position = Vector2(3008, ${arrivals[i]})`,'checkpoint');
node('양동이작업장','체크포인트',null,`position = Vector2(4448, ${workshop-96})`,'checkpoint');
// 지붕을 밟는 마지막 오른쪽 길이 장식 암반에 가려지지 않도록 그림의 추가 두께를 없앤다.
node('출구통로','.',null,`position = Vector2(2816, ${arrivals[4]})
"높이" = 256.0
"깊이" = 512.0
"두께" = 96.0
"암반_위" = 0.0
"암반_아래" = 0.0
"다음_씬" = "res://scenes/lobby/lobby.tscn"
metadata/description = "최상단 중앙의 단일 출구. 후속 씬 미지정으로 로비에 연결."`,'exit');
node('끝도달_검사점','.','Marker2D',`position = Vector2(${CENTER}, ${arrivals[4]})`);
node('Player','.',null,`position = Vector2(${CENTER}, ${departures[0]})\n"점프_높이_칸" = 10.0\n"점프_거리_칸" = 20.0`,'player');

const scene='[gd_scene format=3]\n\n'+Object.entries(refs).map(([id,[type,p]])=>`[ext_resource type="${type}" path="${p}" id="${id}"]`).join('\n')+'\n\n'+subs.join('\n\n')+'\n\n'+nodes.map(n=>n.text).join('\n\n')+'\n';

// 정적 점 검산은 엔진 검사와 구분한다. 저장 전에 알 수 있는 모양 손상과 참조 누락만 검출한다.
function cross(a,b,c){return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0]);}
function triangles(p){
  const ids=p.map((_,i)=>i),out=[];
  while(ids.length>3){
    let found=false;
    for(let j=0;j<ids.length;j++){
      const a=p[ids[(j+ids.length-1)%ids.length]],b=p[ids[j]],c=p[ids[(j+1)%ids.length]];
      if(cross(a,b,c)<=0)continue;
      if(ids.some((id,k)=>k!==j&&k!==(j+ids.length-1)%ids.length&&k!==(j+1)%ids.length&&cross(a,b,p[id])>=0&&cross(b,c,p[id])>=0&&cross(c,a,p[id])>=0))continue;
      out.push([a,b,c]);ids.splice(j,1);found=true;break;
    }
    assert(found,'자기 교차 또는 퇴화한 폴리곤');
  }
  out.push(ids.map(i=>p[i]));return out;
}
function triangleOverlap(a,b){
  for(const p of [a,b])for(let i=0;i<3;i++){
    const q=p[(i+1)%3],r=p[i],axis=[q[1]-r[1],r[0]-q[0]];
    const aa=a.map(v=>v[0]*axis[0]+v[1]*axis[1]),bb=b.map(v=>v[0]*axis[0]+v[1]*axis[1]);
    if(Math.min(Math.max(...aa),Math.max(...bb))-Math.max(Math.min(...aa),Math.min(...bb))<=0.0001)return false;
  }
  return true;
}
for(const t of terrain){
  assert(area(t.points)>0,`시계방향: ${t.name}`);
  assert(t.points.flat().every(n=>n%16===0),`16px 격자: ${t.name}`);
  assert(t.points.every((p,i)=>Math.hypot(p[0]-t.points[(i+1)%t.points.length][0],p[1]-t.points[(i+1)%t.points.length][1])>=90),`짧은 변: ${t.name}`);
  t.triangles=triangles(t.points);
}
const overlaps=[];
for(let i=0;i<terrain.length;i++)for(let j=i+1;j<terrain.length;j++){
  const a=terrain[i],b=terrain[j];
  if(a.triangles.some(p=>b.triangles.some(q=>triangleOverlap(p,q))))overlaps.push([a.name,b.name]);
}
assert.deepEqual(overlaps,[],'SS2D 내부 겹침');
for(const [id,[,p]] of Object.entries(refs))assert(fs.existsSync(path.join(ROOT,p.slice(6))),`리소스 누락: ${id}`);
const subIds=new Set(subs.map(s=>s.match(/id="([^"]+)"/)[1]));
for(const m of scene.matchAll(/SubResource\("([^"]+)"\)/g))assert(subIds.has(m[1]),`내부 참조: ${m[1]}`);
for(const m of scene.matchAll(/ExtResource\("([^"]+)"\)/g))assert(Object.hasOwn(refs,m[1]),`외부 참조: ${m[1]}`);
assert.equal(nodes.filter(n=>n.text.includes('instance=ExtResource("exit")')).length,1);
assert.equal(terrain.filter(t=>t.top).length,20,'20개 연속 회랑은 각각 한 노드');
assert(!scene.includes('움직이는발판.tscn'),'승강기 0대');
assert(terrain.some(t=>t.name==='양동이문_중앙덮개'),'압력버튼 연결');
assert.equal(devices.find(d=>d.id==='bucket').x>devices.find(d=>d.id==='water').x,true,'물→버튼으로 밀 수 있는 배치');
assert(P>1920/0.85/2+220+64 && P>1080/0.85/2+300+64,'기준 시야와 카메라 오프셋의 외곽 여유');
const playable=terrain.filter(t=>t.role!=='exterior');
const sum=xs=>xs.reduce((v,t)=>v+area(t.points),0);
const report={terrain:terrain.length,continuousCorridors:20,decisions:5,elevators:0,
  start:[CENTER,departures[0]],destination:[CENTER,arrivals[4]],
  playableBlackPercent:+(sum(playable.filter(t=>t.color===1))/sum(playable)*100).toFixed(2),
  totalBlackPercent:+(sum(terrain.filter(t=>t.color===1))/sum(terrain)*100).toFixed(2),
  exteriorPadding:P,intersections:overlaps,engine:'NOT RUN'};
const model={frame,departures,arrivals,route,terrain:terrain.map(({triangles,...t})=>t),devices,report};
if(process.argv.includes('--write')){
  fs.writeFileSync(TARGET,scene,'utf8');
  fs.writeFileSync(path.join(ROOT,DIR,'stage_2-10_배치표.json'),JSON.stringify(model,null,2)+'\n','utf8');
}else assert.equal(fs.readFileSync(TARGET,'utf8'),scene,'저장된 씬이 배치표와 다름. 사용자 편집 여부 확인.');
console.log(JSON.stringify(report,null,2));
