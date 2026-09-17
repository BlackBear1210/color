"""stage_2-2 에 2-1 과 같은 하수도 외관·규칙을 얹는다. 기본은 검사(dry-run), --apply 때만 저장한다.

[2026-09-17 Claude] 근거: scenes/world_2_클로드/필독_오퍼스_현재지형디자인_인계.md ·
프롬프트_아스트라_스테이지2_맵제작.md §[2026-09-17] · docs/하수도_흑백벽돌_모듈_사용법.md

하는 일 (전부 "이름으로 찾은 노드만" 고친다 — 빌더를 다시 돌리지 않는다 · CLAUDE.md §4)
  1. 탑_l2~l10 (흰 탑 공중 발판 9 장): 기본지형(두꺼운 벽돌 96) → **공중선반 프리팹**(ledge_v03 · 얇은 석조 선반 · 밑면 깨진 돌).
     착지면(윗면 y)·폭 272·노드 position 은 그대로. 밑면만 44~60 두께로 얇아진다.
     ★콜리전을 **일방통행**으로 되살린다 — 빌더(`공중발판()`)가 넣었던 one_way 가 에디터 재저장 때 사라져
       있었다(두 칸 위 선반 밑면에 머리가 박힌다 · build_하수도_2-2.gd 주석). 에디터가 또 지우지 않게
       `[editable path=...]` 를 같이 적는다(편집 가능한 자식만 인스턴스 내부 덮어쓰기가 저장된다).
  2. 벽에 붙은 선반(l3·l5·l7·l9 = 왼벽 · l4·l8·l10 = 오른쪽 L1/L2 흰바닥)에 삼각지지대 장식.
     l2·l6 은 양옆이 트여 있어 안 단다(그림뿐 · 충돌 없음 · 사용안내 §1).
  3. 내부 반대색 벽돌 무늬(1번) 4 곳: 검정 속 흰(홀_바닥 · 우측_덩어리) · 흰 속 검정(탑_왼벽 · L2_흰바닥).
     줄눈(ROWS/JOINTS)에 맞추고 모든 외곽에서 24px 이상 안쪽. 별도 충돌 없음 · 시작상태 0 · 전용 스크립트.
  4. S01_흰물 너비 64 → 448 (필수 퍼즐형 — 바닥 높이에서 점프 중 이중 색전환 우회 차단. §물너비 규칙).
     S12·S23 은 우회 허용형이라 그대로.
  5. Player `점프_높이_칸 = 10` 명시 (2-1 과 동일 · 기본값에 기대지 않는다).
  6. 다층 배경 `scenes/배경/하수도_다층배경_2_2.tscn` 인스턴스(세로 맵용 배치 사본).
멱등: 표식(`metadata/sewer_look_v1`)이 있으면 다시 쓰지 않는다. 다른 노드의 점·위치는 건드리지 않는다.
"""
import argparse
import math
import re
import sys

sys.path.insert(0, str(__import__('pathlib').Path(__file__).resolve().parent))
import apply_stage22_masonry_joint as c  # 줄눈 표 · 파서 · 서식 도우미 (2-2 UV 기준 (0, 1792.1))

SCENE = c.SCENE
MARKER = 'metadata/sewer_look_v1 = true'
BG_SCENE = c.ROOT / 'scenes/배경/하수도_다층배경_2_2.tscn'

# ── 1. 공중 선반 ─────────────────────────────────────────────────────────────
# 빌더 표(build_하수도_2-2.gd): [이름, 왼쪽 x, 윗면 y] · 폭 272 · 왼열 [768,1040] 은 탑_왼벽에, 오른열 [1136,1408] 은
# L1/L2 흰바닥(같은 y 범위일 때만)에 붙는다.
LEDGES = [
    ('탑_l2', 1136, 3328, None), ('탑_l3', 768, 3200, 'L'), ('탑_l4', 1136, 3072, 'R'), ('탑_l5', 768, 2944, 'L'),
    ('탑_l6', 1136, 2816, None), ('탑_l7', 768, 2688, 'L'), ('탑_l8', 1136, 2560, 'R'), ('탑_l9', 768, 2432, 'L'),
    ('탑_l10', 1136, 2304, 'R'),
]
HALF_W = 136
TOP = -48  # 윗면 = position.y − 48 (원래 두께 96 의 절반 = 원래 윗면과 같은 자리)
# 공중선반 프리팹의 밑면 요철(윗면 기준 두께). 선반마다 위상을 돌려 같은 그림이 반복되지 않게 한다.
BOTTOM_DEPTHS = [59.3, 42.4, 46.6, 52.0, 49.2, 53.2, 49.4, 43.8, 59.8, 58.8, 46.1]


