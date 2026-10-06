# -*- coding: utf-8 -*-
"""
목재 지형 윗면·모서리 예시 이미지 — 2026-10-04 Claude (도형님 요청: "윗면을 조금 더 진하게 해서 앞면과 구분 ·
코너 부분까지 디테일 필요")

실제 결 원본(assets/textures/smartshape/wood_deck_v3/grain.png)과 `shaders/wood_deck.gdshaderinc` 의
명도 공식(검정 g×0.66 · 흰 0.66+g×0.52)을 그대로 써서 오프라인으로 그린다 — 엔진 화면이 아니다.

안
  현재  : 지금 셰이더 — 윗면이 앞면보다 **밝다**(검정 ×1.28, 흰 ×1.03) → 윗면·앞면이 한 덩어리로 보인다
  A     : 윗면을 어둡게(검정 ×0.62 · 흰 ×0.78)
  B     : A + 윗면과 앞면 사이 밝은 입술선 1줄 + 앞면 위쪽 그늘(입술 아래 12px)
  C     : B + 모서리 디테일 — 옆면 마감판(세로 판자 + 모따기 빛), 판자 끝 나이테, 윗모서리 쇠 꺾쇠·못
출력: scenes/쳅터1/도안/미리보기/_예시_목재윗면_비교.png
"""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont

저장소 = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
결 = np.asarray(Image.open(os.path.join(저장소, "assets/textures/smartshape/wood_deck_v3/grain.png")).convert("L"), np.float32) / 255.0
출력 = os.path.join(저장소, "scenes", "쳅터1", "도안", "미리보기", "_예시_목재윗면_비교.png")

윗면높이 = 30      # 게임의 데크 윗면 28.8px 에 맞춤
판높이 = 36        # 앞면 판자 한 줄


def 결_샘플(w, h, ox, oy, 가로판=True):
    ys = (np.arange(h)[:, None] + oy) % 결.shape[0]
    xs = (np.arange(w)[None, :] + ox) % 결.shape[1]
    return 결[ys, xs]


def 톤(g, 색):
    """셰이더와 같은 명도 공식."""
    if 색 == "검정":
        return np.clip(g * 0.66, 0.018, 0.25)
    t = np.clip((g - 0.01) / 0.055, 0, 1)
    return (0.12 + (np.minimum(0.84, 0.66 + g * 0.52) - 0.12) * t) * 0.945


