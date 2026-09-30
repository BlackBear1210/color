# -*- coding: utf-8 -*-
"""
집 배경 키트 v05 — **복도** 부품 (2026-09-28 · Claude)
============================================================================
방 쪽(`만들기.py`)의 도구·결(텍스처)·규칙을 그대로 가져다 쓴다. 같은 결을 쓰는 것이 핵심이다
— 주문서 §5-A: "A1 과 A2 는 같은 집의 다른 부분. 재질과 낡은 정도는 똑같이, 비례와 리듬만 다르게."

만드는 것 (주문서 §5-A2 · §5-C, 파일 이름 그대로):
  far/wall_hall_repeat.png          1024 × 768  불투명 · 가로 반복
  layers/hall_01_portraits.png …    1536 × 1024 알파 · 바닥선 87 %  × 6 장

⚠ 복도 천장은 바닥 위 1,056 px(월드) 이다. 카메라는 발밑 − 60 을 보므로 화면 위 끝이 바닥 위
  600 px 쯤이다. 그래서 주문서의 "액자 30~55 % 높이" 를 그대로 쓰면 액자가 화면 밖으로 나간다.
  → 벽걸이 물건은 바닥 위 **사람 키 2.3~5 배** 사이(캔버스 y 약 500~720)에 건다.

실행:  python tools/배경키트_v05/만들기_복도.py
"""
import os, math, json
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

import 만들기 as K
from 만들기 import (W, H, FLOOR, HUMAN, 가구배율, arr, to_im, gray_rgba, dark_rim, paste, stand,
                  big, scale_part, flip, rotate, texture, mask_poly, surface, line_mask,
                  darken_where, add, layer_canvas, crate, chair, side_table, band_split,
                  finish_layer, save, X, OUT, QA, PLASTER, A1)


def hang(canvas, part, cx, top):
    """벽에 거는 물건: 가구배율을 곱하고, 윗끝을 캔버스 y `top` 에 맞춘다."""
    p = big(part)
    paste(canvas, p, int(cx - p.shape[1] / 2), int(top))
    return p


