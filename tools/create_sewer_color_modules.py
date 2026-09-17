"""새 모듈만 생성한다. 기존 스테이지/빌더는 수정하지 않는다. 줄눈 좌표는 기존 키트 공유."""
import re
from pathlib import Path
import apply_stage22_masonry_joint as kit

ROOT = kit.ROOT
DEST = ROOT/'scenes/지형/하수도/색조합'
MAT = ROOT/'assets/textures/smartshape/sewer_masonry_v02'
kit.ORIGIN_Y = 0
W, H = 828, 552.96

def scene(name, polygons, colors, inlays=None):
    header = '[gd_scene format=3]\n'
    script = '하수도_내부벽돌' if inlays else '하수도_자연발판'
    header += f'[ext_resource type="Script" path="res://scripts/스마트월드/{script}.gd" id="shape"]\n'
    for rid, path in [('4_7je74','point'), ('5_57mdw','point_array')]:
        header += f'[ext_resource type="Script" path="res://addons/rmsmartshape/shapes/{path}.gd" id="{rid}"]\n'
    resources, nodes = '', f'[node name="{name}" type="Node2D"]\n'
    for i,(poly,color) in enumerate(zip(polygons,colors)):
        # 각 지형은 동일한 로컬 원점을 공유하여 줄눈 위상이 이어진다.
        matname = f'내부무늬_{color}' if inlays else f'땅_{color}'
        header += f'[ext_resource type="Resource" path="res://assets/textures/smartshape/sewer_masonry_v02/{matname}.tres" id="m{i}"]\n'
        resource, _ = kit.make_resources(str(i),poly,(0,0)); resources += resource+'\n'
        n=f'벽_{i}'
        nodes += f'\n[node name="{n}" type="Node2D" parent="."]\nscript = ExtResource("shape")\ntexture_repeat = 2\ntexture_filter = 2\n"땅지형" = true\n"시작상태" = {0 if inlays else (1 if color=="black" else 2)}\n"위치별_판정" = true\n_points = SubResource("joint_{i}_array")\nshape_material = ExtResource("m{i}")\ncollision_update_mode = 2\ncollision_size = 0.0\ncollision_polygon_node_path = NodePath("StaticBody2D/CollisionPolygon2D")\n'
        if inlays:
            rects=', '.join('Rect2('+kit.pair((x,y))+', '+kit.pair((r-x,b-y))+')' for x,y,r,b in inlays)
            nodes += f'"내부_바탕흰색" = {str(color=="white").lower()}\n"내부_벽돌영역" = Array[Rect2]([{rects}])\n'
        nodes += f'[node name="StaticBody2D" type="StaticBody2D" parent="{n}"]\n[node name="CollisionPolygon2D" type="CollisionPolygon2D" parent="{n}/StaticBody2D"]\npolygon = PackedVector2Array('+', '.join(kit.pair(p) for p in poly[:-1])+')\n'
    (DEST/f'{name}.tscn').write_text(header+resources+nodes,encoding='utf-8')

def vertical(center,phase):
    ys=[0]+kit.ylines(0,H)+[H]
    pattern=[.5,2,-1,-.5,1.5,-2,1,-1.5,2,.5,-1]
    pts=[(center,0)]
    for i,(a,b) in enumerate(zip(ys,ys[1:])):
        x=kit.nearest_joint(center+36*pattern[(i+phase)%len(pattern)],(a+b)/2)
        pts += [(x,a),(x,b)]
    pts += [(center,H)]
    return kit.compact(pts)

def horizontal(center,phase):
    levels=[0]+kit.ylines(0,H)+[H]
    offsets=[1,-2,2,0,-1,2,-2,1]
    current=center; pts=[(0,current)]
    for i,x in enumerate(range(90,800,90)):
        target=min(levels,key=lambda y:abs(y-(center+21*offsets[(i+phase)%8])))
        for y in sorted(kit.ylines(min(current,target),max(current,target))+[target],reverse=target<current):
            joint=kit.nearest_joint(x,(current+y)/2)
            pts += [(joint,current),(joint,y)];current=y
    pts += [(W,current),(W,center)]
    return kit.compact(pts)

def validate(polys):
    # 전체 면적의 빈틈/겹침과 반대색 영역의 독립성을 확인한다.
    count=0
    for y in range(3,552,7):
        for x in range(3,828,7):
            assert sum(kit.inside((x+.123,y+.321),p) for p in polys)==1,(x,y)
            count+=1
    return count

def main():
    DEST.mkdir(parents=True,exist_ok=True)
    rects=[]
    # 원본 벽돌의 줄눈을 직접 써서 잘린 반쪽 벽돌이 생기지 않게 한다.
    for row,(left,right) in zip(range(2,7),[(340,910),(234,1009),(329,1118),(240,1015),(338,918)]):
        rects.append(tuple(v*.18 for v in (left,kit.ROWS[row],right,kit.ROWS[row+1])))
    for color,label in [('black','검정속흰벽돌'),('white','흰색속검정벽돌')]:
        material=(MAT/f'땅_{color}.tres').read_text(encoding='utf-8')
        material=re.sub(r' uid="[^"]+"','',material)
        params=f'shader_parameter/inlay_count = {len(rects)}\nshader_parameter/inlay_rects = PackedVector4Array('+', '.join(kit.fmt(v) for r in rects for v in r)+', '+', '.join(['0']*(4*(16-len(rects))))+')\n'
        material=material.replace('[resource]',params+'\n[resource]')
        (MAT/f'내부무늬_{color}.tres').write_text(material,encoding='utf-8')
        scene(label,[[(0,0),(340,0),(340,288),(0,288),(0,0)]],[color],rects)
    total=0
    for axis in ['세로','가로']:
        if axis=='세로':
            a,b=vertical(276,0),vertical(552,4)
            polys=[[(0,0)]+a+[(0,H),(0,0)],a[:1]+b+list(reversed(a))+a[:1],b[:1]+[(W,0),(W,H)]+list(reversed(b))+b[:1]]
        else:
            a,b=horizontal(184.32,0),horizontal(368.64,3)
            polys=[[(0,0),(W,0)]+list(reversed(a))+[(0,0)],a+b[::-1]+a[:1],b+[(W,H),(0,H)]+b[:1]]
        polys=[kit.compact(p) for p in polys]
        total+=validate(polys)
        for colors,label in [(['black','white','black'],'검흰검'),(['white','black','white'],'흰검흰')]:
            scene(f'{axis}경계_{label}',polys,colors)
    files=sorted(DEST.glob('*.tscn'))
    preview='[gd_scene format=3]\n'
    for i,path in enumerate(files):
        preview+=f'[ext_resource type="PackedScene" path="res://{path.relative_to(ROOT).as_posix()}" id="m{i}"]\n'
    preview+='[node name="흑백벽돌_비교" type="Node2D"]\n'
    for i,path in enumerate(files):
        preview+=f'[node name="{path.stem}" parent="." instance=ExtResource("m{i}")]\nposition = Vector2({(i%2)*960}, {(i//2)*680})\n'
    (ROOT/'scenes/테스트/하수도_흑백벽돌_비교.tscn').write_text(preview,encoding='utf-8')
    print('Created 6 reusable modules; partition samples:',total,'PASS')

if __name__=='__main__':main()
