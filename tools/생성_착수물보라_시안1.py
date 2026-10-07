"""1번 시안의 낮고 넓은 물살을 48프레임으로 굽는다. Godot 실행 없음.

긴 고정 곡선을 없애고 물막의 팽창/파열과 물방울 낙하를 한 주기로 묶는다.
고정 씨앗과 시간식으로 계산하므로 반복 실행해도 같은 파일이 나온다.
"""
from pathlib import Path
import math
import random
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/textures/obstacles/liquid/impact_concept_a'
REVIEW = ROOT / 'docs/visual_review/water_impact_white_20261007'
W, H, CX, GY, SS = 384, 128, 192, 112, 3
COUNT, COLS, FPS = 48, 8, 60
CYCLE = COUNT / FPS


def frame(index):
    t = index / FPS
    img = Image.new('RGBA', (W * SS, H * SS))

    def ellipse(x, y, rx, ry, alpha):
        # 물방울을 한 알씩 분리해 그려 선이나 촉수처럼 이어지지 않게 한다.
        box = tuple(round(v * SS) for v in (x-rx, y-ry, x+rx, y+ry))
        ImageDraw.Draw(img).ellipse(box, fill=(248, 248, 248, int(alpha)))

    def polygon(points, alpha, rim=False):
        layer = Image.new('RGBA', img.size)
        draw = ImageDraw.Draw(layer)
        coords = [(round(x*SS), round(y*SS)) for x, y in points]
        draw.polygon(coords, fill=(241, 241, 241, int(alpha)))
        if rim:
            draw.line(coords[:6], fill=(255, 255, 255, min(255, int(alpha)+70)), width=SS)
        img.alpha_composite(layer)

    # 바닥의 얇은 흐름은 충돌점에 붙이고 끝으로 갈수록 사라지게 한다.
    for side in (-1, 1):
        for j in range(26):
            run = j * 5.2
            y = GY + math.sin(j*0.8-t*math.tau/CYCLE)*0.5
            ellipse(CX+side*run, y, 4.5, 0.7, 90*(1-run/145))

    rng = random.Random(10701)
    # 물막이 낮게 자라 옆으로 펼쳐진 뒤 짧게 끊어진다. 좌우 시계는 독립이다.
    for side in (-1, 1):
        for jet in range(4):
            phase = rng.random()
            run_size = 24+jet*12+rng.random()*12
            height_size = 13+jet*3+rng.random()*6
            age = (t/CYCLE + phase) % 1.0
            progress = age / 0.43
            if progress >= 1:
                continue
            run = run_size * min(1, progress*2.7)
            height = height_size * math.sin(progress*math.pi)
            base = CX + side*(25+jet*1.8)
            top = []
            bottom = []
            # 파열 뒤에는 뿌리 쪽 막을 지워 분리된 짧은 물살만 남긴다.
            cut = max(0, (progress-0.55)*1.8)
            for k in range(6):
                u = cut + (1-cut)*k/5
                x = base+side*run*u
                # 위로 말리는 곡선 대신 바깥으로 뻗는 낮은 쐐기형 물막을 만든다.
                y = GY-2-height*u*(1-0.15*u)
                top.append((x, y))
                thickness = (1.2+5.5*math.sin(u*math.pi))*(1-progress*0.4)
                bottom.append((x, y+thickness))
            fade = min(1, progress*7)*min(1, (1-progress)*4)
            polygon(top+list(reversed(bottom)), 155*fade, rim=True)
            ellipse(top[-1][0], top[-1][1], 1.7, 1.0, 230*fade)

    rng = random.Random(10703)
    # 낮은 짧은 파편을 더해 시안의 방사형 부채꼴을 채우고 긴 두 줄만 보이지 않게 한다.
    for i in range(16):
        side = -1 if i % 2 == 0 else 1
        phase, length, rise = rng.random(), rng.uniform(10, 32), rng.uniform(4, 14)
        base = CX+side*rng.uniform(24, 40)
        progress = ((t/CYCLE+phase) % 1)/0.32
        if progress >= 1:
            continue
        reach = length*min(1, progress*3)
        high = rise*math.sin(progress*math.pi)
        fade = min(1, progress*8)*min(1, (1-progress)*5)
        polygon([(base, GY-1), (base+side*reach, GY-2-high),
                 (base+side*reach*0.7, GY-high*0.5), (base+side*3, GY)], 175*fade)

    rng = random.Random(10702)
    for i in range(40):
        side = -1 if i % 2 == 0 else 1
        phase, vx, vy = rng.random(), rng.uniform(115, 240), rng.uniform(105, 225)
        sec = ((t/CYCLE+phase) % 1)*CYCLE
        x = CX+side*(rng.uniform(24, 37)+vx*sec)
        y = GY-3-vy*sec+450*sec*sec
        rad = rng.uniform(0.65, 1.6)
        if y > GY+1 or abs(x-CX) > 165:
            continue
        fade = min(1, sec/0.035)*min(1, max(0, (GY+1-y)/4))
        # 물방울은 비행 방향으로 짧게 늘어나고 다시 바닥으로 떨어진다.
        ellipse(x, y, rad*1.4, rad, 230*fade)

    # 착수 거품은 조밀하게 유지하되 1~7px 안에서 끓어오르게 한다.
    for i in range(44):
        x = CX + (i-21.5)*1.65
        wave = math.sin(t*math.tau/CYCLE*3+i*2.4)
        y = GY-2-(2+wave*1.6)*(1-abs(i-21.5)/24)
        ellipse(x, y, 1.6+(wave+1)*0.5, 1.2+(wave+1)*0.9, 220)
    return img.resize((W, H), Image.Resampling.LANCZOS)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    REVIEW.mkdir(parents=True, exist_ok=True)
    frames = [frame(i) for i in range(COUNT)]
    sheet = Image.new('RGBA', (W*COLS, H*(COUNT//COLS)))
    previews = []
    for i, image in enumerate(frames):
        sheet.paste(image, ((i%COLS)*W, (i//COLS)*H))
        canvas = Image.new('RGB', (W, H), (27, 27, 27))
        draw = ImageDraw.Draw(canvas)
        draw.rectangle((CX-27, 0, CX+27, GY), fill=(196, 196, 196))
        draw.line((0, GY+2, W, GY+2), fill=(90, 90, 90), width=2)
        canvas.paste(image, (0, 0), image)
        previews.append(canvas.resize((W*2, H*2), Image.Resampling.NEAREST))
    sheet.save(OUT / 'impact_a_48.png')
    # 실제 게임과 구별되는 프레임 전용 미리보기. 생성형 시안을 검증 캡처로 쓰지 않는다.
    previews[0].save(REVIEW / '시안1_동작_프레임미리보기.webp', save_all=True,
                     append_images=previews[1:], duration=round(1000/FPS), loop=0, lossless=True)
    contact = Image.new('RGB', (W*4, H*3), (27, 27, 27))
    for j, i in enumerate(range(0, COUNT, 4)):
        contact.paste(previews[i].resize((W,H)), ((j%4)*W, (j//4)*H))
    contact.save(REVIEW / '시안1_동작_12프레임.png')
    print(f'48 frames, {W}x{H}, 60 FPS, 0.8s loop; atlas: {OUT / "impact_a_48.png"}')


if __name__ == '__main__':
    main()
