"""호퍼 유입 배치 수정. 실제 판정/통행은 엔진에서 별도 확인한다."""
from pathlib import Path
import re,json,argparse
ROOT=Path(__file__).resolve().parents[1]
# 요청한 스테이지만 수정하여 다른 맵의 편집 중 배치를 건드리지 않는다.
parser=argparse.ArgumentParser()
parser.add_argument('--stages', nargs='+', type=int)
args=parser.parse_args()
report=[]
for p in (ROOT/'scenes/world_2_클로드').glob('stage*.tscn'):
 if args.stages and p.stem not in {f'stage_2-{i}' for i in args.stages}:continue
 s=p.read_text(encoding='utf-8');res={i:path for path,i in re.findall(r'\[ext_resource[^\n]*path="([^"]+)"[^\n]*id="([^"]+)"',s)};nodes=[]
 for m in re.finditer(r'^\[node ([^\n]+)\]\n(.*?)(?=^\[|\Z)',s,re.M|re.S):
  h,b=m.groups();i=re.search(r'instance=ExtResource\("([^"]+)"\)',h)
  if not i:continue
  kind=Path(res.get(i[1],'')).stem
  if kind not in ['유체','호퍼']:continue
  def vec(key,default):
   v=re.search(r'^"?'+key+r'"? = Vector2\(([^,]+), ([^)]+)\)',b,re.M);return tuple(map(float,v.groups())) if v else default
  def num(key,default):
   v=re.search(r'^"?'+key+r'"? = (-?[\d.]+)',b,re.M);return float(v[1]) if v else default
  nodes.append(dict(name=re.search('name="([^"]+)"',h)[1],kind=kind,pos=vec('position',(0,0)),size=vec('크기',(56,300)),w=num('폭',150),ht=num('높이',62),b=b,h=h,block=m[0]))
 changes={};assigned=set()
 def put(b,k,v):
  pat=r'^"?'+re.escape(k)+r'"? = [^\n]*'
  return re.sub(pat,'"'+k+'" = '+v,b,flags=re.M) if re.search(pat,b,re.M) else b.rstrip()+'\n"'+k+'" = '+v+'\n\n'
 for h in [n for n in nodes if n['kind']=='호퍼']:
  x,y=h['pos'];top=y-h['ht'];near=[]
  for w in [n for n in nodes if n['kind']=='유체']:
   wx,wy=w['pos'];end=wy+w['size'][1]
   if abs(wx-x)<h['w']/2+w['size'][0]/2 and wy<top and end>top-84 and end<y+40:near.append(w)
  if not near:continue
  # 꺼진 공급도 포함해서 두 줄기 혼합의 한쪽을 가운데로 옮기지 않는다.
  for w in near:
   assert w['name'] not in assigned,(p,w['name'])
   assigned.add(w['name']);wx,wy=w['pos'];newx=x if len(near)==1 else wx
   length=top+12-wy
   b=put(w['b'],'position',f'Vector2({newx:g}, {wy:g})')
   b=put(b,'크기',f'Vector2({w["size"][0]:g}, {length:g})');b=put(b,'호퍼_유입','true')
   changes[w['block']]='[node '+w['h']+']\n'+b
   report.append(dict(scene=p.name,hopper=h['name'],water=w['name'],inlets=len(near),old_x=wx,new_x=newx,old_length=w['size'][1],new_length=length,mouth_y=top))
  # 물 끝을 앞쪽 테두리로 가려서 호퍼 몸통 위에 물이 덧그려지지 않게 한다.
  b=put(h['b'],'z_index','3')
  # 에디터/실행에서 기존 길이 오버라이드가 수정값을 다시 줄이지 않게 한다.
  if re.search(r'^"?입구_물줄기_길이"? =',b,re.M):b=put(b,'입구_물줄기_길이','-1.0')
  changes[h['block']]='[node '+h['h']+']\n'+b
 for old,new in changes.items():s=s.replace(old,new,1)
 if s!=p.read_text(encoding='utf-8'):p.write_text(s,encoding='utf-8')
# 최초 이동 기록은 재실행으로 덮어쓰지 않는다.
audit=ROOT/'docs/호퍼유입_정렬_2026-09-22.json'
if not audit.exists():
 audit.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print('inlets',len(report),'hoppers',len({(r['scene'],r['hopper']) for r in report}),'centered',sum(r['old_x']!=r['new_x'] for r in report))
assert all(r['new_length']>0 for r in report)
assert all(r['inlets']==1 or r['new_x']==r['old_x'] for r in report)
print('PASS: dual-inlet x positions preserved; all lengths positive')
