"""호퍼 연결부를 보존하고 독립 낙수의 출수 구조를 정면 배관/물받이로 통일한다."""
from pathlib import Path
import re,json
root=Path(__file__).resolve().parents[1]
report=[]
for stage in range(1,5):
 path=root/f'scenes/world_2_클로드/stage_2-{stage}.tscn';src=path.read_text(encoding='utf8');blocks=re.split(r'(?=\[node )',src)
 waterids=re.findall(r'path="res://scripts/스마트월드/유체_흰물v2.gd" id="([^"]+)"',src)
 pipeids=re.findall(r'path="res://scripts/스마트월드/하수도_주철배관.gd" id="([^"]+)"',src)
 exits=set(re.findall(r'"출구_유체" = NodePath\("\.\./([^"/]+)"\)',src));waters={};groups={}
 for b in blocks:
  if any(f'script = ExtResource("{id}")' in b for id in waterids):
   name=re.search(r'\[node name="([^"]+)"',b)[1];parent=re.search(r'parent="([^"]+)"',b)[1]
   pos=re.search(r'position = Vector2\(([^)]+)\)',b)[1];width=float(re.search(r'"크기" = Vector2\(([^)]+)\)',b)[1].split(',')[0])
   hopper='"호퍼_유입" = true' in b or name in exits
   waters[name]=(parent,pos,width,hopper)
   if not hopper:groups[(parent,pos)]=width
 outlets={}
 for b in blocks:
  if 'script = ExtResource("99_reference_outlet")' in b:
   target=re.search(r'"대상_유체" = NodePath\("\.\./([^"/]+)"\)',b)[1]
   parent,pos,width,hopper=waters[target]
   assert not hopper, (stage,target,'hopper must have no round outlet')
   outlets[(parent,pos)]=('basin' if width>=160 else 'round')
 assert set(groups)==set(outlets), (stage,'missing independent outlet')
 hidden=[];preserved=[];changed=[]
 for i,b in enumerate(blocks):
  if not any(f'script = ExtResource("{id}")' in b for id in pipeids):continue
  name=re.search(r'\[node name="([^"]+)"',b)[1];end=re.search(r'"끝_장치" = NodePath\("\.\./([^"/]+)"\)',b)
  if not end or end[1] not in waters:continue
  if waters[end[1]][3]:
   preserved.append(name)
   assert 'visible = false' not in b, (stage,name,'hopper pipe unexpectedly hidden')
  else:
   hidden.append(name)
   # 밸브에서 시작하더라도 호퍼로 가지 않는 기존 관은 정면 출수구로 교체한다. 판정/연결은 유지한다.
   if 'visible = false' not in b:
    blocks[i]=b.replace('\n','\nvisible = false\n',1);changed.append(name)
 result=''.join(blocks)
 if result!=src:path.write_text(result,encoding='utf8')
 report.append({'stage':stage,'round':list(outlets.values()).count('round'),'basins':list(outlets.values()).count('basin'),'hidden_non_hopper_pipes':hidden,'preserved_hopper_pipes':preserved,'changed':changed})
review=root/'docs/visual_review/water_reference_20261008'
(review/'outlet_policy.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf8')
print(json.dumps(report,ensure_ascii=False))
