"""2-2의 지정한 두 접합부만 수정한다. 기본은 검사, --apply 때만 저장한다.

원본 전체 씬을 재생성하지 않고 이름으로 찾은 SS2D 점/재질만 교체한다.
기준 외곽이 달라지면 중단하므로 나중의 에디터 편집을 조용히 덮지 않는다.
"""
import argparse
import hashlib
import math
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def resource_id(value):
    # 노드명/파일명과 달리 Godot 내부 리소스 ID는 ASCII 영숫자와 밑줄만 허용한다.
    if re.fullmatch(r'[A-Za-z0-9_]+',value):return value
    return 'joint_ascii_'+hashlib.sha256(value.encode('utf-8')).hexdigest()[:16]

def sanitize_resource_ids(text):
    ids=re.findall(r'\[(?:sub_resource|ext_resource) [^\]]*\bid="([^"]+)"',text)
    assert len({resource_id(value) for value in ids})==len(set(ids))
    for value in ids:
        safe=resource_id(value)
        if safe==value:continue
        text=text.replace('id="'+value+'"','id="'+safe+'"')
        text=text.replace('SubResource("'+value+'")','SubResource("'+safe+'")')
        text=text.replace('ExtResource("'+value+'")','ExtResource("'+safe+'")')
    return text
SCENE = ROOT / 'scenes/world_2_클로드/stage_2-2.tscn'
SCALE = .18
ORIGIN_Y = 1856 - 355 * SCALE
# 흑백 fill.png는 같은 줄눈을 공유한다. 원본 그림에서 측정한 줄눈 중심이다.
ROWS = [0, 118, 237, 355, 470, 589, 705, 821, 937, 1024]
JOINTS = [
    [0,158,364,556,720,910,1153,1350,1536],
    [0,43,248,462,635,820,1016,1254,1440,1536],
    [0,138,340,537,719,910,1114,1308,1536],
    [0,38,234,433,619,821,1009,1214,1423,1536],
    [0,132,329,538,724,917,1118,1310,1536],
    [0,35,240,436,623,818,1015,1205,1418,1536],
    [0,143,338,538,727,918,1117,1308,1536],
    [0,24,232,430,618,825,1013,1206,1408,1536],
    [0,130,326,534,716,909,1110,1307,1536],
]

def vec(text):
    return tuple(float(x) for x in text.split(','))

def compact(points):
    out=[]
    for p in points:
        p=tuple(round(v,4) for v in p)
        if out and out[-1]==p: continue
        while len(out)>1 and abs((out[-1][0]-out[-2][0])*(p[1]-out[-1][1])-(out[-1][1]-out[-2][1])*(p[0]-out[-1][0]))<1e-6:
            out.pop()
        out.append(p)
    return out

def row_at(y):
    sy=(y-ORIGIN_Y)/SCALE
    tile=math.floor(sy/1024)
    local=sy-tile*1024
    row=next(i for i in range(9) if ROWS[i]<=local<ROWS[i+1])
    return tile,row

def nearest_joint(x,y):
    _,row=row_at(y)
    tile=math.floor(x/(1536*SCALE))
    return min(((t*1536+j)*SCALE for t in range(tile-1,tile+2) for j in JOINTS[row]),key=lambda a:abs(a-x))

def ylines(lo,hi):
    return sorted(set(round(ORIGIN_Y+(t*1024+y)*SCALE,4)
        for t in range(-2,25) for y in ROWS if lo<ORIGIN_Y+(t*1024+y)*SCALE<hi))

def horizontal_path():
    # 가로는 깊이/구간 폭을 각각 바꾼다. 수직 전환도 각 줄의 실제 줄눈을 따라간다.
    levels=[ORIGIN_Y+y*SCALE for y in ROWS]
    current=1856.0
    pts=[(0,current)]
    for x,level in [(80,2),(176,5),(288,1),(400,4),(496,2),(608,5),(704,3)]:
        target=levels[level]
        stops=ylines(min(current,target),max(current,target))+[target]
        stops=sorted(stops,reverse=target<current)
        for y in stops:
            joint=nearest_joint(x,(current+y)/2)
            pts.extend([(joint,current),(joint,y)])
            current=y
    pts.append((768,1856))
    return compact(pts)

