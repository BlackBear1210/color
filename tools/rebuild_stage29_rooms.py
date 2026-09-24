"""사용자 승인한 2-9 전면 재구축. 정적 텍스트 생성이며 Godot는 실행하지 않는다.
--apply만 실제 씬을 교체하고 직전 판본을 별도 보관한다. 기본은 별도 초안 생성.
"""
from pathlib import Path
import argparse, json, hashlib

ROOT=Path(__file__).resolve().parents[1]
TARGET=ROOT/'scenes/world_2_클로드/stage_2-9.tscn'
ap=argparse.ArgumentParser();ap.add_argument('--apply',action='store_true');args=ap.parse_args()
obj='scenes/집/스마트월드_장애물/'
refs={
 'world':('Script','scripts/스마트월드/월드.gd'), 'core':('Script','scripts/스마트월드/페인트_코어.gd'),
 'black':('PackedScene','scenes/지형/하수도/하수도_기본지형_검정.tscn'),
 'white':('PackedScene','scenes/지형/하수도/하수도_기본지형_흰색.tscn'),
 'ledge':('PackedScene','scenes/지형/하수도/하수도_공중선반_검정.tscn'),
 'point':('Script','addons/rmsmartshape/shapes/point.gd'), 'points':('Script','addons/rmsmartshape/shapes/point_array.gd'),
 'player':('PackedScene','scenes/player/Player.tscn'), 'background':('PackedScene','scenes/배경/하수도_다층배경_v02.tscn'),
 'water':('PackedScene',obj+'유체.tscn'), 'water_art':('Script','scripts/스마트월드/유체_흰물v2.gd'),
 'pool':('PackedScene',obj+'웅덩이.tscn'), 'pool_art':('Script','scripts/스마트월드/웅덩이_흰물v2.gd'),
 'hopper':('PackedScene',obj+'호퍼_주철_직하.tscn'), 'valve':('PackedScene',obj+'제어레버.tscn'),
 'button':('Script','scripts/스마트월드/압력버튼.gd'), 'grate':('Script','scripts/스마트월드/통과플랫폼.gd'),
 'lift':('PackedScene',obj+'움직이는발판.tscn'), 'saw':('PackedScene','scenes/장애물/회전톱.tscn'),
 'checkpoint':('PackedScene','scenes/장애물/체크포인트.tscn'), 'exit':('PackedScene',obj+'연결통로.tscn')}
sub=[];nodes=[];editable=[];terrain=[];devices=[]
def shape(name,pts,kind='black'):
    # SS2D 원점/점/저장 충돌을 동일 좌표원에서 생성하여 편집/실행 윤곽 차이를 방지한다.
    key=f't{len(terrain)}';ox,oy=pts[0];local=[(x-ox,y-oy) for x,y in pts];closed=local+[local[0]]
    for i,(x,y) in enumerate(closed):sub.append(f'[sub_resource type="Resource" id="{key}_{i}"]\nresource_local_to_scene = true\nscript = ExtResource("point")\nposition = Vector2({x:g}, {y:g})\n')
    sub.append(f'[sub_resource type="Resource" id="{key}_points"]\nresource_local_to_scene = true\nscript = ExtResource("points")\n_points = {{\n'+',\n'.join(f'{i}: SubResource("{key}_{i}")' for i in range(len(closed)))+'\n}\n_point_order = PackedInt32Array('+', '.join(map(str,range(len(closed))))+f')\n_constraints = {{Vector2i(0, {len(local)}): 15}}\n_next_key = {len(closed)}\n')
    nodes.append(f'[node name="{name}" parent="지형" instance=ExtResource("{kind}")]\nposition = Vector2({ox:g}, {oy:g})\n_points = SubResource("{key}_points")\ncached_draw_mode = 1\n\n[node name="CollisionPolygon2D" parent="지형/{name}/StaticBody2D"]\npolygon = PackedVector2Array('+', '.join(f'{v:g}' for p in local for v in p)+')\n')
    editable.append(f'[editable path="지형/{name}"]');terrain.append(dict(name=name,points=pts,kind=kind))
def box(name,x,y,w,h=96,kind='black'):shape(name,[(x,y),(x+w,y),(x+w,y+h),(x,y+h)],kind)
def ledge(name,x,y,w):shape(name,[(x,y),(x+w,y),(x+w,y+16),(x+w-24,y+48),(x+w*.5,y+40),(x+24,y+56),(x,y+16)],'ledge')
def inst(name,key,x,y,extra='',parent='장치'):
    nodes.append(f'[node name="{name}" parent="{parent}" instance=ExtResource("{key}")]\nposition = Vector2({x:g}, {y:g})\n{extra}\n');devices.append(dict(name=name,key=key,x=x,y=y,extra=extra))
