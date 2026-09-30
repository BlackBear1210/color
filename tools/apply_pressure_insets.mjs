// 씬 전체를 재생성하지 않고 압력 버튼과 바로 아래의 기존 홈만 정리한다.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import {checkResourceOrder} from './check_tscn_resource_order.mjs';
const apply=process.argv.includes('--apply');
const records=[];
for(const stage of [7,8,10,11]) {
 const file=`scenes/world_2_클로드/stage_2-${stage}.tscn`;
 let text=fs.readFileSync(file,'utf8');const original=text;checkResourceOrder(text,file);
 const parts=[...text.matchAll(/^\[(sub_resource|node) ([^\n]*)\]\r?\n([^]*?)(?=^\[|(?![^]))/gm)].map(m=>({whole:m[0],kind:m[1],head:m[2],body:m[3],initialBody:m[3]}));
 const resources=new Map(parts.filter(p=>p.kind==='sub_resource').map(p=>[p.head.match(/id="([^"]+)"/)[1],p]));
 const nodes=parts.filter(p=>p.kind==='node');
 const name=p=>p.head.match(/name="([^"]+)"/)[1];
 const pos=p=>(p.body.match(/position = Vector2\(([^)]+)\)/)?.[1]??'0,0').split(',').map(Number);
 const ids=[...text.matchAll(/\[ext_resource[^\n]*path="res:\/\/scripts\/스마트월드\/압력버튼(?:_매립)?\.gd"[^\n]*id="([^"]+)"/g)].map(m=>m[1]);
 const buttons=nodes.filter(p=>ids.some(id=>p.body.includes(`script = ExtResource("${id}")`)));
 const terrains=nodes.filter(p=>p.head.includes('parent="지형"')&&/^_points =/m.test(p.body)).map(p=>{
  const resource=resources.get(p.body.match(/_points = SubResource\("([^"]+)"\)/)[1]);
  const entries=[...resource.body.matchAll(/^(\d+): SubResource\("([^"]+)"\),?/gm)].map(m=>({key:Number(m[1]),id:m[2],xy:pos(resources.get(m[2]))}));
  return {p,resource,entries,origin:pos(p)};
 });
 const matches=[];
 for(const button of buttons){
  const [x,y]=pos(button), candidates=[];
  for(const t of terrains)for(let i=0;i<t.entries.length-1;i++){
   const a=t.entries[i].xy,b=t.entries[i+1].xy;
   const top=t.origin[1]+a[1];
   if(a[1]===b[1]&&a[0]<b[0]&&x>=t.origin[0]+a[0]&&x<=t.origin[0]+b[0]&&Math.abs(y-top)<=40)candidates.push({t,i,delta:Math.abs(y-top)});
  }
  candidates.sort((a,b)=>a.delta-b.delta);assert(candidates.length, name(button));
  const match={button,...candidates[0]};matches.push(match);
 }
 // 32px 실제 홈의 두 바닥 점을 제외해 원래 보행면을 복원한다. 폐곡선 키/제약은 보존한다.
 const removed=new Map();
 for(const {t,i,button} of matches){
  const [x,y]=pos(button),a=t.entries[i],b=t.entries[i+1];
  if(Math.abs(y-(t.origin[1]+a.xy[1]))>.01)continue;
  const prev=t.entries[i-1],next=t.entries[i+2];
  assert(prev&&next&&prev.xy[0]===a.xy[0]&&next.xy[0]===b.xy[0]&&prev.xy[1]===next.xy[1]&&a.xy[1]-prev.xy[1]===32,'Expected 32px pocket');
  if(!removed.has(t))removed.set(t,new Set());removed.get(t).add(a.key).add(b.key);
 }
 for(const [t,keys] of removed){
  t.entries=t.entries.filter(e=>!keys.has(e.key));
  t.resource.body=t.resource.body.replace(/^\d+: SubResource[^\n]*\r?\n/gm,line=>keys.has(Number(line.match(/^\d+/)[0]))?'':line);
  t.resource.body=t.resource.body.replace(/_point_order = PackedInt32Array\([^)]+\)/,`_point_order = PackedInt32Array(${t.entries.map(e=>e.key).join(', ')})`);
 }
 for(const {t,button} of matches){
  const [oldx,oldy]=pos(button);
  // 마감 생성기와 동일하게 직선상의 편집 점을 묶어 실제 한 변 길이로 돌 개수를 계산한다.
  let points=t.entries.map(e=>e.xy).slice(0,-1),changed=true;
  while(changed&&points.length>3){changed=false;for(let i=0;i<points.length;i++){
   const a=points[(i+points.length-1)%points.length],b=points[i],c=points[(i+1)%points.length];
   if((b[0]-a[0])*(c[1]-b[1])===(b[1]-a[1])*(c[0]-b[0])&&((b[0]-a[0])*(c[0]-b[0])+(b[1]-a[1])*(c[1]-b[1]))>=0){points.splice(i,1);changed=true;break;}
  }}
  const edges=points.map((a,i)=>[a,points[(i+1)%points.length]]).filter(([a,b])=>a[1]===b[1]&&a[0]<b[0]&&oldx>=a[0]+t.origin[0]&&oldx<=b[0]+t.origin[0]&&Math.abs(oldy-(a[1]+t.origin[1]))<=40);
  assert.equal(edges.length,1,name(button));const [a,b]=edges[0];
  const left=t.origin[0]+a[0],len=b[0]-a[0],top=t.origin[1]+a[1];
  const count=Math.max(1,Math.floor(len/(198*.2353)+.5));assert(count>=5);
  const unit=len/count,width=unit*3;
  const index=Math.max(1,Math.min(count-4,Math.round((oldx-left)/unit-1.5)));
  const x=left+(index+1.5)*unit,y=top+24;
  const n=v=>Number(v.toFixed(6));
  button.body=button.body.replace(/position = Vector2\([^)]+\)/,`position = Vector2(${n(x)}, ${n(y)})`).replace(/"폭" = [\d.]+/,`"폭" = ${n(width)}`);
  button.body=button.body.replace(/^"높이" = .*\r?\n/gm,'').replace(/^"매립_지형" = .*\r?\n/gm,'');
  button.body=button.body.replace(/(script = ExtResource\("[^"]+"\)\r?\n)/,`$1"높이" = 24.0\n"매립_지형" = NodePath("../../지형/${name(t.p)}")\n`);
  assert(Math.abs(x-oldx)<unit);assert(Math.abs((x-width/2-left)/unit-index)<1e-8);
  records.push({stage,button:name(button),terrain:name(t.p),before:[oldx,oldy],after:[n(x),n(y)],width:n(width),stones:3,pocketRemoved:removed.has(t)});
 }
 for(const p of parts)if(p.body!==p.initialBody)text=text.replace(p.whole,p.whole.slice(0,p.whole.length-p.initialBody.length)+p.body);
 text=text.replace(/^\[ext_resource[^\n]*path="res:\/\/scripts\/스마트월드\/압력버튼\.gd"[^\n]*\]/gm,line=>line.replace(/ uid="[^"]+"/,'').replace('압력버튼.gd','압력버튼_매립.gd'));
 checkResourceOrder(text,file);
 if(apply && text!==original)fs.writeFileSync(file,text);
 else if(process.argv.includes('--check'))assert.equal(text,original,"Pending changes: "+file);
}
console.log(JSON.stringify(records,null,2));