def vertical_path():
    # 양끝은 기존 접점을 보존한다. 반 장~두 장 깊이를 양방향으로 섞는다.
    bounds=ylines(3670,4110)
    pattern=[.5,1.5,2,1,-.5,-2,-1.5,-1,.5,2,1.5,-.5,-1,-2,.5,1,2,-1,-.5,1.5,1]
    pts=[(768,3584),(768,bounds[0])]
    for i,(a,b) in enumerate(zip(bounds,bounds[1:])):
        x=nearest_joint(768+pattern[i%len(pattern)]*36,(a+b)/2)
        pts.extend([(x,a),(x,b)])
    pts.extend([(768,bounds[-1]),(768,4352)])
    return compact(pts)

def parse(text):
    blocks=re.split(r'(?=\[(?:sub_resource|node) )',text)
    res={re.search(r'id="([^"]+)"',b)[1]:b for b in blocks if b.startswith('[sub_resource')}
    nodes={}
    for b in blocks:
        if not b.startswith('[node') or 'parent="지형"' not in b.splitlines()[0]:continue
        name=re.search(r'name="([^"]+)"',b)[1]
        pos=vec(re.search(r'position = Vector2\(([^)]+)\)',b)[1])
        arr=res[re.search(r'_points = SubResource\("([^"]+)"',b)[1]]
        points=[]
        for rid in re.findall(r'\d+: SubResource\("([^"]+)"',arr):
            p=vec(re.search(r'position = Vector2\(([^)]+)\)',res[rid])[1])
            points.append((round(p[0]+pos[0],4),round(p[1]+pos[1],4)))
        nodes[name]=(b,pos,points)
    return nodes

def splice(points,a,b,path):
    # 공통 경계는 한 번 생성하고 반대쪽에는 역순으로 넣는다.
    for i in range(len(points)-1):
        p,q=points[i:i+2]
        if p[1]==q[1]==a[1]==b[1] and min(p[0],q[0])<=min(a[0],b[0]) and max(p[0],q[0])>=max(a[0],b[0]):
            use=path if q[0]>p[0] else list(reversed(path))
        elif p[0]==q[0]==a[0]==b[0] and min(p[1],q[1])<=min(a[1],b[1]) and max(p[1],q[1])>=max(a[1],b[1]):
            use=path if q[1]>p[1] else list(reversed(path))
        else:continue
        return compact(points[:i+1]+use+points[i+1:])
    raise ValueError('기존 공유 경계가 달라졌습니다. 에디터 변경을 먼저 검토하세요.')

def fmt(n):return f'{n:.4f}'.rstrip('0').rstrip('.') if n else '0'
def pair(p):return ', '.join(map(fmt,p))

def make_resources(name,points,pos):
    local=[(p[0]-pos[0],p[1]-pos[1]) for p in points]
    out=[]
    for i,p in enumerate(local):
        out.append(f'[sub_resource type="Resource" id="joint_{name}_{i}"]\nresource_local_to_scene = true\nscript = ExtResource("4_7je74")\nposition = Vector2({pair(p)})\n')
    refs=',\n'.join(f'{i}: SubResource("joint_{name}_{i}")' for i in range(len(local)))
    order=', '.join(map(str,range(len(local))))
    out.append(f'[sub_resource type="Resource" id="joint_{name}_array"]\nresource_local_to_scene = true\nscript = ExtResource("5_57mdw")\n_points = {{\n{refs}\n}}\n_point_order = PackedInt32Array({order})\n_constraints = {{Vector2i(0, {len(local)-1}): 15}}\n_next_key = {len(local)}\n')
    return '\n'.join(out),local

def inside(p,poly):
    x,y=p; result=False
    for a,b in zip(poly,poly[1:]):
        if (a[1]>y)!=(b[1]>y) and x<(b[0]-a[0])*(y-a[1])/(b[1]-a[1])+a[0]:result=not result
    return result

