# -*- coding: utf-8 -*-
"""회전톱 — 주철 톱날 그림 굽기 (엔진 없이 PNG 를 만든다).

왜:
  예전 톱 = 코드로 그린 흰 톱니바퀴 + 빨간 점. 벽돌·주철 세계에서 혼자 벡터 도형이라 튀었고, 흰색이라
  칠할 수 있는 흰 지형처럼 읽힐 수 있었다(톱은 색과 무관하게 죽인다).
  2026-09-28 시안 3 확정: 녹슨 원형톱 · 갈고리 톱니 14 개(앞날만 밝게) · 가늘게 휜 팽창 홈 4 개 ·
  볼트 6 개 허브 + 육각 너트. (예전 시안의 큰 구멍 3 개 + 허브는 얼굴처럼 읽혀서 뺐다)
  재질은 새로 그리지 않고 호퍼 원화(주철 아틀라스)의 금속 결·리벳·굵은 외곽선을 쓴다.

만드는 것: assets/textures/obstacles/saw/cast_iron_v1/
  saw_r<반지름>.png  — 반지름별 1:1 톱날(가로·세로 = 2 × 반지름 + 8). 톱니 끝 = 반지름.
                      회전톱.gd 가 가장 가까운 크기를 골라 반지름에 맞게 살짝만 늘린다(크게 줄이면 계단이 생긴다).
  stop.png           — 홈 양끝 멈춤쇠(12 × 16)
  톱니의 가파른 면이 **시계 방향**(각도가 커지는 쪽)을 향한다 — 회전톱.gd 가 rotation 을 늘려(시계 방향) 돌리기 때문.

씨앗 고정 → 멱등.

사용:
  python tools/생성_톱_주철.py
  python tools/생성_톱_주철.py --미리보기 <폴더>
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ATLAS = os.path.join(ROOT, "assets", "textures", "obstacles", "hopper", "cast_iron_v1", "hopper_atlas.png")
OUT_DIR = os.path.join(ROOT, "assets", "textures", "obstacles", "saw", "cast_iron_v1")

SIZES = [24, 28, 32, 36, 40, 48]     # world_2_클로드 의 톱: 28 · 30 · 36 · 40
S = 4
OL = 6                               # 내부 외곽선 → 게임 1.5px

src = np.asarray(Image.open(ATLAS).convert("RGBA")).astype(np.float32)
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

    def bevel(s, m, w=3):
        k = max(1, int(w * S / 2))
        up = np.zeros_like(m); up[k:, k:] = m[:-k, :-k]
        dn = np.zeros_like(m); dn[:-k, :-k] = m[k:, k:]
        s.rgb += (np.clip(m - up, 0, 1) * 70)[..., None] - (np.clip(m - dn, 0, 1) * 45)[..., None]

    def outline(s, m):
        dil = np.asarray(Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(OL * 2 + 1))).astype(np.float32) / 255
        ring = np.clip(dil - m, 0, 1)
        s.rgb = s.rgb * (1 - ring[..., None]) + 8 * ring[..., None]
        s.a = np.maximum(s.a, ring)

    def rivet(s, cx, cy, scale):
        n = max(3, int(23 * scale))
        r = np.asarray(Image.fromarray(RIVET.astype(np.uint8), "RGBA").resize((n, n), Image.LANCZOS)).astype(np.float32)
        x0, y0 = int(cx - n / 2), int(cy - n / 2); al = r[..., 3:] / 255
        s.rgb[y0:y0 + n, x0:x0 + n] = s.rgb[y0:y0 + n, x0:x0 + n] * (1 - al) + r[..., :3] * al
        s.a[y0:y0 + n, x0:x0 + n] = np.maximum(s.a[y0:y0 + n, x0:x0 + n], al[..., 0])


def saw(R, teeth=14, seed=2):
    D = (2 * R + 8) * S
    lay = Layer(D, D); cx = cy = D / 2; Rk = R * S
    pts = []
    for i in range(teeth):
        # 갈고리 톱니: 완만히 올라가 끝에서 뚝 떨어진다(가파른 면 = 시계 방향 쪽 = 앞날)
        a0 = 2 * np.pi * i / teeth; am = 2 * np.pi * (i + 0.55) / teeth
        a1 = 2 * np.pi * (i + 0.9) / teeth; a2 = 2 * np.pi * (i + 0.93) / teeth
        pts += [(cx + np.cos(a0) * Rk * 0.76, cy + np.sin(a0) * Rk * 0.76), (cx + np.cos(am) * Rk * 0.9, cy + np.sin(am) * Rk * 0.9),
                (cx + np.cos(a1) * Rk, cy + np.sin(a1) * Rk), (cx + np.cos(a2) * Rk * 0.76, cy + np.sin(a2) * Rk * 0.76)]
    disk = mask(D, D, lambda d: d.polygon(pts, fill=255))
    tex = metal(D, D, seed)
    yy, xx = np.mgrid[0:D, 0:D]
    rr = np.hypot(xx - cx, yy - cy) / Rk
    ang = np.arctan2(yy - cy, xx - cx)
    body = tex * (1.2 - 0.45 * np.clip((rr - 0.55) / 0.3, 0, 1))[..., None] + 8
    body += (28 * np.exp(-((rr - 0.62) / 0.025) ** 2) - 22 * np.exp(-((rr - 0.66) / 0.02) ** 2))[..., None]   # 깎은 동심 홈
    body += (70 * np.clip(np.cos(ang + 2.3), 0, 1) ** 5 * (rr > 0.3) * (rr < 0.8))[..., None]                   # 원판 반사 한 줄기
    lay.fill(disk, body)
    for i in range(teeth):   # 앞날 반사
        am = 2 * np.pi * (i + 0.55) / teeth; a1 = 2 * np.pi * (i + 0.9) / teeth
        p0 = (cx + np.cos(am) * Rk * 0.9, cy + np.sin(am) * Rk * 0.9); p1 = (cx + np.cos(a1) * Rk, cy + np.sin(a1) * Rk)
        lay.fill(mask(D, D, lambda d: d.line([p0, p1], fill=255, width=int(1.6 * S))) * 0.85, np.full_like(tex, 238))
    for k in range(4):       # 팽창 홈 4 개 + 끝 구멍
        a0 = 2 * np.pi * k / 4 + 0.3
        arc = [(cx + np.cos(a0 + t * 0.3) * Rk * (0.8 - 0.2 * t), cy + np.sin(a0 + t * 0.3) * Rk * (0.8 - 0.2 * t)) for t in np.linspace(0, 1, 9)]
        lay.fill(mask(D, D, lambda d: d.line(arc, fill=255, width=max(S, int(1.1 * S)))), np.full_like(tex, 16))
        ex, ey = arc[-1]
        lay.fill(mask(D, D, lambda d: d.ellipse([ex - 1.4 * S, ey - 1.4 * S, ex + 1.4 * S, ey + 1.4 * S], fill=255)), np.full_like(tex, 12))
    lay.bevel(disk, 4)
    lay.outline(disk)
    hub = mask(D, D, lambda d: d.ellipse([cx - 0.3 * Rk, cy - 0.3 * Rk, cx + 0.3 * Rk, cy + 0.3 * Rk], fill=255))
    lay.fill(hub, metal(D, D, seed + 9) * 0.85 + 10)
    lay.fill(mask(D, D, lambda d: d.ellipse([cx - 0.3 * Rk, cy - 0.3 * Rk, cx + 0.3 * Rk, cy + 0.3 * Rk], outline=255, width=OL)), np.full_like(tex, 8))
    for k in range(6):
        a = 2 * np.pi * k / 6
        lay.rivet(cx + np.cos(a) * Rk * 0.2, cy + np.sin(a) * Rk * 0.2, 0.34 * R / 40 * S / 3)
    hexp = [(cx + np.cos(np.pi / 3 * k) * Rk * 0.09, cy + np.sin(np.pi / 3 * k) * Rk * 0.09) for k in range(6)]
    nut = mask(D, D, lambda d: d.polygon(hexp, fill=255))
    lay.fill(nut, metal(D, D, seed + 4) * 0.7); lay.bevel(nut, 2)
    lay.fill(mask(D, D, lambda d: d.polygon(hexp, outline=255, width=max(2, int(0.8 * S)))), np.full_like(tex, 8))
    return lay


def stop():
    W, H = 12 * S, 16 * S
    lay = Layer(W, H)
    m = mask(W, H, lambda d: d.rectangle([OL, OL, W - OL - 1, H - OL - 1], fill=255))
    lay.fill(m, metal(W, H, 31) * 0.8); lay.bevel(m); lay.outline(m)
    lay.rivet(W / 2, H / 2, 0.5 * S / 3)
    return lay


def to_png(lay, w, h, path):
    rgb = Image.fromarray(np.clip(lay.rgb, 0, 255).astype(np.uint8)).resize((w, h), Image.LANCZOS)
    a = Image.fromarray((lay.a * 255).astype(np.uint8)).resize((w, h), Image.LANCZOS)
    Image.merge("RGBA", (*rgb.split(), a)).save(path)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for R in SIZES:
        n = 2 * R + 8
        to_png(saw(R), n, n, os.path.join(OUT_DIR, "saw_r%d.png" % R))
    to_png(stop(), 12, 16, os.path.join(OUT_DIR, "stop.png"))
    print("->", OUT_DIR)
    if "--미리보기" in sys.argv:
        folder = sys.argv[sys.argv.index("--미리보기") + 1]
        os.makedirs(folder, exist_ok=True)
        ims = [Image.open(os.path.join(OUT_DIR, "saw_r%d.png" % R)) for R in SIZES]
        W = sum(i.width for i in ims) + 10 * len(ims)
        sheet = Image.new("RGBA", (W, max(i.height for i in ims)), (70, 70, 70, 255))
        x = 0
        for i in ims:
            sheet.alpha_composite(i, (x, 0)); x += i.width + 10
        sheet.convert("RGB").resize((sheet.width * 3, sheet.height * 3), Image.NEAREST).save(os.path.join(folder, "톱_주철_크기별_확대.png"))
        print("미리보기 ->", folder)


if __name__ == "__main__":
    main()
