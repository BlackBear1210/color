"""stage_2-2 하수도 외관 적용(apply_stage22_sewer_look.py) 결과의 정적 검사. Godot 를 돌리지 않는다.

[2026-09-17 Claude] 검사 항목
  · 탑_l2~l10 = 공중선반 프리팹 · 윗면 y·폭 272·position 은 빌더 표 그대로 · 콜리전 덮어쓰기 = 점 · 일방통행 · [editable]
  · 지지대는 벽 쪽 끝 24px 안쪽, 선반 밑면 요철 바로 위 · l2·l6 은 없음
  · 내부 무늬 4 곳: 노드 export 배열 == 미리보기 셰이더 inlay_rects · 모든 외곽에서 24px 이상 · 줄눈 y 에 맞음 · 시작상태 0 · 바탕색 = 프리팹 색
  · S01 448 · S12/S23 그대로 · Player 점프 높이 10 · 배경 인스턴스 · 모든 res:// 존재 · sub_resource 참조 무결 · 고아 없음
  · 선반 9 장을 뺀 나머지 지형의 점·위치, 장치·체크포인트·출구 블록이 HEAD(git) 와 같다 (있으면)
"""
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import apply_stage22_masonry_joint as c
import apply_stage22_sewer_look as look


def blocks_of(text, parent):
    return {re.search(r'name="([^"]+)"', b)[1]: b for b in re.split(r'(?=^\[node )', text, flags=re.M)
            if b.startswith('[node') and f'parent="{parent}"' in b.splitlines()[0]}


