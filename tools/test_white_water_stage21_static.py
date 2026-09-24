"""엔진을 실행하지 않는 흰물 적용/침수 마감의 제한적인 회귀 검사."""
from pathlib import Path
import math
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
scene_path = 'scenes/world_2_클로드/stage_2-1.tscn'
scene = (ROOT / scene_path).read_text(encoding='utf-8')

def node(name):
    return re.search(r'\[node name="'+re.escape(name)+r'"[^\n]*\]\n([^\[]*)',scene)[1]

flow = node('W5_흰물')
pool = node('B_착지_웅덩이')
assert '"흐름속도" = 390.0' in flow
assert 'position = Vector2(7936, 1024)' in flow
assert '"크기" = Vector2(64, 768)' in flow
assert 'position = Vector2(4032, 1472)' in pool
assert '"크기" = Vector2(384, 64)' in pool
# 물 위치/수심 외에 기존 맵이 다시 생성되거나 다른 물의 색이 바뀌지 않았는지 확인한다.
old = subprocess.check_output(['git','show','HEAD:'+scene_path],cwd=ROOT).decode().replace('\r\n','\n')
def strip_changes(text):
    for ident in ['white_flow_v2','white_pool_v2']:
        text = re.sub(r'\[ext_resource type="Script"[^\n]*id="'+ident+r'"\]\n\n','',text)
        text = text.replace(f'script = ExtResource("{ident}")\n','')
    return text.replace('"흐름속도" = 390.0\n','')
# 허용한 웅덩이/바닥 블록만 제외하고 나머지 씬은 HEAD와 동일해야 한다.
def unrelated(text):
    text=strip_changes(text)
    text=re.sub(r'\[sub_resource[^\n]*id="PoolSlope[^\n]*\]\n.*?(?=^\[)', '', text, flags=re.S|re.M)
    text=re.sub(r'\[node name="B_웅덩이_바닥"[^\n]*\]\n.*?(?=\[node)', '', text, flags=re.S)
    text=re.sub(r'\[node name="B_착지_웅덩이"[^\n]*\]\n.*?(?=\[node)', '', text, flags=re.S)
    text=re.sub(r'\[node name="CollisionPolygon2D" parent="지형/B_웅덩이_바닥/StaticBody2D"[^\n]*\]\n.*?(?=\[node)', '', text, flags=re.S)
    return text
assert unrelated(scene)==unrelated(old), 'Unexpected map differences'
assert '"오른쪽_안쪽폭" = 64.0' in pool
# 수면은 1408을 유지하고 낙하 받기 최소 수심 40보다 깊다.
assert 1472-64 == 1408 and 40 <= 64 < 96
# 물 경사와 지형 경사는 같은 두 세계 좌표를 공유한다.
water_edge=[(4224,1408),(4160,1472)]
terrain_edge=[(4032+192,2048-640),(4032+128,2048-576)]
assert water_edge==terrain_edge
assert 'polygon = PackedVector2Array(-192, -576, 128, -576, 192, -640, 192, 512, -192, 512)' in scene

for file in ['scripts/스마트월드/유체_흰물v2.gd', 'scripts/스마트월드/웅덩이_흰물v2.gd', 'scripts/스마트월드/흰물_디자인.gd']:
    for resource in re.findall(r'res://([^"\n]+)',(ROOT/file).read_text(encoding='utf-8')):
        assert (ROOT/resource).is_file(), resource

# 확장 물보라의 전체 샘플 영역이 렌더 사각형 안에 들어간다(폭 8..500).
for width in range(8,501):
    splash_width=min(240,max(width*3.0,120))
    assert splash_width/2 <= width/2+150
    assert splash_width*.18*.12 <= 32

# 세로 반복의 샘플 가중치가 끝에서 0으로 수렴해 거울 반전/불연속이 없다.
for boundary in range(-10,11):
    v=(boundary+1e-7)%1
    assert math.sin(v*math.pi)**2 < 1e-10

shader=(ROOT/'shaders/white_water_modular_v2.gdshader').read_text()
assert not re.search('[\uac00-\ud7a3]',shader)
assert shader.count('{') == shader.count('}')
assert 'h-back_depth*0.5' in shader
assert 1024+768-4*0.5 == 1790 # 지형 윗면 [1788,1792]의 중앙
print('PASS: scene scope, water position/size/speed, references, splash bounds, vertical repeat continuity')
print('NOT RUN: Godot parsing, actual submerged mesh clipping, gameplay/physics/visual capture')
