"""고정된 배관에서 앞끝이 내려오는 출수 검토 프레임. 원본 RGB·게임의 낙하식을 재사용한다."""
from pathlib import Path
import json
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/textures/obstacles/liquid/pipe_startup_20261009'
REVIEW = ROOT / 'docs/visual_review/pipe_startup_20261009'


def smoothstep(low, high, value):
    t = np.clip((value - low) / (high - low), 0, 1)
    return t * t * (3 - 2 * t)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    REVIEW.mkdir(parents=True, exist_ok=True)
    # 입구 윤곽은 모든 시점에 같은 크기다. 처음부터 끝까지 움직이는 것은 물의 앞끝과 무늬다.
    yy, xx = np.mgrid[:128, :128]
    nx, ny = (xx + .5) / 128 * 2 - 1, (yy + .5) / 128
    upper = .13 + .14 * nx * nx + .012 * np.sin(nx * 13)
    alpha = smoothstep(0, 1 / 128, ny - upper)
    rgba = np.full((128, 128, 4), 255, np.uint8)
    rgba[:, :, 3] = np.rint(alpha * 255).astype(np.uint8)
    Image.fromarray(rgba).save(OUT / 'inlet_profile.png')

    pipe = Image.open(ROOT / 'assets/textures/obstacles/liquid/reference_20261008/pipe_joint_dry_v2.png').convert('RGBA').resize((320, 320))
    body = Image.open(ROOT / 'assets/textures/obstacles/liquid/reference_20261008/water_1_48.png').convert('RGBA')
    size, count, fps = (360, 520), 48, 60
    game_width = 80.0
    scale = 134.0 / game_width
    game_height = 225.0 / scale
    depth = (game_width / .42) * .26
    y0 = 288
    yy, xx = np.mgrid[:size[1], :size[0]]
    x = (xx + .5 - 180) / scale
    y = (yy + .5 - y0) / scale
    half_w = game_width * .5
    # 원본 유체와 똑같은 반암시적 적분 및 1.4배 시간을 쓴다. 먼저 배관 안을 지나야 밖으로 나온다.
    head, velocity, step = -depth * .87, 250.0, 1.4 / fps
    previews, moving_fronts, masks = [], [], []
    atlas = Image.new('RGBA', (128 * 8, 384 * 6))
    for f in range(count):
        if f:
            velocity += 2600.0 * step
            head += velocity * step
        moving_fronts.append(head)
        t = f / fps * 1.4
        frame = int(t * 24) % 48
        cell = np.array(body.crop(((frame % 8) * 256, (frame // 8) * 512, (frame % 8 + 1) * 256, (frame // 8 + 1) * 512)))
        # RGB는 확대하지 않는다. 같은 원본의 무늬가 고정된 입구를 통과하며 아래로 이동한다.
        u = .5 + x / game_width * .50
        # 원본 아틀라스가 이미 아래로 이동한다. 추가 스크롤로 승인된 1.4배 속도를 두 번 적용하지 않는다.
        v = (y / game_height) % 1
        sx = np.clip((u * 256).astype(int), 0, 255)
        sy = np.clip((v * 512).astype(int), 0, 511)
        pixels = np.empty((size[1], size[0], 4), np.uint8)
        pixels[:, :, :3] = cell[sy, sx, :3]
        edge = (1.8 * np.sin(y * .025 - t * 6) + .7 * np.sin(y * .059 - t * 9)) * smoothstep(0, 40, y)
        a = smoothstep(-.6, .7, half_w + edge - abs(x))
        a *= (y >= -depth) & (y <= game_height)
        # 일정한 입구 모양 위로 앞끝이 이동한다. 위쪽 경계가 차오르거나 폭이 커지지 않는다.
        mouth_u = np.clip((.5 + x / game_width) * 128, 0, 127).astype(int)
        mouth_v = np.clip((1 + y / depth) * 128, 0, 127).astype(int)
        a *= np.where(y < 0, rgba[mouth_v, mouth_u, 3] / 255, 1)
        recess = np.maximum(0, 2.2 * np.clip(abs(x) / half_w, 0, 1) ** 2 + .8 * np.sin(x * .21 - t * 11))
        a *= smoothstep(0, 2, head - recess - y)
        if f == 0:
            a[:] = 0
        pixels[:, :, 3] = np.rint(a * 255).astype(np.uint8)
        water = Image.fromarray(pixels)
        canvas = Image.new('RGBA', size, (25, 25, 25, 255))
        canvas.alpha_composite(pipe, (20, 0))
        canvas.alpha_composite(water)
        previews.append(canvas.convert('RGB'))
        # 실제 검토용 48프레임도 저장한다. 게임은 같은 공식을 연속 계산하므로 확대 키프레임이 없다.
        cropped = water.crop((113, 205, 247, 520)).resize((128, 384))
        atlas.paste(cropped, ((f % 8) * 128, (f // 8) * 384))
        masks.append(a)
    atlas.save(OUT / 'outflow_48.png')
    previews[0].save(REVIEW / '출수_앞끝이동_48프레임.webp', save_all=True,
                     append_images=previews[1:], duration=[250] + [17] * 47, loop=0, quality=94)
    sheet = Image.new('RGB', (360 * 6, 520 * 2), '#191919')
    selected = [0, 1, 2, 3, 4, 5, 6, 8, 10, 12, 14, 18]
    for i, f in enumerate(selected):
        sheet.paste(previews[f], ((i % 6) * 360, (i // 6) * 520))
    sheet.save(REVIEW / '출수_앞끝이동_비교.png')
    # 앞끝 도착 전에는 배관 아래 물이 없어야 한다. 소스 폭은 모든 프레임에 고정한다.
    assert not masks[0].any()
    assert all(not a[y >= 0].any() for front, a in zip(moving_fronts, masks) if front <= 0)
    assert all(a < b for a, b in zip(moving_fronts, moving_fronts[1:]))
    (OUT / 'manifest.json').write_text(json.dumps({
        'provider': 'local existing RGB + travelling front', 'frames': count, 'fps': fps,
        'atlas': 'outflow_48.png', 'grid': [8, 6], 'cell': [128, 384],
        'runtime_profile': 'inlet_profile.png', 'outlet_width_changes': False,
        'front_positions': moving_fronts, 'initial_speed': 250, 'gravity': 2600, 'time_scale': 1.4,
        'material': 'existing water_0/1/2_48.png shared by inlet and body',
        'higgsfield_generated': False, 'engine_verified': False,
        'preview_note': 'native formula reconstruction; first empty frame held 250ms for review'
    }, ensure_ascii=False, indent=2), encoding='utf-8')
    print('PASS: fixed outlet, descending front, no water below rim before arrival; 48 frames saved')


if __name__ == '__main__':
    main()
