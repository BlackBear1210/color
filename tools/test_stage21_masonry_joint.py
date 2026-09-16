"""2-1 실제 저장 파일 검사. Godot 실행/시각 검증을 대신하지 않는다."""
import re
import apply_stage22_masonry_joint as common
from apply_stage21_masonry_joint import SCENE,NAMES,ORIGINAL,validate

def area(poly):
    return sum(a[0]*b[1]-b[0]*a[1] for a,b in zip(poly,poly[1:]))/2

def main():
    text=SCENE.read_text(encoding='utf-8');nodes=common.parse(text)
    validate(nodes)
    assert abs(sum(area(nodes[n][2])-area(ORIGINAL[n]) for n in NAMES))<.001
    for name in NAMES:
        block,pos,poly=nodes[name]
        assert '_meshes =' not in block
        assert '"위치별_판정" = true' in block
        assert poly[0]==poly[-1] and area(poly)>0
        # 비인접 선분 교차가 있으면 오목 다각형 메시 생성이 실패할 수 있다.
        edges=list(zip(poly,poly[1:]))
        for i,(a,b) in enumerate(edges):
            for j,(c,d) in enumerate(edges):
                if j<=i+1 or (i==0 and j==len(edges)-1):continue
                if a[0]==b[0] and c[1]==d[1]:
                    assert not (min(c[0],d[0])<a[0]<max(c[0],d[0]) and min(a[1],b[1])<c[1]<max(a[1],b[1]))
                if a[1]==b[1] and c[0]==d[0]:
                    assert not (min(a[0],b[0])<c[0]<max(a[0],b[0]) and min(c[1],d[1])<a[1]<max(c[1],d[1]))
        pat=rf'\[node name="CollisionPolygon2D" parent="지형/{name}/StaticBody2D"[^\]]*\]\npolygon = PackedVector2Array\(([^)]+)\)'
        saved=common.vec(re.search(pat,text)[1])
        expected=tuple(v for p in poly[:-1] for v in (p[0]-pos[0],p[1]-pos[1]))
        assert len(saved)==len(expected) and all(abs(a-b)<.0001 for a,b in zip(saved,expected))
        path=common.ROOT/f'assets/textures/smartshape/sewer_masonry_v02/맞물림_2-1_{name}.tres'
        material=path.read_text(encoding='utf-8')
        assert 'fill_texture_offset = Vector2(3136, 640.1)' in material
        assert 'fill_texture_absolute_position = true' in material
        assert int(re.search(r'ground_edge_count = (\d+)',material)[1])==len(poly)-1
        assert int(re.search(r'ground_cover_count = (\d+)',material)[1])<=256
        for p in re.findall(r'path="res://([^"]+)"',material):assert (common.ROOT/p).is_file()
    for p in re.findall(r'path="res://([^"]+)"',text):assert (common.ROOT/p).is_file()
    ids=re.findall(r'\[sub_resource [^\]]*id="([^"]+)"',text)
    all_ids=re.findall(r'\[(?:sub_resource|ext_resource) [^\]]*\bid="([^"]+)"',text)
    assert all(re.fullmatch(r'[A-Za-z0-9_]+',value) for value in all_ids)
    assert len(ids)==len(set(ids))
    assert set(re.findall(r'SubResource\("([^"]+)"\)',text))<=set(ids)
    shader=(common.ROOT/'shaders/sewer_natural_platform.gdshader').read_text(encoding='utf-8')
    script=(common.ROOT/'scripts/스마트월드/하수도_자연발판.gd').read_text(encoding='utf-8')
    # 정적 맞물림 점은 그대로이고 런타임 본체는 더 이상 선분 배열을 순회하지 않는다.
    assert 'cached_draw_mode' in shader and 'result.set_shader_parameter("ground_edge_count", 0)' in script
    print('stage_2-1 area, collision, cached mesh removal, paint flags, UV, references, limits: PASS')

if __name__=='__main__':main()
