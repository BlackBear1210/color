"""생성형 원본을 제작규격 PNG로 정규화한다. Godot/씬 생성기를 실행하지 않는다.

2026-10-05 사용자 승인: Python 리사이즈·회색조·이음매 후처리.
재실행 때 완성본을 입력으로 쓰지 않아 명도와 크기가 누적 변형되지 않는다.
"""
from pathlib import Path
import argparse
import json
import shutil
from collections import deque
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from 규격 import 가구표

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
SOURCE = HERE / '아트_v01_원본'
TARGET = ROOT / 'assets/background/쳅터1/레이어_v01'
MANIFEST = HERE / '아트_v01_생성목록.json'


def seamless(a, axis, width=16):
    b = np.swapaxes(a, axis, 0).copy()
    n = min(width, len(b) // 4)
    shared = (b[0] + b[-1]) / 2
    left, right = shared - b[0], shared - b[-1]
    for i in range(n):
        t = i / (n - 1)
        w = 1 - t*t*(3-2*t)
        b[i] += left*w
        b[-1-i] += right*w
    # 끝 두 열/행을 맞춰 축소 필터에서도 날카로운 경계가 생기지 않게 한다.
    b[0] = b[-1] = (b[1] + b[-2]) / 2
    return np.swapaxes(b, 0, axis)


def specs():
    # 기존 파일이 잘못되어 있어도 그 크기를 재사용하지 않고 제작규격에서 다시 정한다.
    result = {f'가구/{n}.png': (w*32,h*32) for n,(w,h,_) in 가구표.items()}
    result.update({f'벽지/{n}.png': (512,512) for n in ('다마스크','줄무늬','꽃무늬','판자','벽돌')})
    result.update({'띠/징두리_판넬.png':(512,288),'띠/천장_몰딩.png':(512,64),'띠/걸레받이.png':(512,48),'낡음/먼지.png':(64,256)})
    for name,count,size in [('얼룩',4,(320,260)),('벗겨짐',3,(220,300)),('금',3,(260,260)),('찢김',2,(300,360))]:
        result.update({f'낡음/{name}_{i}.png':size for i in range(1,count+1)})
    return result


def prepare(item, size):
    name = item['name']
    # 수정 생성본도 원본별 파일명으로 보관해 이전 후보와 혼동하지 않는다.
    cached = SOURCE / '생성원본' / Path(item['source']).name
    cached.parent.mkdir(parents=True, exist_ok=True)
    if not cached.exists():
        shutil.copy2(item['source'], cached)
    im = Image.open(cached).convert('RGBA')
    if name == '벽지/꽃무늬.png':
        # 생성기가 8행 대신 9행을 그려 타일 경계의 간격이 벌어졌다.
        # 온전한 네 잎 문양 한 주기를 잘라 64px 간격·32px 엇갈림으로 다시 타일링한다.
        w,h = im.size
        unit = im.crop((round(w*.102),round(h*.0065),round(w*.248),round(h*.1095))).resize((64,64),Image.Resampling.LANCZOS)
        cell = np.asarray(unit).copy()
        for channel in range(3):
            cell[:,:,channel] = np.uint8(np.clip(seamless(seamless(cell[:,:,channel].astype(float),1,6),0,6),0,255))
        row = np.tile(cell,(1,8,1))
        im = Image.fromarray(np.concatenate([np.roll(row,32*(i%2),axis=1) for i in range(8)],axis=0))
    if name in ('띠/천장_몰딩.png', '띠/걸레받이.png'):
        # 생성 원본 아래의 빈 배경을 제거하고 실제 몰딩만 규격 띠로 만든다.
        im = im.crop((0, 0, im.width, round(im.height * 0.51)))
    transparent = name.startswith(('가구/', '낡음/'))
    if transparent:
        alpha = im.getchannel('A')
        if alpha.getextrema()[0] == 255:
            raise ValueError(f'{name}: 실제 투명 알파가 없는 생성 원본')
        if name != '낡음/먼지.png':
            box = alpha.point(lambda a: 255 if a > 4 else 0).getbbox()
            if not box:
                raise ValueError(f'{name}: 빈 이미지')
            im = im.crop(box)
    im = im.resize(size, Image.Resampling.LANCZOS)
    a = np.asarray(im.getchannel('A'), dtype=np.uint8).copy()
    gray = np.asarray(im.convert('L'), dtype=np.float32)
    if name.startswith('벽지/'):
        if name == '벽지/줄무늬.png':
            # 줄의 한가운데를 자르지 않고 빈 종이 부분에서 반복 경계를 맞춘다.
            gray = np.roll(gray,32,axis=1)
        gray = seamless(seamless(gray, 1), 0)
        gray -= gray.mean()
        gray = 107 + gray * (15 / max(1, np.abs(gray).max()))
        a[:] = 255
    elif name.startswith('띠/'):
        gray = seamless(gray, 1)
        gray -= gray.mean()
        gray = 82 + gray * (27 / max(1, np.abs(gray).max()))
        a[:] = 255
    else:
        visible = gray[a > 4]
        lo, hi = np.percentile(visible, [1, 99])
        t = np.clip((gray-lo) / max(1, hi-lo), 0, 1)
        if name.startswith('가구/'):
            # 본체 18~40%와 얇은 하이라이트만 남겨 흑백 지형보다 뒤로 물러나게 한다.
            gray = 46 + 56*np.minimum(t/0.94, 1) + 25*np.maximum((t-0.94)/0.06, 0)
            if name == '가구/문_열림.png':
                gray = np.where(t < 0.12, 24 + t*180, gray)
                # 배경 제거기가 문 안쪽까지 지운 경우 출구의 어두운 구멍을 복원한다.
                # 바깥 투명 영역과 연결되지 않은 중앙 구멍만 채우므로 프레임 밖은 보존된다.
                sy,sx = a.shape[0]//2,a.shape[1]//2
                if a[sy,sx] < 64:
                    seen = {(sy,sx)}
                    queue = deque(seen)
                    border = False
                    while queue:
                        y,x = queue.popleft()
                        if y in (0,a.shape[0]-1) or x in (0,a.shape[1]-1):
                            border = True
                        for ny,nx in ((y-1,x),(y+1,x),(y,x-1),(y,x+1)):
                            if 0<=ny<a.shape[0] and 0<=nx<a.shape[1] and a[ny,nx]<64 and (ny,nx) not in seen:
                                seen.add((ny,nx))
                                queue.append((ny,nx))
                    if not border:
                        for y,x in seen:
                            a[y,x],gray[y,x] = 255,24
            elif name == '가구/창문.png':
                # 주문서에서 유리만 밝은 회색 예외다. 중앙 창살은 그대로 두고 유리만 올린다.
                yy,xx = np.mgrid[:size[1],:size[0]]
                glass = (xx>size[0]*.31)&(xx<size[0]*.69)&(yy>size[1]*.15)&(yy<size[1]*.83)&(t>.55)
                gray[glass] = 145+(t[glass]-.55)*70
        else:
            gray = 48 + t*85
            if name.startswith('낡음/얼룩_'):
                # 물 자국이 회벽처럼 밝게 뜨지 않도록 반투명한 짙은 안료로 제한한다.
                gray = 48 + t*35
                a = np.rint(a.astype(float)*0.65).astype(np.uint8)
            elif name.startswith('낡음/금_'):
                gray = 46 + t*35
            elif name == '낡음/먼지.png':
                # 엔진이 가로로 늘리므로 열별 무늬/명도 차이를 없애고 알파만 아래로 늘린다.
                gray[:] = 48
                a = np.repeat(np.rint(np.linspace(0,153,size[1])[:,None]).astype(np.uint8),size[0],axis=1)
    out = np.empty((*gray.shape, 4), dtype=np.uint8)
    out[:, :, :3] = np.clip(np.rint(gray), 1, 254).astype(np.uint8)[:, :, None]
    out[:, :, 3] = a
    result = Image.fromarray(out)
    if name.startswith('가구/'):
        # 큰 원본의 희미한 가장자리 픽셀이 축소 때 사라져 바닥에 1px 뜨는 것을 막는다.
        for _ in range(3):
            box = result.getchannel('A').point(lambda v: 255 if v>16 else 0).getbbox()
            if box == (0,0,*size):
                break
            result = result.crop(box).resize(size,Image.Resampling.LANCZOS)
    return result


def inspect(im, name, size):
    a = np.asarray(im)
    rgb, alpha = a[:, :, :3], a[:, :, 3]
    assert im.size == size, (name, im.size, size)
    assert np.array_equal(rgb[:, :, 0], rgb[:, :, 1])
    assert np.array_equal(rgb[:, :, 1], rgb[:, :, 2])
    visible = rgb[:, :, 0][alpha > 0]
    report = dict(name=name, size=list(size), mean=round(float(visible.mean()), 2),
                  min=int(visible.min()), max=int(visible.max()),
                  transparent_pixels=int((alpha == 0).sum()))
    if name.startswith(('벽지/', '띠/')):
        assert np.array_equal(a[:, 0], a[:, -1]), name
        report['seam_lr_max'] = 0
    if name.startswith('벽지/'):
        assert np.array_equal(a[0], a[-1]), name
        assert abs(report['mean']-107) < 1
        assert report['min'] >= 92 and report['max'] <= 122
        report['seam_tb_max'] = 0
    if name.startswith('가구/'):
        ceiling = Path(name).stem in ('창문', '액자_팔각', '액자', '샹들리에', '벽등')
        assert alpha[0 if ceiling else -1].max() > 4, f'{name}: 부착선에서 뜸'
        assert report['transparent_pixels'] > 0
    return report


def contact_sheet(files, output, scale=1):
    font = ImageFont.truetype('C:/Windows/Fonts/malgun.ttf', 15)
    cw, ch, cols = 310, 350, 4
    sheet = Image.new('RGB', (cw*cols, ch*((len(files)+cols-1)//cols)), (107,)*3)
    draw = ImageDraw.Draw(sheet)
    for i, p in enumerate(files):
        im = Image.open(p).convert('RGBA')
        im.thumbnail((cw-20, ch-45), Image.Resampling.LANCZOS)
        x, y = (i % cols)*cw, (i//cols)*ch
        sheet.paste(im, (x+(cw-im.width)//2, y+ch-im.height-8), im)
        draw.text((x+10, y+8), p.stem, font=font, fill=(220,)*3)
    sheet.save(output)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--require-complete', action='store_true')
    args = parser.parse_args()
    output = TARGET if args.apply else SOURCE / '완성본'
    sizes = specs()
    items = json.loads(MANIFEST.read_text(encoding='utf-8'))
    if args.require_complete:
        assert {i['name'] for i in items} == set(sizes), '주문서 46개 중 누락된 원본이 있음'
    reports, files = [], []
    for item in items:
        im = prepare(item, sizes[item['name']])
        reports.append(inspect(im, item['name'], sizes[item['name']]))
        p = output / item['name']
        p.parent.mkdir(parents=True, exist_ok=True)
        im.save(p, optimize=True)
        files.append(p)
    SOURCE.mkdir(exist_ok=True)
    (SOURCE / '검사결과.json').write_text(json.dumps(reports, ensure_ascii=False, indent=2), encoding='utf-8')
    contact_sheet(files, SOURCE / '전체_검토판.png')
    print(f'검사 통과 {len(reports)}개 / {output}')


if __name__ == '__main__':
    main()
