# -*- coding: utf-8 -*-
"""넓은 물 출수구 시안 부품 굽기 (엔진 없이 PNG 를 만든다) — ★시안★

왜 (2026-10-04 도형님: "배관 입구는 작은데 물의 너비는 큰 경우가 많아"):
  하수도 주철 배관은 지름 40 고정인데, 물은 64~576 까지 쓴다. 넓은 물 위에 40 짜리 관 끝만 있으면
  "관 아래 허공에서 넓은 물막이 시작" 하는 것처럼 보인다.
  1 차 시안(슬롯관 · 수조 · 노즐줄)은 도형님 기각(2026-10-05): **"배관 입구에서 나오는 것이 아니야."**
  → 물은 반드시 **관 입구**에서 나와야 한다. 2 차 시안:
    A 큰관   : 관 안지름 = 물 폭. 관 자체를 키운다(얇은 물은 "관 입구를 조금씩 조정" 과 같은 규칙)
    B 벽관   : 뒷벽에서 정면으로 나온 큰 관 입구(하수 배출관). 관 안의 물이 아래 입술을 넘쳐 떨어진다.
               물 폭 = 수면 높이에서 본 관 입구 너비(현). 넓은 물막일수록 자연스럽다.
    ③ 천장구 : 1 차 시안 중 기각되지 않은 것 — 비교용으로 남긴다
  재질은 하수도 주철 배관(tools/생성_주철배관.py 의 shade · 결)과 호퍼 원화 결을 그대로 쓴다.

규격(게임 px · y 0 = 물 윗변 · 아래가 +): scripts/스마트월드/하수도_출수구_시안.gd 의 상수와 같아야 한다.
  큰관: 관 두께 t = clamp(물폭 × 0.07, 5, 16) · 바깥 반지름 = 물폭/2 + t
  벽관: 관 입구 안 반지름 R = 물폭 / 2 · 관 중심 = 물 윗변 가운데(0, 0) — 관이 절반 차서 흐른다.
        위 반원 = 어두운 관 속, 아래 반원은 떨어지는 물이 덮는다. 테 두께 rim = clamp(R × 0.09, 8, 26)
        ★처음엔 수면을 중심보다 R/2 위로 잡아(R = 물폭/√3) 관 속 3/4 이 물로 차 하얀 원판처럼 보였다 → 반만 차게.
  2 배로 굽는다(그릴 때 0.5 배 — 배관과 같다). 물 폭마다 한 벌씩 굽는다(시안: 64 96 192 224 576).

만드는 것: assets/textures/obstacles/outlet/cast_iron_draft/*.png
사용:
  python tools/생성_출수구_시안.py [물폭 ...]               # 굽는다(씨앗 고정 → 멱등)
  python tools/생성_출수구_시안.py --미리보기 <폴더>
"""
import importlib
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
박스 = importlib.import_module("생성_박스_주철")
배관 = importlib.import_module("생성_주철배관")
OUT = os.path.join(ROOT, "assets", "textures", "obstacles", "outlet", "cast_iron_draft")

S = 4          # 내부 배율(게임 px → 내부)
B = 2          # 저장 배율(게임 px → 그림 px)
M = 12         # 열린 쪽으로 더 그렸다가 잘라 내는 여유(게임 px) — 이음 쪽에 외곽선이 안 생기게
GRAIN = 박스.GRAIN


