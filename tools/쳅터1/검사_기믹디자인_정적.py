"""Godot 없이 광원 정비의 범위·실제 받침 면·재실행 보존성을 검사한다.

도안 시뮬/실제 엔진 검사를 대체하지 않는다. 씬 재생성이나 파일 쓰기는 하지 않는다.
기준은 현재 HEAD이며 다른 작업자의 변경이 함께 있으면 해당 차이도 보고한다.
"""
import json
import math
import re
import subprocess
from pathlib import Path

from 광원_중앙정비 import ROOT, LIGHTS, CHECKS, blocks, update
from 아트_v02_적용 import world_points
import 씬검사
import 기믹
from 도안 import 도안


def original(path):
    return subprocess.check_output(['git', 'show', 'HEAD:' + path.relative_to(ROOT).as_posix()],
                                   cwd=ROOT).decode('utf-8').replace('\r\n', '\n')


def functions(text):
    # 함수 전체를 비교해 그림 작업이 이동·색 판정·충돌 생성 계약을 건드리지 않았는지 확인한다.
    return {m[1]: m[0].strip() for m in re.finditer(r'^func (\w+)\(.*?(?=^func |\Z)', text, re.M | re.S)}


def scene_without_layout(text, stage):
    edits = []
    for m in blocks(text):
        name = re.search(r'name="([^"]+)"', m[0])[1]
        if name in CHECKS.get(stage, {}) or (name.startswith('빛줄기') and int(name[3:]) in LIGHTS.get(stage, {})):
            value = re.sub(r'^(position|"각도"|"길이"|metadata/placement_reason) = [^\n]+\n?', '', m[0], flags=re.M)
            edits.append((m.start(), m.end(), value.strip() + '\n\n'))
    for a, b, value in reversed(edits):
        text = text[:a] + value + text[b:]
    return text.strip()


def main():
    errors, stages, lamps, moving, checkpoint_count = [], [], 0, 0, 0
    for scene in sorted((ROOT / 'scenes/쳅터1/스테이지').glob('*.tscn')):
        stage = int(scene.stem.split('_')[1])
        text = scene.read_text(encoding='utf-8')
        blueprint = ROOT / 'scenes/쳅터1/도안' / (scene.stem + '.json')
        dn = 도안(str(blueprint))
        beams = [g for g in 기믹.목록(dn) if isinstance(g, 기믹.빛줄기)]
        candidate, design, rows = update(scene, blueprint)
        lamps += len(rows)
        moving += len(re.findall(r'^\[node name="움직이는발판\d+" ', text, re.M))
        if candidate != text or design != blueprint.read_text(encoding='utf-8'):
            errors.append(f'{scene.stem}: 정비 도구가 다시 값을 바꿈')
        if scene_without_layout(original(scene), stage) != scene_without_layout(text, stage):
            errors.append(f'{scene.stem}: 허용한 광원 속성 외의 씬 변경')
        errors.extend(f'{scene.stem}: {e}' for e in 씬검사.검사_파일(str(scene))[0])
        surfaces = []
        for m in blocks(text):
            node = m[0]
            if '_points = SubResource' not in node or '유령' in node.splitlines()[0]:
                continue
            _, points = world_points(text, node)
            for a, b in zip(points, points[1:] + points[:1]):
                if abs(a[1] - b[1]) < 0.1 and b[0] > a[0]:
                    surfaces.append((a[0], b[0], a[1]))
        # 실제 편집된 씬의 점 배열을 쓴다. 도안만 보고 옮기면 수작업으로 바뀐 받침을 놓친다.
        for index, (x, y) in LIGHTS.get(stage, {}).items():
            if not any(left < x < right and abs(y - height) < 0.1 for left, right, height in surfaces):
                errors.append(f'{scene.stem}: 빛줄기{index} 목표에 받침 없음')
        for row in rows:
            if row['node'] not in CHECKS.get(stage, {}):
                continue
            x, y = row['target']
            if not any(left < x < right and abs(y - height) < 0.1 for left, right, height in surfaces):
                errors.append(f'{scene.stem}: {row["node"]} 받침 없음')
        # 주기가 있는 빛도 언젠가 켜진다. 두 몸색 모두 안전해야 하므로 켜짐 여부와 무관하게 겹침을 검사한다.
        for m in blocks(text):
            node = m[0]
            if 'parent="체크포인트"' not in node.splitlines()[0]:
                continue
            checkpoint_count += 1
            x, y = map(float, re.search(r'position = Vector2\(([^,]+), ([^)]+)', node).groups())
            name = re.search(r'name="([^"]+)"', node)[1]
            for beam in beams:
                if beam.닿음(x - 22, y - 98, x + 22, y - 1):
                    errors.append(f'{scene.stem}/{name}: 도안의 빛줄기{beam.i} 안에서 부활')
            for g in dn.d.get('기믹', []):
                if g.get('종류') != '반딧불몹':
                    continue
                if any(math.hypot(x - fx * 32, y + dy - fy * 32) <= g.get('반경', 200)
                       for fx, fy in g['멈춤'] for dy in [-8, -48, -88]):
                    errors.append(f'{scene.stem}/{name}: 반딧불 정지점 반경 안에서 부활')
        stages.append({'stage': scene.stem, 'light_nodes': len(rows), 'targets': [r for r in rows if 'target' in r]})
    contracts = {
        'scripts/스마트월드/움직이는발판.gd': ['_다시_만들기', '_physics_process', '위상_초기화', '현재색',
                                      '반대색인가', '명중', '되돌리기', '강제_초기화'],
        'scripts/스마트월드/도약대.gd': ['_재구성', '_physics_process', '_튕김_시작'],
    }
    for name, selected in contracts.items():
        path = ROOT / name
        before, after = functions(original(path)), functions(path.read_text(encoding='utf-8'))
        for fn in selected:
            # 함수 사이 주석 변화는 계약 변화가 아니므로 실행 줄만 비교한다.
            def code(body):
                return [line.strip() for line in body.splitlines() if line.strip() and not line.lstrip().startswith('#')]
            if fn not in before or fn not in after or code(before[fn]) != code(after[fn]):
                errors.append(f'{name}/{fn}: 물리·색 계약 변경')
    result = {'engine_run': False, 'stages': len(stages), 'light_nodes': lamps, 'moving_platforms': moving,
              'checkpoints': checkpoint_count,
              'errors': errors, 'details': stages}
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return int(bool(errors))


if __name__ == '__main__':
    raise SystemExit(main())
