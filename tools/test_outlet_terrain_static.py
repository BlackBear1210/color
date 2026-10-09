"""Godot 실행 없이 실제 SS2D 단면과 출수구의 지형 내부 배치를 검사한다."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def span(polygon, y, x):
    # 오목한 지형의 비어 있는 가운데를 지형으로 오인하지 않도록 단면을 짝지어 읽는다.
    hits = []
    for a, b in zip(polygon, polygon[1:] + polygon[:1]):
        if a[1] <= y < b[1] or b[1] <= y < a[1]:
            hits.append(a[0] + (b[0] - a[0]) * (y - a[1]) / (b[1] - a[1]))
    hits.sort()
    return next(((a, b) for a, b in zip(hits[::2], hits[1::2]) if a <= x <= b), None)


def scene_geometry(path):
    source = path.read_text(encoding='utf8')
    blocks = re.split(r'(?=\[(?:sub_resource|node|ext_resource) )', source)
    resources = {re.search(r'id="([^"]+)"', b)[1]: b for b in blocks if b.startswith('[sub_resource')}
    polygons, waters, outlets = [], {}, []
    outlet_id = re.search(r'path="res://scripts/스마트월드/물_힉스필드_출수구.gd" id="([^"]+)"', source)
    for block in blocks:
        if not block.startswith('[node'):
            continue
        name = re.search(r'name="([^"]+)"', block)[1]
        pos = re.search(r'position = Vector2\(([^)]+)\)', block)
        x, y = map(float, pos[1].split(',')) if pos else (0, 0)
        ref = re.search(r'_points = SubResource\("([^"]+)"\)', block)
        if ref and 'parent="지형"' in block:
            ids = re.findall(r'\d+: SubResource\("([^"]+)"\)', resources[ref[1]])
            poly = []
            for ident in ids:
                point = re.search(r'position = Vector2\(([^)]+)\)', resources[ident])
                px, py = map(float, point[1].split(','))
                poly.append((px + x, py + y))
            polygons.append((name, poly))
        size = re.search(r'"크기" = Vector2\(([^)]+)\)', block)
        if size and '"힉스필드_삼색프레임" = true' in block:
            waters[name] = (x, y, float(size[1].split(',')[0]))
        if outlet_id and f'script = ExtResource("{outlet_id[1]}")' in block:
            outlets.append(re.search(r'대상_유체" = NodePath\("\.\./([^"]+)"\)', block)[1])
    return polygons, waters, outlets


def main():
    assert span([(0, 0), (10, 0), (10, 10), (7, 10), (7, 3), (3, 3), (3, 10), (0, 10)], 5, 5) is None
    checked = 0
    screenshot_fit = None
    for path in sorted((ROOT / 'scenes/world_2_클로드').glob('stage_2-[1-7].tscn')):
        polygons, waters, outlets = scene_geometry(path)
        for name in outlets:
            if name not in waters:
                continue
            x, y, width = waters[name]
            fits = []
            for terrain, polygon in polygons:
                if not span(polygon, y - 2, x):
                    continue
                half = max(width / 2 + 12, width / .42 / 2) if width < 160 else width / 2 + 12
                depth = 0
                for step in range(2, 363, 2):
                    section = span(polygon, y - step, x)
                    if not section:
                        break
                    available = min(x - section[0], section[1] - x) - 2
                    if available < width / 2 + 2:
                        break
                    half, depth = min(half, available), step
                if depth >= 8:
                    fits.append((depth, half, terrain))
            if fits:
                depth, half, terrain = max(fits)
                # 원형 관과 얕은 배수구 모두 전체 테가 지형의 단면 안에 들어가야 한다.
                diameter = min(max(width / .42, 56), 360, half * 2, depth - 2)
                round_pipe = width < 160 and diameter >= width / .42
                h = diameter if round_pipe else min(24, depth - 4)
                w = diameter if round_pipe else min(width + 12, half * 2)
                for sample in range(2, int(h) + 1, 2):
                    left, right = span(next(p for n, p in polygons if n == terrain), y - sample, x)
                    assert left <= x - w / 2 and x + w / 2 <= right, (path, name)
                checked += 1
                if path.stem == 'stage_2-7' and name == '흰물_2':
                    screenshot_fit = (width, depth, w, h)
            else:
                print(f'{path.stem}/{name}: 지형 접점 없음 → 기존 연결관 복원')
    assert screenshot_fit is not None, '첨부 화면의 큰 낙수에 지형 접점이 있어야 한다'
    print('stage_2-7/흰물_2 (물 폭, 지형 두께, 장식 폭, 깊이):', screenshot_fit)
    print(f'PASS: 실제 지형에 닿은 출수구 {checked}개가 지형 내부에 배치됨')


if __name__ == '__main__':
    main()