def 블록(w, h, 색, 안):
    """앞면 w×h(윗면 포함) 덩어리 하나를 0~1 명도 배열로."""
    img = np.zeros((h, w), np.float32)
    rng = np.random.default_rng(w * 7 + h)
    # ── 앞면: 가로 판자 줄, 줄마다 이음매 엇갈림
    front = 톤(결_샘플(w, h, 37, 120), 색)
    for r, y0 in enumerate(range(윗면높이, h, 판높이)):
        y1 = min(h, y0 + 판높이)
        front[y0:y0 + 2, :] *= 0.35 if 색 == "검정" else 0.55          # 줄 틈
        off = (r * 53) % 140
        for x in range(off, w, 140 + (r % 3) * 30):
            front[y0:y1, x:x + 2] *= 0.35 if 색 == "검정" else 0.55     # 이음매
    img[:] = front
    # ── 윗면: 위에서 본 판자(가로) — 셰이더처럼 3줄
    top = 톤(결_샘플(w, 윗면높이, 300, 40), 색)
    for k in range(1, 3):
        yy = k * 윗면높이 // 3
        top[yy:yy + 1, :] *= 0.5
    for x in range(23, w, 97):
        top[:, x:x + 1] *= 0.55
    if 안 == "현재":
        top = top * (1.28 if 색 == "검정" else 1.03) + (0.02 if 색 == "검정" else 0)
        front *= 0.90 if 색 == "검정" else 0.85
        img[윗면높이:] = front[윗면높이:]
    else:
        top = top * (0.62 if 색 == "검정" else 0.78)
    img[:윗면높이] = top[:윗면높이]
    if 안 in ("B", "C"):
        # 입술선(윗면 끝 모서리가 빛을 받음) + 바로 아래 그늘
        img[윗면높이 - 2:윗면높이, :] = np.clip(img[윗면높이 - 2:윗면높이, :] + (0.10 if 색 == "검정" else 0.12), 0, 1)
        for i in range(12):
            img[윗면높이 + i, :] *= 0.62 + 0.38 * (i / 12)
    if 안 == "C":
        # 옆면 마감판(좌우 18px 세로 판자) + 모따기 빛 + 판자 끝 나이테 + 꺾쇠
        mw = 18
        for side in (0, 1):
            xs = slice(0, mw) if side == 0 else slice(w - mw, w)
            seg = 톤(결_샘플(mw, h, 900 + side * 40, 10).T[:mw, :h].T if False else 결_샘플(h, mw, 500, 60).T, 색)
            img[:, xs] = seg * (0.8 if 색 == "검정" else 0.9)
            edge = 0 if side == 0 else w - 1
            img[:, edge] = np.clip(img[:, edge] + (0.12 if 색 == "검정" else 0.1), 0, 1)          # 모따기 빛
            inner = mw if side == 0 else w - mw - 1
            img[:, inner] *= 0.35                                                               # 마감판 경계 그늘
        # 판자 끝 나이테(앞면 줄마다 옆면 쪽에 작은 동심원)
        for y0 in range(윗면높이 + 6, h - 6, 판높이):
            for cx in (mw // 2, w - mw // 2):
                cy = y0 + 판높이 // 2
                yy, xx = np.ogrid[:h, :w]
                rr = np.hypot((xx - cx) / 1.0, (yy - cy) / 1.6)
                ring = (np.sin(rr * 1.9) > 0.6) & (rr < 8)
                img[ring] *= 0.75
        # 윗모서리 쇠 꺾쇠 + 못
        for cx in (0, w - 26):
            img[윗면높이 - 4:윗면높이 + 20, cx:cx + 26] = 0.30 if 색 == "검정" else 0.42
            img[윗면높이 - 4, cx:cx + 26] += 0.12
            for nx, ny in ((cx + 7, 윗면높이 + 4), (cx + 19, 윗면높이 + 12)):
                img[ny - 2:ny + 2, nx - 2:nx + 2] = 0.55 if 색 == "검정" else 0.2
    return np.clip(img, 0, 1)


def 장면(색, 안):
    """도형님 6번 그림처럼: 회색 배경 앞, 사이에 틈이 있는 두 덩어리."""
    W, H = 640, 300
    bg = np.full((H, W), 0.42, np.float32)
    a = 블록(250, 230, 색, 안)
    b = 블록(250, 230, 색, 안)
    bg[70:300, 0:250] = a
    bg[70:300, 390:640] = b
    return bg


def main():
    안들 = ["현재", "A", "B", "C"]
    설명 = {"현재": "현재 — 윗면이 더 밝다(×1.28) → 앞면과 한 덩어리", "A": "A — 윗면 어둡게(검정 ×0.62 · 흰 ×0.78)",
           "B": "B — A + 입술선 1줄 + 앞면 위쪽 그늘", "C": "C — B + 옆면 마감판·나이테·쇠 꺾쇠(모서리 디테일)"}
    f = ImageFont.truetype(r"C:\Windows\Fonts\malgunbd.ttf", 22)
    f2 = ImageFont.truetype(r"C:\Windows\Fonts\malgun.ttf", 17)
    판 = Image.new("RGB", (640 * 2 + 30, 90 + len(안들) * 340), (230, 225, 215))
    d = ImageDraw.Draw(판)
    d.text((12, 10), "목재 지형 윗면·모서리 예시 (왼쪽 검정 · 오른쪽 흰)", font=ImageFont.truetype(r"C:\Windows\Fonts\malgunbd.ttf", 28), fill=(40, 34, 28))
    d.text((12, 52), "실제 결 원본 grain.png + 지금 셰이더의 명도 공식으로 그린 합성(엔진 화면 아님) · 윗면 30px · 판자 줄 36px",
           font=f2, fill=(80, 70, 60))
    for i, 안 in enumerate(안들):
        y = 90 + i * 340
        d.text((12, y), 설명[안], font=f, fill=(40, 34, 28))
        for j, 색 in enumerate(("검정", "흰")):
            a = (장면(색, 안) * 255).astype(np.uint8)
            판.paste(Image.fromarray(a, "L").convert("RGB"), (10 + j * 650, y + 34))
    os.makedirs(os.path.dirname(출력), exist_ok=True)
    판.save(출력, optimize=True)
    print("생성:", os.path.relpath(출력, 저장소))


if __name__ == "__main__":
    main()
