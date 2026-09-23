"""2-9 저장 씬의 지정 구간만 개편. Godot/전체 맵 빌더를 실행하지 않는다."""
from pathlib import Path
import re

P=Path('scenes/world_2_클로드/stage_2-9.tscn')
s=P.read_text(encoding='utf-8')
if '엇갈린 배수실' in s:
    raise SystemExit('새 방 연결형 맵에는 이전 3층 개편 도구를 적용하지 않습니다.')
if 'name="상층_징검2"' in s:
    print('Already revised; no changes')
    raise SystemExit(0)
NODE=re.compile(r'^\[node ([^\n]+)\]\n(.*?)(?=^\[|\Z)',re.M|re.S)
resources={k:b for k,b in re.findall(r'^\[sub_resource[^\n]*id="([^"]+)"\]\n(.*?)(?=^\[|\Z)',s,re.M|re.S)}
def vec(b):return tuple(map(float,re.search(r'position = Vector2\(([^)]+)\)',b)[1].split(',')))
def block(name):return next(m for m in NODE.finditer(s) if m[1].startswith(f'name="{name}" '))
def put(b,k,v):
    pat=r'^"?'+re.escape(k)+r'"? = [^\n]*'
    return re.sub(pat,k+' = '+v,b,flags=re.M) if re.search(pat,b,re.M) else b.rstrip()+'\n'+k+' = '+v+'\n\n'
def edit(name,k,v):
    global s
    m=block(name);s=s[:m.start()]+'[node '+m[1]+']\n'+put(m[2],k,v)+s[m.end():]
extras=[];subextras=[];nodes=[]
def ext(kind,path,key):extras.append(f'[ext_resource type="{kind}" path="res://{path}" id="{key}"]\n')
ext('PackedScene','scenes/지형/하수도/하수도_공중선반_검정.tscn','rev_ledge')
ext('PackedScene','scenes/집/스마트월드_장애물/유체.tscn','rev_water')
ext('Script','scripts/스마트월드/유체_흰물v2.gd','rev_water_art')
ext('PackedScene','scenes/집/스마트월드_장애물/제어레버.tscn','rev_valve')
ext('PackedScene','scenes/배경/하수도_다층배경_v02.tscn','rev_background')
nodes.append('[node name="하수도배경" parent="." instance=ExtResource("rev_background")]\n\n')
# 외곽/충돌은 유지하고 구형 프리팹과 캐시만 최신 SS2D 마감으로 교체한다.
s=s.replace('scenes/집/스마트 매쉬 assets/WALL_벽체/TEMPLATE_WALL_SOLID.tscn','scenes/지형/하수도/하수도_기본지형_검정.tscn')
s=s.replace('scenes/집/스마트 매쉬 assets/WALL_벽체/TEMPLATE_WALL_SOLID_WHITE.tscn','scenes/지형/하수도/하수도_기본지형_흰색.tscn')
terrain=[]
for m in list(NODE.finditer(s)):
    h,b=m.groups()
    if 'parent="지형"' not in h or not re.search(r'instance=ExtResource\("(?:black|white)"\)',h):continue
    name=re.search(r'name="([^"]+)"',h)[1];origin=vec(b)
    a=re.search(r'_points = SubResource\("([^"]+)"\)',b)[1]
    ids=re.findall(r'\d+: SubResource\("([^"]+)"\)',resources[a])
    pts=[vec(resources[k]) for k in ids]
    terrain.append((name,origin,pts,ids))
    edit(name,'_meshes','Array[ExtResource("mesh")]([])')
    edit(name,'cached_draw_mode','1')
    # 최신 프리팹의 기본 충돌이 남지 않도록 각 씬 윤곽을 저장 충돌에 명시한다.
    poly=', '.join(f'{v:g}' for p in pts[:-1] for v in p)
    header=f'[node name="CollisionPolygon2D" parent="지형/{name}/StaticBody2D"'
    existing=next((q for q in NODE.finditer(s) if q[0].startswith(header)),None)
    if existing:
        b2=put(existing[2],'polygon',f'PackedVector2Array({poly})')
        s=s[:existing.start()]+'[node '+existing[1]+']\n'+b2+s[existing.end():]
    else:nodes.append(header+']\npolygon = PackedVector2Array('+poly+')\n\n')
    if f'[editable path="지형/{name}"]' not in s:s+=f'\n[editable path="지형/{name}"]\n'
# 상층 긴 평지의 시작만 남기고 나머지는 높낮이 있는 독립 선반으로 바꾼다.
name='L3_검정회랑';_,origin,pts,ids=next(t for t in terrain if t[0]==name)
new=[(6272,1536),(6656,1536),(6656,1728),(6272,1728),(6272,1536)]
for ident,(x,y) in zip(ids,new):
    pat=r'(\[sub_resource[^\n]*id="'+re.escape(ident)+r'"\]\n.*?position = )Vector2\([^)]+\)'
    s=re.sub(pat,lambda m:m[1]+f'Vector2({x-origin[0]:g}, {y-origin[1]:g})',s,count=1,flags=re.S)
