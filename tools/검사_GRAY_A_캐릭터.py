"""Godot를 켜지 않고 시트 경계·프레임 참조·수위 데이터·스크립트 문법을 확인한다."""
import json
import re
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'assets/characters/paint_head_a'


def check(preview_dir, validator=None):
    manifest = json.loads((ASSETS / 'manifest.json').read_text(encoding='utf-8'))
    frames = (ASSETS / 'player_frames.tres').read_text(encoding='utf-8')
    assert len(re.findall(r'\[sub_resource type="AtlasTexture"', frames)) == 160
    assert len(re.findall(r'"name": &"', frames)) == 16
    declared = set(re.findall(r'id="([^"]+)"', frames))
    assert set(re.findall(r'SubResource\("([^"]+)"\)', frames)) <= declared
    assert len(manifest['sources']) == 10
    for name, entries in manifest['frames'].items():
        image = Image.open(ASSETS / f'{name}.png')
        assert image.size == (2560, 2560) and image.mode == 'RGBA'
        assert len(entries) == 16
        for i, entry in enumerate(entries):
            tile = image.crop((i % 4 * 640, i // 4 * 640, i % 4 * 640 + 640, i // 4 * 640 + 640))
            assert tile.getbbox() is not None
            assert tile.getpixel((0, 0))[3] == 0
            pixels = np.array(tile)
            yy, xx = np.nonzero(pixels[:, :, 3] > 200)
            assert 564 <= int(yy.max()) <= 570, (name, i, int(yy.max()))
            assert int(xx.min()) > 1 and int(xx.max()) < 638, (name, i, '좌우 잘림')
            if not name.endswith('death'):
                assert entry['tank'] is not None, (name, i)
                left, top, right, bottom = entry['tank']
                assert left < right and top < bottom
            if name.endswith('shoot'):
                mx, my = entry['muzzle']
                assert 0 < mx < 640 and 0 < my < 640
    shader = (ROOT / 'shaders/paint_head.gdshader').read_text(encoding='utf-8')
    assert shader.isascii()
    scene = (ROOT / 'scenes/player/Player.tscn').read_text(encoding='utf-8')
    assert 'paint_head_anim.gd' in scene and 'paint_head_a/player_frames.tres' in scene
    # 물리 충돌과 게임 규칙의 핵심 파일은 바꾸지 않았는지 별도 git diff로도 확인한다.
    if validator:
        sys.path.insert(0, str(validator))
        from gdtoolkit.parser import parser
        paths = ['scripts/paint_head_anim.gd', 'scripts/gun.gd', 'scripts/proto/proto_gun.gd',
                 'scripts/proto/player_shoot_anim.gd', 'scripts/스마트월드/총.gd',
                 'scripts/스마트월드/월드.gd', 'scripts/스마트월드/stage_2_5_월드.gd',
                 'scripts/쳅터1/연결구.gd', 'assets/characters/paint_head_a/tank_rects.gd',
                 'scripts/스마트월드/페인트_코어.gd', 'scripts/proto/tile_paint_map.gd',
                 'scripts/proto/stage_lab.gd', 'scripts/ui/페인트_HUD.gd', 'scripts/ui/페인트_관성.gd',
                 'tools/build_스테이지_1_2층방.gd', 'tools/build_집_배경스테이지.gd',
                 'tools/build_집_복도계단.gd', 'tools/하수도_빌더_공통.gd', 'tools/test_페인트_7발_보행.gd']
        for path in paths:
            parser.parse((ROOT / path).read_text(encoding='utf-8'))
        print(f'GDScript 정적 구문 검사: {len(paths)}개 통과 (엔진 타입 검사는 아님)')
    preview_dir.mkdir(parents=True, exist_ok=True)
    preview(manifest, preview_dir)
    print('시트 10장 / 프레임 160개 / 애니메이션 16개 / 셰이더 ASCII / 투명 배경 검사 통과')


def preview(manifest, destination):
    # 셰이더의 수위 치환을 재현한 에셋 검토용 그림이며 실제 게임 캡처가 아니다.
    canvas = Image.new('RGB', (960, 700), '#35393d')
    draw = ImageDraw.Draw(canvas)
    for ci, color in enumerate(('black', 'white')):
        image = Image.open(ASSETS / f'{color}_walk.png').crop((0, 0, 640, 640)).convert('RGBA')
        entry = manifest['frames'][f'{color}_walk'][0]
        left, top, right, bottom = entry['tank']
        x, y = entry['offset']
        scale = entry['scale']
        rect = [round(x + left * scale), round(y + top * scale), round(x + right * scale), round(y + bottom * scale)]
        for col, fill in enumerate((0.0, .5, 1.0)):
            tile = image.copy()
            pixels = np.array(tile)
            l, t, r, b = rect
            pixels[t:b, l:r] = [189, 189, 189, 41]
            waterline = t + round((b - t) * (1 - fill * .88))
            if fill > 0:
                ink = 11 if color == 'black' else 240
                pixels[waterline:b, l:r] = [ink, ink, ink, 247]
            tile = Image.fromarray(pixels).resize((300, 300), Image.Resampling.LANCZOS)
            canvas.paste(tile, (col * 320 + 10, ci * 340 + 35), tile)
            draw.text((col * 320 + 115, ci * 340 + 10), f'{color}  {int(fill * 100)}%', fill='white')
    canvas.save(destination / 'GRAY_A_잔량_에셋미리보기.png')
    sheet = Image.new('RGBA', (1600, 640), '#35393d')
    for ci, color in enumerate(('black', 'white')):
        for mi, motion in enumerate(('walk', 'jump', 'shoot', 'push', 'death')):
            image = Image.open(ASSETS / f'{color}_{motion}.png')
            index = 9 if motion == 'death' else (5 if motion == 'shoot' else 2)
            tile = image.crop((index % 4 * 640, index // 4 * 640, index % 4 * 640 + 640, index // 4 * 640 + 640)).resize((320, 320), Image.Resampling.LANCZOS)
            sheet.alpha_composite(tile, (mi * 320, ci * 320))
            ImageDraw.Draw(sheet).text((mi * 320 + 20, ci * 320 + 8), f'{color} {motion}', fill='white')
    sheet.convert('RGB').save(destination / 'GRAY_A_모션_에셋미리보기.png')


if __name__ == '__main__':
    check(Path(sys.argv[1]), Path(sys.argv[2]) if len(sys.argv) > 2 else None)
