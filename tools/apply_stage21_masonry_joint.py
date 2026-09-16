"""사용자가 지목한 2-1 A구간 ㄱ자 접합부만 수정. --apply 없으면 검사만 한다."""
import argparse
import re
import apply_stage22_masonry_joint as common

SCENE=common.ROOT/'scenes/world_2_클로드/stage_2-1.tscn'
NAMES=['A_바닥','A_갤러리_슬래브','A_샤프트_왼벽']
ORIGINAL={
 'A_바닥':[(768,1024),(1616,1024),(1616,896),(1872,896),(1872,1024),(3136,1024),(3136,704),(3520,704),(3520,2560),(224,2560),(224,1120),(768,1120),(768,1024)],
 'A_갤러리_슬래브':[(2576,512),(3840,512),(3840,704),(2576,704),(2576,512)],
 'A_샤프트_왼벽':[(3520,704),(3840,704),(3840,1536),(3520,1536),(3520,704)]}

def paths():
    common.ORIGIN_Y=704-355*.18
    levels=[common.ORIGIN_Y+y*.18 for y in common.ROWS]
    h=[(3136,704)];current=704
    # 지형 외곽이 만나는 양 끝은 그대로 두고 내부 경계만 이동한다.
    for x,level in [(48,2),(124,5),(208,1),(284,4),(340,3)]:
        target=levels[level]
        stops=sorted(common.ylines(min(current,target),max(current,target))+[target],reverse=target<current)
        for y in stops:
            joint=3136+common.nearest_joint(x,(current+y)/2)
            h.extend([(joint,current),(joint,y)]);current=y
    h.append((3520,704))
    bounds=common.ylines(748,1488)
    v=[(3520,704),(3520,bounds[0])]
    offsets=[.5,1.5,2,1,-.5,-2,-1.5,-1,.5,2,1.5,-.5,-1,-2,.5,1,2,-1,-.5,1.5,1]
    for i,(a,b) in enumerate(zip(bounds,bounds[1:])):
        x=3136+common.nearest_joint(384+offsets[i%len(offsets)]*36,(a+b)/2)
        v.extend([(x,a),(x,b)])
    v.extend([(3520,bounds[-1]),(3520,1536)])
    return common.compact(h),common.compact(v)

