# -*- coding: utf-8 -*-
"""가시 장애물 — 주철 가시판 그림 굽기 (엔진 없이 PNG 를 만든다).

왜:
  예전 가시는 코드로 그린 흰 삼각형 + 빨간 점이었다. 벽돌·주철(호퍼·배관·레버) 세계에서 혼자 벡터 도형이라 튀었고,
  **흰색**이라 "흰 몸이면 밟아도 되나?" 로 읽힐 수 있었다(가시는 색과 무관하게 죽인다).
  2026-09-28 시안 3 으로 확정: 리벳 박힌 쇠 받침판 + 하나씩 다른 쇠말뚝 · 날과 끝만 밝게 · 붙은 그림자.
  새로 그리지 않고 **호퍼 원화(주철 아틀라스)의 금속 결·리벳·굵은 외곽선**을 조합한다 — 호퍼와 재질이 같다.

만드는 것: assets/textures/obstacles/spike/cast_iron_v1/spike_atlas.png  (200 x 30, 게임 1:1 크기)
  [칸 0~5] 32 x 30 — 가시 한 칸(판정 한 칸 = 32px). 6 종이라 칸마다 달리 골라 "복사해 붙인" 느낌을 없앤다.
  [192~195] 4 x 30 — 받침판 왼쪽 끝 마감(외곽선·모따기)
  [196~199] 4 x 30 — 받침판 오른쪽 끝 마감
  세로 30 = 위아래 여백 4 + 가시 상자 22 + 여백 4. 여백은 외곽선·그림자 자리.
  가시 상자 22 안에서: 아래 6 = 받침판, 위 16 = 말뚝(판정 높이 22 를 넘지 않게 낮추는 쪽으로만 흔든다).
  ⚠ 이 규격을 바꾸면 scripts/장애물/가시.gd 의 상수도 같이 바꿀 것.

게임 줌 1.0 에서 1:1 로 찍히게 4 배로 그린 뒤 줄인다(밉맵 없이 줄여 그리면 계단이 생긴다).
씨앗 고정 → 멱등.

사용:
  python tools/생성_가시_주철.py                  # 굽는다
  python tools/생성_가시_주철.py --미리보기 <폴더>   # 굽고, 8 배 확대 확인 그림도 둔다
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ATLAS = os.path.join(ROOT, "assets", "textures", "obstacles", "hopper", "cast_iron_v1", "hopper_atlas.png")
OUT_DIR = os.path.join(ROOT, "assets", "textures", "obstacles", "spike", "cast_iron_v1")
OUT = os.path.join(OUT_DIR, "spike_atlas.png")

S = 4                    # 내부 배율
CELL, BOX, PAD = 32, 22, 4
PLATE, SPIKE = 6, 16
VARIANTS = 6
CAP = 4
OL = 6                   # 내부 외곽선 두께 → 게임 1.5px (호퍼가 게임에서 보이는 선 두께와 비슷)

src = np.asarray(Image.open(ATLAS).convert("RGBA")).astype(np.float32)
# 금속 결: 깔때기 몸통. 호퍼가 게임에 나오는 배율(원화의 약 0.5)과 결 크기를 맞춘다 → 내부(4배)에서 2.1 배
_m = src[420:540, 180:330, :3]
METAL = np.asarray(Image.fromarray(_m.astype(np.uint8)).resize((int(150 * 2.1), int(120 * 2.1)), Image.LANCZOS)).astype(np.float32)
RIVET = src[554:577, 192:215].copy()
_yy, _xx = np.mgrid[0:23, 0:23]
RIVET[..., 3] = 255 * (np.hypot(_yy - 11, _xx - 11) <= 10.5)


def metal(w, h, seed):
    r = np.random.default_rng(seed)
    t = np.tile(METAL, (h // METAL.shape[0] + 2, w // METAL.shape[1] + 2, 1))
    y0, x0 = r.integers(0, METAL.shape[0]), r.integers(0, METAL.shape[1])
    return t[y0:y0 + h, x0:x0 + w].copy()


def plate_metal(w, h):
    """받침판 결 — 모든 칸이 같은 한 장을 쓰고, 좌우 끝이 이어지게(타일) 만든다.
    칸마다 결이 다르면 칸 경계에서 결이 뚝 끊겨 세로 이음선처럼 보인다."""
    t = metal(w, h, 777)
    x = np.arange(w)[None, :, None].astype(np.float32)
    wgt = np.minimum(x, w - x) / (w / 2)                     # 가운데 1 · 양끝 0
    return t * wgt + np.roll(t, w // 2, axis=1) * (1 - wgt)  # 양끝은 반 바퀴 민 판(가운데가 이어지는 곳)이 차지 → 이음매 없음


def mask(w, h, fn):
    m = Image.new("L", (w, h), 0)
    fn(ImageDraw.Draw(m))
    return np.asarray(m).astype(np.float32) / 255


class Layer:
    def __init__(s, w, h):
        s.w, s.h = w, h
        s.rgb = np.zeros((h, w, 3), np.float32)
        s.a = np.zeros((h, w), np.float32)

    def fill(s, m, rgb):
        s.rgb = s.rgb * (1 - m[..., None]) + rgb * m[..., None]
        s.a = np.maximum(s.a, m)

    def bevel(s, m, w=3, only_y=False):
        # 원화 테두리처럼 왼쪽 위 가장자리는 밝게, 오른쪽 아래는 어둡게.
        # only_y: 받침판은 칸끼리 옆으로 이어지므로 좌우 끝에 선을 넣으면 칸마다 세로 이음선이 생긴다 → 위아래만
        k = max(1, int(w * S / 2))
        kx = 0 if only_y else k
        up = np.zeros_like(m); dn = np.zeros_like(m)
        if kx:
            up[k:, kx:] = m[:-k, :-kx]; dn[:-k, :-kx] = m[k:, kx:]
        else:
            up[k:, :] = m[:-k, :]; dn[:-k, :] = m[k:, :]
        s.rgb += (np.clip(m - up, 0, 1) * 70)[..., None] - (np.clip(m - dn, 0, 1) * 45)[..., None]

    def rivet(s, cx, cy, scale):
        im = Image.fromarray(RIVET.astype(np.uint8), "RGBA").resize((max(3, int(23 * scale)),) * 2, Image.LANCZOS)
        r = np.asarray(im).astype(np.float32); h, w = r.shape[:2]
        x0, y0 = int(cx - w / 2), int(cy - h / 2); al = r[..., 3:] / 255
        s.rgb[y0:y0 + h, x0:x0 + w] = s.rgb[y0:y0 + h, x0:x0 + w] * (1 - al) + r[..., :3] * al
        s.a[y0:y0 + h, x0:x0 + w] = np.maximum(s.a[y0:y0 + h, x0:x0 + w], al[..., 0])


def outline_and_shadow(lay, shape):
    """모양 둘레 검은 외곽선(바깥쪽) + 오른쪽 아래로 민 좁은 그림자(같은 명도의 배경에서 떼어 냄)."""
    dil = np.asarray(Image.fromarray((shape * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(OL * 2 + 1))).astype(np.float32) / 255
    ring = np.clip(dil - shape, 0, 1)
    sh = np.zeros_like(dil); dx, dy = 2 * S, 1 * S
    sh[dy:, dx:] = dil[:-dy, :-dx]
    sh = np.asarray(Image.fromarray((sh * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2 * S))).astype(np.float32) / 255
    sh = np.clip(sh - dil, 0, 1) * 0.5
    # 그림자는 아래에 깔린다: 이미 그린 것이 없는 곳만
    lay.rgb = lay.rgb * (1 - ring[..., None]) + 8 * ring[..., None]
    free = 1 - np.maximum(lay.a, ring)
    lay.a = np.maximum(np.maximum(lay.a, ring), sh * free)   # 그림자 픽셀은 rgb 0(검정)으로 남는다


def cell(seed):
    W, H = CELL * S, (BOX + 2 * PAD) * S
    lay = Layer(W, H); r = np.random.default_rng(seed)
    base_y1 = (PAD + BOX) * S; base_y0 = base_y1 - PLATE * S
    # 쇠말뚝 — 외곽선이 칸 안에 들어오게 좌우를 외곽선 두께만큼 비운다
    bl = OL + r.uniform(0.8, 2.6) * S
    br = W - OL - r.uniform(0.8, 2.6) * S
    tip = ((bl + br) / 2 + r.uniform(-2.2, 2.2) * S, base_y0 - (SPIKE - r.uniform(0.0, 2.8)) * S)
    fb = r.uniform(0.8, 1.12)
    tex = metal(W, H, seed * 7 + 3)
    L = mask(W, H, lambda d: d.polygon([(bl, base_y0 + S), tip, (tip[0], base_y0 + S)], fill=255))
    R = mask(W, H, lambda d: d.polygon([tip, (br, base_y0 + S), (tip[0], base_y0 + S)], fill=255))
    lay.fill(L, (tex * 1.45 + 38) * fb)           # 빛 받는 왼쪽 면(회색 배경에 묻히지 않게 밝게)
    lay.fill(R, tex * 0.55 * fb)                  # 그늘 오른쪽 면
    lay.fill(mask(W, H, lambda d: d.line([tip, (tip[0], base_y0)], fill=255, width=int(1.3 * S))) * 0.6, np.full_like(tex, 215))
    lay.fill(mask(W, H, lambda d: d.line([(bl, base_y0), tip], fill=255, width=int(1.4 * S))) * 0.95, np.full_like(tex, 250))   # 날
    lay.fill(mask(W, H, lambda d: d.ellipse([tip[0] - 1.8 * S, tip[1] - 0.6 * S, tip[0] + 1.8 * S, tip[1] + 3.0 * S], fill=255)), np.full_like(tex, 250))
    spike = np.maximum(L, R)
    # 받침판: 칸 끝까지 이어진다(옆 칸과 이음매 없이) — 깔때기 아랫단처럼 윗모서리 밝게, 아래로 어둡게
    P = np.zeros((H, W), np.float32); P[base_y0:base_y1, :] = 1
    pt = plate_metal(W, H)
    v = np.clip((np.arange(H)[:, None] - base_y0) / (base_y1 - base_y0), 0, 1)
    # 받침판은 "안전한 받침" 이라 말뚝(위험)보다 어둡게 — 게임 조명에서 판이 은색 막대처럼 먼저 눈에 띄었다
    pt = pt * (0.78 - 0.35 * v)[..., None] + (40 * np.exp(-((np.arange(H)[:, None] - base_y0 - 1.5 * S) / (0.9 * S)) ** 2))[..., None]
    lay.fill(P, pt)
    lay.bevel(P, only_y=True)
    lay.rivet(W / 2, (base_y0 + base_y1) / 2, 0.55 * S / 3)
    outline_and_shadow(lay, np.maximum(spike, P))
    # 받침판 좌우 끝은 칸 경계라 외곽선이 없어야 한다(옆 칸이 이어진다) → 판 높이의 외곽선 줄만 칸 폭 전체로
    return lay


def cap(right):
    W, H = CAP * S, (BOX + 2 * PAD) * S
    lay = Layer(W, H)
    base_y1 = (PAD + BOX) * S; base_y0 = base_y1 - PLATE * S
    # 판 끝: 모따기 한 끝면 + 외곽선. 왼쪽 마감이면 판이 오른쪽(칸 쪽)으로 이어진다
    inner = W if not right else 0
    x_end = OL + S if not right else W - OL - S
    P = mask(W, H, lambda d: d.polygon([(inner, base_y0), (x_end + (S if not right else -S), base_y0),
                                        (x_end, base_y0 + 1.5 * S), (x_end, base_y1), (inner, base_y1)], fill=255))
    pt = plate_metal(CELL * S, H)[:, :W] if not right else plate_metal(CELL * S, H)[:, -W:]
    v = np.clip((np.arange(H)[:, None] - base_y0) / (base_y1 - base_y0), 0, 1)
    lay.fill(P, pt * (0.78 - 0.35 * v)[..., None] + (40 * np.exp(-((np.arange(H)[:, None] - base_y0 - 1.5 * S) / (0.9 * S)) ** 2))[..., None])
    lay.bevel(P, only_y=True)
    outline_and_shadow(lay, P)
    return lay


def to_rgba(lay, w, h):
    rgb = Image.fromarray(np.clip(lay.rgb, 0, 255).astype(np.uint8)).resize((w, h), Image.LANCZOS)
    a = Image.fromarray((lay.a * 255).astype(np.uint8)).resize((w, h), Image.LANCZOS)
    out = Image.merge("RGBA", (*rgb.split(), a))
    return out


def build():
    H = BOX + 2 * PAD
    atlas = Image.new("RGBA", (CELL * VARIANTS + CAP * 2, H), (0, 0, 0, 0))
    for i in range(VARIANTS):
        atlas.paste(to_rgba(cell(11 + i), CELL, H), (CELL * i, 0))
    atlas.paste(to_rgba(cap(False), CAP, H), (CELL * VARIANTS, 0))
    atlas.paste(to_rgba(cap(True), CAP, H), (CELL * VARIANTS + CAP, 0))
    os.makedirs(OUT_DIR, exist_ok=True)
    atlas.save(OUT)
    return atlas


def preview(atlas, folder):
    # 확인용: 왼쪽 마감 + 칸 6 종 + 오른쪽 마감을 이어 붙여 회색 배경 위 8 배 확대
    H = atlas.height
    strip = Image.new("RGBA", (CAP * 2 + CELL * VARIANTS, H), (0, 0, 0, 0))
    strip.paste(atlas.crop((CELL * VARIANTS, 0, CELL * VARIANTS + CAP, H)), (0, 0))
    for i in range(VARIANTS):
        strip.paste(atlas.crop((CELL * i, 0, CELL * (i + 1), H)), (CAP + CELL * i, 0))
    strip.paste(atlas.crop((CELL * VARIANTS + CAP, 0, CELL * VARIANTS + CAP * 2, H)), (CAP + CELL * VARIANTS, 0))
    bg = Image.new("RGBA", strip.size, (88, 88, 88, 255)); bg.alpha_composite(strip)
    bg.convert("RGB").resize((strip.width * 8, strip.height * 8), Image.NEAREST).save(os.path.join(folder, "가시_주철_아틀라스_확대.png"))


def main():
    atlas = build()
    print("->", OUT)
    if "--미리보기" in sys.argv:
        folder = sys.argv[sys.argv.index("--미리보기") + 1]
        os.makedirs(folder, exist_ok=True)
        preview(atlas, folder)
        print("미리보기 ->", folder)


if __name__ == "__main__":
    main()