class 캔버스:
    """게임 좌표 사각형 [x0,x1]×[y0,y1] 을 4 배로 그린다. 값은 0..1 밝기(회색)."""

    def __init__(s, x0, x1, y0, y1):
        s.x0, s.x1, s.y0, s.y1 = x0, x1, y0, y1
        s.W, s.H = int(round((x1 - x0) * S)), int(round((y1 - y0) * S))
        s.v = np.zeros((s.H, s.W), np.float32)
        s.a = np.zeros((s.H, s.W), np.float32)
        yy, xx = np.mgrid[0:s.H, 0:s.W]
        s.gx = xx / S + x0
        s.gy = yy / S + y0

    def P(s, pts):
        return [((x - s.x0) * S, (y - s.y0) * S) for x, y in pts]

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

    def 칠(s, m, v, alpha=1.0):
        v = np.broadcast_to(np.asarray(v, np.float32), s.v.shape)
        k = m * alpha
        s.v = s.v * (1 - k) + v * k
        s.a = s.a + (1 - s.a) * k

    def 외곽선(s, m, px=2.0, val=0.03):
        d = np.asarray(Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(int(px * S) | 1))).astype(np.float32) / 255
        s.칠(np.clip(d - m, 0, 1), val)

    def 그림자(s, m, dx=1.5, dy=2.0, val=0.0, alpha=0.45):
        """모양 오른쪽 아래로 민 부드러운 그림자 — 아직 아무것도 없는 곳에만 깐다."""
        sh = np.zeros_like(m)
        ix, iy = int(dx * S), int(dy * S)
        sh[iy:, ix:] = m[:s.H - iy, :s.W - ix]
        sh = np.asarray(Image.fromarray((sh * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.5 * S))).astype(np.float32) / 255
        sh = np.clip(sh - m, 0, 1) * alpha * (1 - s.a)
        s.v = s.v * (1 - sh)
        s.a = s.a + sh

    def 결(s, 주기x=None, 주기y=None, seed=0):
        """주철 결(평균 1). 주기를 주면 그 길이로 이음매 없이 반복되는 결(가운데 조각용)."""
        r = np.random.default_rng(seed)
        oy, ox = int(r.integers(0, GRAIN.shape[0])), int(r.integers(0, GRAIN.shape[1]))
        def 원결(gx, gy):
            iy = ((gy * S).astype(np.int64) + oy) % GRAIN.shape[0]
            ix = ((gx * S).astype(np.int64) + ox) % GRAIN.shape[1]
            return GRAIN[iy, ix]
        gx, gy = s.gx.copy(), s.gy.copy()
        if 주기x:
            gx = np.mod(gx, 주기x)
        if 주기y:
            gy = np.mod(gy, 주기y)
        g = 원결(gx, gy)
        # 주기 끝에서 반 바퀴 민 결과 섞어 이음매를 지운다(가시 받침판과 같은 방법)
        if 주기x:
            w = np.minimum(gx, 주기x - gx) / (주기x / 2)
            g = g * w + 원결(np.mod(gx + 주기x / 2, 주기x), gy) * (1 - w)
        if 주기y:
            w = np.minimum(gy, 주기y - gy) / (주기y / 2)
            g = g * w + 원결(gx, np.mod(gy + 주기y / 2, 주기y)) * (1 - w)
        return g

    def 리벳(s, x, y, r=2.2, base=0.42):
        s.칠(s.원(x + 0.6, y + 0.8, r), 0.03, 0.7)
        d = np.hypot(s.gx - (x - r * 0.35), s.gy - (y - r * 0.35)) / r
        s.칠(s.원(x, y, r), base * np.clip(1.25 - d * 0.75, 0.35, 1.3))

    def 판(s, m, base, g, 위빛=True, 아래그늘=True, y0=None, y1=None):
        """평판: 결 + 윗모서리 밝은 선 + 아래로 갈수록 살짝 어둡게."""
        s.칠(m, base * g)
        if y0 is not None and y1 is not None:
            v = np.clip((s.gy - y0) / max(1e-3, (y1 - y0)), 0, 1)
            s.v = np.where(m > 0, s.v * (1.0 - 0.18 * v), s.v)
            if 위빛:
                s.칠(m * (np.abs(s.gy - (y0 + 0.9)) < 0.8), 0.72, 0.7)
            if 아래그늘:
                s.칠(m * (s.gy > y1 - 1.6), 0.04, 0.55)

    def 원통(s, m, cx, 반지름, base, g, 가로=False):
        """원통(관·노즐) 음영 — 왼쪽 위에서 빛."""
        t = ((s.gy if 가로 else s.gx) - cx) / 반지름
        t = np.clip(t, -1, 1)
        lum = base * (0.55 + 0.75 * np.clip(-t * 0.8 + 0.35, 0, 1)) * g
        lum = lum + 0.38 * np.exp(-((t + 0.45) / 0.16) ** 2)       # 하이라이트 줄
        lum = lum * (0.55 + 0.45 * np.sqrt(np.clip(1 - t ** 2, 0, 1)) ** 0.6)
        s.칠(m, lum)

    def 저장(s, 자르기, 이름):
        """자르기 = 게임 좌표 (x0, x1, y0, y1). 미리 곱한 알파로 줄인다(가장자리 테 방지)."""
        cx0, cx1, cy0, cy1 = 자르기
        a0, a1 = int(round((cx0 - s.x0) * S)), int(round((cx1 - s.x0) * S))
        b0, b1 = int(round((cy0 - s.y0) * S)), int(round((cy1 - s.y0) * S))
        v = np.clip(s.v[b0:b1, a0:a1], 0, 1)
        a = np.clip(s.a[b0:b1, a0:a1], 0, 1)
        rgb = np.dstack([v * 1.0, v * 0.985, v * 0.96])           # 호퍼처럼 아주 약간 따뜻한 쇳빛
        pm = np.dstack([rgb * a[..., None], a]) * 255
        크기 = (int(round((cx1 - cx0) * B)), int(round((cy1 - cy0) * B)))
        im = Image.fromarray(pm.astype(np.uint8), "RGBA").resize(크기, Image.LANCZOS)
        q = np.asarray(im).astype(np.float32)
        al = q[..., 3:4] / 255
        q[..., :3] = np.where(al > 0, q[..., :3] / np.maximum(al, 1e-3), 0)
        out = Image.fromarray(q.clip(0, 255).astype(np.uint8), "RGBA")
        os.makedirs(OUT, exist_ok=True)
        out.save(os.path.join(OUT, 이름 + ".png"))
        return out


