import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';

// Godot 실행 금지 규칙을 지키려고 텍스트 리소스만 작성한다. 기존 씬은 읽거나 다시 굽지 않는다.
// 좌표표에서 매번 같은 결과를 만들며 --check는 파일을 변경하지 않는다.
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const target = path.join(root, 'scenes/world_2_클로드/stage_2-9.tscn');
const kit = 'res://scenes/집/스마트 매쉬 assets/WALL_벽체/';
const obj = 'res://scenes/집/스마트월드_장애물/';
const resources = {
  world: ['Script', 'res://scripts/스마트월드/월드.gd'],
  core: ['Script', 'res://scripts/스마트월드/페인트_코어.gd'],
  black: ['PackedScene', kit + 'TEMPLATE_WALL_SOLID.tscn'],
  white: ['PackedScene', kit + 'TEMPLATE_WALL_SOLID_WHITE.tscn'],
  point: ['Script', 'res://addons/rmsmartshape/shapes/point.gd'],
  points: ['Script', 'res://addons/rmsmartshape/shapes/point_array.gd'],
  mesh: ['Script', 'res://addons/rmsmartshape/shapes/mesh.gd'],
  player: ['PackedScene', 'res://scenes/player/Player.tscn'],
  lift: ['PackedScene', obj + '움직이는발판.tscn'],
  pool: ['PackedScene', obj + '웅덩이.tscn'],
  button: ['Script', 'res://scripts/스마트월드/압력버튼.gd'],
  saw: ['PackedScene', 'res://scenes/장애물/회전톱.tscn'],
  checkpoint: ['PackedScene', 'res://scenes/장애물/체크포인트.tscn'],
  exit: ['PackedScene', obj + '연결통로.tscn'],
};
const polygons = [];
const rect = (x0,y0,x1,y1) => [[x0,y0],[x1,y0],[x1,y1],[x0,y1]];
const add = (name, points, color=1, extra='') => polygons.push({name,points,color,extra});
const box = (name,x0,y0,x1,y1,color=1,extra='') => add(name,rect(x0,y0,x1,y1),color,extra);
const slope = (name,x0,y0,x1,y1,color=1,thickness=192) =>
  add(name,[[x0,y0],[x1,y1],[x1,y1+thickness],[x0,y0+thickness]],color);

// 첫 갈림길의 낮은 길은 256px만 떨어진다. 위의 흰 경사로 아래로 걸어갈 공간을 확보한다.
add('L1_출발',[[512,3072],[1024,3072],[1024,3456],[640,3456],[512,3328]]);
box('L1_낮은수로',1024,3328,4256,3520);
slope('L1_수로오름',4672,3232,5120,3072);
// 두 번째 갈림길 아래는 다시 낮춰 지름길 방의 바닥에 머리가 끼지 않게 한다.
slope('L1_F2_내리막',5120,3168,5632,3328);
box('L1_F2_하부통로서쪽',5632,3328,6144,3520);
box('L1_F2_하부통로동쪽',6528,3328,7168,3520);
slope('L1_F2_복귀경사',7168,3328,7680,3072);
box('L1_검정쉼터',7680,3072,8064,3264);
box('L1_흰수로',8192,3072,9984,4096,2);
box('L1_동쪽기계실',10112,3072,12544,3264);

// F1은 검정 길과 다른 색으로 시작한다. 128px 틈 너머 흰 경사로를 점프로 고른다.
slope('F1_흰진입경사',1152,3024,1984,2880,2,160);
box('F1_흰막다른선반',1984,2880,3136,3040,2);
box('F1_검정장치방',3264,2880,4224,3040);
box('F1_끝벽',4480,2496,4800,3008);
// 끝벽 앞의 옆길로 내려오면 352px 만에 하부 길에 합류한다. 진입 경사를 되밟지 않는다.
box('F1_복귀받침',4256,3232,4672,3520);

