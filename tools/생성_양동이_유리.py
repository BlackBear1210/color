# -*- coding: utf-8 -*-
"""양동이 — 쇠살 유리 들통 그림 굽기 (엔진 없이 PNG 를 만든다).

왜:
  예전 양동이는 코드로 그린 사각형이었고, 물이 찼는지가 안쪽 띠 한 줄로만 보였다.
  도형님(2026-09-30): "양동이 안에 물이 차는 걸 보고 싶다" → 시안 A(쇠살 유리 들통) 확정.
  - 몸통 = 흐린 유리(반투명). 물이 바닥부터 차오르는 게 보인다.
  - 쇠살·테·입구 테 = **몸 색**(검정/흰/회색). 색이 곧 "누가 밀 수 있나" 라서 유리가 아니라 쇠살이 색을 맡는다.
  - 물은 그림에 굽지 않는다 — 수위가 실시간으로 변하니 `양동이.gd` 가 **두 겹 사이에** 그린다.
  재질은 호퍼 원화(주철 아틀라스)의 금속 결을 빌린다(가시·톱·박스와 같다).

만드는 것: assets/textures/obstacles/bucket/glass_v1/bucket_atlas.png  (450 x 340, 게임 1:1 크기)
  칸 150 x 170 · 열 = 색(0 검정 · 1 흰색 · 2 회색) · 행 0 = 뒤 겹(유리) · 행 1 = 앞 겹(쇠살·테·광택·손잡이)
  칸 안에서 노드 원점(바닥 중앙)은 (75, 160). 몸통 = 위 y −100 (반폭 47) ~ 아래 y −8 (반폭 39).
  ⚠ 이 규격을 바꾸면 scripts/스마트월드/양동이.gd 의 상수(`칸_크기`·`칸_원점`·`몸_*`)도 같이 바꿀 것.

게임 줌 1.0 에서 1:1 로 찍히게 4 배로 그린 뒤 줄인다. 씨앗 고정 → 멱등.

사용:
  python tools/생성_양동이_유리.py                  # 굽는다
  python tools/생성_양동이_유리.py --미리보기 <폴더>   # 굽고, 3 배 확대 확인 그림도 둔다
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ATLAS = os.path.join(ROOT, "assets", "textures", "obstacles", "hopper", "cast_iron_v1", "hopper_atlas.png")
OUT_DIR = os.path.join(ROOT, "assets", "textures", "obstacles", "bucket", "glass_v1")
OUT = os.path.join(OUT_DIR, "bucket_atlas.png")

S = 4
CW, CH = 150, 170          # 칸
OX, OY = 75, 160           # 칸 안의 노드 원점
TOP, BOT, TW, BW = -100, -8, 47, 39
PAINT = {0: 0.085, 1: 0.86, 2: 0.44}      # 쇠살 칠 밝기(색 번호 = ColorDefs)
IRON = 0.40

_src = np.asarray(Image.open(ATLAS).convert("RGB")).astype(np.float32)[420:540, 180:330].mean(2)
_src = np.asarray(Image.fromarray(_src.astype(np.uint8)).resize((315, 252), Image.LANCZOS)).astype(np.float32)
GRAIN = np.clip(_src / _src.mean(), 0.72, 1.3)


def 반폭(y):
    return TW + (BW - TW) * (y - TOP) / (BOT - TOP)


class 캔버스:
    def __init__(s):
        s.W, s.H = CW * S, CH * S
        s.rgb = np.zeros((s.H, s.W, 3), np.float32)
        s.a = np.zeros((s.H, s.W), np.float32)
        yy, xx = np.mgrid[0:s.H, 0:s.W]
        s.gx = xx / S - OX
        s.gy = yy / S - OY
        s.O = np.ones(3)

    def P(s, pts):
        return [((x + OX) * S, (y + OY) * S) for x, y in pts]

    def _m(s, fn):
        m = Image.new("L", (s.W, s.H), 0)
        fn(ImageDraw.Draw(m))
        return np.asarray(m).astype(np.float32) / 255

    def 다각형(s, pts):
        return s._m(lambda d: d.polygon(s.P(pts), fill=255))

    def 타원(s, cx, cy, rx, ry):
        return s._m(lambda d: d.ellipse(s.P([(cx - rx, cy - ry), (cx + rx, cy + ry)]), fill=255))

    def 선(s, pts, w):
        return s._m(lambda d: d.line(s.P(pts), fill=255, width=max(1, int(w * S)), joint="curve"))

    def 칠(s, m, col, alpha=1.0):
        """알파를 곱하지 않은 색끼리 over 합성 — 반투명 유리가 제대로 겹친다."""
        col = np.asarray(col, np.float32)
        if col.ndim == 0:
            col = np.full(s.rgb.shape, float(col), np.float32)
        elif col.ndim == 1:
            col = np.broadcast_to(col, s.rgb.shape)
        elif col.ndim == 2:
            col = col[..., None] * s.O
        k = np.clip(m * alpha, 0, 1)
        na = k + s.a * (1 - k)
        w = (k / np.maximum(na, 1e-4))[..., None]
        s.rgb = s.rgb * (1 - w) + col * w
        s.a = na

    def 외곽선(s, m, px=1.6, v=0.04):
        d = np.asarray(Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(int(px * S) | 1))).astype(np.float32) / 255
        s.칠(np.clip(d - m, 0, 1), v)

    def 결(s, seed):
        r = np.random.default_rng(seed)
        t = np.tile(GRAIN, (s.H // GRAIN.shape[0] + 2, s.W // GRAIN.shape[1] + 2))
        y0, x0 = r.integers(0, GRAIN.shape[0]), r.integers(0, GRAIN.shape[1])
        return t[y0:y0 + s.H, x0:x0 + s.W]

    def 원통(s, x0, x1, hi=0.32, lo=0.55, spec=0.0):
        t = np.clip((s.gx - x0) / (x1 - x0), 0, 1)
        return 1 - lo * (np.abs(t - hi) / max(hi, 1 - hi)) ** 1.6 + spec * np.exp(-((t - hi) / 0.05) ** 2)

    def 리벳(s, x, y, r=2.0, base=0.42):
        s.칠(s.타원(x + 0.6, y + 0.8, r, r), 0.03, 0.7)
        d = np.hypot(s.gx - (x - r * 0.35), s.gy - (y - r * 0.35)) / r
        s.칠(s.타원(x, y, r, r), base * np.clip(1.25 - d * 0.75, 0.35, 1.3))

    def 이미지(s):
        pm = np.dstack([np.clip(s.rgb, 0, 1) * s.a[..., None], s.a]) * 255
        im = Image.fromarray(pm.astype(np.uint8), "RGBA").resize((CW, CH), Image.LANCZOS)
        q = np.asarray(im).astype(np.float32)
        a = q[..., 3:4] / 255
        q[..., :3] = np.where(a > 0, q[..., :3] / np.maximum(a, 1e-3), 0)
        return Image.fromarray(q.clip(0, 255).astype(np.uint8), "RGBA")


def 몸통(c):
    return c.다각형([(-TW, TOP), (TW, TOP), (BW, BOT), (-BW, BOT)])


def 뒤겹(색):
    """유리 — 흐린 회색 · 가장자리가 조금 더 진하다(두께). 뒤 배경이 비친다."""
    c = 캔버스()
    m = 몸통(c)
    c.칠(m, (0.62, 0.64, 0.67), 0.30)
    가장자리 = np.clip((np.abs(c.gx) / np.maximum(반폭(np.clip(c.gy, TOP, BOT)), 1) - 0.8) * 5, 0, 1)
    c.칠(m * 가장자리, (0.8, 0.82, 0.85), 0.25)
    return c.이미지()


def 앞겹(색):
    c = 캔버스()
    m = 몸통(c)
    # 유리 앞 광택 — 물 위에 겹쳐야 "유리 너머의 물" 로 읽힌다
    for x, w, a in ((-31, 3.2, 0.35), (-24, 1.3, 0.25), (27, 1.0, 0.12)):
        c.칠(c.선([(x, TOP + 8), (x * 0.86, BOT - 6)], w) * m, (1, 1, 1), a)
    c.외곽선(m, 1.4, 0.05)
    p = PAINT[색]
    g = c.결(91 + 색)
    검정보정 = 0.06 if 색 == 0 else 0.0          # 검정 칠도 어두운 배경에서 윤곽이 읽히게 반사광을 조금

    def 살(xt, xb, w):
        sm = c.다각형([(xt - w, TOP + 2), (xt + w, TOP + 2), (xb + w, BOT - 2), (xb - w, BOT - 2)])
        c.칠(sm, p * (1 + (g - 1) * 0.5) * c.원통(xt - w, xt + w, hi=0.3, lo=0.4) + 검정보정)
        c.외곽선(sm, 1.1)
    살(-TW + 3, -BW + 3, 3.5)
    살(TW - 3, BW - 3, 3.5)
    살(-24, -20, 1.8)
    살(24, 20, 1.8)

    def 테(y, h):
        wt, wb = 반폭(y) + 1.5, 반폭(y + h) + 1.5
        tm = c.다각형([(-wt, y), (wt, y), (wb, y + h), (-wb, y + h)])
        c.칠(tm, p * (1 + (g - 1) * 0.5) * c.원통(-wt, wt, spec=0.3) + 검정보정 + 0.01)
        c.칠(c.다각형([(-wt, y), (wt, y), (wt, y + 1), (-wt, y + 1)]), 0.75, 0.5)
        c.외곽선(tm, 1.3)
        for xx in (-wt * 0.75, 0, wt * 0.75):
            c.리벳(xx, y + h / 2, 1.6)
    테(-96, 8)          # 가운데 테는 없다 — 수위를 가리지 않게
    테(-14, 9)
    rim = c.타원(0, TOP, TW + 3, 7)
    c.칠(rim, (p + 검정보정) * g)
    c.외곽선(rim, 1.3)
    c.칠(c.타원(0, TOP + 0.5, TW - 2, 4.6), 0.05, 0.9)          # 입구 안 = 어둠
    # 귀 + 손잡이(쇠 둥근막대 · 가운데 나무 손잡이)
    for sx in (-1, 1):
        ear = c.다각형([(sx * 40, -98), (sx * 52, -98), (sx * 52, -86), (sx * 44, -80), (sx * 40, -80)])
        c.칠(ear, IRON * 0.95 * c.결(70 + sx))
        c.외곽선(ear, 1.3)
        c.리벳(sx * 47, -92, 2.4)
    pts = [(-47 * np.cos(t), -92 - 44 * np.sin(t)) for t in np.linspace(0, np.pi, 40)]
    hm = c.선(pts, 3.2)
    c.칠(c.선([(x + 1, y + 1.5) for x, y in pts], 3.4), 0.02, 0.55)
    c.외곽선(hm, 1.2)
    c.칠(hm, IRON * 1.05)
    c.칠(c.선(pts[3:20], 1.0), 0.66, 0.6)
    grip = c.다각형([(-13, -140), (13, -140), (13, -132), (-13, -132)])
    yy = c.gy
    c.칠(grip, 0.30 * (0.9 + 0.1 * np.sin(c.gx * 1.3 + np.sin(yy) * 2)))
    c.외곽선(grip, 1.2)
    return c.이미지()


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    atlas = Image.new("RGBA", (CW * 3, CH * 2), (0, 0, 0, 0))
    for 색 in (0, 1, 2):
        atlas.paste(뒤겹(색), (CW * 색, 0))
        atlas.paste(앞겹(색), (CW * 색, CH))
    atlas.save(OUT)
    print("saved", OUT, atlas.size)
    if "--미리보기" in sys.argv:
        폴더 = sys.argv[sys.argv.index("--미리보기") + 1]
        os.makedirs(폴더, exist_ok=True)
        bg = Image.new("RGBA", atlas.size, (40, 40, 44, 255))
        bg.alpha_composite(atlas)
        bg.resize((atlas.width * 3, atlas.height * 3), Image.NEAREST).save(os.path.join(폴더, "bucket_atlas_x3.png"))


if __name__ == "__main__":
    main()