# ============================================================================
# ③ 천장 배수구 (frame) — 위 인방(가로 띠 12) · 양옆 문설주(세로 띠 14) · 모서리 보스 · 아래 발
#    안쪽(throat)은 어두운 젖은 돌, 물빛(glow)은 엔진에서 물 색으로 물들여 위로 갈수록 어둠에 묻는다.
#    조각: lintel_m (64 × 12, 그림 y −4..16) · jamb_m (14 × 64, 그림 x −4..18 · 세로 반복)
#          boss (20×20) · foot_l / foot_r (24 × 12) · throat_m (64×64 양방향 반복) · glow (64 × 128, 흰색 + 알파)
# ============================================================================
FR = dict(인방=12, 설주=14, 타일=64)


def frame():
    T = FR["타일"]
    # 인방(가로)
    c = 캔버스(-M, T + M, -4, FR["인방"] + 4)
    띠 = c.사각(-M - 5, 0, T + M + 5, FR["인방"])
    c.그림자(띠)
    c.판(띠, 0.32, c.결(주기x=T, seed=31), y0=0, y1=FR["인방"])
    for x in (16, 48):
        c.리벳(x, 6, 1.9, 0.44)
    c.외곽선(띠)
    c.저장((0, T, -4, FR["인방"] + 4), "lintel_m")
    # 문설주(세로) — 결을 세로로 반복
    c = 캔버스(-4, FR["설주"] + 4, -M, T + M)
    띠 = c.사각(0, -M - 5, FR["설주"], T + M + 5)
    c.그림자(띠)
    g = c.결(주기y=T, seed=32)
    c.칠(띠, 0.31 * g)
    c.칠(띠 * (np.abs(c.gx - 0.9) < 0.8), 0.68, 0.6)                 # 왼 모서리 빛
    c.칠(띠 * (c.gx > FR["설주"] - 1.8), 0.04, 0.55)                  # 오른 모서리 그늘
    for y in (16, 48):
        c.리벳(FR["설주"] / 2, y, 1.9, 0.44)
    c.외곽선(띠)
    c.저장((-4, FR["설주"] + 4, 0, T), "jamb_m")
    # 모서리 보스(인방과 문설주가 만나는 곳)
    c = 캔버스(-4, 24, -4, 24)
    보 = c.사각(0, 0, 20, 20)
    c.그림자(보)
    c.판(보, 0.36, c.결(seed=33), y0=0, y1=20)
    c.칠(보 * (np.abs(c.gx - 0.9) < 0.8), 0.68, 0.5)
    c.리벳(10, 10, 2.6, 0.48)
    c.외곽선(보)
    c.저장((-4, 24, -4, 24), "boss")
    # 발 — 문설주 아래 끝을 넓게 받친다(물이 나오는 입의 양옆 입술)
    for 오른 in (False, True):
        c = 캔버스(-4, 28, -4, 16)
        if not 오른:
            발 = c.다각형([(0, 2), (4, 0), (24, 0), (24, 9), (0, 9)])
        else:
            발 = c.다각형([(0, 0), (20, 0), (24, 2), (24, 9), (0, 9)])
        c.그림자(발)
        c.판(발, 0.34, c.결(seed=34 + 오른), y0=0, y1=9)
        c.리벳(12, 4.5, 1.9, 0.46)
        c.외곽선(발)
        c.저장((-4, 28, -4, 16), "foot_r" if 오른 else "foot_l")
    # 안쪽(throat) — 젖은 어두운 돌: 세로 물자국이 희미하게
    c = 캔버스(0, T, 0, T)
    r = np.random.default_rng(35)
    g = c.결(주기x=T, 주기y=T, seed=36)
    v = 0.055 * g
    for _ in range(9):
        x = r.uniform(0, T); w = r.uniform(0.6, 2.2); k = r.uniform(0.01, 0.035)
        d = np.minimum(np.abs(c.gx - x), T - np.abs(c.gx - x))
        v = v + k * np.exp(-(d / w) ** 2)
    c.칠(np.ones_like(v), v)
    c.저장((0, T, 0, T), "throat_m")
    # 물빛(glow) — 흰색 + 알파. 물막이 어둠 속에서 이어져 내려오는 것처럼: 가는 세로 줄기만 보이고
    #   아래(물 쪽) 0.40 → 위 40% 지점에서 0. ★처음 판(0.85 · 넓은 띠)은 조명 창처럼 보였다(2026-10-04 실화면) → 줄기로만.
    G = 128
    yy, xx = np.mgrid[0:G * B, 0:T * B]
    gy = yy / B; gx = xx / B
    t = np.clip((gy / G - 0.4) / 0.6, 0, 1)                    # 0 위(40% 위로는 0) · 1 아래
    a = t ** 1.8 * 0.40
    줄 = np.zeros_like(gx)
    for _ in range(16):
        x = r.uniform(0, T); w = r.uniform(0.7, 2.4); k = r.uniform(0.5, 1.0)
        d = np.minimum(np.abs(gx - x), T - np.abs(gx - x))
        줄 = np.maximum(줄, k * np.exp(-(d / w) ** 2))
    a = np.clip(a * (0.25 + 0.95 * 줄), 0, 1)
    im = np.dstack([np.full_like(a, 255), np.full_like(a, 255), np.full_like(a, 255), a * 255]).astype(np.uint8)
    Image.fromarray(im, "RGBA").save(os.path.join(OUT, "glow.png"))


