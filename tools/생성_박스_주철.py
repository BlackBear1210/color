# -*- coding: utf-8 -*-
"""무게 박스 — 주철 무게 궤짝 그림 굽기 (엔진 없이 PNG 를 만든다).

왜:
  예전 박스는 코드로 그린 회색 사각형 + X 선이었다. 호퍼·배관·가시·톱이 전부 주철 원화 재질로 바뀐 뒤
  혼자 벡터 도형이라 튀었다. 2026-09-30 시안 두 벌 중 **시안 1(주철 무게 궤짝)** 로 도형님 확정.
  - 색이 없는 물체다(어느 몸이든 민다 · 사망 판정 없음) → 흑도 백도 아닌 **쇠 중간 회색**.
    검정 바닥 위에서도 흰 바닥 위에서도 "내 색이 아니니 죽는다" 로 읽히면 안 된다.
  - 가운데 둥근 추 표식 + ▼ = "무거워서 버튼을 누른다" 를 글자 없이.
  - 윗면에 밝은 선 = 올라설 수 있는 면.
  새로 그리지 않고 **호퍼 원화(주철 아틀라스)의 금속 결** 을 빌린다 — 호퍼·가시와 재질이 같다.

만드는 것: assets/textures/obstacles/box/cast_iron_v1/box.png  (104 x 102, 게임 1:1 크기)
  판정 상자 96x96 은 그림 안 (4, 4) ~ (100, 100). 바깥 여백 = 외곽선 자리.
  즉 박스 노드 원점(바닥 중앙)이 그림의 (52, 100) 이다.
  ⚠ 이 규격을 바꾸면 scripts/스마트월드/박스.gd 의 `그림_원점` 도 같이 바꿀 것.

게임 줌 1.0 에서 1:1 로 찍히게 4 배로 그린 뒤 줄인다. 씨앗 고정 → 멱등(몇 번 돌려도 같은 그림).

사용:
  python tools/생성_박스_주철.py                  # 굽는다
  python tools/생성_박스_주철.py --미리보기 <폴더>   # 굽고, 4 배 확대 확인 그림도 둔다
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ATLAS = os.path.join(ROOT, "assets", "textures", "obstacles", "hopper", "cast_iron_v1", "hopper_atlas.png")
OUT_DIR = os.path.join(ROOT, "assets", "textures", "obstacles", "box", "cast_iron_v1")
OUT = os.path.join(OUT_DIR, "box.png")

S = 4                      # 내부 배율
W, H = 104, 102            # 게임 크기 그림
OX, OY = 52, 100           # 노드 원점(바닥 중앙)이 그림의 이 자리

# 금속 결 — 호퍼 깔때기 몸통의 밝기 변화만 뽑아 "평균 1" 로 맞춘다(색 기준은 아래에서 따로 준다)
_src = np.asarray(Image.open(ATLAS).convert("RGB")).astype(np.float32)[420:540, 180:330].mean(2)
_src = np.asarray(Image.fromarray(_src.astype(np.uint8)).resize((315, 252), Image.LANCZOS)).astype(np.float32)
GRAIN = np.clip(_src / _src.mean(), 0.72, 1.3)


class 캔버스:
    """게임 좌표(원점 = 바닥 중앙)로 그리는 4 배 RGBA 캔버스."""

    def __init__(s):
        s.W, s.H = W * S, H * S
        s.rgb = np.zeros((s.H, s.W, 3), np.float32)
        s.a = np.zeros((s.H, s.W), np.float32)
        yy, xx = np.mgrid[0:s.H, 0:s.W]
        s.gx = xx / S - OX
        s.gy = yy / S - OY

    def P(s, pts):
        return [((x + OX) * S, (y + OY) * S) for x, y in pts]

    def _m(s, fn):
        m = Image.new("L", (s.W, s.H), 0)
        fn(ImageDraw.Draw(m))
        return np.asarray(m).astype(np.float32) / 255

    def 다각형(s, pts):
        return s._m(lambda d: d.polygon(s.P(pts), fill=255))

    def 사각(s, x0, y0, x1, y1):
        return s.다각형([(x0, y0), (x1, y0), (x1, y1), (x0, y1)])

    def 원(s, cx, cy, r):
        return s._m(lambda d: d.ellipse(s.P([(cx - r, cy - r), (cx + r, cy + r)]), fill=255))

    def 선(s, pts, w):
        return s._m(lambda d: d.line(s.P(pts), fill=255, width=int(w * S)))

    def 칠(s, m, v, alpha=1.0):
        v = np.asarray(v, np.float32)
        col = v[..., None] * np.ones(3) if v.ndim == 2 else np.broadcast_to(v, s.rgb.shape)
        k = (m * alpha)[..., None]
        s.rgb = s.rgb * (1 - k) + col * k
        s.a = s.a + (1 - s.a) * m * alpha

    def 외곽선(s, m, px=2.0, v=0.04):
        d = np.asarray(Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(int(px * S) | 1))).astype(np.float32) / 255
        s.칠(np.clip(d - m, 0, 1), np.full(m.shape, v))

    def 결(s, seed):
        r = np.random.default_rng(seed)
        t = np.tile(GRAIN, (s.H // GRAIN.shape[0] + 2, s.W // GRAIN.shape[1] + 2))
        y0, x0 = r.integers(0, GRAIN.shape[0]), r.integers(0, GRAIN.shape[1])
        return t[y0:y0 + s.H, x0:x0 + s.W]

    def 리벳(s, x, y, r=2.2, base=0.42):
        s.칠(s.원(x + 0.6, y + 0.8, r), np.full(s.gx.shape, 0.03), 0.7)       # 붙은 그림자
        d = np.hypot(s.gx - (x - r * 0.35), s.gy - (y - r * 0.35)) / r
        s.칠(s.원(x, y, r), base * np.clip(1.25 - d * 0.75, 0.35, 1.3))        # 왼위가 밝은 둥근 머리

    def 이미지(s):
        # 미리 곱한 알파로 줄여야 가장자리에 검은/흰 테가 안 생긴다
        pm = np.dstack([np.clip(s.rgb, 0, 1) * s.a[..., None], s.a]) * 255
        im = Image.fromarray(pm.astype(np.uint8), "RGBA").resize((W, H), Image.LANCZOS)
        q = np.asarray(im).astype(np.float32)
        a = q[..., 3:4] / 255
        q[..., :3] = np.where(a > 0, q[..., :3] / np.maximum(a, 1e-3), 0)
        return Image.fromarray(q.clip(0, 255).astype(np.uint8), "RGBA")


def 굽기():
    c = 캔버스()
    x0, x1, y0, y1 = -48, 48, -96, 0          # 판정 상자 96x96 그대로
    몸 = c.사각(x0, y0, x1, y1)
    c.칠(몸, 0.34 * c.결(41))
    # 들어간 가운데 판 — 위는 그늘, 아래로 갈수록 조금 밝다(바닥 반사)
    안 = c.사각(-37, -85, 37, -11)
    c.칠(안, (0.25 + 0.07 * np.clip((c.gy + 85) / 74, 0, 1)) * c.결(42))
    c.칠(c.사각(-37, -85, 37, -82), np.full(몸.shape, 0.05), 0.7)
    c.칠(c.사각(-37, -85, -34, -11), np.full(몸.shape, 0.06), 0.6)
    # X 보강대 — 판 안에서만
    for a, b in (((-35, -83), (35, -13)), ((35, -83), (-35, -13))):
        c.칠(c.선([(a[0] + 1, a[1] + 2), (b[0] + 1, b[1] + 2)], 7.5) * 안, np.full(몸.shape, 0.03), 0.6)
        대 = c.선([a, b], 7.5) * 안
        c.칠(대, 0.40 * c.결(43))
        c.칠(c.선([(a[0], a[1] - 2.8), (b[0], b[1] - 2.8)], 1.0) * 대, np.full(몸.shape, 0.62), 0.55)
    # 가운데 추 표식 + ▼ — "무겁다 · 누른다" 를 글자 없이
    c.칠(c.원(1, -46.5, 13), np.full(몸.shape, 0.03), 0.6)
    d = np.hypot(c.gx + 4, c.gy + 52) / 13
    추 = c.원(0, -48, 13)
    c.칠(추, 0.42 * np.clip(1.2 - d * 0.5, 0.6, 1.2) * c.결(44))
    c.외곽선(추, 1.2)
    c.칠(c.다각형([(-5, -51), (5, -51), (0, -42)]), np.full(몸.shape, 0.08), 0.9)
    # 테두리 빛 — 윗면 밝은 선 = 올라설 수 있다 · 오른/아래는 그늘
    c.칠(c.사각(x0, y0, x1, y0 + 2.2), np.full(몸.shape, 0.75), 0.7)
    c.칠(c.사각(x0, y0, x0 + 2, y1), np.full(몸.shape, 0.6), 0.35)
    c.칠(c.사각(x1 - 2.5, y0, x1, y1), np.full(몸.shape, 0.02), 0.5)
    c.칠(c.사각(x0, y1 - 3, x1, y1), np.full(몸.shape, 0.03), 0.5)
    for x in (-42.5, -21, 0, 21, 42.5):
        c.리벳(x, -90.5)
        c.리벳(x, -5.5)
    for y in (-69, -48, -27):
        c.리벳(-42.5, y)
        c.리벳(42.5, y)
    # 긁힘 — 씨앗 고정
    r = np.random.default_rng(9)
    for _ in range(6):
        x, y = r.uniform(-44, 44), r.uniform(-94, -2)
        c.칠(c.선([(x, y), (x + r.uniform(-6, 6), y + r.uniform(-3, 3))], 0.6) * 몸, np.full(몸.shape, 0.62), 0.35)
    c.외곽선(몸, 2.0)
    return c.이미지()


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    im = 굽기()
    im.save(OUT)
    print("saved", OUT, im.size)
    if "--미리보기" in sys.argv:
        폴더 = sys.argv[sys.argv.index("--미리보기") + 1]
        os.makedirs(폴더, exist_ok=True)
        bg = Image.new("RGBA", (W * 4, H * 4), (40, 40, 44, 255))
        bg.alpha_composite(im.resize((W * 4, H * 4), Image.NEAREST))
        bg.save(os.path.join(폴더, "box_x4.png"))


if __name__ == "__main__":
    main()
