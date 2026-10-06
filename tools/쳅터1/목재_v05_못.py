# -*- coding: utf-8 -*-
"""[2026-10-05 Claude] 목재 v05 — 앞면 판자 못 자리 맵.

도형님 "수정사항" 참고 이미지: 앞면 판자 끝(이음새)마다 못 두 개(위·아래)가 박혀 있다.
grain.png(1536×1024, 가로 판자 9줄)의 세로 이음새를 찾아, 이음새 양옆에 못을 찍은 지도를 만든다.
  R = 못 머리 덮임(0~1) · G = 못 머리 명암(빛 = 왼쪽 위) · B = 못 그림자(오른쪽 아래)
셰이더(wood_deck.gdshaderinc)는 grain 과 같은 UV 로 이 지도를 읽는다 → 앞면 원화와 못이 항상 맞는다.
월드 축척: 텍스처 288px = 월드 32px×9 → 텍스처 1px = 월드 0.28125px.
실행: python tools/쳅터1/목재_v05_못.py
"""
from pathlib import Path
import numpy as np
from PIL import Image

뿌리 = Path(__file__).resolve().parents[2]
원본 = 뿌리 / "assets/textures/smartshape/wood_deck_v3/grain.png"
결과 = 뿌리 / "assets/textures/smartshape/wood_deck_v5/front_nails.png"

배율 = 1.0 / 0.28125            # 월드 1px → 텍스처 px
이음새_거리 = 6.5 * 배율        # 이음새에서 못 가운데까지(월드 6.5px)
반지름 = 2.3 * 배율             # 못 머리(월드 지름 4.6px)
그림자_밀림 = np.array([0.9, 1.2]) * 배율

a = np.asarray(Image.open(원본).convert("L")).astype(np.float32) / 255.0
H, W = a.shape
줄높이 = H / 9.0

R = np.zeros((H, W), np.float32)
G = np.zeros((H, W), np.float32)
B = np.zeros((H, W), np.float32)
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
빛 = np.array([-0.55, -0.65, 0.52])
빛 /= np.linalg.norm(빛)

def 찍기(cx, cy):
    r0 = int(반지름 * 2 + 12)
    x0, x1 = max(0, int(cx) - r0), min(W, int(cx) + r0)
    y0, y1 = max(0, int(cy) - r0), min(H, int(cy) + r0)
    dx = xx[y0:y1, x0:x1] - cx
    dy = yy[y0:y1, x0:x1] - cy
    d = np.sqrt(dx * dx + dy * dy)
    덮임 = np.clip(반지름 + 0.5 - d, 0.0, 1.0)
    nx, ny = dx / 반지름, dy / 반지름
    nz = np.sqrt(np.clip(1.0 - nx * nx - ny * ny, 0.0, 1.0))
    명암 = np.clip(nx * 빛[0] + ny * 빛[1] + nz * 빛[2], 0.0, 1.0)
    명암 = 명암 ** 1.6 * (1.0 - 0.55 * np.clip((d / 반지름 - 0.78) / 0.22, 0.0, 1.0))  # 테두리는 어둡게
    sx, sy = dx - 그림자_밀림[0], dy - 그림자_밀림[1]
    그림자 = np.clip(반지름 + 3.0 - np.sqrt(sx * sx + sy * sy), 0.0, 3.0) / 3.0
    R[y0:y1, x0:x1] = np.maximum(R[y0:y1, x0:x1], 덮임)
    G[y0:y1, x0:x1] = np.where(덮임 > 0, np.maximum(G[y0:y1, x0:x1], 명암), G[y0:y1, x0:x1])
    B[y0:y1, x0:x1] = np.maximum(B[y0:y1, x0:x1], 그림자)

못수 = 0
for 줄 in range(9):
    y0 = 줄 * 줄높이
    안 = a[int(y0 + 줄높이 * 0.18): int(y0 + 줄높이 * 0.82)]
    어둠 = 안.mean(axis=0)
    열 = np.where(어둠 < 0.07)[0]
    if 열.size == 0:
        continue
    # 붙어 있는 열을 한 이음새로 묶는다.
    묶음 = np.split(열, np.where(np.diff(열) > 2)[0] + 1)
    for m in 묶음:
        j = float(m.mean())
        for 쪽 in (-1, 1):
            cx = j + 쪽 * 이음새_거리
            if cx < 반지름 + 2 or cx > W - 반지름 - 2:
                continue
            for t in (0.30, 0.70):
                찍기(cx, y0 + 줄높이 * t)
                못수 += 1

결과.parent.mkdir(parents=True, exist_ok=True)
img = np.stack([R, G, B], axis=-1)
Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8), "RGB").save(결과)
print("못", 못수, "개 →", 결과.relative_to(뿌리))