# ============================================================================
# A2 — 복도 벽 (1024 × 768) : 좁은 하인용 복도. 징두리 널판 62 % · 그림 레일 · 회반죽
# ============================================================================
def wall_hall():
    w, h = 1024, 768
    r = np.random.default_rng(5)
    v = np.zeros((h, w), np.float32)
    # ★주문서는 널판 62 % 인데, 게임 화면은 바닥 위 600 px(= 벽 높이 57 %)까지만 보인다.
    #   62 % 면 화면 전체가 세로 널판뿐이고(1 차), 45 % 도 회반죽이 화면 맨 위 한 줄뿐이었다(2 차).
    #   → 30 %: 화면 아래 절반이 널판, 위 절반이 회반죽 + 액자.
    wain_top = int(h * (1 - 0.30))                 # 널판 윗끝 y 537

    # ① 위쪽 회반죽 — Codex 회반죽을 어둡게 (A1 과 같은 벗겨진 결)
    pl = np.asarray(Image.fromarray((PLASTER * 255).astype(np.uint8)).resize((w, int(w * PLASTER.shape[0] / PLASTER.shape[1])))).astype(np.float32) / 255
    pl = pl[:wain_top]
    v[:wain_top] = 0.17 + (pl - pl.mean()) * 0.55
    # 물 얼룩 — 위에서 아래로 번진 세로 줄 (어둡게만)
    streak = ndimage.gaussian_filter(r.random((1, w)).repeat(wain_top, 0), (0, 9))
    streak = np.clip((streak - 0.5) * 6, 0, 1) * np.linspace(1, 0.2, wain_top)[:, None]
    v[:wain_top] *= 1 - streak * 0.35

    # ② 그림 레일 — 가는 몰딩. 윗선이 밝으면 선반으로 읽히므로 **윗선을 어둡게**
    rail_y = int(wain_top * 0.45)
    v[rail_y:rail_y + 4] *= 0.45
    v[rail_y + 4:rail_y + 12] = 0.22 + texture(8, w, "wood", True, 3) * 0.02
    v[rail_y + 12:rail_y + 15] *= 0.6

    # ③ 징두리 널판 — 64 px 폭 16 장(정수 → 가로 반복 이음매 없음)
    board_w = 64
    for i in range(w // board_w):
        x0 = i * board_w
        t = texture(h - wain_top, board_w, "wood", False, 40 + i)
        base = 0.19 + r.uniform(-0.02, 0.02)
        v[wain_top:, x0:x0 + board_w] = base + t * 0.022
        v[wain_top:, x0:x0 + 3] *= 0.35            # 널판 틈
    # 널판 위 모자 레일(윗면 어둡게) · 걸레받이
    v[wain_top - 10:wain_top] = 0.16 + texture(10, w, "wood", True, 7) * 0.02
    v[wain_top - 10:wain_top - 7] *= 0.5
    v[wain_top:wain_top + 4] *= 0.5
    # 걸레받이: 경계선을 두면 바닥 바로 위 **낮은 턱**으로 읽혔다(2 차 촬영) → 선 없이 아래로 어두워지게
    skirt = int(h * 0.86)
    v[skirt:] *= np.linspace(1.0, 0.55, h - skirt)[:, None]

    # ④ 전체에 낮은 대비의 먼지 얼룩 (방 벽보다 대비 낮게)
    blot = ndimage.gaussian_filter(r.random((h, w)), 40)
    blot = (blot - blot.mean()) / (blot.std() + 1e-5)
    v = v * (1 + blot * 0.06)

    # 좌우 이음매 교차 페이드
    k = 24
    t = np.linspace(0, 1, k)[None, :]
    L, R = v[:, :k].copy(), v[:, -k:].copy()
    v[:, :k] = L * t + R * (1 - t)
    v[:, -k:] = R * (1 - t) + L * t
    v = np.clip(v, 0.05, 0.32)                     # 주문서: 15~32 %
    return np.dstack([v, v, v, np.ones_like(v)])


# ============================================================================
# 벽에 붙는 물건 (크기는 사람 키 77 기준 — 거는 순간 가구배율이 곱해진다)
# ============================================================================
def frame(w, h, seed=0, kind="empty", cord=True):
    """액자 — 캔버스는 **평평한 짙은 회색**(얼굴·그림·글자 없음, 주문서 C1)."""
    b = max(4, int(min(w, h) * 0.13))
    out_m = mask_poly(h, w, [], rects=[(0, 0, w, h)])
    p = surface(out_m, 0.25, "wood", 0.04, horizontal=True, seed=seed)
    bev = line_mask(h, w, [(b, b, w - b, b, 1.2), (b, b, b, h - b, 1.2), (2, 2, w - 2, 2, 1), (2, 2, 2, h - 2, 1)])
    p = darken_where(p, bev, 0.5)
    inner = mask_poly(h, w, [], rects=[(b, b, w - b, h - b)])
    canvas_v = 0.12 + texture(h, w, "plaster", seed=seed + 1) * 0.012
    p[..., :3] = p[..., :3] * (1 - inner[..., None]) + canvas_v[..., None] * inner[..., None]
    if kind == "torn":
        r = np.random.default_rng(seed)
        pts = [(w * 0.5, h * 0.25)]
        for i in range(14):
            ang = i / 14 * 2 * math.pi
            rr = min(w, h) * (0.18 + r.random() * 0.14)
            pts.append((w * 0.5 + math.cos(ang) * rr, h * 0.48 + math.sin(ang) * rr * 1.3))
        hole = mask_poly(h, w, [pts[1:]]) * inner
        p[..., 3] *= (1 - hole)                    # 찢긴 자리 = 진짜 구멍(뒤 벽이 보인다)
        flap = mask_poly(h, w, [[(w * 0.42, h * 0.62), (w * 0.56, h * 0.64), (w * 0.47, h * 0.86)]])
        p = add(p, gray_rgba(np.full((h, w), 0.15), flap))
    if not cord:
        return p
    # 끈 — 양 윗모서리에서 못 하나로 모이는 가는 선 (위로 20 px 여유)
    out = np.zeros((h + 20, w, 4), np.float32)
    cm = line_mask(h + 20, w, [(w * 0.18, 21, w / 2, 1, 1.0), (w * 0.82, 21, w / 2, 1, 1.0)])
    paste(out, gray_rgba(np.full((h + 20, w), 0.10), cm), 0, 0)
    paste(out, p, 0, 20)
    return out


def sconce(seed=0):
    """꺼진 벽 촛대 — 등판·굽은 팔·받침·타다 남은 초 동강(밀랍 흘러내림). 불꽃·빛 없음."""
    w, h = 40, 44
    iron = line_mask(h, w, [(w / 2, 30, w / 2, 20, 2.4), (8, 24, w - 8, 24, 2.0), (8, 24, 6, 16, 1.8), (w - 8, 24, w - 6, 16, 1.8)])
    plate = mask_poly(h, w, [], ellipses=[(w / 2 - 5, 18, w / 2 + 5, 42)])
    pans = mask_poly(h, w, [], ellipses=[(1, 14, 12, 18), (w - 12, 14, w - 1, 18), (w / 2 - 6, 8, w / 2 + 6, 12)])
    m = np.maximum(np.maximum(iron, plate), pans)
    p = gray_rgba(np.full((h, w), 0.11) + texture(h, w, "plaster", seed=seed) * 0.01, m)
    stubs = mask_poly(h, w, [], rects=[(4, 7, 9, 15), (w - 9, 9, w - 4, 15), (w / 2 - 2.5, 1, w / 2 + 2.5, 9)])
    drips = line_mask(h, w, [(5, 14, 5, 19, 1.2), (w - 5, 14, w - 5, 20, 1.2), (w / 2 + 1, 8, w / 2 + 2, 13, 1.0)])
    wax = np.maximum(stubs, drips)
    return add(p, gray_rgba(np.full((h, w), 0.30), wax))   # 밀랍 30 % — 불빛이 아니다


def birdcage_table(seed=0):
    t = side_table(seed=seed)
    cage = mask_poly(30, 26, [[(2, 30), (0, 16), (5, 6), (13, 1), (21, 6), (26, 16), (24, 30)]])
    cp = surface(cage, 0.27, "plaster", 0.05, seed=seed + 3, rim=0.3)
    cp = darken_where(cp, line_mask(30, 26, [(9, 5, 7, 29, 1.2), (17, 5, 19, 29, 1.2)]) * cage, 0.35)
    out = np.zeros((t.shape[0] + 30, max(t.shape[1], 26), 4), np.float32)
    paste(out, t, 0, 30)
    paste(out, cp, (t.shape[1] - 26) // 2, 1)
    return out


def armour(seed=0):
    """갑옷 한 벌 — 받침대 위. 금속은 회반죽 결에 세로 반사 한 줄(≤ 34 %)."""
    w, h = 44, 100
    polys = [
        [(17, 0), (27, 0), (30, 6), (30, 16), (14, 16), (14, 6)],                # 투구
        [(6, 20), (38, 20), (41, 28), (35, 30), (33, 52), (11, 52), (9, 30), (3, 28)],  # 어깨·가슴
        [(11, 52), (33, 52), (35, 62), (9, 62)],                                  # 허리받이
        [(12, 62), (20, 62), (19, 90), (13, 90)], [(24, 62), (32, 62), (31, 90), (25, 90)],  # 다리
        [(3, 28), (8, 30), (7, 54), (3, 54)], [(41, 28), (36, 30), (37, 54), (41, 54)],       # 팔
    ]
    m = mask_poly(h, w, polys, rects=[(4, 92, 40, 100), (20, 88, 24, 92)])
    p = surface(m, 0.22, "plaster", 0.03, seed=seed, rim=0.4)
    shine = mask_poly(h, w, [], rects=[(19, 24, 22, 48)]) * m
    p[..., :3] = np.maximum(p[..., :3], (shine * 0.33)[..., None])
    p = darken_where(p, line_mask(h, w, [(15, 9, 29, 9, 1.4), (6, 36, 38, 36, 1), (9, 44, 35, 44, 1)]) * m, 0.6)
    return p


def mirror(seed=0):
    w, h = 50, 110
    outer = mask_poly(h, w, [[(4, 12), (w / 2, 0), (w - 4, 12), (w - 2, h), (2, h)]])
    p = surface(outer, 0.24, "wood", 0.04, seed=seed)
    glass = mask_poly(h, w, [[(10, 16), (w / 2, 7), (w - 10, 16), (w - 9, h - 7), (9, h - 7)]])
    p[..., :3] = p[..., :3] * (1 - glass[..., None]) + 0.14 * glass[..., None]   # 반사·그림 없음
    cracks = line_mask(h, w, [(18, 30, 30, 58, 1.0), (30, 58, 24, 80, 1.0), (30, 58, 38, 70, 0.8)])
    return darken_where(p, cracks * glass, 0.5)


def dead_plant(seed=0):
    w, h = 36, 60
    pot = mask_poly(h, w, [[(8, 40), (28, 40), (25, 60), (11, 60)]])
    pp = surface(pot, 0.21, "plaster", 0.04, seed=seed)
    r = np.random.default_rng(seed)
    segs = []
    for i in range(7):
        x0 = 14 + i * 1.3
        x1 = x0 + r.uniform(-14, 14)
        y1 = r.uniform(4, 26)
        segs.append((x0, 40, x1, y1, 1.0))
        segs.append((x1, y1, x1 + r.uniform(-6, 6), y1 + r.uniform(4, 10), 0.8))   # 꺾여 늘어진 잎
    stems = gray_rgba(np.full((h, w), 0.13), line_mask(h, w, segs))
    return add(stems, pp)


def door(ajar=False, seed=0):
    """닫힌 판벽 문 + 문틀. ajar 면 한쪽이 벌어져 순흑이 보인다(빛 새지 않음)."""
    w, h = 50, 112
    fr = mask_poly(h, w, [], rects=[(0, 0, w, h)])
    p = surface(fr, 0.22, "wood", 0.035, seed=seed)
    p = darken_where(p, np.clip(1 - np.arange(h) / 8.0, 0, 1)[:, None] * np.ones((1, w)) * fr, 0.45)   # 윗면 어둡게
    leaf = mask_poly(h, w, [], rects=[(6, 7, w - 6, h)])
    lv = surface(leaf, 0.17, "wood", 0.03, seed=seed + 1)
    panels = []
    for (y0, y1) in ((14, 46), (52, 100)):
        for (x0, x1) in ((11, w / 2 - 3), (w / 2 + 3, w - 11)):
            panels += [(x0, y0, x1, y0, 1.1), (x0, y1, x1, y1, 1.1), (x0, y0, x0, y1, 1.1), (x1, y0, x1, y1, 1.1)]
    lv = darken_where(lv, line_mask(h, w, panels) * leaf, 0.5)
    handle = mask_poly(h, w, [], ellipses=[(w - 13, 58, w - 9, 62)])
    lv = add(lv, gray_rgba(np.full((h, w), 0.26), handle))   # 녹슨 손잡이
    if ajar:
        gap = mask_poly(h, w, [], rects=[(w - 16, 7, w - 6, h)])
        lv[..., :3] *= (1 - gap[..., None] * 0.95)
    return add(p, lv)


def mat(w=46, h=4, seed=0):
    m = mask_poly(h, w, [], rects=[(0, 0, w, h)])
    return surface(m, 0.12, "plaster", 0.02, seed=seed, rim=0.2, top_shade=0.0)


def coat_stand(seed=0):
    w, h = 40, 100
    pole = line_mask(h, w, [(20, 4, 20, h - 4, 2.4), (20, 6, 10, 2, 1.6), (20, 6, 30, 2, 1.6), (8, h, 20, h - 10, 2), (32, h, 20, h - 10, 2)])
    pp = surface(pole, 0.15, "wood", 0.02, seed=seed, rim=0.1)
    coat = mask_poly(h, w, [[(10, 4), (16, 8), (18, 20), (19, 52), (16, 62), (4, 64), (2, 40), (5, 16)]])
    cp = surface(coat, 0.19, "plaster", 0.04, seed=seed + 1, rim=0.3)
    cp = darken_where(cp, line_mask(h, w, [(10, 14, 9, 60, 1.2)]) * coat, 0.4)
    return add(pp, cp)


def leaning_frames(seed=0):
    """벽에 등을 보이고 기대 놓은 액자 더미 — 뒷판과 가로대만 보인다."""
    out = np.zeros((62, 70, 4), np.float32)
    for i, (w, h, x) in enumerate(((44, 58, 4), (38, 50, 16), (30, 40, 30))):
        m = mask_poly(h, w, [], rects=[(0, 0, w, h)])
        p = surface(m, 0.20 + i * 0.02, "wood", 0.03, horizontal=True, seed=seed + i)
        p = darken_where(p, line_mask(h, w, [(0, h * 0.5, w, h * 0.5, 2), (w * 0.5, 0, w * 0.5, h, 1.5)]) * m, 0.4)
        p = rotate(p, -6)
        paste(out, p, x, 62 - p.shape[0])
    return out


def rolled_carpet_lying(w=90, h=12, seed=0):
    m = mask_poly(h, w, [], rects=[(4, 0, w - 4, h)], ellipses=[(0, 0, 8, h), (w - 8, 0, w, h)])
    p = surface(m, 0.23, "plaster", 0.05, seed=seed, top_shade=0.0)
    return darken_where(p, line_mask(h, w, [(k, 1, k, h - 1, 0.8) for k in range(12, w - 8, 14)]) * m, 0.3)


def wallpaper_strips(seed=0):
    """벽에서 말려 떨어지는 벽지 띠 — 윗부분은 벽에 붙어 있고 아래가 말려 앞으로 나온다.
    벽지 앞면 22~28 % · 말린 뒷면은 더 어둡게(15 %). 뒤 물 얼룩은 어둡게만 번진다."""
    c = layer_canvas()
    r = np.random.default_rng(seed)
    x = 20
    while x < W - 60:
        sw = int(r.uniform(38, 90))
        top = int(r.uniform(H * 0.22, H * 0.40))
        L = int(r.uniform(140, 330))
        if r.random() < 0.45:                      # 빈 자리 — 떨어져 나간 곳 (1 차: 0.28 은 너무 빽빽해 널판 줄로 보였다)
            x += sw + int(r.uniform(20, 120))
            continue
        # 띠 모양: 아래로 갈수록 한쪽으로 휘며 폭이 줄어든다(말림)
        bend = r.uniform(-30, 30)
        pts = [(0, 0), (sw, 0)]
        n = 10
        for i in range(1, n + 1):
            t = i / n
            pts.append((sw - sw * 0.15 * t + bend * t * t, L * t))
        for i in range(n, 0, -1):
            t = i / n
            pts.append((sw * 0.15 * t + bend * t * t + (sw * 0.2 * t if i == n else 0), L * t))
        bw = sw + int(abs(bend)) + 40
        off = 20 + (int(-bend) if bend < 0 else 0)
        pts = [(px + off, py) for px, py in pts]
        m = mask_poly(L + 4, bw, [pts])
        p = surface(m, r.uniform(0.15, 0.19), "panel", 0.04, seed=int(r.integers(1000000)), rim=0.35)
        # 벽에 붙은 윗끝은 어둡게 — 가로 윗선이 밝으면 선반으로 읽힌다(§3)
        p[..., :3] *= np.clip(0.5 + np.arange(L + 4) / 24.0, 0, 1)[:, None, None]
        # 세로 줄무늬 벽지 무늬(아주 약하게)
        stripes = np.sin(np.arange(bw) / 5.0)[None, :] * 0.5 + 0.5
        p[..., :3] *= (0.94 + stripes[..., None] * 0.06)
        # 말린 끝(아래 25 %)은 뒷면이 보여 어둡다
        curl = np.clip((np.arange(L + 4) / (L + 4) - 0.75) / 0.25, 0, 1)[:, None]
        p[..., :3] *= (1 - curl[..., None] * 0.45)
        paste(c, p, x - off, top)
        # 띠 아래로 번진 물 얼룩 — 어두운 반투명(밝은 후광이 아니다)
        sh = int(r.uniform(80, 200))
        stain = np.zeros((sh, sw + 20), np.float32)
        stain[:, 10:10 + sw] = np.linspace(0.35, 0, sh)[:, None]
        stain = ndimage.gaussian_filter(stain, 6)
        st = gray_rgba(np.full(stain.shape, 0.03), stain)
        sc = layer_canvas()
        paste(sc, st, x - 10, top + int(L * 0.6))
        c = add(sc, c)
        x += sw + int(r.uniform(4, 40))
    return c


# ============================================================================
# C1 ~ C6 — 복도 디테일 레이어
# ============================================================================
## 벽걸이 높이: 캔버스 y. 바닥선(891)에서 사람 키(77)의 몇 배 위인가로 적는다.
def YUP(n):
    return int(FLOOR - HUMAN * n)


def hall_portraits():
    c = layer_canvas()
    sizes = [(34, 44, 0, "empty"), (26, 34, -4, "empty"), (40, 30, 3, "empty"), (30, 40, 0, "torn"),
             (24, 30, 8, "empty"), (36, 46, -2, "empty"), (28, 36, 0, "corner")]
    xs = np.linspace(9, 91, len(sizes))
    for i, ((w, h, tilt, kind), xp) in enumerate(zip(sizes, xs)):
        f = frame(w, h, seed=200 + i, kind=("torn" if kind == "torn" else "empty"))
        if kind == "corner":
            f = rotate(frame(w, h, seed=207, cord=False), 32)   # 한 모서리에만 걸려 기운 액자
        elif tilt:
            f = rotate(f, tilt)
        top = YUP(5.2) + (i % 3) * 18 - (i % 2) * 10
        hang(c, f, X(xp), top)
    return c


def hall_sconces():
    c = layer_canvas()
    for i, xp in enumerate(np.linspace(10, 90, 5)):
        hang(c, sconce(seed=300 + i), X(xp), YUP(3.4))
    stand(c, side_table(seed=310), X(24))
    stand(c, birdcage_table(seed=311), X(70))
    return c


def hall_armour():
    c = layer_canvas()
    stand(c, armour(seed=400), X(25))
    stand(c, mirror(seed=401), X(55))
    stand(c, dead_plant(seed=402), X(81))
    hang(c, frame(26, 32, seed=403), X(40), YUP(4.6))
    hang(c, frame(30, 24, seed=404), X(68), YUP(4.3))
    return c


def hall_peeling():
    c = wallpaper_strips(seed=500)
    # 바닥에 떨어져 깨진 액자 하나(x 44 %)
    f = frame(40, 30, seed=501, cord=False)
    f = rotate(f, 84)
    broken = f.copy()
    h, w = broken.shape[:2]
    broken[:, w // 2 - 2:w // 2 + 2, 3] = 0       # 두 동강
    stand(c, broken, X(44))
    return c


def hall_doors():
    c = layer_canvas()
    for i, (xp, aj) in enumerate(((19, False), (51, True), (81, False))):
        stand(c, door(ajar=aj, seed=600 + i), X(xp))
    stand(c, mat(seed=610), X(51))
    return c


def hall_boxes():
    c = layer_canvas()
    base = FLOOR
    for i, (w, h, dx) in enumerate(((40, 34, 0), (34, 28, 6), (28, 22, -4))):
        w2, h2 = int(w * 가구배율), int(h * 가구배율)
        paste(c, crate(w2, h2, seed=700 + i), X(12) - w2 // 2 + dx, base - h2)
        base -= h2
    stand(c, rotate(rolled_carpet_lying(seed=703), 0), X(20))
    stand(c, chair(seed=704, broken=True), X(38))
    stand(c, leaning_frames(seed=705), X(65))
    stand(c, coat_stand(seed=706), X(85))
    return c


HALL = [
    ("hall_01_portraits.png", hall_portraits),
    ("hall_02_sconces.png", hall_sconces),
    ("hall_03_armour.png", hall_armour),
    ("hall_04_peeling.png", hall_peeling),
    ("hall_05_doors_shut.png", hall_doors),
    ("hall_06_boxes.png", hall_boxes),
]


def main():
    stats = [save(wall_hall(), "far/wall_hall_repeat.png")]
    for name, fn in HALL:
        stats.append(save(finish_layer(fn()), "layers/" + name))
    os.makedirs(QA, exist_ok=True)
    with open(os.path.join(QA, "검사_복도.json"), "w", encoding="utf-8") as f:
        json.dump(stats, f, ensure_ascii=False, indent=1)
    for s in stats:
        print(s)
    # 검수판: 마젠타 위 6 장 + 복도 벽 3×2
    mag = np.array([1.0, 0.0, 0.765])
    tiles = []
    for n, _ in HALL:
        cc = arr(Image.open(os.path.join(OUT, "layers", n)).convert("RGBA"))
        rgb = cc[..., :3] * 2.2 * cc[..., 3:4] + mag * (1 - cc[..., 3:4])
        im = to_im(np.clip(rgb, 0, 1)).resize((768, 512))
        d = ImageDraw.Draw(im); d.text((8, 8), n, fill=(255, 255, 0))
        d.line([(0, FLOOR // 2), (768, FLOOR // 2)], fill=(0, 255, 255))
        tiles.append(im)
    sheet = Image.new("RGB", (768 * 3, 512 * 2))
    for i, t in enumerate(tiles):
        sheet.paste(t, ((i % 3) * 768, (i // 3) * 512))
    sheet.save(os.path.join(QA, "마젠타_검수판_복도.png"))
    wall = Image.open(os.path.join(OUT, "far/wall_hall_repeat.png")).convert("RGB")
    t = Image.new("RGB", (wall.width * 3, wall.height * 2))
    for i in range(3):
        for j in range(2):
            t.paste(wall, (i * wall.width, j * wall.height))
    t.point(lambda v: min(255, int(v * 1.8))).resize((t.width // 2, t.height // 2)).save(os.path.join(QA, "복도벽_3x2.png"))


if __name__ == "__main__":
    main()
