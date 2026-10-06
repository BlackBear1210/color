# -*- coding: utf-8 -*-
"""
집 배경 키트 v05 — 방 스테이지용 (2026-09-28 · Claude)
============================================================================
아스트라 코인이 떨어져서 v05 주문서(바탕화면 `집 배경 이미지/아스트라_프롬프트_집배경_v04.md`)
의 방 쪽 부품을 **여기서 직접 만든다.** 나는 이미지를 생성할 수 없으므로 방법은 두 가지뿐이다.

  1. 이미 받은 그림(아스트라·Codex 납품본)에서 **부품을 잘라** 규격에 맞게 다시 앉힌다
     — 책장·스탠드·소파·계단·창·아치·샹들리에.
  2. 없는 가구(옷장·침대·궤짝·괘종시계·피아노·의자·먼지천·벽난로)는 **코드로 그린다.**
     모양은 다각형, 표면은 A1 벽 타일의 나무·회반죽 결을 잘라 입힌다 → 같은 붓질 결.

그래서 파일 이름·캔버스·바닥선은 주문서 §6 과 **똑같다.** 아스트라가 나중에 진짜 그림을
주면 같은 이름으로 덮어쓰기만 하면 된다 (`집_배경.gd` 는 안 고쳐도 된다).

실행:  python tools/배경키트_v05/만들기.py
출력:  assets/background/집/room_kit_v05/{far,layers,mid,fg}/*.png  + 검수판 PNG
============================================================================
"""
import os, sys, math, json
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
SRC = os.path.join(HERE, "원본")
OUT = os.path.join(ROOT, "assets", "background", "집", "room_kit_v05")
QA = os.path.join(ROOT, "artifacts", "집배경_v05_키트")

W, H = 1536, 1024          # 레이어 캔버스 (주문서 §4)
FLOOR = int(H * 0.87)      # 바닥선 y 891
HUMAN = 77                 # 사람 키 = 캔버스 높이 7.5 %
SS = 2                     # 코드 그림 초과표본 배율(가장자리 계단 방지)
## ★가구 배율 — 주문서 §4 표(책장 = 사람 키 1.8 배)에 곱한다.
##   §4 표대로 그리면 가구가 '사람 크기 집'의 가구라 플레이어와 같은 종족처럼 보인다.
##   이 게임은 "작은 생명체가 큰 집을 돌아다닌다"(주문서 §9-3 · 도형님 지시)이므로
##   가구를 키워서 플레이어를 작게 느끼게 한다. 1.0 으로 두면 주문서 표 그대로.
가구배율 = 2.2

rng = np.random.default_rng(20260928)


# ============================================================================
# 공통 도구
# ============================================================================
def load(name, mode="RGBA"):
    return Image.open(os.path.join(SRC, name)).convert(mode)


def arr(im):
    return np.asarray(im).astype(np.float32) / 255.0


def to_im(a):
    return Image.fromarray(np.clip(a * 255.0 + 0.5, 0, 255).astype(np.uint8))


def luma(rgb):
    return rgb[..., 0] * 0.299 + rgb[..., 1] * 0.587 + rgb[..., 2] * 0.114


def band_split(v, lo=0.40, hi=0.60):
    """§3 명도 규칙: 40~60 % 는 쓰지 않는다(45~55 % 는 회색 안전 지형 전용).
    아래쪽 절반은 40 % 밑으로, 위쪽 절반은 60 % 위로 밀어낸다."""
    v = v.copy()
    m = (v > lo) & (v < hi)
    mid = (lo + hi) / 2
    v[m & (v <= mid)] = lo - 0.02 - (mid - v[m & (v <= mid)]) * 0.2
    v[m & (v > mid)] = hi + 0.02 + (v[m & (v > mid)] - mid) * 0.2
    return v


def gray_rgba(v, a):
    """중성 회색(§3: 색조 금지) RGBA 배열."""
    v = np.clip(v, 0, 1)
    return np.dstack([v, v, v, np.clip(a, 0, 1)])


def dark_rim(v, a, px=3, amount=0.35):
    """가장자리 안쪽을 어둡게 — 밝은 후광의 반대. 윤곽이 '뒤로 물러나' 보인다."""
    inside = a > 0.5
    dist = ndimage.distance_transform_edt(inside)
    k = np.clip(1 - dist / px, 0, 1) * amount
    return v * (1 - k)


def paste(canvas, part, x, y):
    """canvas(RGBA float) 위에 part(RGBA float)를 알파 합성. x,y = 왼쪽 위."""
    ph, pw = part.shape[:2]
    x0, y0 = max(0, x), max(0, y)
    x1, y1 = min(canvas.shape[1], x + pw), min(canvas.shape[0], y + ph)
    if x1 <= x0 or y1 <= y0:
        return
    p = part[y0 - y:y1 - y, x0 - x:x1 - x]
    c = canvas[y0:y1, x0:x1]
    pa = p[..., 3:4]
    out_a = pa + c[..., 3:4] * (1 - pa)
    out_rgb = (p[..., :3] * pa + c[..., :3] * c[..., 3:4] * (1 - pa)) / np.maximum(out_a, 1e-6)
    canvas[y0:y1, x0:x1, :3] = out_rgb
    canvas[y0:y1, x0:x1, 3:4] = out_a


def big(part):
    return scale_part(part, height=part.shape[0] * 가구배율) if 가구배율 != 1.0 else part


def stand(canvas, part, cx, floor=FLOOR, sink=0, raw=False):
    """(raw=False 면 가구배율을 곱한다) part 의 맨 아래(알파 있는 마지막 줄)를 바닥선에 세운다. cx = 가운데 x."""
    if not raw:
        part = big(part)
    rows = np.where(part[..., 3].max(1) > 0.3)[0]
    bottom = rows[-1] if len(rows) else part.shape[0] - 1
    paste(canvas, part, int(cx - part.shape[1] / 2), int(floor - bottom + sink))