def grate(name,x,y,w=192):
    key=f'g{len(sub)}';sub.append(f'[sub_resource type="RectangleShape2D" id="{key}"]\nsize = Vector2({w}, 16)\n')
    nodes.append(f'[node name="{name}" type="StaticBody2D" parent="장치"]\nposition = Vector2({x}, {y+8})\nscript = ExtResource("grate")\n"크기" = Vector2({w}, 16)\n"필요횟수" = 1\n\n[node name="충돌" type="CollisionShape2D" parent="장치/{name}"]\nshape = SubResource("{key}")\none_way_collision = true\n')
    devices.append(dict(name=name,key='grate',x=x,y=y,width=w))
def water(name,x,y,w,h,color,inlet=False):inst(name,'water',x,y,f'script = ExtResource("water_art")\n"크기" = Vector2({w}, {h})\n"색" = {color}\n"흐름속도" = 250.0\n"호퍼_유입" = {str(inlet).lower()}')
def pool(name,x,y,w):inst(name,'pool',x,y,f'script = ExtResource("pool_art")\n"크기" = Vector2({w}, 64)\n"색" = 2')
def button(name,x,y,target,dx,dy):
    nodes.append(f'[node name="{name}" type="AnimatableBody2D" parent="장치"]\nposition = Vector2({x}, {y+24})\nscript = ExtResource("button")\n"폭" = 112.0\n"작동방식" = 1\n"대상들" = Array[NodePath]([NodePath("../../지형/{target}")])\n"대상_이동량들" = Array[Vector2]([Vector2({dx}, {dy})])\n"이동속도" = 320.0\n')
    devices.append(dict(name=name,key='button',x=x,y=y,target=target,dx=dx,dy=dy))