// F3은 작은 흰 방 + 검정 승강기. F1의 유지 버튼이 문을 위로 밀어 진입을 허용한다.
slope('F3_검정진입경사',5120,2976,5568,2944,1,160);
box('F3_흰준비선반',5696,2944,5888,3104,2);
box('F3_흰천장',5696,2496,5888,2656,2);
box('F3_문',6016,2496,6176,2944,1,'metadata/설명 = "F1 버튼으로 위로 512px 이동하는 지름길 문"');
box('F3_검정승강기참',6016,2944,6144,3104);
box('F3_안쪽벽',6528,2496,6848,3104);

// 정답 기본 동선은 오른쪽 끝 → 2층 전체 → 왼쪽 끝 → 3층 전체, 약 37,000px이다.
box('L2_서쪽참',512,2304,2048,2496);
slope('L2_완만오름',2048,2304,2560,2208);
box('L2_높은회랑',2560,2208,3584,2400);
slope('L2_완만내림',3584,2208,4096,2304);
box('L2_교차점',4096,2304,6144,2496);
box('L2_교차점동쪽',6528,2304,8064,2496);
box('L2_흰회랑',8192,2304,9984,2496,2);
box('L2_동쪽참',10112,2304,12544,2496);

box('L3_서쪽출발',512,1536,2048,1728);
slope('L3_상행경사',2048,1536,2560,1440);
box('L3_상부쉼터',2560,1440,3584,1632);
slope('L3_흰구역앞경사',3584,1440,3968,1536);
box('L3_흰정비회랑',4096,1536,6144,1984,2);
box('L3_검정회랑',6272,1536,8192,1728);
slope('L3_톱앞내리막',8192,1536,8704,1632);
box('L3_톱기계실',8704,1632,10240,1824);
slope('L3_출구오름',10240,1632,10752,1536);
box('L3_출구쉼터',10752,1536,12544,1728);

// 지붕과 수로의 국소 천장도 해당 바닥 색을 따른다. 큰 벽과 시작/출구는 검정이다.
box('지붕_서쪽',0,704,3968,896);
box('지붕_흰정비실',4096,-64,6144,896,2);
box('지붕_동쪽',6272,704,13568,896);
box('L1_흰천장',8192,2656,9984,2816,2);
box('L2_흰천장',8192,1888,9984,2048,2);
box('F1_흰천장',1664,2496,3136,2656,2);
box('서쪽_외벽',-320,704,0,3712);
box('서쪽_저층벽',0,2752,512,3712);
box('동쪽_외벽',13056,896,13376,3456);
box('동쪽_출구위벽',12544,896,13056,1280);
box('동쪽_출구아래벽',12544,1728,13056,2048);
// 승강기 옆으로 떨어져도 각 층 가까이의 회색 물이 받아 준다.
box('승강기_동쪽집수바닥',12544,3328,13056,3520);
box('승강기_서쪽집수바닥',0,2560,512,2752);
box('F3_집수받침',6144,3232,6528,3520);

const sub = [];
const nodes = [];
const v = p => `Vector2(${p.join(', ')})`;
const packed = pts => `PackedVector2Array(${pts.flat().join(', ')})`;
const node = (name,parent,type,props='',instance=null,groups=[]) => {
  nodes.push(`[node name="${name}"${type ? ` type="${type}"` : ''}${parent === null ? '' : ` parent="${parent}"`}${groups.length ? ` groups=${JSON.stringify(groups)}` : ''}${instance ? ` instance=ExtResource("${instance}")` : ''}]\n${props}`);
};
node('stage_2-9',null,'Node2D',`script = ExtResource("world")
"스테이지_이름" = "2-9 · 돌아오는 물길"
"카메라_리밋" = Rect2(-320, 384, 13888, 3840)
"카메라_줌" = 0.85
"시작_위치" = Vector2(768, 3072)
"낙사_y" = 4096.0
metadata/설계 = "F1 흰 막다른 선반 → 유지 버튼 → 옆 낙하 복귀 / F2 동쪽·서쪽 왕복 / F3 중앙 지름길"
metadata/검증 = "정적 확인만 수행. Godot 엔진 및 주행검사 미실행."`);
node('페인트코어','.','Node','script = ExtResource("core")\n"최대_탄약" = 12',null,['페인트코어']);
node('지형','.','Node2D');