def scale_part(part, height=None, width=None):
    """part 를 목표 높이(또는 폭)로. 알파 가중 리샘플로 가장자리에 흰 테가 안 생기게."""
    h, w = part.shape[:2]
    s = (height / h) if height else (width / w)
    nw, nh = max(1, int(round(w * s))), max(1, int(round(h * s)))
    pre = part.copy()
    pre[..., :3] *= pre[..., 3:4]                 # 미리 곱한 알파 → 흰 가장자리 없음
    im = to_im(pre).resize((nw, nh), Image.LANCZOS)
    out = arr(im)
    out[..., :3] = out[..., :3] / np.maximum(out[..., 3:4], 1e-4)
    out[..., 3] = np.clip(out[..., 3], 0, 1)
    # 리샘플 링잉 때문에 알파가 얇은 가장자리에서 RGB 가 튀어 밝아진다 → 원본 최대 명도로 묶는다
    vis = part[..., 3] > 0.5
    top = float(part[..., :3][vis].max()) if vis.any() else 1.0
    out[..., :3] = np.minimum(out[..., :3], top)
    return np.clip(out, 0, 1)


def flip(part):
    return part[:, ::-1].copy()


def rotate(part, deg):
    pre = part.copy(); pre[..., :3] *= pre[..., 3:4]
    im = to_im(pre).rotate(deg, resample=Image.BICUBIC, expand=True)
    out = arr(im)
    out[..., :3] = out[..., :3] / np.maximum(out[..., 3:4], 1e-4)
    return np.clip(out, 0, 1)


# ── 결(텍스처) 창고 — 전부 A1 과 Codex 회반죽에서 잘라 온다 ────────────────
A1 = arr(load("astra_A1_wall_room.png", "L"))
PLASTER = arr(load("codex_plaster_a.png", "L"))
# A1 의 붙기둥(세로 나무결)과 벽판(회반죽) 구간 — 열 프로필로 찾은 자리
WOOD = A1[80:1450, 330:352]          # 붙기둥 몸통 한 줄: 세로결이 곧다
PANEL = A1[100:1000, 450:590]        # 큰 벽판 안쪽: 벗겨진 회반죽


