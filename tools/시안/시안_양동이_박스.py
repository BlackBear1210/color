# -*- coding: utf-8 -*-
"""양동이 · 박스 외관 시안 2종씩 — 한 장짜리 비교 시트.
호퍼 원화(주철 아틀라스)의 금속 결을 빌려 재질을 맞춘다(가시·톱 시안과 같은 방식).
4 배로 그려 줄인다. 게임 크기(1:1) 띠 + 3 배 확대를 같이 보여 준다.
"""
import os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = sys.argv[1] if len(sys.argv) > 1 else "시안.png"
S = 4

atlas = np.asarray(Image.open(os.path.join(ROOT, "assets/textures/obstacles/hopper/cast_iron_v1/hopper_atlas.png")).convert("RGB")).astype(np.float32)
_m = atlas[420:540, 180:330].mean(2)
_m = np.asarray(Image.fromarray(_m.astype(np.uint8)).resize((315, 252), Image.LANCZOS)).astype(np.float32)
GRAIN = np.clip(_m / _m.mean(), 0.72, 1.3)


def grain(w, h, seed, amt=1.0):
    r = np.random.default_rng(seed)
    t = np.tile(GRAIN, (h // GRAIN.shape[0] + 2, w // GRAIN.shape[1] + 2))
    y0, x0 = r.integers(0, GRAIN.shape[0]), r.integers(0, GRAIN.shape[1])
    g = t[y0:y0 + h, x0:x0 + w]
    return 1 + (g - 1) * amt


def woodgrain(w, h, seed, vertical=True):
    """나무결 — 가는 줄 + 옹이 느낌의 저주파 흔들림."""
    r = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    a, b = (xx, yy) if vertical else (yy, xx)
    wob = np.sin(b / (37 + r.random() * 20) + r.random() * 6) * 6 + np.sin(b / 11 + r.random() * 6) * 1.5
    lines = np.sin((a + wob) * (0.9 + r.random() * 0.3)) * 0.5 + 0.5
    lines2 = np.sin((a + wob * 1.7) * 0.23 + r.random() * 6) * 0.5 + 0.5
    n = r.normal(0, 1, (h // 4 + 1, w // 4 + 1))
    n = np.asarray(Image.fromarray(((n + 3) * 40).clip(0, 255).astype(np.uint8)).resize((w, h), Image.BILINEAR)).astype(np.float32) / 120
    return 0.82 + lines ** 6 * -0.18 + lines2 * 0.12 + (n - 1) * 0.12


class Canvas:
    """게임 좌표(원점 = 발 밑 중앙)로 그리는 4 배 RGBA 캔버스."""

    def __init__(s, w, h, ox, oy):
        s.W, s.H = w * S, h * S
        s.ox, s.oy = ox * S, oy * S
        s.rgb = np.zeros((s.H, s.W, 3), np.float32)
        s.a = np.zeros((s.H, s.W), np.float32)
        s.yy, s.xx = np.mgrid[0:s.H, 0:s.W]
        s.gx = (s.xx - s.ox) / S          # 게임 좌표
        s.gy = (s.yy - s.oy) / S

    def P(s, pts):
        return [(x * S + s.ox, y * S + s.oy) for x, y in pts]

    def mask(s, fn):
        m = Image.new("L", (s.W, s.H), 0)
        fn(ImageDraw.Draw(m))
        return np.asarray(m).astype(np.float32) / 255

    def poly(s, pts):
        return s.mask(lambda d: d.polygon(s.P(pts), fill=255))

    def ell(s, cx, cy, rx, ry):
        return s.mask(lambda d: d.ellipse(s.P([(cx - rx, cy - ry), (cx + rx, cy + ry)]), fill=255))

    def line(s, pts, w):
        return s.mask(lambda d: d.line(s.P(pts), fill=255, width=int(w * S), joint="curve"))

    def paint(s, m, col, alpha=1.0):
        col = np.asarray(col, np.float32)
        if col.ndim == 1:
            col = np.broadcast_to(col, s.rgb.shape)
        k = (m * alpha)[..., None]
        s.rgb = s.rgb * (1 - k) + col * k
        s.a = s.a + (1 - s.a) * m * alpha

    def outline(s, m, px=1.6, col=(0.04, 0.04, 0.045)):
        """마스크 바깥 테두리를 어둡게 — 호퍼 원화의 굵은 외곽선."""
        img = Image.fromarray((m * 255).astype(np.uint8))
        d = np.asarray(img.filter(ImageFilter.MaxFilter(int(px * S) | 1))).astype(np.float32) / 255
        ring = np.clip(d - m, 0, 1)
        s.paint(ring, col)

    def rivet(s, x, y, r=2.6, base=0.42):
        m = s.ell(x, y, r, r)
        d = np.hypot(s.gx - (x - r * 0.35), s.gy - (y - r * 0.35)) / r
        shade = np.clip(1.25 - d * 0.75, 0.35, 1.3)
        s.paint(s.ell(x + 0.6, y + 0.8, r, r), (0.03, 0.03, 0.03), 0.7)
        s.paint(m, base * shade[..., None] * np.ones(3))

    def image(s, scale):
        rgba = np.dstack([np.clip(s.rgb, 0, 1) * 255, s.a * 255]).astype(np.uint8)
        im = Image.fromarray(rgba, "RGBA")
        # 알파 가장자리 번짐 방지: 미리 곱한 뒤 줄이고 되돌린다
        pm = np.asarray(im).astype(np.float32)
        pm[..., :3] *= pm[..., 3:4] / 255
        imp = Image.fromarray(pm.astype(np.uint8), "RGBA").resize((round(s.W * scale / S), round(s.H * scale / S)), Image.LANCZOS)
        q = np.asarray(imp).astype(np.float32)
        a = q[..., 3:4] / 255
        q[..., :3] = np.where(a > 0, q[..., :3] / np.maximum(a, 1e-3), 0)
        return Image.fromarray(q.clip(0, 255).astype(np.uint8), "RGBA")


# 색 번호 = ColorDefs (0 검정 · 1 흰색 · 2 회색)
PAINT = {0: 0.085, 1: 0.86, 2: 0.44}
WATER = {0: (0.05, 0.05, 0.06), 1: (0.93, 0.95, 0.97), 2: (0.50, 0.52, 0.55)}
IRON = 0.40


def cyl(c, x0, x1, hi=0.32, lo=0.55, spec=0.0):
    """원통 음영 — 왼쪽 1/3 이 밝고 오른쪽 끝이 어둡다."""
    t = np.clip((c.gx - x0) / (x1 - x0), 0, 1)
    v = 1 - lo * (np.abs(t - hi) / np.maximum(hi, 1 - hi)) ** 1.6
    v += spec * np.exp(-((t - hi) / 0.05) ** 2)
    return v


# ─────────────────────────────── 양동이 시안 1 · 주철 들통(에나멜 칠)
def 양동이_1(색, 물참):
    c = Canvas(150, 170, 75, 160)
    g = grain(c.W, c.H, 11 + 색)
    top, bot = -100, -8
    tw, bw = 47, 39
    body = [(-tw, top), (tw, top), (bw, bot), (-bw, bot)]
    m_body = c.poly(body)
    shade = cyl(c, -tw, tw, spec=0.25 if 색 == 1 else 0.5)
    p = PAINT[색]
    col = p * shade * (1 + (g - 1) * (0.35 if 색 == 1 else 0.8))
    if 색 == 0:
        col = col + 0.05 * shade        # 검정 칠도 윤곽은 읽히게 반사광을 조금
    c.paint(m_body, col[..., None] * np.ones(3))
    # 칠 벗겨짐 — 테 주변·아래 모서리에 쇠가 드러난다(색은 칠이 정한다는 것을 보여 주는 흠)
    r = np.random.default_rng(3 + 색)
    for _ in range(9):
        y = r.choice([-86, -84, -30, -28, -14, -12]) + r.normal(0, 2)
        x = r.uniform(-38, 38)
        chip = c.ell(x, y, r.uniform(1.5, 4.5), r.uniform(1, 2.5)) * m_body
        c.paint(chip, (IRON * 0.9 * g)[..., None] * np.ones(3) * shade[..., None])
    # 녹물 자국 — 테 아래로 흘러내림(회색 쇠 톤)
    for x in r.uniform(-34, 34, 4):
        streak = c.line([(x, -76), (x + r.normal(0, 1), -76 + r.uniform(14, 34))], r.uniform(1.2, 2.5)) * m_body
        c.paint(streak, (IRON * 0.8,) * 3, 0.35)
    c.outline(m_body, 1.8)
    # 쇠테 2 줄 + 발테
    def band(y, h, wscale):
        wt = tw + (bw - tw) * (y - top) / (bot - top) + 1.5
        wb = tw + (bw - tw) * (y + h - top) / (bot - top) + 1.5
        m = c.poly([(-wt, y), (wt, y), (wb, y + h), (-wb, y + h)])
        sh = cyl(c, -wt, wt, spec=0.6)
        bg = grain(c.W, c.H, int(y) & 255)
        c.paint(m, (IRON * sh * bg)[..., None] * np.ones(3))
        c.paint(c.poly([(-wt, y), (wt, y), (wt, y + 1), (-wt, y + 1)]), (0.72,) * 3, 0.6)
        c.outline(m, 1.4)
        for xx in (-wt * 0.62, 0, wt * 0.62):
            c.rivet(xx, y + h / 2, 1.8)
    band(-84, 7, 1)
    band(-32, 7, 1)
    fm = c.poly([(-bw - 1, -10), (bw + 1, -10), (bw - 2, -2), (-bw + 2, -2)])
    c.paint(fm, (IRON * 0.75 * cyl(c, -bw, bw) * g)[..., None] * np.ones(3))
    c.outline(fm, 1.4)
    # 귀(손잡이 고리판)
    for sx in (-1, 1):
        ear = c.poly([(sx * 40, -98), (sx * 52, -98), (sx * 52, -86), (sx * 44, -80), (sx * 40, -80)])
        c.paint(ear, (IRON * 0.95 * g)[..., None] * np.ones(3))
        c.outline(ear, 1.3)
        c.rivet(sx * 47, -92, 2.4)
    # 입구 — 살짝 위에서 본 타원. 안쪽은 어둡고, 물이 차면 수면이 보인다.
    rim_o = c.ell(0, top, tw + 3, 8)
    c.paint(rim_o, (IRON * 1.15 * g)[..., None] * np.ones(3))
    c.outline(rim_o, 1.4)
    inner = c.ell(0, top + 0.5, tw - 2, 5.2)
    c.paint(inner, (0.035,) * 3)
    if 물참:
        wc = np.asarray(WATER[색])
        surf = c.ell(0, top + 1.8, tw - 3.5, 3.9)
        wave = 1 + 0.06 * np.sin(c.gx * 0.5)
        c.paint(surf, wc * wave[..., None])
        hl = c.line([(-26, top + 0.5), (-8, top + 0.2)], 1.2) * surf
        c.paint(hl, (1, 1, 1) if 색 != 1 else (0.7, 0.72, 0.75), 0.5)
        # 넘친 물 한 줄 — 몸통 앞으로(가득 찼다는 신호)
        drip = c.line([(20, top + 4), (21, top + 16), (20.5, top + 22)], 2.4)
        c.paint(drip, wc)
        c.paint(c.ell(20.5, top + 23, 2, 2.6), wc)
    # 손잡이 — 쇠 둥근막대 + 가운데 나무 손잡이
    arc = [(sx * 47, -92) for sx in (-1,)]
    pts = []
    for t in np.linspace(0, np.pi, 40):
        pts.append((-47 * np.cos(t), -92 - 44 * np.sin(t)))
    hm = c.line(pts, 3.2)
    c.paint(c.line([(x + 1, y + 1.5) for x, y in pts], 3.4), (0.02,) * 3, 0.55)
    c.outline(hm, 1.2)
    c.paint(hm, (IRON * 1.05,) * 3)
    c.paint(c.line(pts[3:20], 1.0), (0.66,) * 3, 0.6)
    grip = c.poly([(-13, -140), (13, -140), (13, -132), (-13, -132)])
    c.paint(grip, ((0.30 * woodgrain(c.W, c.H, 5, vertical=False)))[..., None] * np.ones(3))
    c.outline(grip, 1.2)
    return c


# ─────────────────────────────── 양동이 시안 2 · 통널 나무통(쇠테 셋 · 밧줄)
def 양동이_2(색, 물참):
    c = Canvas(150, 170, 75, 160)
    top, bot = -98, -6
    half = 44
    staves = 7
    wg = woodgrain(c.W, c.H, 21 + 색)
    # 몸통 = 살짝 배부른 통 — 가운데가 1.5 넓다
    def hw(y):
        t = (y - top) / (bot - top)
        return half - 3 * t + 3 * np.sin(np.pi * t)
    ys = np.linspace(top, bot, 30)
    outline_pts = [(-hw(y), y) for y in ys] + [(hw(y), y) for y in ys[::-1]]
    m_body = c.poly(outline_pts)
    base = {0: 0.13, 1: 0.84, 2: 0.46}[색]
    grain_amt = {0: 0.9, 1: 0.55, 2: 1.2}[색]
    shade = cyl(c, -half, half, spec=0.15)
    col = base * shade * (1 + (wg - 1) * grain_amt * 1.6)
    if 색 == 0:
        col += 0.06 * shade
    c.paint(m_body, col[..., None] * np.ones(3))
    # 통널 이음 — 가운데로 모이는 원통 투영(바깥 통널이 좁아 보인다)
    for k in range(1, staves):
        a = -np.pi / 2 + np.pi * k / staves
        f = np.sin(a)
        seam = c.line([(hw(y) * f, y) for y in ys], 1.1) * m_body
        c.paint(seam, (0.02,) * 3 if 색 != 1 else (0.35,) * 3, 0.8)
        c.paint(c.line([(hw(y) * f + 1.2, y) for y in ys], 0.6) * m_body, (1, 1, 1), 0.08 if 색 == 0 else 0.15)
    # 흰 통 = 석회칠이 결 사이로 벗겨진 흔적
    if 색 == 1:
        r = np.random.default_rng(7)
        for _ in range(14):
            x, y = r.uniform(-38, 38), r.uniform(-90, -12)
            ch = c.ell(x, y, r.uniform(0.8, 2.5), r.uniform(3, 7)) * m_body
            c.paint(ch, (0.5,) * 3, 0.35)
    c.outline(m_body, 1.8)
    # 쇠테 3 줄
    for y in (-88, -52, -18):
        w0 = hw(y) + 1.4
        m = c.poly([(-w0, y), (w0, y), (w0, y + 6), (-w0, y + 6)])
        c.paint(m, (IRON * cyl(c, -w0, w0, spec=0.6) * grain(c.W, c.H, int(-y)))[..., None] * np.ones(3))
        c.paint(c.poly([(-w0, y), (w0, y), (w0, y + 1), (-w0, y + 1)]), (0.7,) * 3, 0.5)
        c.outline(m, 1.3)
        for xx in (-w0 * 0.8, w0 * 0.8):
            c.rivet(xx, y + 3, 1.5, 0.5)
    # 귀 통널 — 양쪽 두 장이 길게 솟아 구멍에 밧줄을 꿴다(두레박)
    for sx in (-1, 1):
        ear = c.poly([(sx * 30, top + 2), (sx * 42, top + 2), (sx * 41, top - 22), (sx * 36, top - 26), (sx * 31, top - 22)])
        ew = woodgrain(c.W, c.H, 31 + sx)
        c.paint(ear, (base * 0.92 * (1 + (ew - 1) * grain_amt * 1.6) * (0.9 if sx > 0 else 1.05))[..., None] * np.ones(3))
        if 색 == 0:
            c.paint(ear, (0.2,) * 3, 0.25)
        c.outline(ear, 1.4)
        c.paint(c.ell(sx * 36, top - 16, 2.6, 2.6), (0.02,) * 3)
    # 입구
    rim = c.ell(0, top, half - 1, 7)
    c.paint(rim, (base * 1.05 * wg)[..., None] * np.ones(3) + (0.05 if 색 == 0 else 0))
    c.outline(rim, 1.3)
    c.paint(c.ell(0, top + 0.5, half - 5, 4.4), (0.035,) * 3)
    if 물참:
        wc = np.asarray(WATER[색])
        surf = c.ell(0, top + 1.6, half - 7, 3.3)
        c.paint(surf, wc)
        c.paint(c.line([(-20, top + 0.3), (-4, top + 0.1)], 1.0) * surf, (1, 1, 1) if 색 != 1 else (0.7, 0.72, 0.75), 0.5)
        # 통널 틈으로 새는 물 두 줄
        for x, L in ((-12, 26), (16, 18)):
            d = c.line([(x, top + 6), (x + 0.5, top + 6 + L)], 2.0)
            c.paint(d, wc, 0.95)
            c.paint(c.ell(x + 0.5, top + 7 + L, 1.8, 2.3), wc)
    # 밧줄 — 귀 구멍 사이, 꼬인 무늬
    pts = []
    for t in np.linspace(0, 1, 50):
        x = -36 + 72 * t
        y = top - 16 - 22 * np.sin(np.pi * t)
        pts.append((x, y))
    rope = c.line(pts, 3.6)
    c.outline(rope, 1.1)
    tw_ = 0.5 + 0.5 * np.sin((c.gx * 0.9 + c.gy * 0.9) * 1.6)
    c.paint(rope, ((0.36 + 0.16 * tw_))[..., None] * np.ones(3))
    return c


# ─────────────────────────────── 박스 시안 1 · 주철 무게 궤짝
def 박스_1():
    c = Canvas(130, 130, 65, 115)
    g = grain(c.W, c.H, 41)
    x0, x1, y0, y1 = -48, 48, -96, 0
    m = c.poly([(x0, y0), (x1, y0), (x1, y1), (x0, y1)])
    c.paint(m, (0.34 * g)[..., None] * np.ones(3))
    # 들어간 가운데 판 — 위는 그늘, 아래는 반사
    inner = c.poly([(-37, -85), (37, -85), (37, -11), (-37, -11)])
    ig = (0.25 + 0.07 * np.clip((c.gy + 85) / 74, 0, 1)) * grain(c.W, c.H, 42)
    c.paint(inner, ig[..., None] * np.ones(3))
    c.paint(c.poly([(-37, -85), (37, -85), (37, -82), (-37, -82)]), (0.05,) * 3, 0.7)
    c.paint(c.poly([(-37, -85), (-34, -85), (-34, -11), (-37, -11)]), (0.06,) * 3, 0.6)
    # X 보강대
    for a, b in (((-35, -83), (35, -13)), ((35, -83), (-35, -13))):
        bm = c.line([a, b], 7.5) * inner
        c.paint(c.line([(a[0] + 1, a[1] + 2), (b[0] + 1, b[1] + 2)], 7.5) * inner, (0.03,) * 3, 0.6)
        c.paint(bm, (0.40 * grain(c.W, c.H, 43))[..., None] * np.ones(3))
        c.paint(c.line([(a[0], a[1] - 2.8), (b[0], b[1] - 2.8)], 1.0) * bm, (0.62,) * 3, 0.55)
    # 가운데 둥근 추 표식 — "무겁다" 를 글자 없이
    disc = c.ell(0, -48, 13, 13)
    c.paint(c.ell(1, -46.5, 13, 13), (0.03,) * 3, 0.6)
    d = np.hypot(c.gx + 4, c.gy + 52) / 13
    c.paint(disc, (0.42 * np.clip(1.2 - d * 0.5, 0.6, 1.2) * g)[..., None] * np.ones(3))
    c.outline(disc, 1.2)
    c.paint(c.poly([(-5, -51), (5, -51), (0, -42)]), (0.08,) * 3, 0.9)   # 아래 화살 = 누른다
    # 테두리 모서리 빛
    c.paint(c.poly([(x0, y0), (x1, y0), (x1, y0 + 2.2), (x0, y0 + 2.2)]), (0.75,) * 3, 0.7)   # 윗면 = 올라설 수 있다
    c.paint(c.poly([(x0, y0), (x0 + 2, y0), (x0 + 2, y1), (x0, y1)]), (0.6,) * 3, 0.35)
    c.paint(c.poly([(x1 - 2.5, y0), (x1, y0), (x1, y1), (x1 - 2.5, y1)]), (0.02,) * 3, 0.5)
    c.paint(c.poly([(x0, y1 - 3), (x1, y1 - 3), (x1, y1), (x0, y1)]), (0.03,) * 3, 0.5)
    for x in (-42.5, -21, 0, 21, 42.5):
        c.rivet(x, -90.5, 2.2)
        c.rivet(x, -5.5, 2.2)
    for y in (-69, -48, -27):
        c.rivet(-42.5, y, 2.2)
        c.rivet(42.5, y, 2.2)
    # 긁힘
    r = np.random.default_rng(9)
    for _ in range(6):
        x, y = r.uniform(-44, 44), r.uniform(-94, -2)
        c.paint(c.line([(x, y), (x + r.uniform(-6, 6), y + r.uniform(-3, 3))], 0.6) * m, (0.62,) * 3, 0.35)
    c.outline(m, 2.0)
    return c


# ─────────────────────────────── 박스 시안 2 · 나무 궤짝(쇠 모서리)
def 박스_2():
    c = Canvas(130, 130, 65, 115)
    x0, x1, y0, y1 = -48, 48, -96, 0
    m = c.poly([(x0, y0), (x1, y0), (x1, y1), (x0, y1)])
    wg = woodgrain(c.W, c.H, 51, vertical=False)
    c.paint(m, (0.40 * wg)[..., None] * np.ones(3))
    # 가로 널 4 장 — 이음 틈
    for y in (-72, -48, -24):
        c.paint(c.line([(x0, y), (x1, y)], 1.6) * m, (0.04,) * 3, 0.9)
        c.paint(c.line([(x0, y + 1.6), (x1, y + 1.6)], 0.7) * m, (0.7,) * 3, 0.25)
    # 널마다 톤을 조금씩 달리
    for i, (ya, yb) in enumerate(((-96, -72), (-72, -48), (-48, -24), (-24, 0))):
        c.paint(c.poly([(x0, ya), (x1, ya), (x1, yb), (x0, yb)]), (0.0,) * 3, (0.0, 0.10, 0.04, 0.16)[i])
    # 대각 버팀목(왼아래 → 오른위)
    brace = c.poly([(-38, -8), (-26, -8), (38, -84), (26, -84)])
    bw = woodgrain(c.W, c.H, 52, vertical=True)
    c.paint(c.poly([(-37, -6), (-25, -6), (39, -82), (27, -82)]), (0.03,) * 3, 0.6)
    c.paint(brace, (0.46 * bw)[..., None] * np.ones(3))
    c.outline(brace, 1.2)
    # 세로 테두리 널
    for xa in (x0, x1 - 10):
        side = c.poly([(xa, y0), (xa + 10, y0), (xa + 10, y1), (xa, y1)])
        c.paint(side, (0.43 * woodgrain(c.W, c.H, 53 + xa, vertical=True))[..., None] * np.ones(3))
        c.outline(side, 1.0)
    # 쇠 모서리(ㄱ자 네 개) + 못
    g = grain(c.W, c.H, 55)
    for sx, sy in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
        cx = x0 if sx < 0 else x1
        cy = y0 if sy < 0 else y1
        L, T = 22, 6
        pts = [(cx, cy), (cx - sx * L, cy), (cx - sx * L, cy - sy * T), (cx - sx * T, cy - sy * T), (cx - sx * T, cy - sy * L), (cx, cy - sy * L)]
        k = c.poly(pts)
        c.paint(k, (IRON * g)[..., None] * np.ones(3))
        c.outline(k, 1.2)
        c.rivet(cx - sx * 3.2, cy - sy * 3.2, 1.7, 0.5)
        c.rivet(cx - sx * 16, cy - sy * 3.1, 1.4, 0.5)
        c.rivet(cx - sx * 3.1, cy - sy * 16, 1.4, 0.5)
    c.paint(c.poly([(x0, y0), (x1, y0), (x1, y0 + 2), (x0, y0 + 2)]), (0.78,) * 3, 0.55)
    c.paint(c.poly([(x1 - 2.5, y0), (x1, y0), (x1, y1), (x1 - 2.5, y1)]), (0.02,) * 3, 0.45)
    c.outline(m, 2.0)
    return c


# ─────────────────────────────── 시트 조립
FONT = lambda sz, b=False: ImageFont.truetype(r"C:\Windows\Fonts\malgunbd.ttf" if b else r"C:\Windows\Fonts\malgun.ttf", sz)
BG = (22, 22, 24)
W, H = 1800, 1560
sheet = Image.new("RGB", (W, H), BG)
dr = ImageDraw.Draw(sheet)

bg_src = Image.open(os.path.join(ROOT, "assets/background/stage_2/sewer_01_main_passage.png")).convert("RGB")
brick = Image.open(os.path.join(ROOT, "assets/textures/smartshape/sewer_masonry_v01/brick_fill.png")).convert("RGB")
brick_w = Image.open(os.path.join(ROOT, "assets/textures/smartshape/sewer_masonry_v01/brick_fill_white.png")).convert("RGB")
top_b = Image.open(os.path.join(ROOT, "assets/textures/smartshape/sewer_masonry_v01/black/top.png")).convert("RGBA")
pl_black = Image.open(os.path.join(ROOT, "assets/p/black/Idle.png")).convert("RGBA").crop((0, 0, 640, 640))
pl_white = Image.open(os.path.join(ROOT, "assets/p/white/Idle.png")).convert("RGBA").crop((0, 0, 640, 640))
PL = 0.2031


def scene_strip(w, h, floor_split=None):
    """게임 1:1 띠: 하수도 배경 + 검정 벽돌 바닥(오른쪽 일부는 흰 바닥)."""
    k = w / bg_src.width
    big = bg_src.resize((w, int(bg_src.height * k)))
    im = big.crop((0, big.height - h - 40, w, big.height - 40))
    im = Image.eval(im, lambda v: int(v * 0.8))
    fy = h - 60
    bb = brick.resize((500, 500)).crop((0, 0, w, 60))
    im.paste(bb, (0, fy))
    if floor_split:
        bw_ = brick_w.resize((500, 500)).crop((60, 20, 60 + w - floor_split, 80))
        im.paste(bw_, (floor_split, fy))
    t = top_b.resize((top_b.width * 18 // top_b.height, 18))
    for x in range(0, floor_split or w, t.width):
        im.paste(t, (x, fy - 6), t)
    return im.convert("RGBA"), fy


def place(dst, obj_img, x, fy, ox_px, oy_px):
    dst.alpha_composite(obj_img, (int(x - ox_px), int(fy - oy_px)))


def shadow(dst, x, fy, w):
    sh = Image.new("RGBA", dst.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).ellipse((x - w / 2, fy - 4, x + w / 2, fy + 5), fill=(0, 0, 0, 150))
    dst.alpha_composite(sh.filter(ImageFilter.GaussianBlur(3)))


def player(dst, x, fy, white=False):
    p = (pl_white if white else pl_black).resize((int(640 * PL), int(640 * PL)), Image.LANCZOS)
    dst.alpha_composite(p, (int(x - p.width / 2), int(fy - 50 - p.height / 2)))


def label(x, y, t, sz=18, b=False, col=(215, 215, 215)):
    dr.text((x, y), t, font=FONT(sz, b), fill=col)


dr.text((40, 26), "양동이 · 박스 외관 시안", font=FONT(40, True), fill=(230, 230, 230))
label(40, 84, "재질은 호퍼 원화 주철 결을 빌림 · 판정 크기 그대로(양동이 92×94 · 박스 96×96) · 확대 3배 + 게임 1:1 띠", 18, col=(160, 160, 160))

PANEL_W, PANEL_H = 850, 700


def panel(px, py, title, sub, bucket_fn=None, box_fn=None):
    dr.rectangle((px, py, px + PANEL_W, py + PANEL_H), outline=(70, 70, 74), width=2, fill=(30, 30, 33))
    label(px + 18, py + 12, title, 26, True, (235, 235, 235))
    label(px + 18, py + 50, sub, 16, col=(165, 165, 165))
    big_y = py + 385      # 확대 그림의 바닥선
    if bucket_fn:
        items = [("검정 · 빔", bucket_fn(0, False)), ("검정 · 참", bucket_fn(0, True)),
                 ("흰색 · 참", bucket_fn(1, True)), ("회색 · 장식", bucket_fn(2, False))]
        xs = [px + 110 + i * 210 for i in range(4)]
        scale = 1.55
        for (name, c), x in zip(items, xs):
            im = c.image(scale)
            sheet.paste(im, (int(x - 75 * scale), int(big_y - 160 * scale)), im)
            label(x - 40, big_y + 8, name, 16, col=(190, 190, 190))
        strip, fy = scene_strip(PANEL_W - 36, 190, floor_split=520)
        objs = [(bucket_fn(0, False), 120), (bucket_fn(0, True), 330), (bucket_fn(1, True), 640)]
        for c, x in objs:
            shadow(strip, x, fy, 80)
            place(strip, c.image(1), x, fy, 75, 160)
        player(strip, 225, fy)
        player(strip, 745, fy, white=True)
    else:
        items = [("", box_fn())]
        c = box_fn()
        im = c.image(3)
        sheet.paste(im, (int(px + PANEL_W / 2 - 65 * 3), int(big_y + 30 - 115 * 3)), im)
        strip, fy = scene_strip(PANEL_W - 36, 190, floor_split=520)
        # 누름 버튼 자리 표시(바닥 홈) 위에 올린 박스 + 두 색 플레이어
        for x in (170, 640):
            shadow(strip, x, fy, 90)
            place(strip, c.image(1), x, fy, 65, 115)
        player(strip, 290, fy)
        player(strip, 760, fy, white=True)
    sheet.paste(strip.convert("RGB"), (px + 18, py + PANEL_H - 208))
    label(px + 24, py + PANEL_H - 206, "게임 1:1 · 왼쪽 검정 바닥 / 오른쪽 흰 바닥", 13, col=(200, 200, 200))


panel(40, 125, "양동이 시안 1 — 주철 들통",
      "쇠 몸통에 검정/흰 에나멜 칠 · 벗겨진 칠 아래 쇠 · 쇠테 2줄 + 나무 손잡이 · 찼을 때 수면 + 넘친 물 한 줄", bucket_fn=양동이_1)
panel(910, 125, "양동이 시안 2 — 통널 나무통(두레박)",
      "통널 7장 + 쇠테 3줄 · 검정 = 타르칠, 흰색 = 석회칠 · 귀 통널에 밧줄 · 찼을 때 통널 틈으로 새는 물", bucket_fn=양동이_2)
panel(40, 840, "박스 시안 1 — 주철 무게 궤짝",
      "색 없는 쇠 회색(흑/백 어느 쪽으로도 안 읽힘) · X 보강 + 리벳 · 가운데 '추' 표식(▼ = 누른다) · 윗면 밝은 선", box_fn=박스_1)
panel(910, 840, "박스 시안 2 — 쇠 모서리 나무 궤짝",
      "가로 널 4장 + 대각 버팀목 · ㄱ자 쇠 모서리 4개 · 나무 중간톤 = 색 없음 · 손으로 미는 물건이라는 인상", box_fn=박스_2)

sheet.save(OUT)
print("saved", OUT)