# ① 오른쪽 입구: 같은 색으로 짧은 점프를 익히고 아래 물받이에서 바로 복귀한다.
box('A_출발',512,4096,512);box('A_징검',1184,4096,256,64,'white');box('A_갱도접근',1600,4096,832)
box('A_물받이바닥',512,4320,1920,160);pool('A_낙하물받이',1216,4320,1408)
for x in [1104,1520]:grate(f'A_복귀{x}',x,4208,128)
# ② 좁은 수직 연결: 격자는 아래에서 통과하며 머리 공간112 이상을 확보한다.
for i,y in enumerate(range(3968,3199,-128)):grate(f'B_상승{i+1}',2272+64*(i%2),y,192)
# ③ 오른쪽에서 왼쪽: 밸브로 흰 공급을 끄면 호퍼 출력은 검정으로 바뀐다.
box('C_배관실오른쪽',1696,3200,512);box('C_배관실왼쪽',768,3200,608)
box('C_천장',512,2560,1920,128)
water('C_검정공급',1472,2688,64,524,0,True);water('C_흰공급',1600,2688,64,524,1,True)
inst('C_혼합호퍼','hopper',1536,3364,'z_index = 3\n"폭" = 320.0\n"높이" = 164.0\n"자동_출구_연결" = false\n"출구_유체" = NodePath("../D_호퍼출력")\n"출구_물줄기_폭" = -1.0')
water('D_호퍼출력',1536,3420,128,292,2)
inst('C_흰공급밸브','valve',1904,3168,'"대상_유체" = NodePath("../C_흰공급")')
button('C_배수문버튼',960,3200,'E_진입수문',0,-512)
# ④ 왼쪽 낙하 후 오른쪽: 수문 버튼은 상부, 결과는 아래 통로 끝에 있다.
box('D_배수로',512,3712,1696,64)
box('E_진입수문',2432,3200,128,512)
box('E_수문아래벽',2432,3712,128,768)
box('E_수문위벽',2432,2048,128,1152)
# ⑤ 중앙 기계실: 버튼으로 연결 발판을 올려 이동 발판에 탑승한다.
box('E_기계실',2560,3712,1088,160);box('E_천장',2560,3040,1408,160)
ledge('E_연결발판',3776,3968,192);button('E_연결버튼',3520,3712,'E_연결발판',0,-256)
inst('E_승강발판','lift',4064,2960,'"크기" = Vector2(192, 32)\n"이동방향" = 1\n"이동거리" = 768.0\n"왕복시간" = 5.0\n"필요횟수" = 1')
box('E_물받이바닥',2560,4256,1792,224);pool('E_낙하물받이',4000,4256,576)
ledge('E_외곽복귀발판',4416,4368,192)
for i,y in enumerate([4144,4032,3920,3808]):grate(f'E_복귀{i+1}',4064,y)
inst('E_왕복톱','saw',3104,3664,'"반지름" = 30.0\n"이동거리" = 224.0\n"왕복시간" = 4.0')
# ⑥ 다시 왼쪽: 톱의 양끝에 대기 공간, 이후 별도 갱도로 위층 진입.
box('F_역방향통로',3008,2944,960,64)
inst('F_왕복톱','saw',3456,2896,'"반지름" = 28.0\n"이동거리" = 192.0\n"왕복시간" = 3.6')
for i,y in enumerate(range(2816,2175,-128)):grate(f'F_상승{i+1}',2784+64*(i%2),y,192)
# ⑦ 오른쪽 출구: 두 색 착지점과 높낮이. 아래 회색 수조에서 재도전 가능.
box('G_출발',2912,2048,512);box('G_흰발판',3584,2048,320,64,'white')
ledge('G_검정높은발판',4064,1968,256);box('G_출구길',4480,2048,1664)
box('G_수조바닥',2912,2496,3232,128);pool('G_낙하물받이',4784,2496,2592)
for i,y in enumerate([2384,2272,2160]):grate(f'G_복귀{i+1}',5952,y)
# 얇은 물은 기술 통과 구간. 같은 색 물/바닥의 안전 관계를 앞서 판단할 여유를 둔다.
water('G_얇은흰물',5520,1536,64,512,1)
box('G_천장',2688,1408,3712,128)
# 공간 경계는 루트 배경과 독립된 실제 벽. 중간 연결 입구는 열어 둔다.
box('외벽_왼쪽',0,2560,512,1920)
# 출구가 벽 속에서 막히지 않도록 통로 높이만 비우고 위아래 외벽을 남긴다.
box('외벽_오른쪽위',6400,1408,640,384);box('외벽_오른쪽아래',6400,2240,640,2240)
box('바닥_전체',0,4480,7040,384)
for name,x,y in [('입구',768,4096),('호퍼앞',2016,3200),('배수로',768,3712),('기계실',2688,3712),('상부통로',3840,2944),('출구구간',3104,2048)]:inst('체크포인트_'+name,'checkpoint',x,y)
inst('출구통로','exit',6144,2048,'"높이" = 256.0\n"깊이" = 420.0\n"다음_씬" = "res://scenes/lobby/lobby.tscn"','.')
inst('Player','player',768,4096,'"점프_높이_칸" = 10.0\n"점프_거리_칸" = 20.0','.')
prefix='[gd_scene format=3]\n\n'+'\n'.join(f'[ext_resource type="{kind}" path="res://{path}" id="{key}"]' for key,(kind,path) in refs.items())+'\n\n'+'\n'.join(sub)
root='''
[node name="stage_2-9" type="Node2D"]
script = ExtResource("world")
"스테이지_이름" = "2-9 · 엇갈린 배수실"
"카메라_리밋" = Rect2(0, 1408, 7040, 3456)
"카메라_줌" = 1.0
"시작_위치_방식" = 0
"시작_위치" = Vector2(768, 4096)
"낙사_y" = 4800.0
"치명_낙하거리" = 1500.0

[node name="페인트코어" type="Node" parent="." groups=["페인트코어"]]
script = ExtResource("core")

[node name="하수도배경" parent="." instance=ExtResource("background")]

[node name="지형" type="Node2D" parent="."]

[node name="장치" type="Node2D" parent="."]
'''
text=prefix+root+'\n'.join(nodes)+'\n'+'\n'.join(editable)+'\n'
archive=ROOT/'scenes/world_2_클로드/보관/stage29_재구축전_2026-09-23'
if args.apply:
    if TARGET.exists() and TARGET.read_text(encoding='utf-8')!=text:
        archive.mkdir(parents=True,exist_ok=True);(archive/'.gdignore').touch()
        old=TARGET.read_bytes();saved=archive/('stage_2-9_'+hashlib.sha256(old).hexdigest()[:12]+'.tscn')
        if not saved.exists():saved.write_bytes(old)
    TARGET.write_text(text,encoding='utf-8')
else:(ROOT/'docs/stage29_rooms_draft.tscn').write_text(text,encoding='utf-8')
(ROOT/'docs/stage29_rooms_manifest.json').write_text(json.dumps(dict(terrain=terrain,devices=devices),ensure_ascii=False,indent=2),encoding='utf-8')
print('Scene', 'APPLIED' if args.apply else 'DRAFT',len(terrain),'terrain',len(devices),'devices')