def ledge_points(index, wall=None):
    # 프리팹 모양: 윗면 양끝 10px 모따기 + 밑면 요철. 벽(또는 L2 흰바닥)에 붙는 쪽 끝은 모따기를 빼고 직각으로 —
    # 벽 앞에서 10px 홈이 파여 보이고, l10→L2_흰바닥 이음새에 V 자 틈이 생기기 때문.
    depths = BOTTOM_DEPTHS[index:] + BOTTOM_DEPTHS[:index]
    left_top = [(-HALF_W, TOP)] if wall == 'L' else [(-HALF_W, TOP + 10), (-HALF_W + 10, TOP)]
    right_top = [(HALF_W, TOP)] if wall == 'R' else [(HALF_W - 10, TOP), (HALF_W, TOP + 10)]
    pts = left_top + right_top + [(HALF_W, TOP + 12)]
    step = 2 * HALF_W / 12
    for i, depth in enumerate(depths):
        pts.append((round(HALF_W - step * (i + 1), 4), round(TOP + depth, 4)))
    pts += [(-HALF_W, TOP + 12), pts[0]]
    assert len(pts) == (18 if wall is None else 17)
    return pts


def ledge_resources(name, pts):
    key = 'ledge_' + name.split('_')[1]  # 리소스 id 는 ASCII 만 (apply_stage22_masonry_joint.resource_id 와 같은 이유)
    out = []
    for i, p in enumerate(pts):
        out.append(f'[sub_resource type="Resource" id="{key}_p{i}"]\nresource_local_to_scene = true\n'
                   f'script = ExtResource("4_7je74")\nposition = Vector2({c.pair(p)})\n')
    refs = ',\n'.join(f'{i}: SubResource("{key}_p{i}")' for i in range(len(pts)))
    order = ', '.join(map(str, range(len(pts))))
    out.append(f'[sub_resource type="Resource" id="{key}_array"]\nresource_local_to_scene = true\n'
               f'script = ExtResource("5_57mdw")\n_points = {{\n{refs}\n}}\n_point_order = PackedInt32Array({order})\n'
               f'_constraints = {{Vector2i(0, {len(pts) - 1}): 15}}\n_next_key = {len(pts)}\n')
    lo = min(p[1] for p in pts)
    hi = max(p[1] for p in pts)
    # 에디터 미리보기용 재질. 실행 때는 하수도_자연발판.gd 가 석조선반=true 를 보고 ledge 셰이더를 다시 만든다.
    out.append(f'[sub_resource type="ShaderMaterial" id="{key}_preview"]\nshader = ExtResource("ledge_shader")\n'
               f'shader_parameter/surface_bounds = Vector4({-HALF_W}, {c.fmt(lo)}, {HALF_W}, {c.fmt(hi)})\n'
               'shader_parameter/ground_platform = false\nshader_parameter/ledge_top_half_depth = 4.0\n'
               'shader_parameter/alt_tex = ExtResource("9_rjc5r")\nshader_parameter/base_is_white = true\n'
               'shader_parameter/alt_invert = false\n')
    out.append(f'[sub_resource type="Resource" id="{key}_mat"]\nscript = ExtResource("12_uvrwf")\n'
               'fill_textures = Array[Texture2D]([ExtResource("ledge_white")])\nfill_texture_z_index = -1\n'
               f'fill_texture_scale = 0.18\nfill_mesh_material = SubResource("{key}_preview")\n')
    return key, '\n'.join(out)


