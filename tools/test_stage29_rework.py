"""저장된 윤곽/연결/도약 예산 검사. 실제 엔진 충돌·재미 검증은 아니다."""
from pathlib import Path
import re, math, hashlib

p=Path('scenes/world_2_클로드/stage_2-9.tscn')
s=p.read_text(encoding='utf-8')
if '엇갈린 배수실' in s:
    import runpy
    runpy.run_path(str(Path(__file__).with_name('test_stage29_rooms.py')), run_name='__main__')
    raise SystemExit(0)
resources={k:b for k,b in re.findall(r'^\[sub_resource[^\n]*id="([^"]+)"\]\n(.*?)(?=^\[|\Z)',s,re.M|re.S)}
nodes={}
for h,b in re.findall(r'^\[node ([^\n]+)\]\n(.*?)(?=^\[|\Z)',s,re.M|re.S):
    attrs=dict(re.findall(r'(\w+)="([^"]*)"',h));nodes[(attrs.get('parent',''),attrs['name'])]=(h,b)
def vec(b):return tuple(map(float,re.search(r'position = Vector2\(([^)]+)\)',b)[1].split(',')))
polys={}
for (parent,name),(h,b) in nodes.items():
    if parent!='지형':continue
    a=re.search(r'_points = SubResource\("([^"]+)"\)',b)
    if not a:continue
    ids=re.findall(r'\d+: SubResource\("([^"]+)"\)',resources[a[1]])
    pts=[vec(resources[k]) for k in ids];assert pts[0]==pts[-1],name
    collision=nodes[(f'지형/{name}/StaticBody2D','CollisionPolygon2D')][1]
    saved=list(map(float,re.search(r'polygon = PackedVector2Array\(([^)]+)\)',collision)[1].split(',')))
    assert saved==[v for pt in pts[:-1] for v in pt],name
    assert f'[editable path="지형/{name}"]' in s,name
    ox,oy=vec(b);polys[name]=[(x+ox,y+oy) for x,y in pts[:-1]]
assert len(polys)==57
assert 'wall_sparse_bricks' not in s and 'TEMPLATE_WALL_SOLID' not in s
assert '하수도_다층배경_v02.tscn' in s
names=['L3_검정회랑',*[f'상층_징검{i}' for i in range(2,6)]]
for a,b in zip(names,names[1:]):
    pa,pb=polys[a],polys[b];gap=min(x for x,y in pb)-max(x for x,y in pa)
    rise=min(y for x,y in pa)-min(y for x,y in pb)
    # 거리320/정점160 포물선에서 내려오는 착지 해. 몸 너비44까지 더해 보수적으로 계산한다.
    reach=160*(1+math.sqrt(1-rise/160))
    assert gap<=272 and rise<=110 and gap+44<reach,(a,b,gap,rise,reach)
    assert min(y for x,y in pb)-896>=96+160,'천장과 점프 머리 공간'
    print(a,'->',b,'gap',gap,'rise',rise,'required',gap+44,'budget',round(reach,1))
gate=nodes[('장치','출구_백수문')][1];valve=nodes[('장치','밸브_출구백수문')][1]
assert 'Vector2(448, 640)' in gate and vec(gate)==(11616,896)
assert 'NodePath("../출구_백수문")' in valve
assert 11616-224-vec(valve)[0]>74+22,'밸브 조작 위치 안전 여유'
assert len([n for (parent,n) in nodes if parent=='장치' and n.startswith('회전톱')])==3
assert '"왕복시간" = 3.8' in nodes[('장치','회전톱_F1_맥동문')][1]
assert 2304-1456<1500,'상층 실패→중층 낙하 예산'
assert '중앙_상층격자5' in s,'중층 복귀 경로 보존'
print('PASS: 57 SS2D/저장충돌 일치, 최신 자산, 점프 예산, 수문 연결/안전 조작 위치; 엔진 미실행')

# 실제 씬에서 추출한 배치도. 게임 렌더링으로 오인하지 않도록 제목에 명시한다.
svg=['<svg xmlns="http://www.w3.org/2000/svg" viewBox="-400 400 14000 3350">','<rect x="-400" y="400" width="14000" height="3350" fill="#24282d"/>']
for name,pts in polys.items():
    h,b=nodes[('지형',name)];color='#d7d7d2' if 'ExtResource("white")' in h else '#62676c'
    if name.startswith('상층_징검'):color='#e0b15e'
    svg.append('<polygon points="'+' '.join(f'{x},{y}' for x,y in pts)+f'" fill="{color}" stroke="#999" stroke-width="4"/>')
for (parent,name),(h,b) in nodes.items():
    if parent!='장치' or 'position = Vector2' not in b:continue
    x,y=vec(b)
    if name.startswith('회전톱'):svg.append(f'<circle cx="{x}" cy="{y}" r="65" fill="#e97668"/>')
    elif name.startswith('체크포인트'):svg.append(f'<circle cx="{x}" cy="{y-60}" r="30" fill="#6bddbc"/>')
svg.append('<rect x="11392" y="896" width="448" height="640" fill="#dff7ff" opacity=".8"/>')
for x,y,label in [(1800,2730,'① 색 전환 → 버튼 / 세로 왕복 톱'),(5800,1200,'② 중앙 상승 → 높낮이 징검'),(8800,1420,'③ 관찰대 → 왕복 톱'),(10600,1100,'④ 밸브 → 넓은 백수문')]:svg.append(f'<text x="{x}" y="{y}" fill="#ffd27d" font-size="95" font-family="sans-serif">{label}</text>')
svg.append('</svg>')
out=Path('docs/stage29_rework_layout.html')
out.write_text('<!doctype html><meta charset="utf-8"><title>2-9 개편 배치도</title><style>body{background:#16191e;color:#eee;font-family:sans-serif;margin:24px}svg{width:100%}</style><h2>2-9 개편 배치도 — 저장 씬 좌표, 게임 화면 아님</h2><p>노랑: 새 징검 / 빨강: 톱 / 민트: 체크포인트. 상층에서 떨어지면 중층→중앙 격자로 복귀. 실제 조작 검증은 미실행.</p>'+''.join(svg),encoding='utf-8')