def validate(nodes):
    h,v=paths();count=0
    for names,path in [((NAMES[0],NAMES[1]),h),((NAMES[0],NAMES[2]),v)]:
        for a,b in zip(path,path[1:]):
            dx,dy=b[0]-a[0],b[1]-a[1];length=(dx*dx+dy*dy)**.5
            for f in [.125,.25,.5,.75,.875]:
                for side in [-.25,.25]:
                    p=(a[0]+dx*f-dy/length*side,a[1]+dy*f+dx/length*side)
                    assert sum(common.inside(p,nodes[n][2]) for n in names)==1,(names,p)
                    assert any(common.inside(p,ORIGINAL[n]) for n in names)
                    count+=1
    for name in NAMES:
        assert len(nodes[name][2])<=128,(name,len(nodes[name][2]))
    print('stage_2-1 boundary samples:',count,'PASS')

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--apply',action='store_true');args=parser.parse_args()
    text=SCENE.read_text(encoding='utf-8');nodes=common.parse(text)
    if 'joint_A_바닥_array' in text or common.resource_id('joint_A_바닥_array') in text:
        validate(nodes);print('Already applied. No rewrite.');return
    for name in NAMES:assert nodes[name][2]==ORIGINAL[name],name+' 외곽이 변경됨: 자동 덮어쓰기 중단'
    h,v=paths();changed={}
    for name in NAMES:
        block,pos,poly=nodes[name]
        if name in [NAMES[0],NAMES[1]]:poly=common.splice(poly,h[0],h[-1],h)
        if name in [NAMES[0],NAMES[2]]:poly=common.splice(poly,v[0],v[-1],v)
        changed[name]=(block,pos,poly)
    validate(changed)
    print('Edges:',{n:len(changed[n][2])-1 for n in NAMES})
    if not args.apply:return
    # 양쪽 동일 UV 기준을 쓰되 공유 프리팹/2-2 재질은 변경하지 않는다.
    extra='';ext=''
    for name,(block,pos,poly) in changed.items():
        resources,local=common.make_resources(name,poly,pos)
        extra+=resources.replace('"4_7je74"','"4_l7012"').replace('"5_57mdw"','"5_rp1cr"')+'\n'
        color='black' if name==NAMES[0] else 'white'
        # 각 지형별 미리보기 윤곽/이웃 가림도 저장해 첫 프레임부터 사각형 잔상이 없게 한다.
        material=(common.ROOT/f'assets/textures/smartshape/sewer_masonry_v02/땅_{color}.tres').read_text(encoding='utf-8')
        material=re.sub(r' uid="[^"]+"','',material,count=1)
        edges=[(*local[i],*local[i+1]) for i in range(len(local)-1)]
        cover=[]
        for other,(_,_,op) in {**nodes,**changed}.items():
            if other==name:continue
            if max(p[0] for p in op)<min(p[0] for p in poly)-8 or min(p[0] for p in op)>max(p[0] for p in poly)+8:continue
            if max(p[1] for p in op)<min(p[1] for p in poly)-8 or min(p[1] for p in op)>max(p[1] for p in poly)+8:continue
            for a,b in zip(op,op[1:]):cover.append((a[0]-pos[0],a[1]-pos[1],b[0]-pos[0],b[1]-pos[1]))
        assert len(cover)<=256,(name,len(cover))
        for key,values in [('ground_edges',edges),('ground_cover_edges',cover)]:
            array=', '.join(common.fmt(x) for edge in values for x in edge)
            material=re.sub(rf'shader_parameter/{key} = .*',f'shader_parameter/{key} = PackedVector4Array({array})',material)
        for key,value in [('ground_edge_count',len(edges)),('ground_cover_count',len(cover))]:
            material=re.sub(rf'shader_parameter/{key} = .*',f'shader_parameter/{key} = {value}',material)
        bounds=(min(p[0] for p in local),min(p[1] for p in local),max(p[0] for p in local),max(p[1] for p in local))
        material=re.sub(r'shader_parameter/surface_bounds = .*','shader_parameter/surface_bounds = Vector4('+', '.join(map(common.fmt,bounds))+')',material)
        material+='fill_texture_absolute_position = true\nfill_texture_offset = Vector2(3136, 640.1)\n'
        target=f'assets/textures/smartshape/sewer_masonry_v02/맞물림_2-1_{name}.tres'
        (common.ROOT/target).write_text(material,encoding='utf-8')
        ext+=f'[ext_resource type="Resource" path="res://{target}" id="joint21_{name}"]\n'
        replacement=re.sub(r'_points = SubResource\("[^"]+"\)',f'_points = SubResource("joint_{name}_array")',block)
        # 저장된 옛 사각 메시를 재사용하면 새 점이 있어도 구형 화면이 보일 수 있다.
        replacement=re.sub(r'^_meshes = .*\n','',replacement,flags=re.M)
        replacement=re.sub(r'shape_material = .*',f'shape_material = ExtResource("joint21_{name}")',replacement)
        replacement+='"위치별_판정" = true\n'
        replacement+=f'\n[node name="CollisionPolygon2D" parent="지형/{name}/StaticBody2D" index="0"]\npolygon = PackedVector2Array({", ".join(common.pair(p) for p in local[:-1])})\n\n'
        text=text.replace(block,replacement)
    text=text.replace('[sub_resource',ext+'\n[sub_resource',1)
    text=text.replace('[node name="stage_2-1"',extra+'[node name="stage_2-1"',1)
    assert 'joint_A_바닥_array' in text
    SCENE.write_text(common.sanitize_resource_ids(text),encoding='utf-8')
    validate(common.parse(text));print('Saved stage_2-1.tscn')

if __name__=='__main__':main()