def main():
    text = look.SCENE.read_text(encoding='utf-8')
    assert look.MARKER in text, '아직 적용 안 됨'
    nodes = c.parse(text)
    ledge_names = {l[0] for l in LEDGES} if (LEDGES := look.LEDGES) else set()

    # ── 선반
    for i, (name, x0, y0, wall) in enumerate(look.LEDGES):
        block, pos, poly = nodes[name]
        assert 'instance=ExtResource("sewer_air_white")' in block, name
        assert pos == (x0 + look.HALF_W, y0 + 48), name
        assert min(p[1] for p in poly) == y0 and min(p[0] for p in poly) == x0 and max(p[0] for p in poly) == x0 + 272, name
        thick = max(p[1] for p in poly) - y0
        assert 40 <= thick <= 64, (name, thick)
        assert poly[0] == poly[-1] and len(poly) - 1 == (17 if wall is None else 16), name
        corner = (x0 if wall == 'L' else x0 + 272, y0)
        assert (corner in poly) == (wall is not None), (name, '벽 쪽 끝은 직각, 트인 끝은 모따기')
        pat = rf'\[node name="CollisionPolygon2D" parent="지형/{re.escape(name)}/StaticBody2D" index="0"\]\npolygon = PackedVector2Array\(([^)]+)\)\none_way_collision = true\none_way_collision_margin = 4.0\n'
        found = re.search(pat, text)
        assert found, (name, '일방통행 콜리전 덮어쓰기 없음')
        saved = c.vec(found[1])
        expected = tuple(v for p in poly[:-1] for v in (p[0] - pos[0], p[1] - pos[1]))
        assert len(saved) == len(expected) and all(abs(a - b) < .0001 for a, b in zip(saved, expected)), name
        assert f'[editable path="지형/{name}"]' in text, name
        bracket = re.search(rf'\[node name="벽고정_지지대" parent="지형/{re.escape(name)}" instance=ExtResource\("ledge_bracket"\)\]\nposition = Vector2\(([^)]+)\)\n(?:"방향" = (\d)\n)?', text)
        if wall is None:
            assert bracket is None, name
        else:
            assert bracket, name
            bx, by = c.vec(bracket[1])
            assert bx == (-look.HALF_W + 24 if wall == 'L' else look.HALF_W - 24), name
            assert (bracket[2] == '1') == (wall == 'R'), name
            local = [(p[0] - pos[0], p[1] - pos[1]) for p in poly]
            bottom = min(p[1] for p in local if abs(p[0] - bx) <= 12)
            assert abs(by - (bottom - 3)) < .01, (name, by, bottom)
        assert '_meshes' not in block, name

    # ── 내부 무늬
    for name, white, *_ in look.INLAYS:
        block, pos, poly = nodes[name]
        assert 'script = ExtResource("color_inlay_script")' in block, name
        assert '"시작상태" = 0' in block and f'"내부_바탕흰색" = {"true" if white else "false"}' in block, name
        assert ('6_6fbqg' in block) == white, (name, '프리팹 색과 바탕색 불일치')
        rects = [tuple(map(float, m)) for m in re.findall(r'Rect2\(([-\d.]+), ([-\d.]+), ([-\d.]+), ([-\d.]+)\)', re.search(r'"내부_벽돌영역" = (.*)', block)[1])]
        assert 1 <= len(rects) <= 16, name
        world = [(x + pos[0], y + pos[1], x + w + pos[0], y + h + pos[1]) for x, y, w, h in rects]
        look.validate_inlays(poly, world)
        lines = set(c.ylines(min(r[1] for r in world) - 1, max(r[3] for r in world) + 1))
        for x, y, r, b in world:
            assert y in lines and b in lines, (name, y, b, '줄눈 y 아님')
            assert abs(c.nearest_joint(x, (y + b) / 2) - x) < .01 and abs(c.nearest_joint(r, (y + b) / 2) - r) < .01, (name, '줄눈 x 아님')
        mat_id = re.search(r'shape_material = SubResource\("([^"]+)"\)', block)[1]
        mat = re.search(r'\[sub_resource type="Resource" id="' + re.escape(mat_id) + r'"\]\n(?:.*\n)*?\n', text)[0]
        shader_id = re.search(r'fill_mesh_material = SubResource\("([^"]+)"\)', mat)[1]
        shader = re.search(r'\[sub_resource type="ShaderMaterial" id="' + re.escape(shader_id) + r'"\]\n(?:.*\n)*?\n', text)[0]
        assert f'shader_parameter/inlay_count = {len(rects)}' in shader, name
        packed = c.vec(re.search(r'inlay_rects = PackedVector4Array\(([^)]+)\)', shader)[1])
        assert len(packed) == 64, name
        for k, (x, y, w, h) in enumerate(rects):
            assert all(abs(a - b) < .01 for a, b in zip(packed[4 * k:4 * k + 4], (x, y, x + w, y + h))), (name, k, '노드 배열과 미리보기 배열 불일치')

    # ── 물 · 플레이어 · 배경
    devices = blocks_of(text, '장치')
    assert '"크기" = Vector2(448, 480)' in devices['S01_흰물']
    assert '"크기" = Vector2(64, 576)' in devices['S12_흰물'] and '"크기" = Vector2(64, 576)' in devices['S23_검정물']
    root = blocks_of(text, '.')
    assert '"점프_높이_칸" = 10.0' in root['Player'] and '"점프_거리_칸" = 20.0' in root['Player']
    assert 'instance=ExtResource("sewer_background")' in root['하수도배경']
    assert list(root).index('하수도배경') < list(root).index('지형'), '배경은 지형보다 앞(뒤에 그려짐)'
    assert look.BG_SCENE.is_file()
    for path in re.findall(r'path="res://([^"]+)"', text) + re.findall(r'path="res://([^"]+)"', look.BG_SCENE.read_text(encoding='utf-8')):
        assert (c.ROOT / path).is_file(), path
    ids = re.findall(r'\[sub_resource [^\]]*id="([^"]+)"', text)
    assert len(ids) == len(set(ids)) and all(re.fullmatch(r'[A-Za-z0-9_]+', i) for i in ids)
    used = set(re.findall(r'SubResource\("([^"]+)"\)', text))
    assert used <= set(ids), used - set(ids)
    assert set(ids) <= used, ('고아 sub_resource', set(ids) - used)
    ext_ids = re.findall(r'\[ext_resource [^\]]*id="([^"]+)"', text)
    assert set(re.findall(r'ExtResource\("([^"]+)"\)', text)) <= set(ext_ids)

    # ── HEAD 와 비교: 선반 9 장 외 지형 점·위치 · 장치/체크포인트/위험물/출구 블록 (S01 크기만 다름)
    try:
        head = subprocess.run(['git', 'show', 'HEAD:scenes/world_2_클로드/stage_2-2.tscn'], cwd=c.ROOT,
                              capture_output=True, check=True).stdout.decode('utf-8')
    except Exception as e:  # git 이 없거나 경로가 다르면 이 비교만 건너뛴다
        print('HEAD 비교 건너뜀:', e)
        head = None
    if head:
        before = c.parse(head)
        assert set(before) == set(nodes)
        for name in before:
            assert before[name][1] == nodes[name][1], name
            if name not in ledge_names:
                assert before[name][2] == nodes[name][2], name
        for parent in ['장치', '위험물', '체크포인트']:
            a, b = blocks_of(head, parent), blocks_of(text, parent)
            assert set(a) == set(b), parent
            for name in a:
                x, y = a[name], b[name]
                if name == 'S01_흰물':
                    x = x.replace('Vector2(64, 480)', 'Vector2(448, 480)')
                assert x == y, (parent, name)
        for name in ['출구통로', '끝도달_검사점', '페인트코어', 'stage_2-2']:
            assert blocks_of(head, '.').get(name, '') == root.get(name, '') or name == 'stage_2-2', name
        print('HEAD 대비: 선반 9 장 외 지형·장치·체크포인트·출구 불변 PASS')
    print('stage_2-2 sewer look: 선반 9 · 지지대 7 · 무늬 4 · S01 448 · 점프높이 · 배경 · 참조 무결 PASS')


if __name__ == '__main__':
    main()
