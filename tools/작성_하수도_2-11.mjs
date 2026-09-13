import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';

// 엔진을 실행하지 않는 새 맵 전용 텍스트 작성기다. 기본 실행은 읽기 전용 검산이다.
const ROOT=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const DIR='scenes/world_2_클로드', NAME='stage_2-11';
const kit='res://scenes/집/스마트 매쉬 assets/', parts='res://scenes/집/스마트월드_장애물/';
const refs={
 world:['Script','res://scripts/스마트월드/하강수로_월드.gd'], core:['Script','res://scripts/스마트월드/페인트_코어.gd'],
 point:['Script','res://addons/rmsmartshape/shapes/point.gd'],points:['Script','res://addons/rmsmartshape/shapes/point_array.gd'],mesh:['Script','res://addons/rmsmartshape/shapes/mesh.gd'],
 black:['PackedScene',kit+'WALL_벽체/TEMPLATE_WALL_SOLID.tscn'], white:['PackedScene',kit+'WALL_벽체/TEMPLATE_WALL_SOLID_WHITE.tscn'],
 crumble:['Script','res://scripts/스마트월드/SS2D_붕괴발판.gd'], valveGroup:['Script','res://scripts/스마트월드/폭포_수문묶음.gd'],
 button:['Script','res://scripts/스마트월드/압력버튼.gd'], moving:['PackedScene',parts+'움직이는발판.tscn'],
 grate:['PackedScene',parts+'통과플랫폼.tscn'],
 water:['PackedScene',parts+'유체.tscn'],pool:['PackedScene',parts+'웅덩이.tscn'],lever:['PackedScene',parts+'제어레버.tscn'],
 pipe:['PackedScene',kit+'PIPE_배관/TEMPLATE_PIPE_OPEN_GRAY.tscn'],sprayer:['PackedScene',parts+'페인트분사기.tscn'],
 checkpoint:['PackedScene','res://scenes/장애물/체크포인트.tscn'],player:['PackedScene','res://scenes/player/Player.tscn'],exit:['PackedScene',parts+'연결통로.tscn']
};
const terrain=[],devices=[],nodes=[],subs=[],zones=[],motions=[],safeAreas=[];
const frame={left:128,top:256,right:17792,bottom:8960,padding:2048};
const start=[384,1024],destination=[17216,8448];
const vec=p=>`Vector2(${p.join(', ')})`,packed=p=>`PackedVector2Array(${p.flat().join(', ')})`;
const rect=(l,t,r,b)=>[[l,t],[r,t],[r,b],[l,b]];
const area=p=>p.reduce((s,a,i)=>{const b=p[(i+1)%p.length];return s+a[0]*b[1]-b[0]*a[1];},0)/2;
function poly(name,points,options={}){terrain.push({name,points,color:1,...options});}
function box(name,l,t,r,b,options={}){poly(name,rect(l,t,r,b),options);}
function node(name,parent,type,props='',instance=null,groups=[]){
 const full=parent===null?'.':parent==='.'?name:`${parent}/${name}`;
 assert(!nodes.some(n=>n.full===full),`노드 중복: ${full}`);
 nodes.push({full,text:`[node name="${name}"${type?` type="${type}"`:''}${parent===null?'':` parent="${parent}"`}${groups.length?` groups=${JSON.stringify(groups)}`:''}${instance?` instance=ExtResource("${instance}")`:''}]\n${props}`});
}
function device(name,id,x,y,props=''){devices.push({name,id,x,y,props});}
function pool(name,x,floor,width,depth=192,color=2){device(name,'pool',x,floor,`"색" = ${color}\n"크기" = Vector2(${width}, ${depth})\n"낙하_받아줌" = true\n"페인트_지움" = false`);}
function sprayer(name,x,y){device(name,'sprayer',x,y,'"각도" = 90.0\n"총구거리" = 32.0\n"탄속" = 560.0\n"탄낙차" = 0.0\n"발사간격" = 4.0\n"색_번갈아" = true\n"색_전환주기" = 8.0\n"발사색" = 1');}

