"""2-1~2-5의 지형 원근 선택만 멱등 적용한다. Godot/씬 빌더는 실행하지 않는다."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def apply(text: str) -> tuple[str, int]:
    refs = {m[1]: m[0] for m in re.findall(
        r'\[ext_resource[^\n]*path="([^"]+)"[^\n]*id="([^"]+)"', text)}
    count = 0

    def node(match: re.Match) -> str:
        nonlocal count
        block = match.group()
        instance = re.search(r'instance=ExtResource\("([^"]+)"\)', block)
        if not instance or not refs.get(instance[1], '').startswith('res://scenes/지형/하수도/'):
            return block
        # 좌표/충돌/장치 설정은 손대지 않고 해당 지형의 표시 방식만 선택한다.
        count += 1
        if re.search(r'^"챕터1_원근" = ', block, re.M):
            return re.sub(r'^"챕터1_원근" = .*$', '"챕터1_원근" = true', block, flags=re.M)
        return block.replace('\n', '\n"챕터1_원근" = true\n', 1)

    result = re.sub(r'^\[node[^\n]*\](?:\n(?!\[)[^\n]*)*', node, text, flags=re.M)
    # 2-4의 붕괴 발판도 같은 돌 투영을 쓰되 붕괴 동작은 그대로 유지한다.
    result = result.replace('path="res://scripts/스마트월드/SS2D_붕괴발판.gd"',
                            'path="res://scripts/스마트월드/하수도_붕괴발판.gd"')
    return result, count


if __name__ == '__main__':
    for stage in range(1, 6):
        path = ROOT / f'scenes/world_2_클로드/stage_2-{stage}.tscn'
        raw = path.read_bytes()
        newline = '\r\n' if b'\r\n' in raw else '\n'
        result, count = apply(raw.decode('utf-8').replace('\r\n', '\n'))
        data = result.replace('\n', newline).encode('utf-8')
        if data != raw:
            path.write_bytes(data)
        print(f'{path.name}: {count} terrain nodes')
