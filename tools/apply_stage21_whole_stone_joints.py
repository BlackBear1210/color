"""승인한 2-1 흑백 접합을 실제 줄눈에 맞춘다. 엔진/전체 씬 빌더는 실행하지 않는다."""
import argparse
import math
import re
from pathlib import Path
import apply_stage22_masonry_joint as kit

ROOT = Path(__file__).resolve().parents[1]
SCENE = ROOT / 'scenes/world_2_클로드/stage_2-1.tscn'
ANCHOR = (2600.0, 1200.0)  # 검정 본체의 기존 무늬를 보존하고 흰 조각만 같은 UV 기준에 맞춘다.
TARGETS = ['튜토리얼_흰바닥', '웅덩이_홈_흰']


def lines(lo, hi):
    return sorted(set(round(ANCHOR[1] + (tile * 1024 + y) * .18, 4)
                      for tile in range(-10, 20) for y in kit.ROWS
                      if lo < ANCHOR[1] + (tile * 1024 + y) * .18 < hi))


def joints(y, lo, hi):
    sy = (y - ANCHOR[1]) / .18 % 1024
    row = next(i for i in range(9) if kit.ROWS[i] <= sy < kit.ROWS[i + 1])
    return sorted(set(round(ANCHOR[0] + (tile * 1536 + x) * .18, 4)
                      for tile in range(-20, 20) for x in kit.JOINTS[row]
                      if lo <= ANCHOR[0] + (tile * 1536 + x) * .18 <= hi))


def boundary(poly):
    left, right = min(x for x, y in poly), max(x for x, y in poly)
    top, bottom = min(y for x, y in poly), max(y for x, y in poly)
    start = min(lines(top + 26.0, top + 50.0))  # 갓돌 아래 첫 실제 줄눈부터 물린다.
    levels = lines(start, bottom + 22)
    end = max(y for y in levels if y <= bottom)  # 추가 돌은 원래 밑면을 넘는 첫 한 줄까지만 허용한다.
    levels = [start] + [y for y in levels if y < end] + [end]
    sides = []
    for x, sign in [(left, -1), (right, 1)]:
        pts = [(x, top), (x, start)]
        for i, (a, b) in enumerate(zip(levels, levels[1:])):
            # 반 장~한 장 이내로 교대한다. 각 행의 실제 줄눈을 골라 돌 중간을 자르지 않는다.
            candidates = joints((a + b) / 2, x - 38, x + 38)
            target = x + sign * (19 if i % 2 == 0 else -12)
            joint = min(candidates, key=lambda value: abs(value - target))
            pts.extend([(joint, a), (joint, b)])
        sides.append(kit.compact(pts))
    # 아랫줄의 온전한 돌 일부만 한 줄 내려 물린다. 두 줄 돌출이나 규칙적인 톱니는 만들지 않는다.
    low = min(lines(end, end + 24))
    row_joints = joints((end + low) / 2, sides[0][-1][0], sides[1][-1][0])
    floor = [sides[0][-1]]
    for i, (a, b) in enumerate(zip(row_joints, row_joints[1:])):
        if i % 5 in (1, 3):
            floor.extend([(a, end), (a, low), (b, low), (b, end)])
    floor.append(sides[1][-1])
    return kit.compact(sides[0] + floor[1:] + list(reversed(sides[1]))[1:])


def resources(name, poly, pos, point_id, array_id):
    tag = kit.resource_id('whole_stone_' + name)
    local = [(round(x - pos[0], 4), round(y - pos[1], 4)) for x, y in poly]
    result = []
    for i, point in enumerate(local):
        result.append(f'[sub_resource type="Resource" id="{tag}_{i}"]\nresource_local_to_scene = true\nscript = ExtResource("{point_id}")\nposition = Vector2({kit.pair(point)})\n')
    refs = ',\n'.join(f'{i}: SubResource("{tag}_{i}")' for i in range(len(local)))
    result.append(f'[sub_resource type="Resource" id="{tag}_array"]\nresource_local_to_scene = true\nscript = ExtResource("{array_id}")\n_points = {{\n{refs}\n}}\n_point_order = PackedInt32Array({", ".join(map(str, range(len(local))))})\n_constraints = {{Vector2i(0, {len(local)-1}): 15}}\n_next_key = {len(local)}\n')
    return '\n'.join(result), tag + '_array', local


def verify(before, after, paths):
    count = 0
    for name, path in paths:
        old = [before[name][2], before['좌하_덩어리'][2]]
        new = [after[name][2], after['좌하_덩어리'][2]]
        for a, b in zip(path, path[1:]):
            length = math.dist(a, b)
            for i in range(1, 10):
                for side in (-.25, .25):
                    t = i / 10
                    p = (a[0] + (b[0]-a[0])*t - (b[1]-a[1])/length*side,
                         a[1] + (b[1]-a[1])*t + (b[0]-a[0])/length*side)
                    assert sum(kit.inside(p, poly) for poly in new) == 1, (name, p)
                    assert any(kit.inside(p, poly) for poly in old), (name, p)
                    count += 1
    return count


