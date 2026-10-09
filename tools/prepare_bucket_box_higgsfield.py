"""힉스필드 양동이·박스 원본을 투명 PNG로 멱등하게 정리한다."""
from pathlib import Path
import json
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
REVIEW = ROOT / 'docs/visual_review/bucket_box_20261009'
BUCKET = ROOT / 'assets/textures/obstacles/bucket/higgsfield_v1'
BOX = ROOT / 'assets/textures/obstacles/box/higgsfield_v1'


def cutout(source):
    # 분홍 배경만 알파로 빼고 가장자리의 분홍 번짐을 없애 흑백 게임에 맞춘다.
    rgb = np.asarray(source.convert('RGB')).astype(float)
    spill = np.minimum(rgb[:, :, 0], rgb[:, :, 2]) - rgb[:, :, 1]
    alpha = np.clip(1 - np.maximum(spill, 0) / 220, 0, 1)
    alpha[spill > 200] = 0
    gray = np.divide(rgb[:, :, 1], np.maximum(alpha, .01))
    # 원화 금속의 약한 갈색도 중성 회색으로 정리하며 그림 모양은 유지한다.
    out = np.empty((*alpha.shape, 4), dtype=np.uint8)
    out[:, :, :3] = np.clip(gray, 0, 255).astype(np.uint8)[:, :, None]
    out[:, :, 3] = np.rint(alpha * 255).astype(np.uint8)
    frame = Image.fromarray(out)
    bbox = frame.getchannel('A').point(lambda x: 255 if x > 128 else 0).getbbox()
    if bbox is None:
        raise ValueError('배경 제거 후 스프라이트가 비어 있습니다.')
    return frame.crop(bbox)


def tile(frame, size, limit, origin):
    # 원본에서 매번 다시 계산하고 바닥 중앙을 맞춰 반복 실행 시 누적 변형을 막는다.
    scale = min(limit[0] / frame.width, limit[1] / frame.height)
    resized = frame.resize((round(frame.width * scale), round(frame.height * scale)), Image.Resampling.LANCZOS)
    result = Image.new('RGBA', size)
    result.paste(resized, (origin[0] - resized.width // 2, origin[1] - resized.height))
    return result


def main():
    BUCKET.mkdir(parents=True, exist_ok=True)
    BOX.mkdir(parents=True, exist_ok=True)
    source = Image.open(REVIEW / 'source/bucket.png')
    atlas = Image.new('RGBA', (450, 340))
    large = Image.new('RGBA', (900, 680))
    frames = []
    for row, color in enumerate(('black', 'white')):
        for col, state in enumerate(('empty', 'half', 'full')):
            frame = cutout(source.crop((col * source.width // 3, row * source.height // 2,
                                       (col + 1) * source.width // 3, (row + 1) * source.height // 2)))
            small = tile(frame, (150, 170), (130, 150), (75, 160))
            big = tile(frame, (300, 340), (260, 300), (150, 320))
            name = f'{color}_{state}.png'
            small.save(BUCKET / name)
            atlas.paste(small, (col * 150, row * 170))
            large.paste(big, (col * 300, row * 340))
            frames.append({'file': name, 'color': color, 'shots': col, 'fill': col / 2,
                           'atlas_rect': [col * 150, row * 170, 150, 170]})
    atlas.save(BUCKET / 'bucket_fill_atlas.png')
    large.save(REVIEW / 'bucket_fill_large.png')
    frame = cutout(Image.open(REVIEW / 'source/box.png'))
    box = tile(frame, (104, 102), (96, 96), (52, 100))
    box.save(BOX / 'box.png')
    bigbox = tile(frame, (312, 306), (288, 288), (156, 300))
    bigbox.save(REVIEW / 'box_large.png')
    manifest = {'provider': 'Higgsfield', 'model': 'gpt_image_2_5',
                'bucket_job': '8ff4dc86-b41c-494b-9402-45b848bf96cd',
                'box_job': '7a35f4cb-3c4f-47f0-868c-a372303bf112',
                'bucket_origin': [75, 160], 'box_origin': [52, 100],
                'columns': ['empty', 'half', 'full'], 'rows': ['black', 'white'],
                'frames': frames, 'engine_applied': False,
                'note': '그림 자산만 제작. 2발 채움 동작과 엔진 적용은 별도 작업.'}
    (BUCKET / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
    # 정적 시트에서 큰 그림과 실제 크기 그림을 함께 보여 수위 가독성을 확인한다.
    review = Image.new('RGB', (1060, 1110), '#202126')
    review.paste(large, (20, 30), large)
    review.paste(atlas, (35, 730), atlas)
    review.paste(bigbox, (700, 690), bigbox)
    review.paste(box, (550, 770), box)
    d = ImageDraw.Draw(review)
    d.text((25, 8), 'BUCKET: 0 SHOTS / 1 SHOT (50%) / 2 SHOTS (100%)', fill='white')
    d.text((35, 710), 'GAME SIZE: 150 x 170', fill='white')
    d.text((550, 745), 'BOX: 104 x 102', fill='white')
    review.save(REVIEW / 'sprite_review.png')
    print('Saved 6 bucket frames, bucket atlas, box and static review PNG.')


if __name__ == '__main__':
    main()
