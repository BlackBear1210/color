"""Godot를 실행하지 않는 실제 저장 씬의 접합/충돌/리소스 검사."""
import re
from apply_stage22_masonry_joint import ROOT, SCENE, parse, verify, horizontal_path, vertical_path, vec

ORIGINAL = {
    '좌상_덩어리': [(0,1216),(1856,1216),(1856,1984),(1408,1984),(1408,1856),(0,1856),(0,1216)],
    '탑_왼벽': [(0,1856),(768,1856),(768,3584),(0,3584),(0,1856)],
    '좌하_채움': [(0,3584),(768,3584),(768,4352),(0,4352),(0,3584)],
    '탑_바닥': [(768,3456),(1040,3456),(1040,3584),(1664,3584),(1664,4352),(768,4352),(768,3456)],
}

def main():
    text=SCENE.read_text(encoding='utf-8'); nodes=parse(text)
    before={name:('',(0,0),poly) for name,poly in ORIGINAL.items()}
    pairs=[(('좌상_덩어리','탑_왼벽'),horizontal_path()),(('좌하_채움','탑_바닥'),vertical_path())]
    print('Saved boundary samples:',verify(before,nodes,pairs),'PASS')
    for names,path in pairs:
        for name in names:
            poly=nodes[name][2]
            # 두 지형에 모든 경계 구간이 반대 방향으로 똑같이 저장돼 있어야 한다.
            for a,b in zip(path[1:-2],path[2:-1]):
                assert (a,b) in list(zip(poly,poly[1:])) or (b,a) in list(zip(poly,poly[1:])),name
            # 축 정렬 다각형의 비인접 선분 교차(셀프 교차) 검사.
            segments=list(zip(poly,poly[1:]))
            for i,(a,b) in enumerate(segments):
                for j,(c,d) in enumerate(segments):
                    if j<=i+1 or (i==0 and j==len(segments)-1):continue
                    if a[0]==b[0] and c[1]==d[1]:
                        assert not (min(c[0],d[0])<a[0]<max(c[0],d[0]) and min(a[1],b[1])<c[1]<max(a[1],b[1]))
                    if a[1]==b[1] and c[0]==d[0]:
                        assert not (min(a[0],b[0])<c[0]<max(a[0],b[0]) and min(c[1],d[1])<a[1]<max(c[1],d[1]))
    for name,(block,pos,poly) in nodes.items():
        # [2026-09-17 Claude] 에디터가 다시 저장한 씬은 프리팹 기본값과 같은 값(위치별_판정=true)과
        # 편집 불가 인스턴스 내부의 콜리전 덮어쓰기를 지운다(HEAD 8351ead 가 그렇다). 콜리전은
        # collision_update_mode=2 라 실행 때 점에서 다시 굽히므로, 덮어쓰기가 **있으면** 점과 같아야 하고 없으면 통과.
        pat=rf'\[node name="CollisionPolygon2D" parent="지형/{re.escape(name)}/StaticBody2D"[^\]]*\]\npolygon = PackedVector2Array\(([^)]+)\)'
        found=re.search(pat,text)
        if found:
            saved=vec(found[1])
            expected=tuple(v for p in poly[:-1] for v in (p[0]-pos[0],p[1]-pos[1]))
            assert len(saved)==len(expected) and all(abs(a-b)<.0001 for a,b in zip(saved,expected)),name
        assert '"위치별_판정" = false' not in block,name
        assert '칠하기_방식' not in block and '칠하기_허용' not in block,name
        # 미리보기 마감 한도는 실제 인접 다각형 수로 확인한다.
        bounds=lambda p:(min(q[0] for q in p),min(q[1] for q in p),max(q[0] for q in p),max(q[1] for q in p))
        x,y,r,b=bounds(poly);cover=0
        for other,(_,_,op) in nodes.items():
            if other==name:continue
            ox,oy,orr,ob=bounds(op)
            if not (orr<x-8 or ox>r+8 or ob<y-8 or oy>b+8):cover+=len(op)
        assert len(poly)<=64 and cover<=256,(name,len(poly),cover)
    for path in re.findall(r'path="res://([^"]+)"',text):assert (ROOT/path).is_file(),path
    # 맞물린 네 지형의 **실제** 재질(외부 .tres 든, 에디터가 씬 안에 풀어 넣은 sub_resource 든)이 같은 월드 UV 기준인지 본다.
    for name in ['좌상_덩어리','탑_왼벽','좌하_채움','탑_바닥']:
        ref=re.search(r'shape_material = (Ext|Sub)Resource\("([^"]+)"\)',nodes[name][0])
        if ref[1]=='Ext':
            path=re.search(r'\[ext_resource[^\]]*path="res://([^"]+)"[^\]]*id="'+re.escape(ref[2])+'"',text)[1]
            material=(ROOT/path).read_text(encoding='utf-8')
        else:
            material=re.search(r'\[sub_resource type="Resource" id="'+re.escape(ref[2])+r'"\]\n(?:.*\n)*?\n',text)[0]
        assert 'fill_texture_absolute_position = true' in material,name
        assert 'fill_texture_offset = Vector2(0, 1792.1)' in material,name
        assert 'fill_texture_scale = 0.18' in material,name
        for path in re.findall(r'path="res://([^"]+)"',material):assert (ROOT/path).is_file(),path
    ids=re.findall(r'\[sub_resource [^\]]*id="([^"]+)"',text)
    assert len(ids)==len(set(ids))
    assert set(re.findall(r'SubResource\("([^"]+)"\)',text))<=set(ids)
    assert '"시작상태" = 0' in nodes['L3_유령발판'][0]
    print('Collision, paint flags, UV alignment, resource references, trim limits: PASS')

if __name__=='__main__':main()