poly=', '.join(f'{v:g}' for x,y in new[:-1] for v in (x-origin[0],y-origin[1]))
for i,b in enumerate(nodes):
    if f'parent="지형/{name}/StaticBody2D"' in b:nodes[i]=re.sub(r'polygon = .*',f'polygon = PackedVector2Array({poly})',b)
def ledge(name,x,y,w):
    # 얇은 상면과 비대칭 밑면을 써 벽 블록을 잘라 붙인 느낌을 줄인다.
    pts=[(0,0),(w,0),(w,16),(w-24,48),(w*0.625,40),(w*0.375,56),(24,40),(0,16),(0,0)]
    key='rev_'+str(len(subextras))
    for i,(px,py) in enumerate(pts):subextras.append(f'[sub_resource type="Resource" id="{key}_p{i}"]\nresource_local_to_scene = true\nscript = ExtResource("point")\nposition = Vector2({px:g}, {py:g})\n\n')
    subextras.append(f'[sub_resource type="Resource" id="{key}_points"]\nresource_local_to_scene = true\nscript = ExtResource("points")\n_points = {{\n'+',\n'.join(f'{i}: SubResource("{key}_p{i}")' for i in range(len(pts)))+'\n}\n_point_order = PackedInt32Array('+', '.join(map(str,range(len(pts))))+f')\n_constraints = {{Vector2i(0, {len(pts)-1}): 15}}\n_next_key = {len(pts)}\n\n')
    nodes.append(f'[node name="{name}" parent="지형" instance=ExtResource("rev_ledge")]\nposition = Vector2({x}, {y})\n_points = SubResource("{key}_points")\n_meshes = Array[ExtResource("mesh")]([])\n\n[node name="CollisionPolygon2D" parent="지형/{name}/StaticBody2D"]\npolygon = PackedVector2Array('+', '.join(f'{v:g}' for p in pts[:-1] for v in p)+')\n\n')
    return f'[editable path="지형/{name}"]\n'
for name,x,y,w in [('상층_징검2',6848,1456,192),('상층_징검3',7232,1536,256),('상층_징검4',7680,1456,224),('상층_징검5',8064,1536,128),('톱_서쪽관찰대',8896,1552,192),('톱_동쪽관찰대',9920,1552,192)]:s+='\n'+ledge(name,x,y,w)
def device(name,inst,body):nodes.append(f'[node name="{name}" parent="장치" instance=ExtResource("{inst}")]\n'+body+'\n\n')
device('회전톱_F1_맥동문','saw','position = Vector2(3648, 2768)\n"반지름" = 32.0\n"이동거리" = 224.0\n"이동방향" = 1\n"왕복시간" = 3.8\neditor_description = "검정 방에서 위로 물러나는 톱을 보고 통과. x3424와 x3872는 대기 자리."')
device('체크포인트_중앙상층','checkpoint','position = Vector2(6432, 1536)')
device('체크포인트_톱앞','checkpoint','position = Vector2(8832, 1632)')
device('출구_백수문','rev_water','position = Vector2(11616, 896)\nscript = ExtResource("rev_water_art")\n"크기" = Vector2(448, 640)\n"색" = 1\n"흐름속도" = 250.0\neditor_description = "천장부터 바닥까지 넓은 백수문. 단순 점프 중 색 2회 전환으로 넘지 못하는 폭. 바닥 도색 우회는 기존 게임 규칙대로 허용."')
device('밸브_출구백수문','rev_valve','position = Vector2(11072, 1504)\n"대상_유체" = NodePath("../출구_백수문")\neditor_description = "물 앞 안전한 검정 준비 공간에서 E로 수문을 잠근다."')
# 새 선언은 반드시 노드보다 먼저 배치한다. editable 뒤에 노드를 두지 않는다.
first=re.search(r'^\[sub_resource ',s,re.M).start();s=s[:first]+''.join(extras)+'\n'+s[first:]
first=re.search(r'^\[node ',s,re.M).start();s=s[:first]+''.join(subextras)+s[first:]
first=re.search(r'^\[editable ',s,re.M).start();s=s[:first]+''.join(nodes)+s[first:]
# 메시에만 쓰이던 구형 텍스처/캐시 리소스는 참조 그래프에서 제거한다.
parts=list(re.finditer(r'^\[(ext|sub)_resource [^\n]+id="([^"]+)"\]\n.*?(?=^\[|\Z)',s,re.M|re.S))
lookup={(m[1],m[2]):m for m in parts};live=set();todo=[]
def refs(t):return [('ext' if k=='Ext' else 'sub',v) for k,v in re.findall(r'(Ext|Sub)Resource\("([^"]+)"\)',t)]
todo=refs(s[re.search(r'^\[node ',s,re.M).start():])
while todo:
    key=todo.pop()
    if key in live:continue
    live.add(key)
    if key in lookup:todo.extend(refs(lookup[key][0]))
for m in reversed(parts):
    if (m[1],m[2]) not in live:s=s[:m.start()]+s[m.end():]
P.write_text(s,encoding='utf-8')
print('Updated terrain:',len(terrain),'new ledges: 6; new saw: 1; gate + valve; checkpoints: 2')