for (const [i,p] of polygons.entries()) {
  const xs=p.points.map(a=>a[0]), ys=p.points.map(a=>a[1]);
  const origin=[(Math.min(...xs)+Math.max(...xs))/2,(Math.min(...ys)+Math.max(...ys))/2];
  const local=p.points.map(a=>[a[0]-origin[0],a[1]-origin[1]]);
  const closed=[...local,local[0]];
  closed.forEach((pt,j)=>sub.push(`[sub_resource type="Resource" id="p${i}_${j}"]\nresource_local_to_scene = true\nscript = ExtResource("point")\nposition = ${v(pt)}`));
  sub.push(`[sub_resource type="Resource" id="a${i}"]
resource_local_to_scene = true
script = ExtResource("points")
_points = {
${closed.map((_,j)=>`${j}: SubResource("p${i}_${j}")`).join(',\n')}
}
_point_order = PackedInt32Array(${closed.map((_,j)=>j).join(', ')})
_constraints = { Vector2i(0, ${local.length}): 15 }
_next_key = ${closed.length}`);
  // 템플릿 자식은 복제하지 않는다. 정확히 맞댄 경계가 충돌 오프셋으로 벌어지지 않게 0을 쓴다.
  node(p.name,'지형',null,`position = ${v(origin)}
"시작상태" = ${p.color}
"칠하기_허용" = true
"칠하기_방식" = 0
"위치별_판정" = true
_points = SubResource("a${i}")
_meshes = Array[ExtResource("mesh")]([])
collision_size = 0.0
collision_offset = 0.0
${p.extra}`,p.color===2?'white':'black');
  node('CollisionPolygon2D',`지형/${p.name}/StaticBody2D`,null,`polygon = ${packed(local)}`);
}
node('장치','.','Node2D');
const inst=(name,id,x,y,props='')=>node(name,'장치',null,`position = Vector2(${x}, ${y})\n${props}`,id);
const lift=(name,x,top,dist,seconds)=>inst(name,'lift',x,top+16,`"크기" = Vector2(256, 32)\n"이동방향" = 1\n"이동거리" = ${dist}.0\n"왕복시간" = ${seconds}.0\n"필요횟수" = 1`);
lift('승강기_동쪽_F2',12800,2304,768,10);
lift('승강기_서쪽_F2',256,1536,768,10);
lift('승강기_중앙_F3',6336,2304,640,7);
inst('집수조_동쪽','pool',12800,3328,'"크기" = Vector2(512, 96)\n"색" = 2');
inst('집수조_서쪽','pool',256,2560,'"크기" = Vector2(512, 96)\n"색" = 2');
inst('집수조_중앙','pool',6336,3232,'"크기" = Vector2(384, 96)\n"색" = 2');
node('버튼_F1_지름길열기','장치','AnimatableBody2D',`position = Vector2(4128, 2904)
script = ExtResource("button")
"폭" = 128.0
"작동방식" = 1
"누름_가능_그룹" = PackedStringArray("player")
"대상들" = Array[NodePath]([NodePath("../../지형/F3_문")])
"대상_이동량들" = Array[Vector2]([Vector2(0, -512)])
"이동속도" = 384.0`);
inst('회전톱_F2_수로','saw',11264,3024,'"반지름" = 36.0\n"이동거리" = 384.0\n"왕복시간" = 3.0');
inst('회전톱_출구종합','saw',9472,1584,'"반지름" = 40.0\n"이동거리" = 512.0\n"왕복시간" = 4.0');
for(const [name,x,y] of [['시작',768,3072],['F1',4000,2880],['갈림길',4960,3152],['동쪽',12160,3072],['서쪽',896,2304],['상층',896,1536],['출구앞',11008,1536]])
  inst(`체크포인트_${name}`,'checkpoint',x,y);
node('출구통로','.',null,`position = Vector2(12544, 1536)
"높이" = 256.0
"깊이" = 420.0
"다음_씬" = "res://scenes/lobby/lobby.tscn"
metadata/설명 = "후속 스테이지가 지정되지 않아 독립 실행 완료 시 로비로 돌아간다."`,'exit');
node('끝도달_검사점','.','Marker2D','position = Vector2(12416, 1536)');
node('Player','.',null,'position = Vector2(768, 3072)\n"점프_높이_칸" = 10.0\n"점프_거리_칸" = 20.0','player');