# ============================================================================
# A 큰관 — 관 안지름 = 물 폭. 기존 주철 배관과 같은 음영 함수(shade)를 반지름만 바꿔 쓴다.
#   bigpipe_<폭>_straight_v (세로 직관 · 256 반복) · _flange_v (입구 플랜지) · _band_v (벽 고정 밴드)
# ============================================================================
def 큰관_두께(폭):
    return float(np.clip(폭 * 0.07, 5, 16))


def bigpipe(폭):
    R = 폭 / 2 + 큰관_두께(폭)
    배관.OUT = OUT
    원래 = 배관.R_PIPE
    try:
        배관.R_PIPE = R * B          # shade() 의 외곽선·가장자리 계산이 이 값을 쓴다 → 큰 관도 선 굵기가 같다
        H = int(2 * (R + 8) * B); T = 256 * B
        y = np.arange(H)[:, None] + 0.5 - H / 2
        s_ = np.repeat(y / (R * B), T, 1)
        perp = np.zeros((H, T, 2)); perp[..., 1] = 1
        rgb, a, n = 배관.shade(s_, perp, 배관.grain(H, T))
        배관.to_png(rgb.transpose(1, 0, 2), a.T, n.transpose(1, 0, 2)[..., [1, 0, 2]], "bigpipe_%d_straight_v" % 폭)
        배관.collar(14 * B, 1.10, False, "bigpipe_%d_flange" % 폭)
        배관.collar(10 * B, 1.06, True, "bigpipe_%d_band" % 폭)
    finally:
        배관.R_PIPE = 원래
    for 끝 in ("_h", "_h_n", "_n"):
        for 이름 in ("bigpipe_%d_flange" % 폭, "bigpipe_%d_band" % 폭):
            f = os.path.join(OUT, 이름 + 끝 + ".png")
            if os.path.exists(f) and 끝.startswith("_h"):
                os.remove(f)                                    # 세로 관만 쓴다