# ── 3. 내부 무늬 ─────────────────────────────────────────────────────────────
# (노드, 바탕이 흰색인가, 왼쪽 x, 오른쪽 x, 줄 범위) — 줄 경계는 ylines 로, 양옆은 nearest_joint 로 줄눈에 맞춘다.
# 마지막 값 = 줄마다 양옆을 흔드는 폭의 배율(좁은 벽은 줄여서 40px 미만 조각이 안 생기게).
INLAYS = [
    ('홀_바닥', False, 2990, 3270, (3610, 3750), 1.0),      # 시작 화면 · 바닥 윗면 3584 에서 35px 아래
    ('우측_덩어리', False, 2596, 2716, (2335, 2460), 0.4),  # 갱도 오른벽(2560~2752) · L2 허브 높이
    ('탑_왼벽', True, 520, 720, (2750, 2890), 1.0),        # 흰 탑 왼벽 · l7~l5 사이 높이
    ('L2_흰바닥', True, 1480, 1780, (2340, 2450), 1.0),    # L2 열림 흰 바닥 · 윗면 2304 에서 41px 아래
]
JITTER_L = [32, 0, 48, 16, 64]
JITTER_R = [36, 0, 18, 54, 0]


def inlay_rects(left, right, lo, hi, jitter=1.0):
    ys = c.ylines(lo, hi)
    out = []
    for i, (a, b) in enumerate(zip(ys, ys[1:])):
        mid = (a + b) / 2
        x0 = c.nearest_joint(left + JITTER_L[i % 5] * jitter, mid)
        x1 = c.nearest_joint(right - JITTER_R[i % 5] * jitter, mid)
        out.append((round(x0, 4), a, round(x1, 4), b))
    return out


def distance(p, a, b):
    dx, dy = b[0] - a[0], b[1] - a[1]
    d = dx * dx + dy * dy
    t = max(0, min(1, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / d)) if d else 0
    return math.hypot(p[0] - a[0] - t * dx, p[1] - a[1] - t * dy)


def validate_inlays(poly, rects):
    # 모든 실제 외곽(구멍·오목 포함)에서 24px 이상 안쪽 — 마감 깊이(최대 24)와 겹치지 않게 (인계 §4).
    for x, y, r, b in rects:
        assert r - x >= 40 and b - y >= 10, (x, y, r, b)
        for p in [(x, y), (r, y), (r, b), (x, b), ((x + r) / 2, (y + b) / 2)]:
            assert c.inside(p, poly), p
            assert min(distance(p, a, z) for a, z in zip(poly, poly[1:])) >= 24, p


def put(block, key, value):
    line = f'{key} = {value}'
    if re.search(r'^' + re.escape(key) + r' = ', block, re.M):
        return re.sub(r'^' + re.escape(key) + r' = .*$', line, block, flags=re.M)
    return block.rstrip() + '\n' + line + '\n\n'


def drop_orphans(text):
    # 선반으로 바뀐 노드가 더 안 쓰는 점·메시·재질 sub_resource 를 지운다(참조가 없어질 때까지 반복).
    while True:
        blocks = re.split(r'(?=^\[(?:sub_resource|node) )', text, flags=re.M)
        used = set(re.findall(r'SubResource\("([^"]+)"\)', text))
        kept = []
        removed = 0
        for b in blocks:
            m = re.match(r'\[sub_resource [^\]]*id="([^"]+)"', b)
            if m and m[1] not in used:
                removed += 1
                continue
            kept.append(b)
        text = ''.join(kept)
        if removed == 0:
            return text


