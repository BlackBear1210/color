"""승인된 4×4 시트를 발 기준 640px 프레임과 실시간 잔량 마스크로 정리한다.

사용법: python tools/준비_GRAY_A_캐릭터.py <원본 시트 폴더>
엔진을 실행하지 않으며, 매번 원본에서 계산하므로 반복해도 누적 변형이 없다.
"""
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/characters/paint_head_a'
SIZE = 640


def component(mask):
    # 배경 후광과 발사 시트에 따로 그려진 탄을 제거해 실제 총알과 중복되지 않게 한다.
    seen = np.zeros(mask.shape, dtype=bool)
    groups = []
    for y, x in zip(*np.nonzero(mask)):
        if seen[y, x]:
            continue
        stack = [(int(y), int(x))]
        seen[y, x] = True
        group = []
        while stack:
            yy, xx = stack.pop()
            group.append((yy, xx))
            for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
                ny, nx = yy + dy, xx + dx
                if 0 <= ny < 512 and 0 <= nx < 512 and mask[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    stack.append((ny, nx))
        groups.append(group)
    result = np.zeros(mask.shape, dtype=np.uint8)
    for y, x in max(groups, key=len):
        result[y, x] = 255
    return Image.fromarray(result)


def prepare(source):
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = {'frame_size': SIZE, 'foot_y': 567, 'sources': {}, 'frames': {}}
    for color in ('black', 'white'):
        for motion in ('walk', 'jump', 'shoot', 'push', 'death'):
            name = f'{color}_{motion}'
            filename = f'{name}_projectile.png' if motion == 'shoot' else f'{name}.png'
            path = source / filename
            original = Image.open(path).convert('RGBA')
            if original.size != (2048, 2048):
                raise ValueError(f'{filename}: 2048×2048 시트 필요')
            manifest['sources'][name] = {'file': filename, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
            atlas = Image.new('RGBA', (SIZE * 4, SIZE * 4))
            entries = []
            for i in range(16):
                frame = original.crop((i % 4 * 512, i // 4 * 512, i % 4 * 512 + 512, i // 4 * 512 + 512))
                pixels = np.array(frame)
                solid = component(pixels[:, :, 3] >= 200)
                bbox = solid.getbbox()
                # 가장 큰 연결 덩어리의 가장자리만 남겨 반투명 후광을 지운다.
                from PIL import ImageFilter
                edge = np.array(solid.filter(ImageFilter.MaxFilter(5))) > 0
                pixels[:, :, 3] = np.where(edge, np.clip((pixels[:, :, 3].astype(float) - 90) * 255 / 164, 0, 255), 0)
                frame = Image.fromarray(pixels)
                x0, y0, x1, y1 = bbox
                factor = 500 / (y1 - y0) if motion == 'death' else 500 / 470
                # 죽음은 넓게 눕는 포즈이므로 확대하지 않고 같은 배율을 유지한다.
                factor = min(factor, 500 / 470)
                center = (x0 + x1) / 2
                offset = (round(320 - center * factor), round(567 - y1 * factor))
                resized = frame.resize((round(512 * factor), round(512 * factor)), Image.Resampling.LANCZOS)
                tile = Image.new('RGBA', (SIZE, SIZE))
                tile.paste(resized, offset)
                atlas.paste(tile, (i % 4 * SIZE, i // 4 * SIZE))
                # 위쪽 유리 양쪽 벽에서 탱크 내부를 찾는다. 테두리는 수위 마스크에서 제외한다.
                rgb = pixels[:, :, :3].mean(axis=2)
                bright = (rgb > 110) & (pixels[:, :, 3] > 150)
                spans = []
                for yy in range(y0 + 12, min(y0 + 110, 512)):
                    xx = np.where(bright[yy])[0]
                    xx = xx[(xx >= x0) & (xx < x1)]
                    if len(xx) > 8 and 75 < xx[-1] - xx[0] < 205:
                        spans.append((yy, int(xx[0]), int(xx[-1])))
                tank = None
                if spans and motion != 'death':
                    widths = np.array([r - l for _, l, r in spans])
                    widest = int(np.quantile(widths, .8))
                    broad = [(y, l, r) for y, l, r in spans if r - l >= widest * .90]
                    top, left, right = broad[0]
                    left = int(np.median([l for _, l, _ in broad])) + 9
                    right = int(np.median([r for _, _, r in broad])) - 9
                    top += 9
                    bottom = min(top + round((right - left) * .86), y0 + 175)
                    tank = [left, top, right, bottom]
                muzzle = None
                if motion == 'shoot':
                    # 총 그림의 오른쪽 끝을 발사 원점으로 쓴다. 얼굴 색 판정 좌표는 따로 유지한다.
                    yy, xx = np.nonzero((np.array(solid) > 0))
                    keep = (yy > y0 + 155) & (yy < y1 - 125)
                    xx, yy = xx[keep], yy[keep]
                    tip = int(xx.max())
                    ys = yy[xx >= tip - 5]
                    muzzle = [round(offset[0] + (tip + 3) * factor), round(offset[1] + float(np.quantile(ys, .75)) * factor)]
                entries.append({'source_bbox': list(bbox), 'offset': list(offset), 'scale': factor, 'tank': tank, 'muzzle': muzzle})
            atlas.save(OUT / f'{name}.png', optimize=True)
            entries and manifest['frames'].update({name: entries})
    (OUT / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
    write_frames()
    # 작은 사각 좌표만 전달해 잔량 표시 때문에 대형 텍스처 10장을 더 올리지 않는다.
    rects = {}
    for name, entries in manifest['frames'].items():
        rects[name] = []
        for i, entry in enumerate(entries):
            tank = entry['tank']
            if tank is None:
                rects[name].append([0, 0, 0, 0])
                continue
            x, y = entry['offset']
            scale = entry['scale']
            rects[name].append([(i % 4 * SIZE + x + tank[0] * scale) / (SIZE * 4),
                                (i // 4 * SIZE + y + tank[1] * scale) / (SIZE * 4),
                                (i % 4 * SIZE + x + tank[2] * scale) / (SIZE * 4),
                                (i // 4 * SIZE + y + tank[3] * scale) / (SIZE * 4)])
    muzzles = {color: [entry['muzzle'] for entry in manifest['frames'][f'{color}_shoot']] for color in ('black', 'white')}
    (OUT / 'tank_rects.gd').write_text('extends RefCounted\n# 원본 프레임별 탱크·총구 좌표: 내보내기에도 포함되도록 코드 리소스로 저장한다.\nconst FRAMES = ' + json.dumps(rects) + '\nconst MUZZLES = ' + json.dumps(muzzles) + '\n', encoding='utf-8')
    print(f'10장 정리 완료: {OUT}')


def write_frames():
    lines = ['[gd_resource type="SpriteFrames" format=3]', '']
    motions = ('walk', 'jump', 'shoot', 'push', 'death')
    for color in ('black', 'white'):
        for motion in motions:
            key = f'{color}_{motion}'
            lines.append(f'[ext_resource type="Texture2D" path="res://assets/characters/paint_head_a/{key}.png" id="{key}"]')
    for color in ('black', 'white'):
        for motion in motions:
            for i in range(16):
                key = f'{color}_{motion}'
                lines += ['', f'[sub_resource type="AtlasTexture" id="{key}_{i}"]', f'atlas = ExtResource("{key}")', f'region = Rect2({i % 4 * SIZE}, {i // 4 * SIZE}, {SIZE}, {SIZE})']
    animations = []
    for color in ('black', 'white'):
        for motion, source, frames, fps, loop in (
            ('idle', 'walk', [0], 1, True), ('walk', 'walk', list(range(16)), 20, True),
            ('jump', 'jump', list(range(2, 8)), 18, False), ('fall', 'jump', list(range(8, 12)), 14, False),
            ('land', 'jump', list(range(12, 16)), 22, False), ('shoot', 'shoot', list(range(4, 16)), 45, False),
            ('push', 'push', list(range(16)), 20, True), ('death', 'death', list(range(16)), 20, False)):
            refs = ', '.join('{"duration": 1.0, "texture": SubResource("' + f'{color}_{source}_{i}' + '")}' for i in frames)
            animations.append('{"frames": [' + refs + f'], "loop": {str(loop).lower()}, "name": &"{color}_{motion}", "speed": {fps}.0' + '}')
    lines += ['', '[resource]', 'animations = [' + ',\n'.join(animations) + ']']
    (OUT / 'player_frames.tres').write_text('\n'.join(lines) + '\n', encoding='utf-8')


if __name__ == '__main__':
    prepare(Path(sys.argv[1]))