for(let i=0;i<5;i++){
 const x=256+i*3328,y=1024+i*1536,n=i+1;
 zones.push({zone:n,x,y,puzzle:['폭포 잠그기','압력발판 다리','투명 발판','폭포 + 이동 다리','붕괴 발판'][i]});
 // 구덩이·착륙대·경사·하강 계단은 이어진 윤곽 하나다. 평지와 경사를 조각내지 않는다.
 // 첫 방의 낮은 단상도 같은 바닥의 점으로 만든다. 위쪽 유령 지름길을 선택할 수 있다.
 const approach=i===0?[[x,y],[x+384,y],[x+384,y-96],[x+640,y-96],[x+640,y]]:[[x,y]];
 const top=[...approach,[x+768,y],[x+768,y+384],[x+1792,y+384],[x+1792,y],[x+2304,y]];
 for(let j=0;j<4;j++)top.push([x+2496+j*192,y+96+j*320],[x+2496+j*192,y+320+j*320]);
 top.push([x+3200,y+1280]);
 const end=i===4?frame.right:x+3200;
 if(i===4)top.push([end,y+1280]);
 poly(`구역${n}_일체형_수로바닥`,[...top,[end,y+1792],[x,y+1792]],{role:'foundation',top});
 box(`구역${n}_천장`,x,y-768,x+2304,y-512,{role:'ceiling'});
 // 아래 물받이는 실제 충돌 바닥 위에 있다. 떨어진 뒤 왼쪽 복귀 발판으로 재시도한다.
 // 분사기 아래는 검정 물이 흰 탄을 흡수한다. 다리가 없을 때 바닥이 흰색으로 칠해지는 것을 막는다.
 // 해당 물받이에 떨어질 때는 검정으로 전환해야 한다. 나머지 완충수는 회색이다.
 pool(`구역${n}_구덩이_물받이`,x+1280,y+384,1024,192,[1,2,4].includes(i)?0:2);
 // 두꺼운 중앙 발판 밑으로 머리가 들어가지 않게 복귀 계단은 구덩이 왼쪽의 얇은 격자로 둔다.
 for(let j=1;j<=3;j++)device(`구역${n}_복귀발판${j}`,'grate',x+864,y+j*96+12,'"크기" = Vector2(128, 24)\n"필요횟수" = 1');
 for(let j=0;j<4;j++)pool(`구역${n}_하강_완충수${j+1}`,x+2400+j*192,y+96+j*320,192,160);
 if(i>0)pool(`구역${n}_진입_완충수`,x+160,y,320,96);
 safeAreas.push([x+96,y-8,544,16],[x+1824,y-8,224,16]);
 if(i===0){
  for(const [j,l,r] of [[1,1024,1216],[2,1408,1664]])box(`구역1_징검다리${j}`,x+l,y,x+r,y+144);
  box('구역1_투명_상부지름길',x+864,y-192,x+1728,y-48,{ghost:true,role:'ghost'});
 }
 if(i===1||i===3){
  // 플레이어가 발판에서 내려와도 생긴 길이 유지되게 첫 누름을 기억한다.
  // 왕복 이동거리 0은 버튼과 기존 발판 스크립트가 위치를 서로 덮어쓰지 않게 한다.
  const bridge=`구역${n}_버튼이동다리`,button=`구역${n}_압력발판`;
  device(bridge,'moving',x+1280,y-616,'"크기" = Vector2(768, 48)\n"이동거리" = 0.0\n"필요횟수" = 1');
  device(button,'button',x+576,y+24,`"폭" = 160.0\n"작동방식" = 1\n"누름_가능_그룹" = PackedStringArray("player")\n"대상들" = Array[NodePath]([NodePath("../${bridge}")])\n"대상_이동량들" = Array[Vector2]([Vector2(0, 640)])\n"이동속도" = 320.0`);
  motions.push({name:bridge,from:[x+1280,y-616],to:[x+1280,y+24],size:[768,48],role:'bridge'});
 }
 if(i===2){
  for(const [j,l,r] of [[1,1024,1280],[2,1408,1664]])box(`구역3_투명발판${j}`,x+l,y,x+r,y+144,{ghost:true,role:'ghost'});
  // 총알을 아끼면 아래 물길로 돌아간다. 상부 투명 다리와 하부 우회가 실제로 다시 합류한다.
  for(let j=1;j<=3;j++)device(`구역3_물길우회_출구발판${j}`,'grate',x+1728,y+j*96+12,'"크기" = Vector2(96, 24)\n"필요횟수" = 1');
 }
 if(i===4){
  for(const [j,l,r] of [[1,1024,1216],[2,1344,1536],[3,1632,1760]])box(`구역5_붕괴발판${j}`,x+l,y,x+r,y+144,{crumble:true,role:'crumble'});
 }
 if([0,3,4].includes(i)){
  const gate=`구역${n}_밸브수문`,group=`구역${n}_폭포묶음`;
  box(gate,x+2112,y-512,x+2240,y,{role:'gate'});
  const waterNames=[];
  for(const [j,xx,width,color] of [[1,1088,256,1],[2,1536,256,0]]){
   const name=`구역${n}_폭포${j}`;waterNames.push(name);
   device(name,'water',x+xx,y-512,`"색" = ${color}\n"크기" = Vector2(${width}, 560)\n"켜짐" = true\n"낙하_받아줌" = false`);
  }
  device(group,'valveGroup',0,0,`"유체들" = Array[NodePath]([${waterNames.map(v=>`NodePath("../${v}")`).join(', ')}])\n"수문" = NodePath("../../지형/${gate}")\n"열림_이동량" = Vector2(0, -640)`);
  device(`구역${n}_폭포차단_레버`,'lever',x+416,y-(i===0?160:64),`"종류" = 0\n"반응반경" = 96.0\n"대상_유체" = NodePath("../${group}")\n"시작_켜짐" = true`);
  motions.push({name:gate,delta:[0,-640],role:'gate'});
 }
 if(i===1||i===2||i===4)sprayer(`구역${n}_발판변색_분사기`,x+(i===4?1440:1536),y-304);
}

