"""하수도 2-1~2-7의 누름/고정색 승강기 표시만 멱등 적용한다. 씬을 다시 생성하지 않는다."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def apply(text):
    resources = {i: p for p, i in re.findall(r'\[ext_resource[^\n]*path="([^"]+)"[^\n]*id="([^"]+)"', text)}
    count = 0
    parts = re.split(r'(?=\[node )', text)
    for i, block in enumerate(parts):
        refs = re.findall(r'(?:script|instance)\s*=\s*ExtResource\("([^"]+)"\)', block)
        paths = [resources.get(ref, '') for ref in refs]
        # 칠하기 승강기는 기존 퍼즐 그림을 유지한다. 고정색 주철만 같은 격자 원근으로 바꾼다.
        pressure = any(p.endswith('/압력버튼.gd') for p in paths)
        lift = any(p.endswith('/움직이는발판.tscn') for p in paths) and '"칠하기_가능" = false' in block
        if not pressure and not lift:
            continue
        # 직접 만든 버튼은 script 연결 뒤에 전용 속성을 읽어야 한다.
        # 헤더 직후에 쓰면 AnimatableBody2D에는 아직 이 속성이 없어 설정이 유실된다.
        newline = '\r\n' if '\r\n' in block else '\n'
        block = re.sub(r'^"챕터1_원근" = (?:true|false)\r?\n', '', block, flags=re.M)
        script = re.search(r'^script\s*=\s*ExtResource\("[^"\n]+"\)\r?\n', block, re.M)
        if pressure and script is None:
            raise ValueError('압력 버튼 스크립트 연결이 없습니다.')
        # PackedScene 승강기는 인스턴스 생성 시 스크립트가 이미 붙어 있다.
        at = script.end() if script else block.index('\n') + 1
        block = block[:at] + '"챕터1_원근" = true' + newline + block[at:]
        parts[i] = block
        count += 1
    return ''.join(parts), count


if __name__ == '__main__':
    for stage in range(1, 8):
        path = ROOT / f'scenes/world_2_클로드/stage_2-{stage}.tscn'
        before = path.read_bytes()
        after, count = apply(before.decode('utf-8'))
        assert apply(after)[0] == after, path
        # 기존 줄바꿈/좌표/연결/리소스를 그대로 두고 선택 속성만 추가한다.
        data = after.encode('utf-8')
        if data != before:
            path.write_bytes(data)
        print(f'{path.name}: pressure/lift {count}')