def verify(before,after,pairs):
    count=0
    for names,path in pairs:
        old=[before[n][2] for n in names]; new=[after[n][2] for n in names]
        for poly in new:
            assert poly[0]==poly[-1]
            assert len(poly)-1<=64,(names,len(poly))
        # 실제 저장 점에서 공유선의 양옆을 촘촘히 검사: 구멍, 겹침, 바깥 윤곽 변화.
        for a,b in zip(path,path[1:]):
            dx,dy=b[0]-a[0],b[1]-a[1]; length=math.hypot(dx,dy)
            for j in range(1,8):
                for side in [-.25,.25]:
                    p=(a[0]+dx*j/8-dy/length*side,a[1]+dy*j/8+dx/length*side)
                    assert sum(inside(p,poly) for poly in new)==1,(names,p)
                    assert any(inside(p,poly) for poly in old),(names,'외곽 변경',p)
                    count+=1
    return count

def main():
    apply=argparse.ArgumentParser();apply.add_argument('--apply',action='store_true');args=apply.parse_args()
    text=SCENE.read_text(encoding='utf-8')
    nodes=parse(text)
    if 'joint_좌상_덩어리_array' in text or resource_id('joint_좌상_덩어리_array') in text:
        print('Already applied; no rewrite.');return
    paths=[(('좌상_덩어리','탑_왼벽'),horizontal_path()),(('좌하_채움','탑_바닥'),vertical_path())]
    changed={}
    for names,path in paths:
        for name in names:
            b,pos,points=nodes[name]
            changed[name]=(b,pos,splice(points,path[0],path[-1],path))
    total=verify(nodes,{**nodes,**changed},paths)
    print('Boundary samples:',total,'PASS')
    for name,(_,_,points) in changed.items(): print(name,'edges',len(points)-1)
    if not args.apply:return
    # 원본 재질은 건드리지 않는다. 2-2 전용 짝에 같은 월드 UV 기준을 저장한다.
    material_dir=ROOT/'assets/textures/smartshape/sewer_masonry_v02'
    for color in ['black','white']:
        material=(material_dir/f'땅_{color}.tres').read_text(encoding='utf-8')
        material=re.sub(r' uid="[^"]+"','',material,count=1)
        material += f'fill_texture_absolute_position = true\nfill_texture_offset = Vector2(0, {fmt(ORIGIN_Y)})\n'
        (material_dir/f'맞물림_{color}.tres').write_text(material,encoding='utf-8')
    extra=''
    for name,(block,pos,points) in changed.items():
        resources,local=make_resources(name,points,pos);extra+=resources+'\n'
        replacement=re.sub(r'_points = SubResource\("[^"]+"\)',f'_points = SubResource("joint_{name}_array")',block)
        replacement+='\n'
        text=text.replace(block,replacement)
    text=text.replace('[node name="stage_2-2"',extra+'[node name="stage_2-2"',1)
    text=text.replace('res://scenes/집/스마트 매쉬 assets/WALL_벽체/TEMPLATE_WALL_SOLID.tscn','res://scenes/지형/하수도/하수도_기본지형_검정.tscn')
    text=text.replace('res://scenes/집/스마트 매쉬 assets/WALL_벽체/TEMPLATE_WALL_SOLID_WHITE.tscn','res://scenes/지형/하수도/하수도_기본지형_흰색.tscn')
    ext=''.join(f'[ext_resource type="Resource" path="res://assets/textures/smartshape/sewer_masonry_v02/맞물림_{c}.tres" id="joint_{c}"]\n' for c in ['black','white'])
    text=text.replace('[sub_resource',ext+'\n[sub_resource',1)
    # 저장된 콜리전도 실제 점과 맞춰 편집기/런타임의 첫 프레임 차이를 없앤다.
    for name,(block,pos,points) in parse(text).items():
        color='white' if '6_6fbqg' in block else 'black'
        local=[(p[0]-pos[0],p[1]-pos[1]) for p in points[:-1]]
        replacement=block.rstrip()+f'\nshape_material = ExtResource("joint_{color}")\n'
        if name=='L3_유령발판':replacement+='"시작상태" = 0\n'
        replacement+=f'\n[node name="CollisionPolygon2D" parent="지형/{name}/StaticBody2D" index="0"]\npolygon = PackedVector2Array({", ".join(pair(p) for p in local)})\n\n'
        text=text.replace(block,replacement)
    SCENE.write_text(sanitize_resource_ids(text),encoding='utf-8')
    print('Saved',SCENE)

if __name__=='__main__':main()