// 카메라 모서리 밖까지 벽 두께를 연장해 직사각형 맵 외부가 비어 보이지 않게 한다.
const {left:L,right:R,top:T,bottom:B,padding:P}=frame;
box('외곽_왼벽',L-P,T,L,B,{role:'exterior'});box('외곽_오른벽',R,T,R+P,B,{role:'exterior'});
box('외곽_천장',L-P,T-P,R+P,T,{role:'exterior'});box('외곽_바닥',L-P,B,R+P,B+P,{role:'exterior'});

node(NAME,null,'Node2D',`script = ExtResource("world")\n"스테이지_이름" = "2-11 · 잠긴 폭포의 계단"\n"시작_위치" = ${vec(start)}\n"카메라_리밋" = Rect2(${L}, ${T}, ${R-L}, ${B-T})\n"카메라_줌" = 0.85\n"낙사_y" = ${B-32}.0\n"안전구역들" = Array[Rect2]([${safeAreas.map(r=>`Rect2(${r.join(', ')})`).join(', ')}])\nmetadata/design = "좌측 최상단 → 우측 최하단. 물·밸브·압력발판·투명·붕괴. 실제 주행 미실행."`);
// 월드와 분사기는 이름이 아니라 그룹으로 코어를 찾는다. 씬에 그룹을 반드시 직렬화한다.
node('페인트코어','.','Node','script = ExtResource("core")\n"최대_탄약" = 12',null,['페인트코어']);
node('지형','.','Node2D');