# ============================================================================
# B 벽관 — 뒷벽에서 정면으로 나온 큰 관 입구. 안 반지름 R = 물폭/2 · 테 rim · 중심 = 물 윗변 가운데.
#   outfall_<폭>      : 테(볼트 박힌 주철 고리) + 어두운 관 속(깊어질수록 더 어둡다)
#   outfall_<폭>_fill : 관 속 물(흰색 + 알파 — 엔진이 물 색으로 물들인다). 수면(y 0) 위로 얇게 비치는 물 띠
#                       (관 안쪽으로 멀어지는 수면) + 수면 앞 가장자리 밝은 선
# ============================================================================
def 벽관_치수(폭):
    R = 폭 / 2.0
    return R, float(np.clip(R * 0.09, 8, 26))


def outfall(폭):
    R, rim = 벽관_치수(폭)
    E = R + rim + 8
    N = int(2 * E * B)
    yy, xx = np.mgrid[0:N, 0:N] + 0.5
    gx = xx / B - E; gy = yy / B - E                   # 관 중심 기준 게임 좌표
    d = np.hypot(gx, gy) + 1e-6
    배관.OUT = OUT
    원래 = 배관.R_PIPE
    try:
        배관.R_PIPE = rim / 2 * B
        s_ = (d - (R + rim / 2)) / (rim / 2)
        perp = np.stack([gx / d, gy / d], -1)
        g = np.tile(배관._GRAIN, (N // 배관._GRAIN.shape[0] + 2, N // 배관._GRAIN.shape[1] + 2))[:N, :N] * 0.7
        rgb, a, n = 배관.shade(s_, perp, g, base=6)
        # 볼트 — 테 가운데 원 위에 고르게
        개수 = int(np.clip(round(2 * np.pi * (R + rim / 2) / 56), 10, 36))
        for i in range(개수):
            t = 2 * np.pi * (i + 0.5) / 개수
            bx, by = np.cos(t) * (R + rim / 2), np.sin(t) * (R + rim / 2)
            bd = np.hypot(gx - bx, gy - by)
            br = min(3.2, rim * 0.22)
            bm = bd <= br
            bperp = np.stack([(gx - bx) / (bd + 1e-6), (gy - by) / (bd + 1e-6)], -1)
            b_rgb, _, b_n = 배관.shade(bd / br, bperp, g * 0, base=22)
            rgb[bm] = b_rgb[bm]; n[bm] = b_n[bm]
    finally:
        배관.R_PIPE = 원래
    # 관 속 — 테 안쪽 그늘(위가 더 어둡다) → 안쪽 원(깊이)으로 갈수록 거의 검정
    속 = d < R
    깊이 = np.clip(d / R, 0, 1)
    v = 10 + 16 * 깊이 ** 3 + 6 * np.clip(gy / R, 0, 1)
    v = v * (0.8 + 0.2 * g / (np.abs(g).max() + 1e-6))
    rgb[속] = np.stack([v, v, v * 0.98], -1)[속]
    a = np.where(속, 1.0, a)
    # 테 안쪽 가장자리 위 그늘(관 두께가 보이게): 원 안 바로 안쪽 위쪽에 어두운 초승달
    초 = 속 & (d > R - 0.10 * R) & (gy < 0)
    rgb[초] *= 0.55
    배관.to_png(rgb, a, n, "outfall_%d" % 폭)
    # 물 — 수면(관 중심 기준 y = −R/2) 아래 원 안 + 수면 위 얇은 띠(관 안쪽으로 멀어지는 수면 — 위로 갈수록 옅다)
    수면 = 0.0
    아래 = 속 & (gy >= 수면)
    띠 = 속 & (gy < 수면) & (gy >= 수면 - max(4.0, R * 0.06))
    al = np.zeros((N, N))
    # ★수면 아래는 칠하지 않는다 — 떨어지는 물(자연물)이 반투명이라 그 뒤로 하얀 반원판이 비쳤다(2026-10-05 실화면).
    #   수면 아래 관 속은 어두운 그대로 두고, 물 띠만 수면 위로 보이게 한다.
    al[띠] = (0.55 * (1 - (수면 - gy) / max(4.0, R * 0.06)))[띠]
    # 수면 앞 가장자리 밝은 선(물이 입술로 넘어가는 곳)
    선 = 속 & (np.abs(gy - 수면) < 1.2)
    lum = np.full((N, N), 235.0)
    lum[아래] = (235 - 60 * np.clip((gy - 수면) / R, 0, 1))[아래]
    lum[선] = 255; al[선] = 1.0
    im = np.dstack([lum, lum, lum, al * 255]).clip(0, 255).astype(np.uint8)
    Image.fromarray(im, "RGBA").save(os.path.join(OUT, "outfall_%d_fill.png" % 폭))


# ============================================================================
# B 변형 (2026-10-07 · 도형님: "넓은 곳은 B 가 좋아 보이긴 한데 헷갈리네 — 더 좋은 시안?")
#   B 가 헷갈리는 까닭(실화면): 576 에서 위로 288 짜리 **검은 반원판**이 생기고, 테가 납작한 고리뿐이라
#   "관 끝" 인지 "벽의 둥근 구멍" 인지 애매하다. 두 축으로 푼다.
#     타원 : 입구를 위아래로 눌러(세로 = 가로 × 0.5) 검은 부분 높이를 반으로 — 하수도의 납작한 배수 암거관
#     돌출 : 관 몸통이 벽에서 앞으로 나와 있다(조금 위에서 내려다본 원근) — 입구 테 위로 관 윗면 띠 + 벽 쪽 플랜지
#           → "벽에 박힌 관 끝" 으로 읽힌다
#   outfall_<종류>_<폭> / _fill · 종류 e = 타원 · p = 돌출(원) · pe = 돌출 타원
#   그림 가운데 = 입구 중심 = 물 윗변 가운데(정사각 캔버스).
# ============================================================================
def 벽관2_치수(폭, 종류):
    a = 폭 / 2.0
    b = a * (0.5 if "e" in 종류 else 1.0)
    rim = float(np.clip(min(a, b * 1.6) * 0.09, 8, 22))
    p = float(np.clip(a * 0.14, 10, 44)) if "p" in 종류 else 0.0
    return a, b, rim, p


def _타원_거리(x, y, a, b):
    """타원(반축 a, b)까지의 부호 거리 근사(안 −) + 바깥 방향 단위벡터."""
    q = np.sqrt((x / a) ** 2 + (y / b) ** 2) + 1e-9
    gx_, gy_ = x / (a * a * q), y / (b * b * q)
    gn = np.hypot(gx_, gy_) + 1e-9
    return (q - 1) / gn, np.stack([gx_ / gn, gy_ / gn], -1)


def outfall2(폭, 종류):
    a, b, rim, p = 벽관2_치수(폭, 종류)
    E = max(a + rim, b + rim + p) + 18
    N = int(2 * E * B)
    yy, xx = np.mgrid[0:N, 0:N] + 0.5
    gx = xx / B - E; gy = yy / B - E
    g = np.tile(배관._GRAIN, (N // 배관._GRAIN.shape[0] + 2, N // 배관._GRAIN.shape[1] + 2))[:N, :N] * 0.7
    배관.OUT = OUT
    원래 = 배관.R_PIPE
    rgb = np.zeros((N, N, 3)); al = np.zeros((N, N)); nm = np.dstack([np.zeros((N, N)), np.zeros((N, N)), np.ones((N, N))])
    def 덮기(r2, a2, n2, m=None):
        nonlocal rgb, al, nm
        if m is not None:
            a2 = a2 * m
        k = a2[..., None]
        rgb = rgb * (1 - k) + r2 * k
        nm = np.where(k > 0.5, n2, nm)
        al = np.maximum(al, a2)
    try:
        bo, ao = b + rim, a + rim                                  # 앞 테 바깥 반축
        # 0) 벽에 진 그림자 — 관 전체 윤곽을 오른쪽 아래로 민 흐린 그림자
        if p > 0:
            hx = bo * np.sqrt(np.clip(1 - (gx / ao) ** 2, 0, 1))
            몸통 = (np.abs(gx) < ao) & (gy >= -p - hx) & (gy <= hx)
        else:
            몸통 = _타원_거리(gx, gy, ao, bo)[0] <= 0
        sh = np.zeros((N, N)); dx, dy = int(6 * B), int(9 * B)
        sh[dy:, dx:] = 몸통[:N - dy, :N - dx]
        sh = np.asarray(Image.fromarray((sh * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(5 * B))).astype(np.float64) / 255
        덮기(np.zeros((N, N, 3)), sh * 0.55, nm)
        if p > 0:
            # 1) 벽 쪽 플랜지 — 벽에 붙은 넓은 고리(뒤 · 어둡게)
            배관.R_PIPE = 5 * B
            sd, perp = _타원_거리(gx, gy + p, ao + 5, bo + 5)
            r1, a1, n1 = 배관.shade(sd / 5, perp, g, base=0)
            덮기(r1 * 0.7, a1, n1)
            # 2) 관 몸통 윗면 — 앞 테 위로 보이는 띠. 가로로 원통 음영 + 벽 쪽으로 갈수록 어둡게
            배관.R_PIPE = ao * B
            r2, a2, n2 = 배관.shade(gx / ao, np.dstack([np.ones((N, N)), np.zeros((N, N))]), g, base=4)
            깊이 = np.clip((-gy - (bo * np.sqrt(np.clip(1 - (gx / ao) ** 2, 0, 1)))) / max(p, 1), 0, 1)   # 0 앞 · 1 벽
            # 윗면은 빛을 받는다(왼쪽 위 광원) — 처음 판(×1.0)은 앞 테와 구별이 안 돼 돌출이 안 읽혔다 → 앞은 밝게, 벽 쪽은 어둡게
            r2 = r2 * (1.75 - 0.95 * 깊이[..., None])
            띠 = 몸통.astype(np.float64) * (np.abs(gx) <= ao)
            덮기(r2, a2, n2, 띠)
            # 몸통 고정 밴드 한 줄(앞 테와 벽 사이 가운데) — 관이라는 표시
            밴드 = 띠 * (np.abs(-gy - bo * np.sqrt(np.clip(1 - (gx / ao) ** 2, 0, 1)) - p * 0.5) < 2.2)
            덮기(r2 * 1.35, 밴드, n2)
        # 3) 앞 테(입구 고리) + 볼트
        배관.R_PIPE = rim / 2 * B
        sd, perp = _타원_거리(gx, gy, a + rim / 2, b + rim / 2)
        r3, a3, n3 = 배관.shade(sd / (rim / 2), perp, g, base=6)
        덮기(r3, a3, n3)
        둘레 = np.pi * (3 * (a + b) - np.sqrt((3 * a + b) * (a + 3 * b)))
        개수 = int(np.clip(round(둘레 / 56), 10, 36))
        for i in range(개수):
            t = 2 * np.pi * (i + 0.5) / 개수
            bx, by = np.cos(t) * (a + rim / 2), np.sin(t) * (b + rim / 2)
            bd = np.hypot(gx - bx, gy - by)
            br = min(3.2, rim * 0.22)
            bm = bd <= br
            bperp = np.stack([(gx - bx) / (bd + 1e-6), (gy - by) / (bd + 1e-6)], -1)
            b_rgb, _, b_n = 배관.shade(bd / br, bperp, g * 0, base=22)
            rgb[bm] = b_rgb[bm]; nm[bm] = b_n[bm]
    finally:
        배관.R_PIPE = 원래
    # 4) 관 속 — 어둡게, 안쪽 위 가장자리에 관 두께 그늘
    sd_in, _ = _타원_거리(gx, gy, a, b)
    속 = sd_in < 0
    q = np.sqrt((gx / a) ** 2 + (gy / b) ** 2)
    v = 10 + 16 * np.clip(q, 0, 1) ** 3 + 6 * np.clip(gy / b, 0, 1)
    rgb[속] = np.stack([v, v, v * 0.98], -1)[속]
    al = np.where(속, 1.0, al)
    nm[속] = [0, 0, 1]
    초 = 속 & (sd_in > -0.10 * min(a, b) - 2) & (gy < 0)
    rgb[초] *= 0.55
    이름 = "outfall_%s_%d" % (종류, 폭)
    배관.to_png(rgb, al, nm, 이름)
    # 5) 관 속 물 — 수면(y 0) 위 얇은 띠 + 앞 가장자리 밝은 선 (수면 아래는 칠하지 않는다 — 위 outfall 과 같은 까닭)
    두께 = max(4.0, b * 0.06)
    띠 = 속 & (gy < 0) & (gy >= -두께)
    fa = np.zeros((N, N))
    fa[띠] = (0.55 * (1 - (-gy) / 두께))[띠]
    선 = 속 & (np.abs(gy) < 1.2)
    fa[선] = 1.0
    im = np.dstack([np.full((N, N), 245.0)] * 3 + [fa * 255]).clip(0, 255).astype(np.uint8)
    Image.fromarray(im, "RGBA").save(os.path.join(OUT, 이름 + "_fill.png"))


def preview(folder):
    os.makedirs(folder, exist_ok=True)
    for f in sorted(os.listdir(OUT)):
        if not f.endswith(".png"):
            continue
        im = Image.open(os.path.join(OUT, f)).convert("RGBA")
        bg = Image.new("RGBA", (im.width * 2, im.height * 2), (44, 44, 48, 255))
        bg.alpha_composite(im.resize((im.width * 2, im.height * 2), Image.NEAREST))
        bg.save(os.path.join(folder, "x4_" + f))


def main():
    폭들 = [int(x) for x in sys.argv[1:] if x.isdigit()] or [64, 96, 192, 224, 576]
    frame()
    for w in 폭들:
        bigpipe(w); outfall(w)
        for 종류 in ("e", "p", "pe"):
            outfall2(w, 종류)
    print("saved", OUT, sorted(f for f in os.listdir(OUT) if f.endswith(".png")))
    if "--미리보기" in sys.argv:
        preview(sys.argv[sys.argv.index("--미리보기") + 1])


if __name__ == "__main__":
    main()
