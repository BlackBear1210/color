from pathlib import Path
import re, json
from PIL import Image,ImageDraw
import numpy as np
root=Path('.')
p=root/'scripts/스마트월드/유체_흰물v2.gd'; s=p.read_text(encoding='utf8')
s=s.replace('const WHITE_DESIGN =', '## 2-1~2-4에만 승인된 삼색 프레임을 연결해 다른 스테이지의 외관을 유지한다.\n@export var 힉스필드_삼색프레임: bool = false\nconst REFERENCE_VISUAL = preload("res://scripts/스마트월드/물_힉스필드_삼색프레임.gd")\nconst WHITE_DESIGN =',1)
s=s.replace('_white_visual = WHITE_DESIGN.instantiate()', '_white_visual = Node2D.new() if 힉스필드_삼색프레임 else WHITE_DESIGN.instantiate()\n\t\tif 힉스필드_삼색프레임:\n\t\t\t_white_visual.set_script(REFERENCE_VISUAL)',1)
if 'REFERENCE_VISUAL' not in p.read_text(encoding='utf8'):
 p.write_text(s,encoding='utf8')
# 수정 전 텍스트를 검증 자료로 보관한다. 씬 전체 재생성 대신 필요한 노드 속성만 바꾼다.
report=[]
for i in range(1,5):
 p=root/f'scenes/world_2_클로드/stage_2-{i}.tscn'; s=p.read_text(encoding='utf8')
 if '99_reference_outlet' in s:
  continue
 (root/f'docs/visual_review/water_reference_20261008/stage_2-{i}_before.tscn.txt').write_text(s,encoding='utf8')
 ids=re.findall(r'path="res://scripts/스마트월드/유체_흰물v2.gd" id="([^"]+)"',s)
 blocks=re.split(r'(?=\[node )',s); waters={}; outlets=[]
 hopper_out=set(re.findall(r'"출구_유체" = NodePath\("\.\./([^"/]+)"\)',s))
 for idx,b in enumerate(blocks):
  if any('script = ExtResource("'+id+'")' in b for id in ids):
   name=re.search(r'\[node name="([^"]+)"',b)[1]; parent=re.search(r'parent="([^"]+)"',b)[1]
   pos=re.search(r'position = Vector2\(([^)]+)\)',b)[1]
   size=tuple(map(float,re.search(r'"크기" = Vector2\(([^)]+)\)',b)[1].split(',')))
   intake='"호퍼_유입" = true' in b
   blocks[idx]=b.replace('"물줄기_v3" = true','"물줄기_v3" = true\n"힉스필드_삼색프레임" = true',1)
   waters[name]=(parent,pos,size,intake)
 seen=set()
 for name,(parent,pos,size,intake) in waters.items():
  if intake or name in hopper_out or (parent,pos) in seen: continue
  seen.add((parent,pos)); outlets.append(name)
  blocks.append(f'\n[node name="出水_{name}" type="Node2D" parent="{parent}"]\nscript = ExtResource("99_reference_outlet")\n"대상_유체" = NodePath("../{name}")\n')
 # 호퍼로 연결되는 관은 보존한다. 독립 낙수는 밸브 공급 여부와 관계없이 정면 출수구로 통일한다.
 pipeids=re.findall(r'path="res://scripts/스마트월드/하수도_주철배관.gd" id="([^"]+)"',s)
 hidden=[]
 for idx,b in enumerate(blocks):
  if not any('script = ExtResource("'+k+'")' in b for k in pipeids): continue
  end=re.search(r'"끝_장치" = NodePath\("\.\./([^"/]+)"\)',b)
  if end and end[1] in outlets:
   lines=b.splitlines(); lines.insert(1,'visible = false'); blocks[idx]='\n'.join(lines)+'\n'; hidden.append(end[1])
 s=''.join(blocks)
 s=s.replace('[ext_resource ', '[ext_resource type="Script" path="res://scripts/스마트월드/물_힉스필드_출수구.gd" id="99_reference_outlet"]\n\n[ext_resource ',1)
 p.write_text(s,encoding='utf8'); report.append({'stage':i,'water_frames':len(waters),'outlets':outlets,'hidden_independent_pipes':hidden,'preserved_hopper_outlets':sorted(hopper_out)})
# 관 속에 남은 원본 흰 물은 지우고 게임의 낙수가 덮도록 한다.
a=root/'assets/textures/obstacles/liquid/reference_20261008'
im=Image.open(a/'round_pipe.png').convert('RGBA'); d=ImageDraw.Draw(im); d.ellipse((58,55,263,263),fill=(5,5,5,255)); im.save(a/'round_pipe.png')
base=np.asarray(Image.open(a/'catch_basin.png').convert('RGBA')).copy(); h,w=base.shape[:2]
for tone in range(3):
 arr=base.copy(); yy,xx=np.mgrid[:h,:w]
 water=(xx>w*.11)&(xx<w*.89)&(yy<h*.49)&(yy>h*.23)&(arr[:,:,:3].mean(2)>145)
 if tone!=1:
  v=arr[:,:,:3].mean(2)/255; val=(.05+v*.16 if tone==0 else .34+v*.23)*255
  arr[:,:,:3][water]=np.repeat(val[:,:,None],3,axis=2)[water].astype('uint8')
 # 뒤벽 위로 올라온 원본 급수 줄은 새 급수 줄과 중복되지 않게 제거한다.
 arr[:int(h*.24),int(w*.42):int(w*.57),3]=0
 Image.fromarray(arr).save(a/f'catch_basin_{tone}.png')
if report: (root/'docs/visual_review/water_reference_20261008/application.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf8')
print(json.dumps(report,ensure_ascii=False))

# 출수구에 원본 흰 물 조각이 남지 않게 아래 입술을 실제 물에 맡긴다.
a=np.asarray(Image.open(root/"assets/textures/obstacles/liquid/reference_20261008/round_pipe.png")).copy();a[245:,102:223,3]=0;Image.fromarray(a).save(root/"assets/textures/obstacles/liquid/reference_20261008/round_pipe.png")
