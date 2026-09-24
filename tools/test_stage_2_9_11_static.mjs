// Godot를 실행하지 않는 저장 씬 검사. 실제 점프/색 판정 성공을 대신하지 않는다.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import {checkResourceOrder} from './check_tscn_resource_order.mjs';
export function scene(n){
  const text=fs.readFileSync(`scenes/world_2_클로드/stage_2-${n}.tscn`,'utf8');
  const blocks=[...text.matchAll(/^\[node [^\n]+\]\r?\n[\s\S]*?(?=^\[|$(?![\s\S]))/gm)].map(m=>m[0]);
  const node=name=>{const found=blocks.filter(b=>b.startsWith(`[node name="${name}" `));assert.equal(found.length,1,name);return found[0];};
  const vector=(b,k='position')=>{const m=b.match(new RegExp(`(?:^|\\n)${k} = Vector2\\(([-.\\d]+), ([-.\\d]+)\\)`));assert(m,k);return m.slice(1).map(Number);};
  return {text,blocks,node,vector};
}
const stages=process.argv.slice(2).length?process.argv.slice(2):['10'];
for(const n of stages){
  const {text,blocks,node,vector}=scene(n);
  checkResourceOrder(text,`stage_2-${n}`);
  const root=node(`stage_2-${n}`);
  assert(root.includes('"카메라_줌" = 1.0'),'명시 줌');
  assert(root.includes('"치명_낙하거리" = 1500.0'),'명시 낙하');
  assert.deepEqual(vector(root,'"시작_위치"'),vector(node('Player')),'스폰 일치');
  const paths=blocks.map(b=>{const h=b.split('\n')[0];return (h.match(/parent="([^"]+)"/)?.[1]??'ROOT')+'/'+h.match(/name="([^"]+)"/)[1];});
  assert.equal(new Set(paths).size,paths.length,'중복 노드');
  const ids=kind=>new Set([...text.matchAll(new RegExp(`^\\[${kind}_resource [^\\n]+id="([^"]+)"`,'gm'))].map(m=>m[1]));
  for(const [kind,label] of [['ext','Ext'],['sub','Sub']])for(const m of text.matchAll(new RegExp(`${label}Resource\\("([^"]+)"\\)`,'g')))assert(ids(kind).has(m[1]),m[0]);
  for(const m of text.matchAll(/^\[ext_resource .*?path="res:\/\/([^"]+)"/gm))assert(fs.existsSync(m[1]),m[1]);
  for(const m of text.matchAll(/^metadata\/([^ =]+)/gm))assert(/^[A-Za-z_]\w*$/.test(m[1]),'메타데이터 식별자');
  const fullPaths=new Set(paths.map(p=>p.replace(/^\.\//,'')));
  for(const b of blocks){
    const h=b.split('\n')[0],parent=h.match(/parent="([^"]+)"/)?.[1]??'',name=h.match(/name="([^"]+)"/)[1];
    for(const m of b.matchAll(/NodePath\("([^"]+)"\)/g)){
      const path=(parent==='.'?'':parent+'/')+name+'/'+m[1],parts=[];
      for(const part of path.split('/')){if(part==='..')parts.pop();else if(part&&part!=='.')parts.push(part);}
      assert(fullPaths.has(parts.join('/')),`장치 대상: ${path}`);
    }
  }
  if(n==='11'){
    assert(!text.includes('[node name="구역3_물길우회_출구발판'));
    assert(!text.includes('[node name="구역3_발판변색_분사기"'));
    for(let j=1;j<=2;j++)assert(node(`구역3_투명발판${j}`).includes('"무색일때_통과" = true'));
    const lever=node('구역4_폭포차단_레버');
    for(const value of ['"종류" = 1','"갈래_A" = NodePath("../구역4_폭포묶음")','"갈래_B" = NodePath("../구역4_우회배수")'])assert(lever.includes(value));
    assert(node('구역4_우회배수').includes('"켜짐" = false'));
    assert.deepEqual(vector(node('구역5_통과')),[15648,7168]);
    assert(root.includes('Rect2(15632, 7160, 32, 16)'));
    for(let j=1;j<=3;j++)assert(node(`구역5_붕괴발판${j}`).includes('script = ExtResource("crumble")'));
    assert(text.includes('path="res://scripts/스마트월드/SS2D_붕괴발판.gd"'));
    const resources=[...text.matchAll(/^\[sub_resource [^\n]+\]\r?\n[\s\S]*?(?=^\[|$(?![\s\S]))/gm)].map(m=>m[0]);
    const resource=id=>resources.find(b=>b.split('\n')[0].includes(`id="${id}"`));
    const polygon=name=>{
      const b=node(name),origin=vector(b),array=resource(b.match(/_points = SubResource\("([^"]+)"\)/)[1]);
      return [...array.matchAll(/\d+: SubResource\("([^"]+)"\)/g)].map(m=>vector(resource(m[1])).map((v,i)=>v+origin[i]));
    };
    for(const name of ['구역5_일체형_수로바닥','구역5_붕괴발판3']){
      const points=polygon(name),origin=vector(node(name));
      assert.deepEqual(points[0],points.at(-1),'닫힌 윤곽');
      const collision=blocks.find(b=>b.includes(`parent="지형/${name}/StaticBody2D"`));
      const stored=collision.match(/polygon = PackedVector2Array\(([^)]+)\)/)[1].split(',').map(Number);
      assert.deepEqual(stored,points.slice(0,-1).flatMap(p=>p.map((v,i)=>v-origin[i])),'SS2D/저장 충돌 일치');
      assert(text.includes(`[editable path="지형/${name}"]`));
    }
    assert(polygon('구역5_일체형_수로바닥').some(([x,y])=>x===15616&&y===7168));
    const intervals=[...Array(3)].map((_,i)=>{const p=polygon(`구역5_붕괴발판${i+1}`);return [Math.min(...p.map(q=>q[0])),Math.max(...p.map(q=>q[0]))];});
    assert.deepEqual(intervals,[[14592,14784],[14912,15104],[15328,15520]]);
    // 몸 폭44까지 보수적으로 더해도 2→바닥 및 1→3 직행은 점프320을 초과한다.
    assert(15616-intervals[1][1]>320+44);
    assert(intervals[2][0]-intervals[0][1]>320+44);
    for(const gap of [14592-14336,14912-14784,15328-15104,15616-15520])assert(gap+44<=320,'정규 경로 착지 폭 포함 도약거리');
    assert(4480-4096>160,'방3 물길에서 출구로 바로 상승 불가');
    assert(8704-8192>320+44,'투명2 건너뛰기 불가');
    const code=fs.readFileSync('scripts/스마트월드/SS2D_붕괴발판.gd','utf8');
    for(const snippet of ['extends "res://scripts/스마트월드/지형.gd"','_실제로_밟혔나()','_붕괴단계 = 2','set_deferred("disabled", _붕괴단계 == 2)','not _복구위치에_플레이어가_있나()','func 강제_초기화()'])assert(code.includes(snippet),'붕괴 계약 '+snippet);
  }
  if(n==='9' && text.includes('엇갈린 배수실')){
    assert.deepEqual(vector(node('Player')),[768,4096]);
    assert(node('C_배수문버튼').includes('NodePath("../../지형/E_진입수문")'));
    assert(node('E_연결버튼').includes('NodePath("../../지형/E_연결발판")'));
    assert(node('C_혼합호퍼').includes('NodePath("../D_호퍼출력")'));
    assert(text.includes('하수도_다층배경_v02.tscn'));
    assert(!text.includes('TEMPLATE_WALL_SOLID'));
  } else if(n==='9'){
    assert(root.includes('"시작_위치_방식" = 0'));
    assert.deepEqual(vector(node('Player')),[768,3072]);
    assert(node('버튼_F1_지름길열기').includes('Vector2(0, -2240)'));
    assert(2944-2240<=896,'문 지붕 수납');
    assert(!text.includes('[node name="F1_흰천장"'));
    assert(!text.includes('[node name="F3_흰천장"'));
    for(const [name,floor,bottom] of [['L1_흰천장',3072,2752],['L2_흰천장',2304,1984]]){
      assert.equal(vector(node(name))[1]+16,bottom);
      assert(floor-bottom>=320,'천장 높이');
      const collision=blocks.find(b=>b.includes(`parent="지형/${name}/StaticBody2D"`));
      assert(collision.includes('polygon = PackedVector2Array(-896, -80, 896, -80, 896, 16, -896, 16)'));
      assert(node(name).includes('_meshes = Array[ExtResource("mesh")]([])'));
    }
    for(const [name,width] of [['승강기_중앙_F3',384],['승강기_동쪽_F2',512],['승강기_서쪽_F2',512]]){
      assert(node(name).includes(`"크기" = Vector2(${width}, 32)`));
      assert(node(name).includes('"왕복시간" = 5.0'));
    }
    assert.deepEqual(vector(node('중앙_상부참')),[6336,2312]);
    for(let j=1;j<=5;j++){
      assert.deepEqual(vector(node(`중앙_상층격자${j}`)),[6208,2312-j*128]);
      assert(text.replaceAll('\r\n','\n').includes(`parent="장치/중앙_상층격자${j}"]\nshape = SubResource("shortcut_${2304-j*128}")\none_way_collision = true`));
    }
  }
  if(n==='10'){
    const departures=[12288,10112,8192,6016,3840];
    assert(!text.includes('[node name="분사기_1구역_발밑변색"'));
    for(const [i,d] of departures.entries())for(const side of ['왼쪽','오른쪽'])for(let j=1;j<=3;j++){
      const b=node(`구역${i+1}_${side}_반환발판${j}`);
      assert(b.includes('script = ExtResource("return_grate")'));
      assert(b.includes('"크기" = Vector2(192, 16)'));
      assert(b.includes(`"시작색" = ${side==='왼쪽'?1:0}`));
      assert.deepEqual(vector(b),[side==='왼쪽'?672:5472,d-768-128*j+8]);
      assert(128-16>=96+16,'머리 여유');
    }
    const code=fs.readFileSync('scripts/스마트월드/stage_2_10_반환격자.gd','utf8');
    assert(code.includes('충돌.one_way_collision = true'));
    assert(code.includes('func 강제_초기화()'));
  }
  console.log(`stage_2-${n}: PASS (정적 참조/노드/스폰/설정 및 해당 맵 회귀 조건, 엔진 미실행)`);
}