def main():
    args = argparse.ArgumentParser()
    args.add_argument('--apply', action='store_true')
    apply = args.parse_args().apply
    text = SCENE.read_text(encoding='utf-8')
    # 반복 실행해도 점을 누적하지 않는다. 저장한 식별자로 이미 적용한 씬을 판별한다.
    if 'metadata/whole_stone_joint = true' in text:
        print('already applied; no changes')
        return
    before = kit.parse(text)
    changed = {n: data[2] for n, data in before.items()}
    paths = []
    for name in TARGETS:
        poly = before[name][2]
        left, right = min(x for x, y in poly), max(x for x, y in poly)
        top, bottom = min(y for x, y in poly), max(y for x, y in poly)
        path = boundary(poly)
        # 흰색의 세 접합선을 한 번에 교체하고 검정 본체에는 정확히 역순으로 넣는다.
        indices = [i for i, p in enumerate(poly) if p == (right, top)]
        index = indices[0]
        white_path = list(reversed(path))
        changed[name] = kit.compact(poly[:index] + white_path + [poly[0]])
        black = changed['좌하_덩어리']
        ia, ib = black.index((left, top)), black.index((right, top))
        assert ia < ib and (left, bottom) in black[ia:ib] and (right, bottom) in black[ia:ib]
        changed['좌하_덩어리'] = kit.compact(black[:ia] + path + black[ib+1:])
        paths.append((name, path))
    ext = dict((path, rid) for path, rid in re.findall(r'path="([^"]+)" id="([^"]+)"', text))
    point_id = ext['res://addons/rmsmartshape/shapes/point.gd']
    array_id = ext['res://addons/rmsmartshape/shapes/point_array.gd']
    additions = []
    materials = []
    for name in TARGETS + ['좌하_덩어리']:
        block, pos, _ = before[name]
        res, rid, local = resources(name, changed[name], pos, point_id, array_id)
        additions.append(res)
        replacement = re.sub(r'_points = SubResource\("[^"]+"\)', f'_points = SubResource("{rid}")', block)
        replacement = re.sub(r'^_meshes = .*\n', '', replacement, flags=re.M)
        replacement = replacement.rstrip() + '\nmetadata/whole_stone_joint = true\n\n'
        if name in TARGETS:
            mat_id = 'whole_stone_mat_' + str(TARGETS.index(name))
            path = f'assets/textures/smartshape/sewer_masonry_v02/접합_2-1_{TARGETS.index(name)}.tres'
            material = (ROOT / 'assets/textures/smartshape/sewer_masonry_v02/땅_white.tres').read_text(encoding='utf-8')
            material = re.sub(r' uid="[^"]+"', '', material)
            offset = (ANCHOR[0] - pos[0], ANCHOR[1] - pos[1])
            material = material.rstrip() + f'\nfill_texture_offset = Vector2({kit.pair(offset)})\n'
            materials.append((ROOT / path, material))
            replacement = replacement.replace('_points = ', f'shape_material = ExtResource("{mat_id}")\n_points = ', 1)
            first_sub = text.index('[sub_resource')
            text = text[:first_sub] + f'[ext_resource type="Resource" path="res://{path}" id="{mat_id}"]\n\n' + text[first_sub:]
        text = text.replace(block, replacement)
        # 저장 충돌도 새 공통 경계와 같게 갱신한다. 밟는 외곽/윗면은 그대로 유지된다.
        pattern = rf'(\[node name="CollisionPolygon2D"[^\n]*parent="지형/{re.escape(name)}/StaticBody2D"[^\n]*\]\n)([^\[]*)'
        polygon = 'polygon = PackedVector2Array(' + ', '.join(kit.fmt(v) for p in local[:-1] for v in p) + ')'
        if re.search(pattern, text):
            text = re.sub(pattern, lambda m: m[1] + re.sub(r'polygon = PackedVector2Array\([^)]*\)', polygon, m[2]), text)
        else:
            # 상속한 충돌도 명시 저장한다. 에디터 재생성에 의존하면 이전 프리팹 모양이 남을 수 있다.
            collision = f'[node name="CollisionPolygon2D" parent="지형/{name}/StaticBody2D" index="0"]\n{polygon}\n\n'
            end_nodes = text.index('[editable ')
            text = text[:end_nodes] + collision + text[end_nodes:]
            text += f'[editable path="지형/{name}"]\n'
    first_node = text.index('[node ')
    text = text[:first_node] + '\n'.join(additions) + '\n' + text[first_node:]
    after = kit.parse(text)
    samples = verify(before, after, paths)
    assert all(after[n][2][0] == after[n][2][-1] for n in changed)
    assert max(len(after[n][2]) for n in changed) <= 128
    print(f'validated {samples} seam samples; points: ' + str({n: len(after[n][2])-1 for n in TARGETS + ['좌하_덩어리']}))
    if apply:
        backup = ROOT / 'tmp/whole_stone_20261009'
        backup.mkdir(parents=True, exist_ok=True)
        (backup / SCENE.name).write_text(SCENE.read_text(encoding='utf-8'), encoding='utf-8')
        for path, material in materials:
            path.write_text(material, encoding='utf-8')
        SCENE.write_text(text, encoding='utf-8')
        print('applied')


if __name__ == '__main__':
    main()