function pointArray(id,points,closed=true){
 const list=closed?[...points,points[0]]:points;
 list.forEach((p,j)=>subs.push(`[sub_resource type="Resource" id="${id}p${j}"]\nresource_local_to_scene = true\nscript = ExtResource("point")\nposition = ${vec(p)}`));
 subs.push(`[sub_resource type="Resource" id="${id}"]\nresource_local_to_scene = true\nscript = ExtResource("points")\n_points = {\n${list.map((_,j)=>`${j}: SubResource("${id}p${j}")`).join(',\n')}\n}\n_point_order = PackedInt32Array(${list.map((_,j)=>j).join(', ')})\n${closed?`_constraints = { Vector2i(0, ${points.length}): 15 }\n`:''}_next_key = ${list.length}`);
}
for(const [i,t] of terrain.entries()){
 const xs=t.points.map(p=>p[0]),ys=t.points.map(p=>p[1]),origin=[(Math.min(...xs)+Math.max(...xs))/2,(Math.min(...ys)+Math.max(...ys))/2];
 const local=t.points.map(([x,y])=>[x-origin[0],y-origin[1]]);pointArray(`terrain${i}`,local);
 // 긴 유령 지름길도 실제로 굳어야 한다. 해당 부품에만 전체 칠 크기 한도를 넓힌다.
 const ghostProps=t.ghost?'"무색일때_통과" = true\n"유령_반투명도" = 0.42\n"전체_색칠_최대긴변" = 1024.0\n':'';
 node(t.name,'지형',null,`position = ${vec(origin)}\n${t.crumble?'script = ExtResource("crumble")\n"붕괴_대기" = 0.9\n"복구_대기" = 3.0\n':''}"시작상태" = ${t.ghost?0:t.color}\n"칠하기_방식" = 0\n"칠하기_허용" = true\n"필요횟수_수동" = 1\n${ghostProps}_points = SubResource("terrain${i}")\n_meshes = Array[ExtResource("mesh")]([])\ncollision_size = 0.0\ncollision_offset = 0.0\nmetadata/role = "${t.role||'platform'}"`,'black');
 // 상속한 충돌 자식 값만 덮어쓴다. owner나 이미 읽은 자식 구조는 건드리지 않는다.
 node('CollisionPolygon2D',`지형/${t.name}/StaticBody2D`,null,`polygon = ${packed(local)}${t.oneWay?'\none_way_collision = true\none_way_collision_margin = 4.0':''}`);
 if(t.crumble){
  // 무너지기 전에도 취약한 발판을 알아볼 수 있도록 표면에 균열을 표시한다.
  const w=Math.max(...xs)-Math.min(...xs),surface=Math.min(...ys)-origin[1];
  node('표면균열',`지형/${t.name}`,'Line2D',`points = ${packed([[-w*.3,surface+8],[-w*.1,surface+32],[w*.1,surface+16],[w*.3,surface+48]])}\nwidth = 3.0\ndefault_color = Color(0.7, 0.7, 0.7, 0.8)`);
 }
}
node('장치','.','Node2D');
for(const d of devices){
 const scriptOnly=['button','valveGroup'].includes(d.id);
 node(d.name,'장치',scriptOnly?(d.id==='button'?'AnimatableBody2D':'Node2D'):null,`position = Vector2(${d.x}, ${d.y})\n${scriptOnly?`script = ExtResource("${d.id}")\n`:''}${d.props}`,scriptOnly?null:d.id);
 if(d.id==='grate'){
  // 기존 부품은 기본 양방향 충돌이다. 머리를 통과시킬 보조 계단에만 단방향 충돌을 명시한다.
  const width=Number(d.props.match(/Vector2\((\d+)/)[1]),id=`grate${subs.length}`;
  subs.push(`[sub_resource type="RectangleShape2D" id="${id}"]\nsize = Vector2(${width}, 24)`);
  node('충돌',`장치/${d.name}`,'CollisionShape2D',`shape = SubResource("${id}")\none_way_collision = true\none_way_collision_margin = 4.0`);
 }
}
// 각 폭포 위에 실제 SS2D 배관을 두어 급수 방향과 밸브의 대상이 눈에 들어오게 한다.
for(const d of devices.filter(d=>d.id==='water')){
 const id=`pipe${subs.length}`,name=d.name+'_급수관';pointArray(id,[[-192,-128],[0,-128],[0,0]],false);
 node(name,'장치',null,`position = Vector2(${d.x}, ${d.y})`,'pipe');
 node('경로',`장치/${name}`,null,`_points = SubResource("${id}")`);
 node('시작_물_포트',`장치/${name}`,null,'position = Vector2(-192, -128)');
 node('끝_물_포트',`장치/${name}`,null,'position = Vector2(0, 0)');
}
node('체크포인트','.','Node2D');
for(const z of zones)for(const [label,dx] of [['진입',256],['통과',1936]])node(`구역${z.zone}_${label}`,'체크포인트',null,`position = Vector2(${z.x+dx}, ${z.y})`,'checkpoint');
node('출구통로','.',null,'position = Vector2(16896, 8448)\n"높이" = 256.0\n"깊이" = 512.0\n"두께" = 96.0\n"다음_씬" = "res://scenes/lobby/lobby.tscn"','exit');
node('끝도달_검사점','.','Marker2D',`position = ${vec(destination)}`);
node('Player','.',null,`position = ${vec(start)}\n"점프_높이_칸" = 10.0\n"점프_거리_칸" = 20.0`,'player');
const scene='[gd_scene format=3]\n\n'+Object.entries(refs).map(([id,[type,p]])=>`[ext_resource type="${type}" path="${p}" id="${id}"]`).join('\n')+'\n\n'+subs.join('\n\n')+'\n\n'+nodes.map(n=>n.text).join('\n\n')+'\n';

// 검사 함수와 저장부는 아래에 둔다. 실제 Godot 파싱·주행과 텍스트 검산을 구분한다.
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
 assert(area(t.points)>0,`뒤집힌 윤곽: ${t.name}`);
 assert(t.points.flat().every(v=>v%16===0),`격자 오류: ${t.name}`);
 assert(t.points.every((p,i)=>Math.hypot(p[0]-t.points[(i+1)%t.points.length][0],p[1]-t.points[(i+1)%t.points.length][1])>=90),`짧은 변: ${t.name}`);
 t.triangles=triangles(t.points);
}
const overlaps=[];
for(let i=0;i<terrain.length;i++)for(let j=i+1;j<terrain.length;j++){
 const a=terrain[i],b=terrain[j];
 if(a.triangles.some(p=>b.triangles.some(q=>triangleOverlap(p,q))))overlaps.push([a.name,b.name]);
}
assert.deepEqual(overlaps,[],'지형 내부 겹침');
for(const [id,[,p]] of Object.entries(refs))assert(fs.existsSync(path.join(ROOT,p.slice(6))),`없는 리소스: ${id}`);
const subIds=new Set(subs.map(s=>s.match(/id="([^"]+)"/)[1]));
for(const m of scene.matchAll(/SubResource\("([^"]+)"\)/g))assert(subIds.has(m[1]),`없는 내부 리소스: ${m[1]}`);
for(const m of scene.matchAll(/ExtResource\("([^"]+)"\)/g))assert(Object.hasOwn(refs,m[1]),`없는 외부 리소스: ${m[1]}`);
// 상대 경로를 실제 노드 목록에서 해석한다. 타입 배열만 맞고 연결은 끊긴 경우도 검출한다.
const existing=new Set(nodes.map(n=>n.full));
for(const n of nodes)for(const m of n.text.matchAll(/NodePath\("([^"]+)"\)/g)){
 const resolved=path.posix.normalize(`${n.full}/${m[1]}`);
 assert(existing.has(resolved),`끊긴 장치 경로: ${n.full} → ${resolved}`);
}
assert.equal(terrain.filter(t=>t.role==='ghost').length,3);
assert.equal(terrain.filter(t=>t.role==='crumble').length,3);
assert.equal(devices.filter(d=>d.id==='moving').length,2);
assert(nodes.some(n=>n.text.includes('groups=["페인트코어"]')),'페인트코어 그룹 누락');
for(const z of zones){
 assert(devices.some(d=>d.id==='pool'&&d.x===z.x+1280&&d.y===z.y+384),'구덩이 물받이 누락');
 assert.equal(devices.filter(d=>d.id==='grate'&&d.name.startsWith(`구역${z.zone}_복귀`)).length,3);
}
// 높은 이동 다리가 도착했을 때 양 끝 틈은 128px, 투명 첫 발판까지의 틈은 256px다.
assert(128<320&&256<320);
assert(P>1920/.85/2+300 && P>1080/.85/2+300);
const report={terrain:terrain.length,zones:zones.length,start,destination,
 playableBounds:[R-L,B-T],areaComparedToStage210:+((R-L)*(B-T)/(6400*11648)).toFixed(2),
 pressureBridges:2,ghostPlatforms:3,crumblePlatforms:3,routeChoices:2,
 waterfalls:devices.filter(d=>d.id==='water').length,waterValves:devices.filter(d=>d.id==='lever').length,
 paintSprayers:devices.filter(d=>d.id==='sprayer').length,pools:devices.filter(d=>d.id==='pool').length,
 terrainIntersections:overlaps,exteriorPadding:P,engine:'NOT RUN'};
const model={frame,zones,terrain:terrain.map(({triangles,...t})=>t),devices,motions,safeAreas,report};
const target=path.join(ROOT,DIR,NAME+'.tscn');
if(process.argv.includes('--write')){
 fs.writeFileSync(target,scene,'utf8');
 fs.writeFileSync(path.join(ROOT,DIR,NAME+'_배치표.json'),JSON.stringify(model,null,2)+'\n','utf8');
}else assert.equal(fs.readFileSync(target,'utf8'),scene,'저장된 씬이 달라짐. 사용자 수정 여부를 먼저 확인할 것.');
console.log(JSON.stringify(report,null,2));