def texture(h, w, kind="wood", horizontal=False, seed=0):
    """h×w 결 조각. 평균 0 · 표준편차 약 1 로 정규화해서 돌려준다."""
    r = np.random.default_rng(seed)
    if kind == "wood":
        src = WOOD.T if horizontal else WOOD
    elif kind == "panel":
        src = PANEL
    else:
        src = PLASTER
    sh, sw = src.shape
    # 필요하면 반복해서 늘린다
    reps = (h // sh + 2, w // sw + 2)
    big = np.tile(src, reps)
    y = r.integers(0, big.shape[0] - h)
    x = r.integers(0, big.shape[1] - w)
    t = big[y:y + h, x:x + w]
    t = (t - t.mean()) / (t.std() + 1e-5)
    return t


def mask_poly(h, w, polys, rects=(), ellipses=(), lines=()):
    """SS 배 초과표본으로 그린 뒤 줄여서 부드러운 가장자리 마스크."""
    im = Image.new("L", (w * SS, h * SS), 0)
    d = ImageDraw.Draw(im)
    for p in polys:
        d.polygon([(x * SS, y * SS) for x, y in p], fill=255)
    for r in rects:
        d.rectangle([r[0] * SS, r[1] * SS, r[2] * SS - 1, r[3] * SS - 1], fill=255)
    for e in ellipses:
        d.ellipse([e[0] * SS, e[1] * SS, e[2] * SS, e[3] * SS], fill=255)
    for (x0, y0, x1, y1, wd) in lines:
        d.line([x0 * SS, y0 * SS, x1 * SS, y1 * SS], fill=255, width=max(1, int(wd * SS)))
    return arr(im.resize((w, h), Image.LANCZOS))


def surface(mask, base, kind="wood", contrast=0.035, horizontal=False, seed=0,
            top_shade=0.10, rim=0.35):
    """마스크에 결을 입힌다. 위가 살짝 밝고 아래로 어두워지는 먼지 낀 실내광.
    §3: 윗면을 밝게 하지 않는다 — 대신 '가운데 조금 위'가 가장 밝게."""
    h, w = mask.shape
    t = texture(h, w, kind, horizontal, seed)
    yy = np.linspace(0, 1, h)[:, None]
    grad = 1.0 - top_shade * np.abs(yy - 0.35) * 2
    v = (base + t * contrast) * grad
    v = dark_rim(v, mask, px=3, amount=rim)
    return gray_rgba(np.clip(v, 0.03, 0.36), mask)   # §2 중경 대역 — 40 % 는 절대 안 넘는다


def layer_canvas():
    return np.zeros((H, W, 4), np.float32)


def add(part, over):
    """같은 크기 두 RGBA 를 합성(over 가 위)."""
    out = part.copy()
    paste(out, over, 0, 0)
    return out


def line_mask(h, w, segs):
    return mask_poly(h, w, [], lines=segs)


def darken_where(part, mask, amount):
    p = part.copy()
    p[..., :3] *= (1 - mask[..., None] * amount)
    return p


# ============================================================================
# ① 잘라 온 부품 (그림 품질 그대로)
# ============================================================================
L2 = arr(load("codex_v02_L2.png"))
L3 = arr(load("codex_v02_L3.png"))


def cut(src, x0, y0, x1, y1):
    p = src[y0:y1, x0:x1].copy()
    # 크롭 영역 밖 덩어리 조각이 섞이지 않게 제일 큰 연결 성분만 남긴다
    a = p[..., 3] > 0.3
    lab, n = ndimage.label(a)
    if n > 1:
        sizes = ndimage.sum(a, lab, range(1, n + 1))
        keep = np.isin(lab, [i + 1 for i, s in enumerate(sizes) if s > sizes.max() * 0.04])
        keep = ndimage.binary_dilation(keep, iterations=2)
        p[..., 3] *= keep
    return p


P_BOOKCASE = cut(L2, 59, 520, 284, 877)
P_LAMPTABLE = cut(L2, 284, 600, 392, 877)
P_SOFA = cut(L2, 376, 720, 737, 877)
P_STAIRS = cut(L2, 736, 460, 1412, 877)

# 샹들리에: v02 L3 의 천장 보 아래 (촛불은 이미 꺼진 판)
P_CHAND = L3[18:322, 890:1130].copy()


def fix_mid(part, lo=0.10, hi=0.33, cut_a=0.45):
    """중경 규칙(§2): 명도 17~33 % · 알파 하드컷 · 가장자리 어둡게."""
    p = part.copy()
    a = p[..., 3]
    a = np.where(a >= cut_a, 1.0, 0.0).astype(np.float32)
    a = np.maximum(a * 0, ndimage.uniform_filter(a, 2) * (a > 0))
    v = luma(p[..., :3])
    # 원래 명암 대비는 살리고 대역만 옮긴다
    vv = v[a > 0.5]
    if vv.size:
        p5, p95 = np.percentile(vv, [3, 97])
        v = lo + (np.clip(v, p5, p95) - p5) / max(p95 - p5, 1e-3) * (hi - lo)
    v = dark_rim(v, a, px=2, amount=0.4)
    return gray_rgba(v, a)


# ============================================================================
# ② 코드로 그리는 가구 — 전부 '사람 키 77' 기준 비례 (주문서 §4 표)
# ============================================================================
def crate(w, h, seed=0, base=0.24):
    m = mask_poly(h, w, [], rects=[(0, 0, w, h)])
    p = surface(m, base, "wood", 0.04, horizontal=True, seed=seed)
    # 널판 이음 · 가새(X) · 모서리 각재 — 전부 어두운 선
    segs = [(0, h * k / 4, w, h * k / 4, 1.2) for k in (1, 2, 3)]
    segs += [(3, 3, w - 3, h - 3, 3), (w - 3, 3, 3, h - 3, 3)]
    p = darken_where(p, line_mask(h, w, segs) * m, 0.45)
    fr = line_mask(h, w, [(2, 0, 2, h, 4), (w - 2, 0, w - 2, h, 4), (0, 2, w, 2, 4), (0, h - 2, w, h - 2, 4)])
    p = darken_where(p, fr * m, 0.30)
    return p


def wardrobe(w=74, h=140, ajar=False, seed=1):
    corn = 6
    polys = [[(0, 12), (w, 12), (w - 3, h - 8), (3, h - 8)],
             [(-corn + corn, 0), (w, 0), (w, 14), (0, 14)]]
    feet = [(4, h - 9, 12, h), (w - 12, h - 9, w - 4, h)]
    m = mask_poly(h, w, polys, rects=feet)
    p = surface(m, 0.22, "wood", 0.035, seed=seed)
    # 문짝 두 장 테두리와 가운데 이음, 코니스 아래 그늘
    segs = [(w / 2, 18, w / 2, h - 12, 1.6), (0, 15, w, 15, 2.5)]
    for x0, x1 in ((7, w / 2 - 4), (w / 2 + 4, w - 7)):
        segs += [(x0, 22, x1, 22, 1.2), (x0, h - 18, x1, h - 18, 1.2), (x0, 22, x0, h - 18, 1.2), (x1, 22, x1, h - 18, 1.2)]
    p = darken_where(p, line_mask(h, w, segs) * m, 0.5)
    # 손잡이
    p = darken_where(p, mask_poly(h, w, [], ellipses=[(w / 2 - 6, h * 0.5, w / 2 - 3, h * 0.5 + 3), (w / 2 + 3, h * 0.5, w / 2 + 6, h * 0.5 + 3)]), 0.6)
    if ajar:
        # 한쪽 문이 열려 안이 새까맣다 → 검정 틈 + 비스듬히 튀어나온 문짝
        gap = mask_poly(h, w, [], rects=[(w / 2 + 1, 18, w - 5, h - 12)])
        p[..., :3] *= (1 - gap[..., None] * 0.9)
        door = mask_poly(h + 0, 26, [[(0, 18), (24, 26), (24, h - 20), (0, h - 12)]])
        dp = surface(door, 0.20, "wood", 0.03, seed=seed + 5)
        out = np.zeros((h, w + 26, 4), np.float32)
        paste(out, p, 0, 0)
        paste(out, dp, w - 2, 0)
        return out
    return p


def bed(w=190, h=78, seed=2):
    """철제 침대 옆모습 — 머리판·발판 살 사이는 진짜 구멍(알파 0)."""
    segs = []
    # 머리판(왼쪽, 높다) / 발판(오른쪽, 낮다)
    for x0, top in ((4, 0), (w - 16, 26)):
        segs += [(x0, top, x0, h, 3.2), (x0 + 12, top, x0 + 12, h, 3.2), (x0, top + 2, x0 + 12, top + 2, 2.4)]
        for k in range(1, 4):
            xx = x0 + 3 * k
            segs.append((xx, top + 4, xx, h - 30, 1.1))
    # 침대 틀(옆 레일)
    segs.append((6, h - 30, w - 6, h - 30, 3.0))
    frame = line_mask(h, w, segs)
    iron = gray_rgba(np.full((h, w), 0.13) + texture(h, w, "plaster", seed=seed) * 0.02, frame)
    # 처진 매트리스 + 바닥까지 늘어진 홑이불(천은 조금 밝다, 그래도 33 % 아래)
    mat = mask_poly(h, w, [[(14, h - 46), (60, h - 42), (120, h - 40), (w - 18, h - 44), (w - 18, h - 30), (14, h - 30)]])
    sheet = mask_poly(h, w, [[(40, h - 42), (118, h - 39), (150, h - 36), (142, h - 20), (152, h - 1), (104, h), (70, h - 2), (56, h - 16), (44, h - 30)]])
    cloth = surface(np.maximum(mat, sheet), 0.30, "plaster", 0.05, seed=seed + 1, rim=0.25)
    fold = line_mask(h, w, [(80, h - 36, 74, h - 4, 1.5), (104, h - 36, 110, h - 3, 1.5), (126, h - 34, 134, h - 6, 1.2)])
    cloth = darken_where(cloth, fold * np.maximum(mat, sheet), 0.35)
    out = add(iron, cloth)
    return add(out, gray_rgba(np.full((h, w), 0.12), line_mask(h, w, [(x, 0 if x < 30 else 26, x, h, 3.2) for x in (4, 16, w - 16, w - 4)])))


def washstand(w=48, h=52, seed=3):
    m = mask_poly(h, w, [[(0, 18), (w, 18), (w, 24), (0, 24)]], rects=[(3, 24, 7, h), (w - 7, 24, w - 3, h), (3, h - 14, w - 3, h - 11)])
    p = surface(m, 0.21, "wood", 0.03, seed=seed)
    basin = mask_poly(h, w, [[(8, 8), (w - 8, 8), (w - 13, 18), (13, 18)]])
    bp = surface(basin, 0.31, "plaster", 0.03, seed=seed + 1)
    bp = darken_where(bp, line_mask(h, w, [(20, 9, 26, 17, 1.2)]) * basin, 0.6)   # 금 간 대야
    jug = mask_poly(h, w, [[(w - 17, 0), (w - 12, 0), (w - 10, 9), (w - 19, 9)]])
    return add(add(p, bp), surface(jug, 0.27, "plaster", 0.02, seed=seed + 2))


def clock(w=30, h=100, seed=4, door_open=True):
    """괘종시계 — 문짝 열림, 추 멈춤, 숫자 없는 옅은 회색 판(35 %)."""
    polys = [[(3, 0), (w - 3, 0), (w, 8), (w - 2, 34), (w - 5, 36), (w - 5, h - 16), (w - 1, h - 12), (w - 1, h), (1, h), (1, h - 12), (5, h - 16), (5, 36), (2, 34), (0, 8)]]
    m = mask_poly(h, w, polys)
    p = surface(m, 0.20, "wood", 0.035, seed=seed)
    face = mask_poly(h, w, [], ellipses=[(w / 2 - 9, 10, w / 2 + 9, 28)])
    p[..., :3] = p[..., :3] * (1 - face[..., None]) + 0.36 * face[..., None]
    p = darken_where(p, line_mask(h, w, [(w / 2, 19, w / 2, 13, 1.1), (w / 2, 19, w / 2 + 5, 21, 1.1)]), 0.7)
    win = mask_poly(h, w, [], rects=[(8, 42, w - 8, h - 22)])
    p[..., :3] *= (1 - win[..., None] * 0.75)
    pend = line_mask(h, w, [(w / 2, 42, w / 2, h - 34, 1.2)])
    bob = mask_poly(h, w, [], ellipses=[(w / 2 - 4, h - 38, w / 2 + 4, h - 30)])
    p = add(p, gray_rgba(np.full((h, w), 0.24), np.maximum(pend, bob) * win))
    if door_open:
        out = np.zeros((h, w + 14, 4), np.float32)
        paste(out, p, 0, 0)
        dm = mask_poly(h, 14, [[(0, 42), (12, 46), (12, h - 26), (0, h - 22)]])
        paste(out, surface(dm, 0.18, "wood", 0.03, seed=seed + 1), w - 1, 0)
        return out
    return p


def chair(w=26, h=46, seed=5, broken=False):
    segs = [(3, 0, 3, h, 3), (3, h * 0.52, w - 2, h * 0.52, 4), (w - 3, h * 0.52, w - 3, h, 2.6),
            (3, 2, 3 + 6, 2, 3)]
    if broken:
        segs = segs[:2] + [(w - 3, h * 0.52, w + 2, h * 0.8, 2.6)]
    m = line_mask(h, w + 4, segs)
    back = mask_poly(h, w + 4, [], rects=[(1, 4, 7, h * 0.5)])
    m = np.maximum(m, back)
    return surface(m, 0.19, "wood", 0.03, seed=seed, rim=0.2)


def armchair(w=52, h=44, seed=6):
    polys = [[(2, 6), (14, 0), (18, 8), (18, 22), (w - 4, 22), (w - 2, 16), (w, 18), (w, h - 6), (2, h - 6)]]
    m = mask_poly(h, w, polys, rects=[(4, h - 7, 8, h), (w - 8, h - 7, w - 4, h)])
    p = surface(m, 0.23, "plaster", 0.05, seed=seed)
    return darken_where(p, line_mask(h, w, [(18, 26, w - 4, 26, 1.4)]) * m, 0.4)


def side_table(w=30, h=34, seed=7):
    m = mask_poly(h, w, [[(0, 0), (w, 0), (w - 2, 5), (2, 5)]], rects=[(w / 2 - 2, 5, w / 2 + 2, h - 5)],
                  ellipses=[(w / 2 - 9, h - 6, w / 2 + 9, h)])
    return surface(m, 0.20, "wood", 0.03, seed=seed)


def desk(w=104, h=42, seed=8):
    m = mask_poly(h, w, [[(0, 0), (w, 0), (w, 6), (0, 6)]],
                  rects=[(3, 6, 34, h - 4), (w - 34, 6, w - 3, h - 4), (4, h - 4, 9, h), (w - 9, h - 4, w - 4, h), (28, h - 4, 33, h), (w - 33, h - 4, w - 28, h)])
    p = surface(m, 0.21, "wood", 0.035, seed=seed)
    segs = [(3, 6 + k * 11, 34, 6 + k * 11, 1.3) for k in range(1, 4)] + [(w - 34, 6 + k * 11, w - 3, 6 + k * 11, 1.3) for k in range(1, 4)]
    p = darken_where(p, line_mask(h, w, segs) * m, 0.5)
    # 흩어진 종이 — 책상 위 낮은 더미(밝아도 33 %)
    out = np.zeros((h + 10, w, 4), np.float32)
    paste(out, p, 0, 10)
    papers = mask_poly(10, w, [[(20, 10), (26, 5), (46, 6), (48, 10)], [(60, 10), (64, 7), (80, 8), (79, 10)]])
    paste(out, gray_rgba(np.full((10, w), 0.31), papers), 0, 0)
    return out


def piano(w=112, h=70, seed=9):
    """업라이트 피아노 — 뚜껑 닫힘, 위에 꺼진 촛대(§3 불 없음)."""
    polys = [[(0, 8), (w, 8), (w, 40), (w + 0, 44), (w - 2, h - 8), (2, h - 8), (0, 44)]]
    m = mask_poly(h, w, polys, rects=[(4, h - 9, 10, h), (w - 10, h - 9, w - 4, h)])
    p = surface(m, 0.17, "wood", 0.03, seed=seed)
    segs = [(0, 40, w, 40, 2.5), (8, 14, w - 8, 14, 1.2), (8, 34, w - 8, 34, 1.2), (w * 0.33, 14, w * 0.33, 34, 1), (w * 0.66, 14, w * 0.66, 34, 1)]
    p = darken_where(p, line_mask(h, w, segs) * m, 0.45)
    # 꺼진 촛대: 철 받침 + 초 동강 3 개(밀랍은 30 % — 불꽃 없음)
    cm = line_mask(h, w, [(w * 0.7, 8, w * 0.7, -2, 1.6), (w * 0.7 - 9, 0, w * 0.7 + 9, 0, 1.4)])
    p = add(p, gray_rgba(np.full((h, w), 0.12), cm))
    stubs = mask_poly(h, w, [], rects=[(w * 0.7 - 10, -1, w * 0.7 - 7, 0), (w * 0.7 - 1, -3, w * 0.7 + 2, 0), (w * 0.7 + 7, -1, w * 0.7 + 10, 0)])
    out = np.zeros((h + 12, w, 4), np.float32)
    paste(out, p, 0, 12)
    cand = mask_poly(12, w, [[(w * 0.7 - 1, 14), (w * 0.7 + 0.5, 14), (w * 0.7, 12)]], rects=[
        (w * 0.7 - 11, 4, w * 0.7 + 11, 7), (w * 0.7 - 1, 4, w * 0.7 + 1, 12),
        (w * 0.7 - 11, 0, w * 0.7 - 8, 5), (w * 0.7 - 2, -2, w * 0.7 + 1, 5), (w * 0.7 + 8, 1, w * 0.7 + 11, 5)])
    paste(out, gray_rgba(np.full((12, w), 0.15), cand), 0, 0)
    stool = mask_poly(22, 30, [], rects=[(0, 0, 30, 5), (4, 5, 7, 22), (23, 5, 26, 22)])
    return out, surface(stool, 0.18, "wood", 0.03, seed=seed + 1)


def low_table(w=60, h=20, seed=10):
    m = mask_poly(h, w, [[(0, 0), (w, 0), (w - 2, 4), (2, 4)]], rects=[(4, 4, 8, h), (w - 8, 4, w - 4, h)])
    return surface(m, 0.20, "wood", 0.03, seed=seed)


def dust_sheet_flat(w=190, h=12, seed=11):
    """바닥에 구겨진 먼지천. ★1 차 촬영에서 가구배율 2.2 로 키우니 윗면이 평평한
    밝은 판(높이 40 px)이 되어 **발판처럼 읽혔다** → 더 낮고(12) 더 어둡게(22 %),
    윗선은 봉우리가 여러 개인 울퉁불퉁한 모양으로."""
    pts = [(0, h)]
    r = np.random.default_rng(seed)
    for i in range(1, 24):
        x = w * i / 24
        bump = abs(math.sin(i * 1.7)) * 0.7 + r.random() * 0.3
        pts.append((x, h - 2 - bump * (h - 3) * math.sin(i / 24 * math.pi)))
    pts.append((w, h))
    m = mask_poly(h, w, [pts])
    p = surface(m, 0.22, "plaster", 0.04, seed=seed, rim=0.35)
    # 위쪽 절반을 더 어둡게 — 윗선이 밝으면 선반으로 읽힌다(§3)
    yy = np.linspace(0, 1, h)[:, None]
    p[..., :3] *= (0.7 + 0.3 * yy)[..., None]
    return p


def sheeted_statue(w=64, h=104, seed=12):
    pts = [(10, h), (4, h - 20), (8, 60), (14, 36), (22, 18), (32, 4), (40, 8), (46, 26), (50, 48), (58, 70), (62, h - 16), (56, h)]
    m = mask_poly(h, w, [pts])
    p = surface(m, 0.30, "plaster", 0.05, seed=seed, rim=0.3)
    return darken_where(p, line_mask(h, w, [(30, 20, 22, h - 4, 1.6), (40, 24, 46, h - 6, 1.6), (36, 50, 34, h - 2, 1.2)]) * m, 0.35)


def rolled_carpets(seed=13):
    out = np.zeros((110, 80, 4), np.float32)
    for i, (x, ang, L, r) in enumerate(((10, 12, 104, 8), (28, 7, 96, 9), (46, 16, 100, 7))):
        h, w = L, r * 2
        m = mask_poly(h, w, [], rects=[(0, 3, w, h - 3)], ellipses=[(0, 0, w, 6), (0, h - 6, w, h)])
        p = surface(m, 0.24 + 0.03 * i, "plaster", 0.05, seed=seed + i)
        p = darken_where(p, line_mask(h, w, [(k, 4, k, h - 4, 0.8) for k in (w * 0.3, w * 0.7)]) * m, 0.3)
        p = rotate(p, -ang)
        stand_part = p
        paste(out, stand_part, x, 110 - stand_part.shape[0])
    return out


def reading_set(seed=14):
    """낮은 독서 의자 + 곁탁자 (서재 오른쪽)."""
    out = np.zeros((48, 92, 4), np.float32)
    ac = armchair(seed=seed)
    paste(out, ac, 0, 48 - ac.shape[0])
    st = side_table(seed=seed + 1)
    paste(out, st, 60, 48 - st.shape[0])
    # 곁탁자 위 책 두어 권
    bk = mask_poly(6, 20, [], rects=[(0, 1, 18, 3), (2, 3, 20, 6)])
    paste(out, gray_rgba(np.full((6, 20), 0.22), bk), 64, 48 - st.shape[0] - 6)
    return out


# ============================================================================
# ③ B 가구 레이어 6 장 — 주문서 §5-B 표의 배치 그대로 (x 는 캔버스 %)
# ============================================================================
def X(p):
    return int(W * p / 100)


BOOKCASE = fix_mid(scale_part(P_BOOKCASE, height=int(HUMAN * 1.8)))
LAMPTABLE = fix_mid(scale_part(P_LAMPTABLE, height=int(HUMAN * 1.25)))
SOFA = fix_mid(scale_part(P_SOFA, height=int(HUMAN * 0.62)))
STAIRS = fix_mid(scale_part(P_STAIRS, height=int(H * (0.87 - 0.50)) + 30), lo=0.10, hi=0.30)


def furniture_study():
    c = layer_canvas()
    stand(c, BOOKCASE, X(13))
    stand(c, flip(BOOKCASE), X(30))
    stand(c, desk(), X(51))
    stand(c, flip(chair(seed=21)), X(55))
    stand(c, reading_set(), X(75))
    return c


def furniture_parlour():
    c = layer_canvas()
    stand(c, SOFA, X(28))
    stand(c, low_table(), X(28), sink=0)
    pno, stool = piano()
    stand(c, pno, X(62))
    stand(c, stool, X(62) + 8)
    stand(c, LAMPTABLE, X(45))
    return c


def furniture_bedroom():
    c = layer_canvas()
    stand(c, bed(), X(22))
    stand(c, wardrobe(ajar=True), X(52))
    stand(c, washstand(), X(70))
    return c


def furniture_storeroom():
    c = layer_canvas()
    for (x, sizes) in ((X(11), [(46, 40), (40, 34), (30, 26)]), (X(35), [(52, 36), (36, 30)])):
        y = FLOOR
        for i, (w, h) in enumerate(sizes):
            w, h = int(w * 가구배율), int(h * 가구배율)
            cr = crate(w, h, seed=100 + x + i)
            paste(c, cr, x - w // 2 + (i * 5 - 5), y - h)
            y -= h
    stand(c, sheeted_statue(), X(56))
    stand(c, rolled_carpets(), X(79))
    for x, (w, h) in ((X(22), (22, 18)), (X(45), (26, 20)), (X(66), (18, 14)), (X(69), (16, 12))):
        w, h = int(w * 가구배율), int(h * 가구배율)
        paste(c, crate(w, h, seed=x), x, FLOOR - h)
    return c


def furniture_empty():
    c = layer_canvas()
    stand(c, rotate(chair(seed=41), 92), X(33))       # 넘어진 의자
    stand(c, dust_sheet_flat(), X(48))
    stand(c, clock(), X(65))
    return c


def furniture_stairhall():
    c = layer_canvas()
    # 계단: 신주 기둥을 x 40 % 에, 오른쪽으로 올라간다. 난간 살 사이는 원화에서 이미 구멍.
    s = STAIRS                                  # 계단은 층계참 높이(50 %)로 크기가 정해져 있다
    paste(c, s, X(40) - int(s.shape[1] * 0.02), FLOOR - s.shape[0])
    stand(c, chair(seed=61), X(17))
    return c


FURNITURE = [
    ("furniture_01_study.png", furniture_study),
    ("furniture_02_parlour.png", furniture_parlour),
    ("furniture_03_bedroom.png", furniture_bedroom),
    ("furniture_04_storeroom.png", furniture_storeroom),
    ("furniture_05_empty.png", furniture_empty),
    ("furniture_06_stairhall.png", furniture_stairhall),
]


# ============================================================================
# ④ A1 먼 벽 — 아스트라 원본을 규칙에 맞게만 손본다
# ============================================================================
def wall_room():
    a = A1.copy()
    h, w = a.shape
    # 좌우 이음매: 가장자리 24 px 를 반대쪽과 교차 페이드 → 이어 붙여도 단이 0
    k = 24
    t = np.linspace(0, 1, k)[None, :]
    left, right = a[:, :k].copy(), a[:, -k:].copy()
    avg = (left[:, :1] + right[:, -1:]) / 2
    a[:, :k] = left * t + (avg * (1 - t) + left * t) * (1 - t)
    a[:, -k:] = right * (1 - t) + (avg * t + right * (1 - t)) * t
    # §5-A: 아래 92~100 % 는 민무늬 어두운 벽 밑동 (바닥 아님)
    y0 = int(h * 0.90)
    yy = np.clip((np.arange(h) - y0) / (h - y0), 0, 1)[:, None]
    a = a * (1 - yy * 0.55)
    a = np.clip(a, 0, 0.38)                    # 먼 벽은 20~38 %
    a = band_split(a)
    return np.dstack([a, a, a, np.ones_like(a)])


# ============================================================================
# ⑤ D 방 구조 3 장 — 좌·우·위 200 px 안에서 알파 0, 아래 20 % 는 안 그린다
# ============================================================================
def edge_fade(c, side=200, bottom_clear=0.20):
    h, w = c.shape[:2]
    xs = np.arange(w)
    fx = np.clip(np.minimum(xs, w - 1 - xs) / side, 0, 1)
    fy = np.clip(np.arange(h) / side, 0, 1)
    f = np.minimum(fx[None, :], fy[:, None])
    c[..., 3] *= f ** 1.5
    c[int(h * (1 - bottom_clear)):, :, 3] = 0
    return c


def mid_window():
    src = arr(load("codex_window.png"))
    p = src[9:1459, 157:864]
    p = scale_part(p, height=int(H * 0.64))
    v = luma(p[..., :3])
    # 유리(밝은 곳)는 62~70 % 로 평평하게, 나머지는 13~33 %
    glass = v > 0.5
    v = np.where(glass, 0.62 + (v - 0.5) * 0.16, np.clip(v * 0.62, 0.05, 0.33))
    v = band_split(v)
    a = np.where(p[..., 3] > 0.45, 1.0, 0.0)
    p = gray_rgba(dark_rim(v, a, 2, 0.4), a)
    c = layer_canvas()
    paste(c, p, W // 2 - p.shape[1] // 2, int(H * 0.08))
    return edge_fade(c)


def mid_door():
    src = arr(load("codex_arch.png"))[:, 170:1145]     # 기둥 바깥으로 뻗은 가로보는 잘라 낸다
    arch = scale_part(src, height=int(H * 0.66))
    v = luma(arch[..., :3])
    v = np.clip((v - 0.2) * 0.8 + 0.2, 0.08, 0.33)
    # §3: 가로로 긴 밝은 윗선 = 밟을 선반으로 읽힌다 → 위 22 % 를 숯빛으로 눌러 둔다
    yy = np.linspace(0, 1, v.shape[0])[:, None]
    v = v * (0.45 + 0.55 * np.clip((yy - 0.02) / 0.20, 0, 1))
    a = np.where(arch[..., 3] > 0.45, 1.0, 0.0)
    arch = gray_rgba(dark_rim(v, a, 2, 0.4), a)
    ah, aw = arch.shape[:2]
    # 아치 안쪽: 가장자리에서 가운데로 갈수록 순흑 — "어둠이 주제"
    inner = (a < 0.5)
    lab, n = ndimage.label(inner)
    centre_lab = lab[int(ah * 0.7), aw // 2]
    hole = (lab == centre_lab).astype(np.float32)
    d = ndimage.distance_transform_edt(hole)
    dark = np.clip(0.06 - d / 900.0, 0.0, 0.06)
    fill = gray_rgba(dark, hole)
    body = add(fill, arch)
    # 안으로 열린 무거운 문짝(왼쪽 벽에 비스듬히)
    dw, dh = int(aw * 0.16), int(ah * 0.62)
    dm = mask_poly(dh, dw, [[(0, 0), (dw, dh * 0.07), (dw, dh * 0.97), (0, dh)]])
    door = surface(dm, 0.11, "wood", 0.02, seed=77)
    paste(body, door, int(aw * 0.18), ah - dh - 2)
    c = layer_canvas()
    paste(c, body, W // 2 - aw // 2, int(H * 0.80) - ah)
    return edge_fade(c)


def mid_fireplace():
    c = layer_canvas()
    fw, fh = 330, 230
    base_y = int(H * 0.80)
    x0 = W // 2 - fw // 2
    # 돌 테두리 + 벽난로 선반(윗면은 어둡게 눌러 '밟을 선반'으로 안 읽히게)
    m = mask_poly(fh, fw, [[(0, 22), (fw, 22), (fw - 12, fh), (12, fh)], [(-0 + 0, 6), (fw, 6), (fw - 4, 24), (4, 24)]])
    p = surface(m, 0.27, "plaster", 0.05, seed=90, top_shade=0.0)
    top = np.clip(1 - np.arange(fh) / 16.0, 0, 1)[:, None] * np.ones((1, fw))
    p = darken_where(p, top * m, 0.45)
    # 홈 파인 붙기둥 두 개
    flutes = [(x, 36, x, fh - 8, 1.2) for x in (26, 34, 42, fw - 42, fw - 34, fw - 26)]
    p = darken_where(p, line_mask(fh, fw, flutes) * m, 0.45)
    # 화구 — 거의 검정, 비어 있음(불·잉걸 없음)
    box = mask_poly(fh, fw, [[(70, fh), (70, 110), (fw / 2, 84), (fw - 70, 110), (fw - 70, fh)]])
    d = ndimage.distance_transform_edt(box > 0.5)
    p[..., :3] = p[..., :3] * (1 - box[..., None]) + (np.clip(0.05 - d / 800, 0.01, 0.05) * box)[..., None]
    paste(c, p, x0, base_y - fh)
    # 선반 위 빈 거울: 조각 틀 + 평평한 짙은 회색 (반사·그림 없음)
    mw, mh = 190, 210
    mm = mask_poly(mh, mw, [[(10, 30), (mw / 2, 0), (mw - 10, 30), (mw - 10, mh), (10, mh)]])
    mp = surface(mm, 0.22, "wood", 0.04, seed=91)
    glass = mask_poly(mh, mw, [[(26, 40), (mw / 2, 18), (mw - 26, 40), (mw - 26, mh - 14), (26, mh - 14)]])
    mp[..., :3] = mp[..., :3] * (1 - glass[..., None]) + 0.15 * glass[..., None]
    paste(c, mp, W // 2 - mw // 2, base_y - fh - mh + 2)
    # 기대 놓은 녹슨 불가리개
    sw, sh = 70, 64
    sm = mask_poly(sh, sw, [[(0, 12), (sw / 2, 0), (sw, 12), (sw, sh), (0, sh)]])
    sp = gray_rgba(np.full((sh, sw), 0.12), sm - mask_poly(sh, sw, [], rects=[(6 + 12 * k, 16, 12 + 12 * k, sh - 6) for k in range(5)]) * sm)
    paste(c, rotate(sp, 8), x0 + fw + 10, base_y - sh - 6)
    return edge_fade(c)


# ============================================================================
# ⑥ E 전경 — 꺼진 샹들리에 640×640 (숯 5~16 %)
# ============================================================================
def fg_chandelier():
    p = P_CHAND.copy()
    a = p[..., 3]
    v = luma(p[..., :3])
    # 밝은 초 동강까지 전부 숯 대역으로 — 실루엣이지 광원이 아니다
    v = 0.05 + np.clip(v, 0, 0.6) / 0.6 * 0.11
    a = np.where(a > 0.45, 1.0, 0.0)
    p = gray_rgba(v, a)
    p = scale_part(p, height=600)
    c = np.zeros((640, 640, 4), np.float32)
    paste(c, p, 320 - p.shape[1] // 2, 0)
    c[..., 3] = np.where(c[..., 3] > 0.45, 1.0, 0.0)
    return c


# ============================================================================
# 저장 · 검사
# ============================================================================
def save(c, rel):
    path = os.path.join(OUT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    to_im(c).save(path)
    v = luma(c[..., :3]); a = c[..., 3]
    vis = a > 0.5
    stat = {
        "파일": rel, "크기": [c.shape[1], c.shape[0]],
        "알파0_비율": round(float((a < 0.02).mean()), 3),
        "명도45_55_비율": round(float((((v > 0.45) & (v < 0.55)) & vis).mean()), 5),
        "최대명도(보이는 픽셀)": round(float(v[vis].max()) if vis.any() else 0, 3),
        "중간알파_비율": round(float(((a > 0.02) & (a < 0.98)).mean()), 4),
    }
    rows = np.where(a.max(1) > 0.5)[0]
    stat["가장아래_y"] = int(rows[-1]) if len(rows) else None
    return stat


def finish_layer(c, vmax=0.36):
    """가구·디테일 레이어 마무리: 알파 하드컷(§3 2 px) + 중경 명도 상한."""
    a = np.where(c[..., 3] >= 0.45, 1.0, 0.0).astype(np.float32)
    soft = ndimage.uniform_filter(a, 2)
    c[..., 3] = np.where(a > 0, np.maximum(soft, 0.75), 0)
    c[..., :3] = np.minimum(c[..., :3], vmax)
    return c


def main():
    stats = []
    stats.append(save(wall_room(), "far/wall_room_repeat.png"))
    for name, fn in FURNITURE:
        stats.append(save(finish_layer(fn()), "layers/" + name))
    stats.append(save(mid_window(), "mid/room_window_bay.png"))
    stats.append(save(mid_fireplace(), "mid/room_fireplace_bay.png"))
    stats.append(save(mid_door(), "mid/room_door_bay.png"))
    stats.append(save(fg_chandelier(), "fg/fg_chandelier_dead.png"))
    os.makedirs(QA, exist_ok=True)
    with open(os.path.join(QA, "검사.json"), "w", encoding="utf-8") as f:
        json.dump(stats, f, ensure_ascii=False, indent=1)
    for s in stats:
        print(s)
    qa_sheets()


def qa_sheets():
    """§7 증거 이미지: 마젠타 위 · 가구 6 장 겹침 · 벽 3×2 이어붙임."""
    mag = np.array([1.0, 0.0, 0.765])
    files = [f"layers/{n}" for n, _ in FURNITURE] + ["mid/room_window_bay.png", "mid/room_fireplace_bay.png", "mid/room_door_bay.png"]
    tiles = []
    for rel in files:
        c = arr(Image.open(os.path.join(OUT, rel)).convert("RGBA"))
        rgb = c[..., :3] * 2.2 * c[..., 3:4] + mag * (1 - c[..., 3:4])   # 밝게 올려 보이게
        im = to_im(np.clip(rgb, 0, 1)).resize((768, 512))
        d = ImageDraw.Draw(im); d.text((8, 8), rel, fill=(255, 255, 0))
        d.line([(0, FLOOR // 2), (768, FLOOR // 2)], fill=(0, 255, 255))
        tiles.append(im)
    sheet = Image.new("RGB", (768 * 3, 512 * 3), (0, 0, 0))
    for i, t in enumerate(tiles):
        sheet.paste(t, ((i % 3) * 768, (i // 3) * 512))
    sheet.save(os.path.join(QA, "마젠타_검수판.png"))
    # 가구 6 장 겹침 — 바닥선 정합
    acc = np.zeros((H, W, 3), np.float32)
    for n, _ in FURNITURE:
        c = arr(Image.open(os.path.join(OUT, "layers", n)).convert("RGBA"))
        acc = acc * (1 - c[..., 3:4] * 0.5) + c[..., :3] * 2.2 * c[..., 3:4] * 0.5
    ov = to_im(np.clip(acc, 0, 1))
    d = ImageDraw.Draw(ov); d.line([(0, FLOOR), (W, FLOOR)], fill=(255, 0, 0))
    ov.save(os.path.join(QA, "가구6장_겹침.png"))
    # 먼 벽 3×2
    wall = Image.open(os.path.join(OUT, "far/wall_room_repeat.png")).convert("RGB")
    ww, wh = wall.size
    t = Image.new("RGB", (ww * 3, wh * 2))
    for i in range(3):
        for j in range(2):
            t.paste(wall, (i * ww, j * wh))
    t.point(lambda v: min(255, int(v * 1.8))).resize((ww * 3 // 3, wh * 2 // 3)).save(os.path.join(QA, "먼벽_3x2.png"))
    ch = Image.open(os.path.join(OUT, "fg/fg_chandelier_dead.png")).convert("RGBA")
    bg = Image.new("RGBA", ch.size, (255, 0, 195, 255)); bg.alpha_composite(ch); bg.save(os.path.join(QA, "샹들리에_마젠타.png"))


if __name__ == "__main__":
    main()
