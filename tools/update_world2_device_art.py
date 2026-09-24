"""world_2_클로드의 장치 외관만 갱신한다. 맵 빌더를 실행하지 않는다."""
from pathlib import Path
import re,json,hashlib,argparse
ROOT=Path(__file__).resolve().parents[1]
DIR=ROOT/'scenes/world_2_클로드'
# 범위를 명시하면 해당 씬만 갱신해 다른 스테이지의 작업 내용을 보호한다.
parser=argparse.ArgumentParser()
parser.add_argument('--stages', nargs='+', type=int)
args=parser.parse_args()
TARGET={
 '호퍼':('latest_hopper_art','res://scripts/스마트월드/호퍼_주철_기존배치.gd'),
 '유체':('latest_water_art','res://scripts/스마트월드/유체_흰물v2.gd'),
 '웅덩이':('latest_pool_art','res://scripts/스마트월드/웅덩이_흰물v2.gd')}
NODE=re.compile(r'^\[node ([^\n]+)\]\n(.*?)(?=^\[|\Z)',re.M|re.S)
report=[]
for p in sorted(DIR.glob('stage*.tscn')):
 if args.stages and p.stem not in {f'stage_2-{i}' for i in args.stages}:continue
 old=p.read_text(encoding='utf-8');s=old
 res={i:path for path,i in re.findall(r'\[ext_resource[^\n]*path="([^"]+)"[^\n]*id="([^"]+)"',s)}
 added=[];changes=[];counts={};valves=[]
 def node_edit(m):
  h,b=m.groups();inst=re.search(r'instance=ExtResource\("([^"]+)"\)',h)
  if not inst:return m[0]
  path=res.get(inst[1],'');kind=Path(path).stem
  if kind=='제어레버':
   valves.append({'name':re.search('name="([^"]+)"',h)[1],'circular':not bool(re.search(r'^"?종류"? = 1$',b,re.M))})
   return m[0]
  if kind not in TARGET:return m[0]
  counts[kind]=counts.get(kind,0)+1
  ident,target=TARGET[kind]
  script=re.search(r'^script = ExtResource\("([^"]+)"\)\n',b,re.M)
  if script:
   if res.get(script[1])==target:return m[0]
   # 알 수 없는 커스텀 동작을 덮어쓰지 않고 중단한다.
   assert res.get(script[1])==f'res://scripts/스마트월드/{kind}.gd',(p, h, res.get(script[1]))
  found=next((i for i,v in res.items() if v==target),None)
  if found:ident=found
  elif ident not in res:
   res[ident]=target;added.append(f'[ext_resource type="Script" path="{target}" id="{ident}"]\n')
  else:assert res[ident]==target
  new_b=re.sub(r'^script = ExtResource\("[^"]+"\)\n',f'script = ExtResource("{ident}")\n',b,flags=re.M) if script else f'script = ExtResource("{ident}")\n'+b
  changes.append((m[0],'[node '+h+']\n'+new_b))
  return '[node '+h+']\n'+new_b
 s=NODE.sub(node_edit,s)
 if added:
  first=re.search(r'^\[(?:sub_resource|node) ',s,re.M).start()
  s=s[:first]+''.join(added)+'\n'+s[first:]
  # format3의 load_steps가 있으면 새 외부 리소스 개수만 반영한다.
  s=re.sub(r'load_steps=(\d+)',lambda m:'load_steps='+str(int(m[1])+len(added)),s,count=1)
 # 역변환하여 위치/크기/연결/색/속도 등 어떤 기존 내용도 바뀌지 않았음을 검증한다.
 restored=s
 for _,new in changes:assert restored.count(new)==1
 for prev,new in changes:restored=restored.replace(new,prev,1)
 if added:
  restored=restored.replace(''.join(added)+'\n','',1)
  restored=re.sub(r'load_steps=(\d+)',lambda m:'load_steps='+str(int(m[1])-len(added)),restored,count=1)
 assert restored==old,p
 if s!=old:p.write_text(s,encoding='utf-8')
 report.append({'scene':p.name,'counts':counts,'updated':len(changes),'valves':valves,'preserved_content_sha256':hashlib.sha256(old.encode()).hexdigest()})
 # 편집된 장치 자식의 별도 그림은 숨겨진 구형 아트가 다시 나타나지 않는지 수동 검토용으로 보고한다.
 for m in NODE.finditer(s):
  if ('texture = ' in m[2] or 'sprite_frames = ' in m[2]) and any(w in m[1] for w in ['물','호퍼','레버','밸브']):print('REVIEW child art',p.name,m[1])
audit=ROOT/'docs/장치외관_일괄교체_2026-09-22.json'
if any(x['updated'] for x in report) or not audit.exists():
 audit.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps([{'scene':x['scene'],'counts':x['counts'],'updated':x['updated'],'circular_valves':sum(v['circular'] for v in x['valves'])} for x in report],ensure_ascii=False))