BACKGROUND = '''[gd_scene load_steps=10 format=3]

[ext_resource type="Texture2D" path="res://assets/background/stage_2/layers_v02/01_quiet_wall.png" id="1_wall"]
[ext_resource type="Texture2D" path="res://assets/background/stage_2/layers_v02/02_drains.png" id="2_drains"]
[ext_resource type="Texture2D" path="res://assets/background/stage_2/layers_v02/03_arches.png" id="3_arches"]
[ext_resource type="Texture2D" path="res://assets/background/stage_2/layers_v02/04_mist.png" id="4_mist"]
[ext_resource type="Shader" path="res://shaders/sewer_layer_repeat_v02.gdshader" id="5_shader"]

[sub_resource type="ShaderMaterial" id="ShaderMaterial_wall"]
shader = ExtResource("5_shader")
shader_parameter/opaque_wall = true
shader_parameter/edge_width = 0.06
shader_parameter/haze_color = Color(0.30, 0.30, 0.30, 1)
shader_parameter/atmosphere = 0.55

[sub_resource type="ShaderMaterial" id="ShaderMaterial_drains"]
shader = ExtResource("5_shader")
shader_parameter/opaque_wall = false
shader_parameter/edge_width = 0.045
shader_parameter/haze_color = Color(0.30, 0.30, 0.30, 1)
shader_parameter/atmosphere = 0.25

[sub_resource type="ShaderMaterial" id="ShaderMaterial_arches"]
shader = ExtResource("5_shader")
shader_parameter/opaque_wall = false
shader_parameter/edge_width = 0.06
shader_parameter/haze_color = Color(0.30, 0.30, 0.30, 1)
shader_parameter/atmosphere = 0.12

[sub_resource type="ShaderMaterial" id="ShaderMaterial_mist"]
shader = ExtResource("5_shader")
shader_parameter/opaque_wall = false
shader_parameter/edge_width = 0.08
shader_parameter/haze_color = Color(0.45, 0.45, 0.45, 1)
shader_parameter/atmosphere = 0.45

[node name="하수도_다층배경_v02" type="Node2D"]
editor_description = "stage_2-2 전용 배치 사본(하수도_다층배경_2_1.tscn 과 같은 층·재질·시차). 4608×4352 세로 맵이라 배수구·아치를 위/아래 두 높이에 나눠 두었다: 배수구_1 은 L3 복도(위), 배수구_2 는 홀·탑 밑동(아래), 아치_1 은 왼쪽 위(탑), 아치_2 는 오른쪽 아래(홀). 먼 벽과 안개만 반복하고 건축물은 비반복. 장식 위치는 패럴럭스 좌표 = 카메라 왼위 × Scroll Scale + 화면 안 위치. 이미지·셰이더는 공용 v02 와 공유한다."
texture_filter = 2

[node name="먼벽" type="Parallax2D" parent="."]
z_index = -100
scroll_scale = Vector2(0.12, 0.10)
repeat_size = Vector2(3072, 2048)
repeat_times = 3

[node name="그림" type="Sprite2D" parent="먼벽"]
material = SubResource("ShaderMaterial_wall")
scale = Vector2(2, 2)
texture = ExtResource("1_wall")
centered = false

[node name="배수시설" type="Parallax2D" parent="."]
z_index = -90
scroll_scale = Vector2(0.32, 0.28)

[node name="배수구_1" type="Sprite2D" parent="배수시설"]
modulate = Color(1, 1, 1, 0.55)
material = SubResource("ShaderMaterial_drains")
position = Vector2(700, -560)
scale = Vector2(0.9, 0.9)
texture = ExtResource("2_drains")
centered = false

[node name="배수구_2" type="Sprite2D" parent="배수시설"]
modulate = Color(1, 1, 1, 0.55)
material = SubResource("ShaderMaterial_drains")
position = Vector2(150, 1500)
scale = Vector2(0.85, 0.85)
texture = ExtResource("2_drains")
centered = false

[node name="가까운아치" type="Parallax2D" parent="."]
z_index = -80
scroll_scale = Vector2(0.60, 0.55)

[node name="아치_1" type="Sprite2D" parent="가까운아치"]
modulate = Color(1, 1, 1, 0.72)
material = SubResource("ShaderMaterial_arches")
position = Vector2(-400, -300)
scale = Vector2(2.0, 2.0)
texture = ExtResource("3_arches")
centered = false

[node name="아치_2" type="Sprite2D" parent="가까운아치"]
modulate = Color(1, 1, 1, 0.72)
material = SubResource("ShaderMaterial_arches")
position = Vector2(1900, 2200)
scale = Vector2(1.8, 1.8)
texture = ExtResource("3_arches")
centered = false

[node name="안개" type="Parallax2D" parent="."]
z_index = -70
scroll_scale = Vector2(0.78, 0.70)
scroll_offset = Vector2(0, 640)
repeat_size = Vector2(3072, 2048)
repeat_times = 3

[node name="그림" type="Sprite2D" parent="안개"]
modulate = Color(1, 1, 1, 0.32)
material = SubResource("ShaderMaterial_mist")
scale = Vector2(2, 2)
texture = ExtResource("4_mist")
centered = false
'''


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--apply', action='store_true')
    args = ap.parse_args()
    text = SCENE.read_text(encoding='utf-8')
    if MARKER in text:
        print('Already applied; no rewrite.')
        return
    nodes = c.parse(text)

    # ── 검사: 선반 9 장의 현재 윗면·폭·위치가 빌더 표와 같은가 (다르면 에디터 편집이 있었다 → 중단)
    for name, x0, y0, _ in LEDGES:
        block, pos, poly = nodes[name]
        assert pos == (x0 + HALF_W, y0 + 48), (name, pos)
        assert min(p[1] for p in poly) == y0 and min(p[0] for p in poly) == x0 and max(p[0] for p in poly) == x0 + 2 * HALF_W, name
        assert '6_6fbqg' in block, name  # 흰색 기본지형이어야 한다 (흰 탑)

    # ── 검사: 무늬가 외곽에서 24px 이상 안쪽인가
    inlay_plan = {}
    for name, white, left, right, (lo, hi), jitter in INLAYS:
        rects = inlay_rects(left, right, lo, hi, jitter)
        validate_inlays(nodes[name][2], rects)
        inlay_plan[name] = (white, rects)
        print(f'{name}: 무늬 {len(rects)} 줄 · x {rects[0][0]:.0f}~{rects[0][2]:.0f} · y {rects[0][1]:.0f}~{rects[-1][3]:.0f}')

    # ── 검사: S01 448 이 바닥 높이에서 320 점프를 막는가 (실루엣 바닥띠 ≈ 0.754~0.773 W · 몸 44)
    assert 0.754 * 448 + 44 > 320 + 40, 'S01 너비가 바닥 우회를 못 막는다'
    print('S01 448: 바닥띠 %.0f + 몸 44 = %.0f > 점프 320 (정적 추정)' % (0.754 * 448, 0.754 * 448 + 44))
    print('dry-run PASS' if not args.apply else 'applying...')
    if not args.apply:
        return

    # ── ext_resource 추가 (마지막 ext_resource 뒤)
    ext = ('[ext_resource type="PackedScene" path="res://scenes/지형/하수도/하수도_공중선반_흰색.tscn" id="sewer_air_white"]\n'
           '[ext_resource type="Texture2D" path="res://assets/textures/smartshape/sewer_ledge_v03/white/fill.png" id="ledge_white"]\n'
           '[ext_resource type="Shader" path="res://shaders/sewer_ledge_v03.gdshader" id="ledge_shader"]\n'
           '[ext_resource type="PackedScene" path="res://scenes/장식/하수도_지지구조/삼각지지대.tscn" id="ledge_bracket"]\n'
           '[ext_resource type="Script" path="res://scripts/스마트월드/하수도_내부벽돌.gd" id="color_inlay_script"]\n'
           '[ext_resource type="PackedScene" path="res://scenes/배경/하수도_다층배경_2_2.tscn" id="sewer_background"]\n')
    text = text.replace('\n[sub_resource', '\n' + ext + '\n[sub_resource', 1)

    # ── 1·2. 선반 교체 + 일방통행 콜리전 + 지지대
    resources = ''
    editable = ''
    for i, (name, x0, y0, wall) in enumerate(LEDGES):
        block, pos, _ = nodes[name]
        pts = ledge_points(i, wall)
        key, rs = ledge_resources(name, pts)
        resources += rs + '\n'
        uid = re.search(r'unique_id=(\d+)', block)[1]
        new = (f'[node name="{name}" parent="지형" unique_id={uid} instance=ExtResource("sewer_air_white")]\n'
               f'position = Vector2({c.pair(pos)})\n_points = SubResource("{key}_array")\n'
               f'shape_material = SubResource("{key}_mat")\nmetadata/terrain_style = "공중"\nmetadata/role = "플랫폼"\n'
               f'{MARKER}\n\n')
        # 일방통행: 두 칸 위 선반이 도약 자리 위에 걸친다(머리 96 + 점프 160 > 층 간격 256 − 두께).
        polygon = ', '.join(c.pair(p) for p in pts[:-1])
        new += (f'[node name="CollisionPolygon2D" parent="지형/{name}/StaticBody2D" index="0"]\n'
                f'polygon = PackedVector2Array({polygon})\none_way_collision = true\none_way_collision_margin = 4.0\n\n')
        if wall:
            # 원점 = 밑면이 벽에 닿는 모서리(사용안내 §1). 2-1 A_L2 처럼 벽에서 24px 안쪽 · 밑면 요철보다 3px 위.
            edge = -HALF_W if wall == 'L' else HALF_W
            bx = edge + (24 if wall == 'L' else -24)
            by = min(p[1] for p in pts if abs(p[0] - bx) <= 12) - 3
            new += (f'[node name="벽고정_지지대" parent="지형/{name}" instance=ExtResource("ledge_bracket")]\n'
                    f'position = Vector2({c.pair((bx, by))})\n')
            if wall == 'R':
                new += '"방향" = 1\n'
            new += '\n'
        editable += f'[editable path="지형/{name}"]\n'
        text = text.replace(block, new)

    # ── 3. 내부 무늬: 전용 스크립트 + 시작상태 0 + 로컬 Rect2 배열 + 미리보기 셰이더의 inlay_rects (둘 다 갱신 · 사용법 §1)
    for name, (white, rects) in inlay_plan.items():
        block, pos, _ = nodes[name]
        local = [(x - pos[0], y - pos[1], r - pos[0], b - pos[1]) for x, y, r, b in rects]
        new = put(block, 'script', 'ExtResource("color_inlay_script")')
        new = put(new, '"시작상태"', '0')
        new = put(new, '"내부_바탕흰색"', 'true' if white else 'false')
        array = ', '.join('Rect2(' + c.pair((x, y)) + ', ' + c.pair((r - x, b - y)) + ')' for x, y, r, b in local)
        new = put(new, '"내부_벽돌영역"', 'Array[Rect2]([' + array + '])')
        new = put(new, 'metadata/color_inlays_v1', 'true')
        new = put(new, MARKER.split(' = ')[0], 'true')
        text = text.replace(block, new)
        mat_id = re.search(r'shape_material = SubResource\("([^"]+)"\)', block)[1]
        mat_block = re.search(r'\[sub_resource type="Resource" id="' + re.escape(mat_id) + r'"\]\n(?:.*\n)*?\n', text)[0]
        shader_id = re.search(r'fill_mesh_material = SubResource\("([^"]+)"\)', mat_block)[1]
        packed = ', '.join(c.fmt(v) for rect in local for v in rect) + ', ' + ', '.join(['0'] * (4 * (16 - len(local))))
        params = f'shader_parameter/inlay_count = {len(local)}\nshader_parameter/inlay_rects = PackedVector4Array({packed})\n'
        head = f'[sub_resource type="ShaderMaterial" id="{shader_id}"]\nshader = ExtResource("7_hve3h")\n'
        assert text.count(head) == 1, shader_id
        text = text.replace(head, head + params)

    # ── 4. S01 너비
    s01 = re.search(r'\[node name="S01_흰물"[^\n]*\n(?:.*\n)*?\n', text)[0]
    assert '"크기" = Vector2(64, 480)' in s01
    text = text.replace(s01, s01.replace('"크기" = Vector2(64, 480)', '"크기" = Vector2(448, 480)'))

    # ── 5. Player 점프 높이 명시
    player = re.search(r'\[node name="Player"[^\n]*\n(?:.*\n)*', text)[0]
    assert '점프_높이_칸' not in player
    text = text.replace(player, player.rstrip() + '\n"점프_높이_칸" = 10.0\n')

    # ── 6. 배경 (지형보다 앞 = 뒤에 그려진다)
    text = text.replace('[node name="지형" type="Node2D" parent="."',
                        '[node name="하수도배경" parent="." instance=ExtResource("sewer_background")]\n\n'
                        '[node name="지형" type="Node2D" parent="."', 1)
    BG_SCENE.write_text(BACKGROUND, encoding='utf-8', newline='\n')

    text = text.replace('[node name="stage_2-2"', resources + '[node name="stage_2-2"', 1)
    text = drop_orphans(text)
    text = text.rstrip('\n') + '\n\n' + editable
    text = c.sanitize_resource_ids(text)

    # ── 사후 검사: 선반 9 장 외의 지형 점·위치 불변 · 선반 윗면·폭 불변
    after = c.parse(text)
    assert set(after) == set(nodes)
    for name in nodes:
        assert after[name][1] == nodes[name][1], name
        if name not in {l[0] for l in LEDGES}:
            assert after[name][2] == nodes[name][2], name
    for name, x0, y0, _ in LEDGES:
        poly = after[name][2]
        assert min(p[1] for p in poly) == y0 and min(p[0] for p in poly) == x0 and max(p[0] for p in poly) == x0 + 2 * HALF_W
    SCENE.write_text(text, encoding='utf-8', newline='\n')
    print('Saved', SCENE, 'and', BG_SCENE)


if __name__ == '__main__':
    main()
