"""Godot 없이 원래 걷기 시트의 다리 앞뒤 회전만 검토한다. 실제 게임 캡처가 아니다."""
from pathlib import Path
import json
import math
import re
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/visual_review/player_walk_20261012'


def load():
    source = (ROOT / 'scripts/플레이어_양발보행.gd').read_text(encoding='utf-8')
    result = {}
    for color in ('black', 'white'):
        block = source.split('"' + color + '": {', 1)[1]
        if color == 'black':
            block = block.split('"white":', 1)[0]
        cut = float(re.search(r'"cut": ([\d.]+)', block).group(1))
        result[color] = {'cut': cut}
        for side in ('far', 'near'):
            part = re.search(r'"' + side + r'": (.*?)"outline": PackedVector2Array\((\[.*?\])\)', block, re.S)
            points = lambda text: [np.array(tuple(map(float, v))) for v in re.findall(r'Vector2\(([\d.]+),\s*([\d.]+)\)', text)]
            values = points(part.group(1))
            result[color][side] = {'hip': values[0]}
            result[color][side]['outline'] = points(part.group(2))
    return result


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def rotate(p, a):
    c, s = math.cos(a), math.sin(a)
    return np.array((p[0] * c - p[1] * s, p[0] * s + p[1] * c))


def angle(p):
    return math.atan2(p[1], p[0])


def pose(phase, rest, cut, side):
    return {'angle': math.sin(phase * math.tau) * .28 * (-1 if side == 'far' else 1)}


def skin(p, rest, target):
    hip = rest['hip']
    moved = hip + rotate(p - hip, target['angle'])
    return p + (moved - p) * smooth(hip[1], hip[1] + 18, p[1])


def render_triangle(canvas, image, source, target, render_scale=.5):
    # 시안은 절반 크기, 적용용 시트는 원본 해상도로 같은 변형을 그린다.
    target = np.array(target) * render_scale
    x0, y0 = np.floor(target.min(axis=0)).astype(int)
    x1, y1 = np.ceil(target.max(axis=0)).astype(int) + 1
    if x1 <= x0 or y1 <= y0:
        return
    m = np.column_stack((target - (x0, y0), np.ones(3)))
    try:
        coeff = np.linalg.solve(m, np.array(source)).T
    except np.linalg.LinAlgError:
        return
    tile = image.transform((x1 - x0, y1 - y0), Image.Transform.AFFINE, tuple(coeff.flatten()), Image.Resampling.BICUBIC)
    mask = Image.new('L', tile.size)
    ImageDraw.Draw(mask).polygon([tuple(p - (x0, y0)) for p in target], fill=255)
    tile.putalpha(Image.fromarray(np.minimum(np.array(tile.getchannel('A')), np.array(mask))))
    canvas.alpha_composite(tile, (int(x0), int(y0)))


def render(frame, color, design):
    i = frame // 2
    image = Image.open(ROOT / f'assets/characters/paint_head_a/{color}_walk.png').crop((i % 4 * 640, i // 4 * 640, i % 4 * 640 + 640, i // 4 * 640 + 640)).convert('RGBA')
    upper = image.copy()
    alpha = np.array(upper.getchannel('A'))
    alpha[int(design['cut']):] = 0
    upper.putalpha(Image.fromarray(alpha))
    canvas = Image.new('RGBA', (320, 320))
    canvas.alpha_composite(upper.resize((320, 320), Image.Resampling.LANCZOS))
    for side in ('far', 'near'):
        rest = design[side]
        target = pose(frame / 32, rest, design['cut'], side)
        outline = rest['outline']
        nx, ny = 1, 3
        xx = [outline[0][0], outline[1][0]]
        yy = [outline[0][1], outline[0][1]+9, outline[0][1]+18, outline[2][1]]
        pts = [[np.array((x,y)) for x in xx] for y in yy]
        moved = [[skin(p, rest, target) for p in row] for row in pts]
        for y in range(ny):
            for x in range(nx):
                for indices in (((y,x),(y,x+1),(y+1,x+1)),((y,x),(y+1,x+1),(y+1,x))):
                    tri = [pts[i][j] for i,j in indices]
                    # 완전히 투명한 원화 조각은 렌더 비용만 들므로 검토 그림에서 건너뛴다.
                    bounds = (math.floor(min(p[0] for p in tri)),math.floor(min(p[1] for p in tri)),math.ceil(max(p[0] for p in tri))+1,math.ceil(max(p[1] for p in tri))+1)
                    if image.crop(bounds).getchannel('A').getbbox() is None:
                        continue
                    render_triangle(canvas, image, tri, [moved[i][j] for i,j in indices])
    return canvas


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    designs = load()
    frames = []
    sheets = Image.new('RGB', (1280, 640), '#444950')
    for frame in range(32):
        canvas = Image.new('RGBA', (640, 640), '#444950')
        draw = ImageDraw.Draw(canvas)
        for row, color in enumerate(('black', 'white')):
            old_sheet = Image.open(ROOT / f'assets/characters/paint_head_a/{color}_walk.png')
            i = frame // 2
            old = old_sheet.crop((i % 4 * 640, i // 4 * 640, i % 4 * 640 + 640, i // 4 * 640 + 640)).resize((320, 320), Image.Resampling.LANCZOS)
            new = render(frame, color, designs[color])
            canvas.alpha_composite(old, (0, row * 320))
            canvas.alpha_composite(new, (320, row * 320))
            draw.line((0, row * 320 + 284, 640, row * 320 + 284), fill='#a4a8ad', width=1)
            draw.text((10, row * 320 + 10), 'BEFORE / sheet', fill='white')
            draw.text((330, row * 320 + 10), 'AFTER / leg swing only (offline)', fill='white')
            if frame in (0, 8, 16, 24):
                sheets.paste(new.convert('RGB'), ((frame // 8) * 320, row * 320))
        frames.append(canvas.convert('RGB'))
    frames[0].save(OUT / '원본_다리앞뒤만_전후.gif', save_all=True, append_images=frames[1:], duration=50, loop=0, optimize=False)
    sheets.save(OUT / '원본_다리앞뒤만_주요자세.png')
    print('Offline review saved; this is not an engine capture.')


if __name__ == '__main__':
    main()
