"""2-1의 기존 이동 외곽을 유지하며 내부 무늬 두 곳과 샤프트 내부 접합만 적용."""
import re
import math
import apply_stage22_masonry_joint as c

SCENE=c.ROOT/'scenes/world_2_클로드/stage_2-1.tscn'
MAT=c.ROOT/'assets/textures/smartshape/sewer_masonry_v02'
MARKER='metadata/color_inlays_v1 = true'

def put(block,key,value):
    line=f'{key} = {value}'
    return re.sub(r'^'+re.escape(key)+r' = .*$',line,block,flags=re.M) if re.search(r'^'+re.escape(key)+r' = ',block,re.M) else block.rstrip()+'\n'+line+'\n\n'

def inlays(ymin,ymax):
    ys=c.ylines(ymin,ymax);out=[]
    for i,(a,b) in enumerate(zip(ys,ys[1:])):
        left=c.nearest_joint(2750-3136+[32,0,48,16,64][i%5],(a+b)/2)+3136
        right=c.nearest_joint(3030-3136-[36,0,18,54,0][i%5],(a+b)/2)+3136
        out.append((left,a,right,b))
    return out

def distance(p,a,b):
    dx,dy=b[0]-a[0],b[1]-a[1];d=dx*dx+dy*dy
    t=max(0,min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dy)/d)) if d else 0
    return math.hypot(p[0]-a[0]-t*dx,p[1]-a[1]-t*dy)

def validate_inlays(poly,rects):
    for x,y,r,b in rects:
        for p in [(x,y),(r,y),(r,b),(x,b),((x+r)/2,(y+b)/2)]:
            assert c.inside(p,poly),p
            assert min(distance(p,a,z) for a,z in zip(poly,poly[1:]))>=24,p

def main():
    text=SCENE.read_text(encoding='utf-8')
    if MARKER in text:
        print('Already applied; no rewrite.');return
    c.ORIGIN_Y=640.1
    nodes=c.parse(text)
    # 통행 가능한 외곽은 고정하고, 기존 흑백 내부 경계의 가운데만 이동한다.
    a='A_샤프트_왼벽';b='A_샤프트_왼벽_밑채움'
    path=[(3520,1536),(3550,1536)];current=1536
    levels=c.ylines(1490,1580)
    for x,offset in [(3580,-32),(3640,32),(3700,-21),(3760,21)]:
        target=min(levels,key=lambda y:abs(y-(1536+offset)))
        for y in sorted(c.ylines(min(current,target),max(current,target))+[target],reverse=target<current):
            joint=3136+c.nearest_joint(x-3136,(current+y)/2)
            path.extend([(joint,current),(joint,y)]);current=y
    path.extend([(3816,current),(3816,1536),(3840,1536)])
    path=c.compact(path)
    new={name:c.splice(nodes[name][2],(3520,1536),(3840,1536),path) for name in [a,b]}
    # 변경 후에도 두 지형의 합집합과 노드 수는 같아야 한다.
    samples=0
    for y in range(1480,1590,2):
        for x in range(3500,3850,2):
            p=(x+.217,y+.319)
            old=sum(c.inside(p,nodes[n][2]) for n in [a,b])
            now=sum(c.inside(p,new[n]) for n in [a,b])
            assert old==now and now<=1,p
            samples+=1
    ext='[ext_resource type="Script" path="res://scripts/스마트월드/하수도_내부벽돌.gd" id="color_inlay_script"]\n'
    resources=''; additions=''
    rects_by_name={'A_바닥':inlays(1120,1250),'A_갤러리_슬래브':inlays(548,646)}
    targets=['A_바닥','A_갤러리_슬래브',a,b]
    for i,name in enumerate(targets):
        block,pos,poly=nodes[name];replacement=block
        color='white' if name in ['A_갤러리_슬래브',a] else 'black'
        # 다른 지형의 공유 재질은 수정하지 않고 이 배치 전용으로 저장한다.
        source=MAT/f'맞물림_2-1_{name}.tres' if name!=b else MAT/'땅_black.tres'
        material=re.sub(r' uid="[^"]+"','',source.read_text(encoding='utf-8'))
        if name==b:
            material+='fill_texture_absolute_position = true\nfill_texture_offset = Vector2(3136, 640.1)\n'
        if name in rects_by_name:
            rects=rects_by_name[name];validate_inlays(poly,rects)
            local=[(x-pos[0],y-pos[1],r-pos[0],z-pos[1]) for x,y,r,z in rects]
            packed=', '.join(c.fmt(v) for rect in local for v in rect)+', '+', '.join(['0']*(4*(16-len(local))))
            params=f'shader_parameter/inlay_count = {len(local)}\nshader_parameter/inlay_rects = PackedVector4Array({packed})\n'
            material=material.replace('[resource]',params+'\n[resource]')
            replacement=put(replacement,'script','ExtResource("color_inlay_script")')
            replacement=put(replacement,'"시작상태"','0')
            replacement=put(replacement,'"내부_바탕흰색"',str(color=='white').lower())
            array=', '.join('Rect2('+c.pair((x,y))+', '+c.pair((r-x,z-y))+')' for x,y,r,z in local)
            replacement=put(replacement,'"내부_벽돌영역"','Array[Rect2](['+array+'])')
        if name in new:
            rs,local=c.make_resources('color21_'+str(i),new[name],pos)
            resources+=rs.replace('"4_7je74"','"4_l7012"').replace('"5_57mdw"','"5_rp1cr"')+'\n'
            replacement=put(replacement,'_points',f'SubResource("joint_color21_{i}_array")')
            collision=f'polygon = PackedVector2Array({", ".join(c.pair(p) for p in local[:-1])})'
            pattern=r'(\[node name="CollisionPolygon2D" parent="지형/'+re.escape(name)+r'/StaticBody2D"[^\]]*\]\n)polygon = [^\n]+'
            if re.search(pattern,text):text=re.sub(pattern,lambda m:m[1]+collision,text)
            else:additions+=f'\n[node name="CollisionPolygon2D" parent="지형/{name}/StaticBody2D" index="0"]\n{collision}\n'
            # 이전 지형 윤곽 유니폼은 캐시 모드에서 사용하지 않는다.
            material=re.sub(r'shader_parameter/ground_edge_count = .*','shader_parameter/ground_edge_count = 0',material)
        replacement=re.sub(r'^_meshes = .*\n','',replacement,flags=re.M)
        target=f'색조합_2-1_{name}.tres'
        (MAT/target).write_text(material,encoding='utf-8')
        ext+=f'[ext_resource type="Resource" path="res://assets/textures/smartshape/sewer_masonry_v02/{target}" id="color21_mat{i}"]\n'
        replacement=put(replacement,'shape_material',f'ExtResource("color21_mat{i}")')
        replacement=put(replacement,'metadata/color_inlays_v1','true')
        text=text.replace(block,replacement)
    text=text.replace('[sub_resource',ext+'\n[sub_resource',1)
    text=text.replace('[node name="stage_2-1"',resources+'\n[node name="stage_2-1"',1)
    # 원래 노드의 충돌 자식과 같은 위치에 넣어 상속 노드 순서를 지킨다.
    if additions:
        text=text.replace('[node name="장치"',additions+'\n[node name="장치"',1)
    result=c.parse(text)
    assert set(result)==set(nodes)
    for name in nodes:
        assert result[name][1]==nodes[name][1]
        if name not in new:assert result[name][2]==nodes[name][2]
    SCENE.write_text(text,encoding='utf-8')
    print('Stage 2-1 applied. Shared boundary samples:',samples,'PASS; all outer routes and node positions preserved.')

if __name__=='__main__':main()
