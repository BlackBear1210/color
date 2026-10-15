"""챕터1 광원의 국소 배치만 정비한다. 기본은 읽기 전용이며 Godot/씬 생성기를 실행하지 않는다.

--apply는 아래에서 검토한 노드의 좌표·광선 각도/길이만 바꾼다. 도안도 같은 값으로 맞추되
나머지 JSON 서식과 씬 블록은 보존한다. 절대 목표값을 써서 재실행해도 누적 이동하지 않는다.
넓은 바닥의 중간 체크포인트와 거울·반딧불 경로는 퍼즐의 동선이므로 일괄 중앙 이동하지 않는다.
"""
import argparse
import json
import math
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REASON = '2026-10-15: 광원/착지점을 받침 상판의 가운데에 정렬. 색·주기·연결·지형 점은 보존.'
# 천장빛은 x를, 창문빛은 창문을 고정한 채 각도를 바꾼다. 목표 y는 실제 편집된 씬의 첫 지형 면이다.
LIGHTS = {
    1: {1: (1600, 1568)},
    2: {1: (1584, 896), 2: (2800, 992)},
    3: {1: (2528, 1696)},
    # 06의 두 번째 빛은 가운데로 옮기면 위 선반을 관통한다(도안 전후 시뮬로 확인). 기존 안전한 빈틈을 쓴다.
    6: {1: (4048, 1184)},
    7: {1: (336, 832)},
    8: {1: (1328, 1152), 2: (2880, 896)},
    9: {1: (1440, 3328)},
    10: {4: (5152, 928)},
    11: {1: (4016, 1888)},
    12: {2: (4096, 896)},
    13: {2: (1760, 992), 3: (3232, 992)},
    16: {1: (3136, 1088)},
}
# 가로로 긴 바닥의 여러 저장점은 역할을 유지한다. 빛/도약대와 겹치는 중앙 후보(02·10·13)는 제외했다.
CHECKS = {
    1: {'체크03': 288, '체크04': 2464, '체크_색전환': 1968},
    3: {'체크06': 1952}, 4: {'체크03': 2704},
    5: {'체크02': 1616, '체크05': 1600}, 6: {'체크03': 3488},
    7: {'체크02': 1408, '체크04': 2416}, 8: {'체크03': 3104},
    9: {'체크02': 1856, '체크03': 448}, 11: {'체크04': 6640},
    14: {'체크02': 1056, '체크03': 1056},
    16: {'체크03': 1856, '체크05': 2816},
    17: {'체크02': 2448, '체크03': 4640}, 18: {'체크04': 3168},
}


def blocks(text):
    return list(re.finditer(r'^\[node [^\n]+\]\n.*?(?=^\[|\Z)', text, re.M | re.S))


def number(block, key, default):
    found = re.search(r'^"' + re.escape(key) + r'" = ([^\n]+)', block, re.M)
    return float(found[1]) if found else default


def property_set(block, key, value):
    line = key + ' = ' + value
    pattern = r'^' + re.escape(key) + r' = [^\n]+'
    return re.sub(pattern, lambda _: line, block, flags=re.M) if re.search(pattern, block, re.M) else block.rstrip() + '\n' + line + '\n\n'


def array_items(text, key):
    """JSON 전체를 다시 쓰지 않고 배열 원소의 범위만 찾아 기존 탭·공백을 보존한다."""
    match = re.search('"' + key + r'"\s*:\s*\[', text)
    if not match:
        return []
    at = match.end()
    result = []
    while True:
        while text[at].isspace() or text[at] == ',':
            at += 1
        if text[at] == ']':
            return result
        value, length = json.JSONDecoder().raw_decode(text[at:])
        result.append((at, at + length, value))
        at += length


def update(scene, blueprint):
    source = scene.read_text(encoding='utf-8')
    design = blueprint.read_text(encoding='utf-8')
    stage = int(scene.stem.split('_')[1])
    nodes = blocks(source)
    checkpoints = [m for m in nodes if 'parent="체크포인트"' in m[0].splitlines()[0]]
    light_items = [item for item in array_items(design, '기믹') if item[2].get('종류') == '빛줄기']
    edits, json_edits, rows = [], [], []
    for m in nodes:
        block = m[0]
        name = re.search(r'name="([^"]+)"', block)[1]
        if not (name.startswith(('빛줄기', '체크', '촛불')) or name in ('반사빛길', '양초')):
            continue
        row = {'node': name, 'changed': False}
        pos = re.search(r'^position = Vector2\(([^,]+), ([^)]+)\)', block, re.M)
        if not pos:
            continue
        x, y = map(float, pos.groups())
        new = block
        if name.startswith('빛줄기'):
            index = int(name.removeprefix('빛줄기'))
            target = LIGHTS.get(stage, {}).get(index)
            if target:
                a, b, obj = light_items[index - 1]
                obj = dict(obj)
                tx, ty = target
                if obj.get('근원') == '창문':
                    angle = round(math.degrees(math.atan2(ty - y, tx - x)), 5)
                    length = round(math.hypot(tx - x, ty - y), 5)
                    new = property_set(new, '"각도"', str(angle))
                    obj['각도'] = angle
                else:
                    x = tx
                    length = ty - y
                    # 구형 빛줄기의 x는 왼쪽 변, 신형 x는 광원 중심이다.
                    obj['x'] = tx / 32 - (obj.get('두께', 2) * 0.5 if '근원' not in obj and '각도' not in obj else 0)
                obj['길이'] = length / 32
                obj['_디자인_이유'] = REASON
                new = property_set(new, 'position', f'Vector2({x:g}, {y:g})')
                new = property_set(new, '"길이"', str(length))
                json_edits.append((a, b, json.dumps(obj, ensure_ascii=False, indent=2)))
                row['target'] = target
        elif name in CHECKS.get(stage, {}):
            x = CHECKS[stage][name]
            new = property_set(new, 'position', f'Vector2({x:g}, {y:g})')
            ci = checkpoints.index(m)
            a, b, point = array_items(design, '체크')[ci]
            json_edits.append((a, b, json.dumps([x / 32 - 0.5, point[1]])))
            row['target'] = [x, y]
        if new != block:
            new = property_set(new, 'metadata/placement_reason', json.dumps(REASON, ensure_ascii=False))
            # 마지막 노드에 메타데이터를 붙일 때 파일 끝 빈 줄을 계속 만들지 않는다.
            new = new.rstrip() + ('\n' if m.end() == len(source) else '\n\n')
            edits.append((m.start(), m.end(), new))
            row['changed'] = True
        rows.append(row)
    for a, b, value in reversed(edits):
        source = source[:a] + value + source[b:]
    for a, b, value in sorted(json_edits, reverse=True):
        design = design[:a] + value + design[b:]
    return source, design, rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    for scene in sorted((ROOT / 'scenes/쳅터1/스테이지').glob('*.tscn')):
        blueprint = ROOT / 'scenes/쳅터1/도안' / (scene.stem + '.json')
        source, design, rows = update(scene, blueprint)
        if args.apply:
            if source != scene.read_text(encoding='utf-8'):
                scene.write_text(source, encoding='utf-8')
            if design != blueprint.read_text(encoding='utf-8'):
                blueprint.write_text(design, encoding='utf-8')
        print(json.dumps({'stage': scene.stem, 'apply': args.apply, 'lights': rows}, ensure_ascii=False))


if __name__ == '__main__':
    main()