const scene='[gd_scene format=3]\n\n'+Object.entries(resources).map(([id,[type,p]])=>`[ext_resource type="${type}" path="${p}" id="${id}"]`).join('\n')+'\n\n'+sub.join('\n\n')+'\n\n'+nodes.join('\n\n')+'\n';
const area = pts => pts.reduce((a,p,i)=>{const q=pts[(i+1)%pts.length];return a+p[0]*q[1]-q[0]*p[1];},0)/2;
// 분리축 검사로 볼록 지형의 내부 겹침을 찾는다. 공유 변과 꼭짓점 접촉은 허용한다.
const overlaps = (a,b) => [...a,...b].every((_,i)=>{
  const poly=i<a.length?a:b, j=i<a.length?i:i-a.length;
  const p=poly[j],q=poly[(j+1)%poly.length],axis=[q[1]-p[1],p[0]-q[0]];
  const aa=a.map(r=>r[0]*axis[0]+r[1]*axis[1]),bb=b.map(r=>r[0]*axis[0]+r[1]*axis[1]);
  return Math.min(Math.max(...aa),Math.max(...bb))-Math.max(Math.min(...aa),Math.min(...bb))>0.001;
});
const intersections=[];
for(let i=0;i<polygons.length;i++)for(let j=i+1;j<polygons.length;j++)
  if(overlaps(polygons[i].points,polygons[j].points))intersections.push([polygons[i].name,polygons[j].name]);
assert.deepEqual(intersections,[],'지형 내부 겹침');
for(const [name,[,p]] of Object.entries(resources)) assert(fs.existsSync(path.join(root,p.slice(6))),`리소스 누락: ${name}`);
for(const p of polygons){
  assert(area(p.points)>0,`시계방향 오류: ${p.name}`);
  assert(p.points.flat().every(n=>n%16===0),`격자 오류: ${p.name}`);
  assert(p.points.every((pt,i)=>Math.hypot(pt[0]-p.points[(i+1)%p.points.length][0],pt[1]-p.points[(i+1)%p.points.length][1])>=90),`짧은 변: ${p.name}`);
}
assert.equal(new Set(polygons.map(p=>p.name)).size,polygons.length);
assert.equal((scene.match(/instance=ExtResource\("exit"\)/g)||[]).length,1);
assert(fs.existsSync(path.join(root,'scenes/lobby/lobby.tscn')));
const total=polygons.reduce((n,p)=>n+area(p.points),0);
const black=polygons.filter(p=>p.color===1).reduce((n,p)=>n+area(p.points),0);
assert(black/total>=0.6 && black/total<=0.7,'지형 색 면적 비율');
const resourceIds=new Set(sub.map(s=>s.match(/id="([^"]+)"/)[1]));
for(const m of scene.matchAll(/SubResource\("([^"]+)"\)/g)) assert(resourceIds.has(m[1]),`내부 리소스 누락: ${m[1]}`);
for(const m of scene.matchAll(/ExtResource\("([^"]+)"\)/g)) assert(Object.hasOwn(resources,m[1]),`외부 리소스 누락: ${m[1]}`);
assert(scene.includes('groups=["페인트코어"]'),'월드와 HUD가 찾는 페인트코어 그룹');
assert(polygons.some(p=>p.name==='F3_문'),'버튼 NodePath 대상');
// 기본은 읽기 전용이다. 나중에 에디터로 편집한 씬을 실수로 덮어쓰지 않도록 명시적 옵션을 요구한다.
if(process.argv.includes('--write')) fs.writeFileSync(target,scene,'utf8');
else assert.equal(fs.readFileSync(target,'utf8'),scene,'씬이 좌표표와 다름 (에디터 편집 여부 확인)');
console.log(JSON.stringify({scene:path.relative(root,target),terrain:polygons.length,blackPercent:+(100*black/total).toFixed(2),whitePercent:+(100-100*black/total).toFixed(2),referenceChecks:'passed',engine:'NOT RUN'},null,2));
