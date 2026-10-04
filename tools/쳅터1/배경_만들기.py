# -*- coding: utf-8 -*-
"""
쳅터1 방 배경 레이어 — 임시 그림 생성기 — 2026-10-04 Claude

아스트라(GPT) 그림이 오기 전까지 **느낌을 확인하는 자리표시 그림**을 코드로 그린다.
진짜 그림이 오면 **같은 파일 이름으로 덮어쓰기만** 하면 된다(씬·프리셋은 그대로).

출력: assets/background/쳅터1/레이어_v01/
  벽지/   다마스크 · 줄무늬 · 꽃무늬 · 판자 · 벽돌         512×512, 상하좌우 이음매 없음
  띠/     징두리_판넬(512×288) · 천장_몰딩(512×64) · 걸레받이(512×48)   가로 이음매 없음
  낡음/   얼룩_1~4 · 벗겨짐_1~3 · 금_1~3 · 찢김_1~2        투명 PNG
  가구/   규격.가구표의 이름.png                          32px = 1칸(게임 배율 그대로)

명도 규칙(흑백 게임): 벽 평균 ≈ 0.42, 무늬 ±0.05 · 징두리 ≈ 0.32 · 가구 0.18~0.40.
  → 검정 지형(≈0.05)·흰 지형(≈0.9)이 둘 다 배경에서 또렷이 떨어진다.
"""
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import 규격  # noqa: E402

저장소 = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
출력 = os.path.join(저장소, "assets", "background", "쳅터1", "레이어_v01")
C = 규격.칸


def g(v, a=255):
    v = int(max(0, min(255, round(v))))
    return (v, v, v, a)


def 잡음(w, h, 반경, 세기, 씨앗):
    """이음매 없는 부드러운 잡음 (평균 0, 표준편차 = 세기). 감싸는(wrap) 가우스 흐림."""
    from scipy.ndimage import gaussian_filter
    rng = np.random.default_rng(씨앗)
    a = gaussian_filter(rng.normal(0, 1, (h, w)), sigma=max(반경, 0.3), mode="wrap")
    a = (a - a.mean()) / (a.std() + 1e-9)
    return (a * 세기).astype(np.float32)


def 바탕(w, h, 밝기, 씨앗, 결=14, 세기=3.5):
    a = np.full((h, w), 밝기, np.float32) + 잡음(w, h, 결, 세기, 씨앗) + 잡음(w, h, 1.0, 1.6, 씨앗 + 1)
    return a


def 저장(a_or_img, 경로):
    os.makedirs(os.path.dirname(경로), exist_ok=True)
    if isinstance(a_or_img, np.ndarray):
        img = Image.fromarray(np.clip(a_or_img, 0, 255).astype(np.uint8), "L").convert("RGBA")
    else:
        img = a_or_img
    img.save(경로, optimize=True)


def _감싸그리기(d, w, h, fn):
    for ox in (-w, 0, w):
        for oy in (-h, 0, h):
            fn(d, ox, oy)


# ── 벽지 ────────────────────────────────────────────────────────────────────
def 벽지_다마스크():
    w = h = 512
    a = 바탕(w, h, 108, 11)
    무늬 = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(무늬)
    칸 = 64

    def 그림(d, ox, oy):
        for j in range(0, h // 칸 + 1):
            for i in range(0, w // 칸 + 1):
                cx = i * 칸 + (칸 // 2 if j % 2 else 0) + ox
                cy = j * 칸 + oy
                r = 18
                d.polygon([(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)], outline=255, width=2)
                d.polygon([(cx, cy - 7), (cx + 7, cy), (cx, cy + 7), (cx - 7, cy)], fill=170)
                d.ellipse([cx - 2, cy - r - 9, cx + 2, cy - r - 5], fill=200)
                d.ellipse([cx - 2, cy + r + 5, cx + 2, cy + r + 9], fill=200)
    _감싸그리기(d, w, h, 그림)
    m = np.asarray(무늬.filter(ImageFilter.GaussianBlur(0.8)), np.float32) / 255
    a = a - m * 26
    저장(a, os.path.join(출력, "벽지", "다마스크.png"))


def 벽지_줄무늬():
    w = h = 512
    a = 바탕(w, h, 112, 21, 10, 5)
    x = np.arange(w)
    주기 = 64
    p = (x % 주기)
    줄 = np.where(p < 22, -9.0, 0.0) + np.where((p >= 30) & (p < 34), -5.0, 0.0) + np.where((p >= 52) & (p < 54), 6.0, 0.0)
    a = a + 줄[None, :]
    저장(a, os.path.join(출력, "벽지", "줄무늬.png"))


def 벽지_꽃무늬():
    w = h = 512
    a = 바탕(w, h, 104, 31)
    무늬 = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(무늬)
    칸 = 64

    def 그림(d, ox, oy):
        for j in range(h // 칸 + 1):
            for i in range(w // 칸 + 1):
                cx = i * 칸 + (32 if j % 2 else 0) + ox
                cy = j * 칸 + 16 + oy
                for k in range(4):
                    t = k * math.pi / 2 + math.pi / 4
                    px, py = cx + math.cos(t) * 7, cy + math.sin(t) * 7
                    d.ellipse([px - 5, py - 5, px + 5, py + 5], fill=210)
                d.ellipse([cx - 3, cy - 3, cx + 3, cy + 3], fill=120)
                d.line([(cx, cy + 9), (cx + 6, cy + 22)], fill=160, width=2)
    _감싸그리기(d, w, h, 그림)
    m = np.asarray(무늬.filter(ImageFilter.GaussianBlur(0.7)), np.float32) / 255
    a = a + m * 24
    저장(a, os.path.join(출력, "벽지", "꽃무늬.png"))


def 벽지_판자():
    w = h = 512
    a = 바탕(w, h, 92, 41, 3, 4)
    rng = random.Random(4)
    x = 0
    while x < w:
        pw = rng.choice([48, 56, 64])
        if x + pw > w:
            pw = w - x
        a[:, x:x + pw] += rng.uniform(-7, 7)
        a[:, x:x + 2] -= 26
        a[:, x + 2:x + 3] += 8
        # 나뭇결: 세로 잡음
        x += pw
    결 = 잡음(w, h, 1.0, 1.0, 42)
    결 = np.repeat(결.mean(axis=0, keepdims=True), h, axis=0)
    a += 결 * 5
    for _ in range(14):
        cx, cy = rng.randrange(w), rng.randrange(h)
        yy, xx = np.ogrid[:h, :w]
        dd = ((xx - cx) / 5.0) ** 2 + ((yy - cy) / 9.0) ** 2
        a -= np.exp(-dd) * 18
    저장(a, os.path.join(출력, "벽지", "판자.png"))


def 벽지_벽돌():
    w = h = 512
    a = 바탕(w, h, 84, 51, 3, 6)
    bh, bw = 32, 64
    rng = random.Random(5)
    for j in range(h // bh):
        off = (bw // 2) if j % 2 else 0
        for i in range(-1, w // bw + 1):
            x0 = i * bw + off
            v = rng.uniform(-9, 9)
            for x in range(x0, x0 + bw):
                a[j * bh:(j + 1) * bh, x % w] += v
            a[j * bh:(j + 1) * bh, x0 % w] -= 30
        a[j * bh:j * bh + 3, :] -= 30
    저장(a, os.path.join(출력, "벽지", "벽돌.png"))


# ── 띠 ──────────────────────────────────────────────────────────────────────
def 띠_징두리():
    w, h = 512, 288
    a = 바탕(w, h, 80, 61, 4, 4)
    a[0:14, :] += 16           # 윗 난간
    a[14:18, :] -= 22
    a[h - 40:h, :] -= 10       # 아래 걸레받이 자리
    pw = 128
    for i in range(w // pw):
        x0, x1 = i * pw + 14, (i + 1) * pw - 14
        y0, y1 = 40, h - 60
        a[y0:y1, x0:x1] -= 6
        a[y0:y0 + 3, x0:x1] += 14     # 빛 받는 윗변
        a[y0:y1, x0:x0 + 3] += 10
        a[y1 - 3:y1, x0:x1] -= 18     # 그림자 아랫변
        a[y0:y1, x1 - 3:x1] -= 14
    저장(a, os.path.join(출력, "띠", "징두리_판넬.png"))


def 띠_몰딩():
    w, h = 512, 64
    a = np.zeros((h, w), np.float32)
    단 = [(0, 10, 70), (10, 18, 96), (18, 22, 60), (22, 34, 104), (34, 40, 72), (40, 52, 90), (52, 64, 58)]
    for y0, y1, v in 단:
        a[y0:y1, :] = v
    a += 잡음(w, h, 3, 3, 71)
    for x in range(0, w, 32):
        a[40:52, x:x + 4] -= 16
    저장(a, os.path.join(출력, "띠", "천장_몰딩.png"))


def 띠_걸레받이():
    w, h = 512, 48
    a = np.zeros((h, w), np.float32)
    a[0:6, :] = 96
    a[6:10, :] = 58
    a[10:48, :] = 64
    a += 잡음(w, h, 3, 3, 81)
    저장(a, os.path.join(출력, "띠", "걸레받이.png"))


# ── 낡음 ────────────────────────────────────────────────────────────────────
def _알파그림(w, h, 알파, 밝기):
    img = np.zeros((h, w, 4), np.uint8)
    img[..., 0:3] = np.clip(밝기, 0, 255).astype(np.uint8)[..., None]
    img[..., 3] = np.clip(알파, 0, 255).astype(np.uint8)
    return Image.fromarray(img, "RGBA")


def 낡음_그림들():
    rng = np.random.default_rng(7)
    for k in range(4):     # 얼룩 — 물 자국: 가장자리가 진한 불규칙 원
        w, h = 320, 260
        yy, xx = np.mgrid[:h, :w]
        r = np.hypot((xx - w / 2) / (w * 0.38), (yy - h / 2) / (h * 0.38))
        r += 잡음(w, h, 32, 0.13, 100 + k) + 잡음(w, h, 9, 0.03, 200 + k)
        안 = np.clip(1 - r, 0, 1)
        테 = np.exp(-((r - 0.95) / 0.06) ** 2)
        알파 = (안 * 50 + 테 * 110)
        알파[r > 1.15] = 0
        저장(_알파그림(w, h, 알파, np.full((h, w), 40.0)), os.path.join(출력, "낡음", f"얼룩_{k + 1}.png"))
    for k in range(3):     # 벗겨짐 — 벽지가 들려 밝은 안쪽 + 어두운 그늘
        w, h = 220, 300
        yy, xx = np.mgrid[:h, :w]
        r = np.hypot((xx - w / 2) / (w * 0.4), (yy - h * 0.45) / (h * 0.42)) + 잡음(w, h, 28, 0.14, 300 + k) + 잡음(w, h, 6, 0.03, 320 + k)
        안 = r < 0.9
        테 = (r >= 0.9) & (r < 1.0)
        밝기 = np.where(안, 116.0, 30.0) + 잡음(w, h, 2, 5, 310 + k)   # [2차] 150 → 116: 벽보다 조금만 밝게
        알파 = np.where(안, 190.0, np.where(테, 170.0, 0.0))
        저장(_알파그림(w, h, 알파, 밝기), os.path.join(출력, "낡음", f"벗겨짐_{k + 1}.png"))
    for k in range(3):     # 금 — 가지 치는 가는 선
        w, h = 260, 260
        im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        rr = random.Random(400 + k)

        def 가지(x, y, 각, 길이, 굵기):
            if 길이 < 8 or 굵기 < 1:
                return
            nx, ny = x + math.cos(각) * 길이, y + math.sin(각) * 길이
            d.line([(x, y), (nx, ny)], fill=(20, 20, 20, 210), width=int(굵기))
            가지(nx, ny, 각 + rr.uniform(-0.5, 0.5), 길이 * 0.8, 굵기 * 0.85)
            if rr.random() < 0.45:
                가지(nx, ny, 각 + rr.choice([-1, 1]) * rr.uniform(0.6, 1.1), 길이 * 0.6, 굵기 * 0.7)
        가지(w * 0.5, 10, math.pi / 2 + rr.uniform(-0.3, 0.3), 34, 3)
        저장(im, os.path.join(출력, "낡음", f"금_{k + 1}.png"))
    for k in range(2):     # 찢김 — 벽지가 뜯겨 판자가 보인다
        w, h = 300, 360
        판 = np.asarray(Image.open(os.path.join(출력, "벽지", "판자.png")).convert("L"), np.float32)[:h, :w] * 0.8
        yy, xx = np.mgrid[:h, :w]
        r = np.hypot((xx - w / 2) / (w * 0.42), (yy - h / 2) / (h * 0.45)) + 잡음(w, h, 26, 0.16, 500 + k) + 잡음(w, h, 6, 0.04, 520 + k)
        알파 = np.where(r < 0.85, 255.0, np.where(r < 0.93, 230.0, 0.0))
        밝기 = np.where(r < 0.85, 판, 112.0)
        저장(_알파그림(w, h, 알파, 밝기), os.path.join(출력, "낡음", f"찢김_{k + 1}.png"))
    # 먼지 — 아래로 갈수록 짙어지는 세로 띠(방 아래쪽에 깐다)
    w, h = 64, 256
    알파 = np.tile(np.linspace(0, 120, h)[:, None], (1, w))
    저장(_알파그림(w, h, 알파, np.full((h, w), 30.0)), os.path.join(출력, "낡음", "먼지.png"))


# ── 가구 ────────────────────────────────────────────────────────────────────
class 붓:
    """가구를 그리는 작은 도구 — 밝기만 다루는 판자/몰딩 그리기."""

    def __init__(self, w칸, h칸):
        self.W, self.H = int(w칸 * C), int(h칸 * C)
        self.im = Image.new("RGBA", (self.W, self.H), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im)

    def 판(self, x0, y0, x1, y1, v, 테=True):
        d = self.d
        d.rectangle([x0, y0, x1, y1], fill=g(v))
        if 테:
            d.line([(x0, y0), (x1, y0)], fill=g(v + 26), width=2)
            d.line([(x0, y0), (x0, y1)], fill=g(v + 16), width=2)
            d.line([(x0, y1), (x1, y1)], fill=g(v - 22), width=2)
            d.line([(x1, y0), (x1, y1)], fill=g(v - 16), width=2)

    def 원(self, cx, cy, r, v, 테=None):
        self.d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=g(v), outline=g(테) if 테 is not None else None, width=2)

    def 결(self, 씨앗=1, 세기=7):
        a = np.asarray(self.im).astype(np.float32)
        n = 잡음(self.W, self.H, 1.5, 세기, 씨앗)
        a[..., :3] += n[..., None]
        self.im = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")
        self.d = ImageDraw.Draw(self.im)


def 가구_그리기():
    rng = random.Random(9)
    out = {}

    b = 붓(12, 5)                                    # 침대
    W, H = b.W, b.H
    b.판(0, 10, 26, H - 1, 52)                       # 머리판
    b.판(W - 22, 60, W - 1, H - 1, 50)               # 발판
    b.판(20, 78, W - 20, 120, 150, False)            # 매트리스(밝다)
    b.d.rounded_rectangle([60, 64, W - 24, 128], 14, fill=g(118))   # 이불
    b.d.rounded_rectangle([26, 62, 80, 90], 10, fill=g(170))       # 베개
    b.판(18, 120, W - 18, H - 8, 44)
    b.결(1)
    out["침대"] = b

    b = 붓(7, 10)                                    # 옷장
    W, H = b.W, b.H
    b.판(0, 18, W - 1, H - 10, 58)
    b.판(10, 0, W - 11, 22, 66)
    b.판(14, 34, W // 2 - 4, H - 30, 64)
    b.판(W // 2 + 4, 34, W - 14, H - 30, 64)
    b.원(W // 2 - 12, H // 2, 4, 150)
    b.원(W // 2 + 12, H // 2, 4, 150)
    b.판(6, H - 12, 22, H - 1, 40, False)
    b.판(W - 22, H - 12, W - 6, H - 1, 40, False)
    b.결(2)
    out["옷장"] = b

    b = 붓(8, 4)                                     # 책상
    W, H = b.W, b.H
    b.판(0, 20, W - 1, 34, 70)
    b.판(10, 34, 22, H - 1, 48, False)
    b.판(W - 22, 34, W - 10, H - 1, 48, False)
    b.판(W - 110, 34, W - 24, 70, 60)
    b.판(40, 0, 70, 20, 130, False)                   # 책 더미
    b.원(W - 60, 8, 7, 170)                           # 촛대 불
    b.결(3)
    out["책상"] = b

    b = 붓(3, 4)                                     # 의자
    W, H = b.W, b.H
    b.판(10, 0, 24, H - 1, 54)
    b.판(10, 64, W - 4, 76, 62)
    b.판(W - 16, 76, W - 6, H - 1, 50, False)
    b.결(4)
    out["의자"] = b

    def 책장(w, h, 씨):
        b = 붓(w, h)
        W, H = b.W, b.H
        b.판(0, 0, W - 1, H - 1, 46)
        단 = 6 if h <= 12 else 9
        간 = (H - 24) / 단
        r = random.Random(씨)
        for k in range(단):
            y0 = int(12 + k * 간)
            y1 = int(12 + (k + 1) * 간)
            b.판(10, y1 - 8, W - 11, y1, 64)
            x = 14
            while x < W - 18:
                bw = r.randint(8, 16)
                bh = r.randint(int(간 * 0.55), int(간 - 12))
                v = r.choice([70, 84, 96, 110, 60, 124])
                if r.random() < 0.08:
                    x += bw
                    continue
                b.d.rectangle([x, y1 - 8 - bh, x + bw - 2, y1 - 9], fill=g(v))
                b.d.line([(x + 2, y1 - 8 - bh + 6), (x + bw - 4, y1 - 8 - bh + 6)], fill=g(v + 30), width=1)
                x += bw
        b.결(씨)
        return b
    out["책장"] = 책장(7, 12, 11)
    out["책장_높음"] = 책장(8, 18, 12)

    b = 붓(4, 8)                                     # 거울
    W, H = b.W, b.H
    b.d.ellipse([4, 4, W - 5, H - 40], fill=g(60), outline=g(90), width=4)
    b.d.ellipse([16, 16, W - 17, H - 52], fill=g(150))
    b.d.line([(30, 40), (60, 80)], fill=g(190), width=3)
    b.판(W // 2 - 8, H - 40, W // 2 + 8, H - 1, 50)
    b.결(13)
    out["거울"] = b

    def 시계(h칸, 씨):
        b = 붓(3, h칸)
        W, H = b.W, b.H
        b.판(4, 0, W - 5, H - 1, 52)
        b.원(W // 2, 26, 17, 160, 80)
        b.d.line([(W // 2, 26), (W // 2, 14)], fill=g(30), width=2)
        b.d.line([(W // 2, 26), (W // 2 + 9, 30)], fill=g(30), width=2)
        b.판(14, 60, W - 15, H - 30, 34)
        b.d.line([(W // 2, 62), (W // 2, H - 50)], fill=g(140), width=2)
        b.원(W // 2, H - 48, 7, 150)
        b.결(씨)
        return b
    out["시계"] = 시계(8, 14)
    out["괘종시계"] = 시계(9, 15)

    def 문(열림):
        b = 붓(5, 8)
        W, H = b.W, b.H
        b.판(0, 0, W - 1, H - 1, 50)                    # 문틀
        if 열림:
            for y in range(12, H):
                pass
            b.d.rectangle([12, 12, W - 13, H - 1], fill=g(8))
            # 안쪽으로 열린 문짝(사다리꼴)
            b.d.polygon([(12, 12), (40, 24), (40, H - 10), (12, H - 1)], fill=g(56))
            b.d.line([(40, 24), (40, H - 10)], fill=g(90), width=2)
        else:
            b.판(12, 12, W - 13, H - 1, 66)
            b.판(22, 24, W - 23, H // 2 - 8, 74)
            b.판(22, H // 2 + 4, W - 23, H - 14, 74)
            b.원(W - 26, H // 2 + 10, 4, 160)
        b.결(16 if 열림 else 17)
        return b
    out["문_닫힘"] = 문(False)
    out["문_열림"] = 문(True)

    b = 붓(4, 3)                                     # 협탁
    W, H = b.W, b.H
    b.판(0, 40, W - 1, 52, 70)
    b.판(10, 52, 20, H - 1, 48, False)
    b.판(W - 20, 52, W - 10, H - 1, 48, False)
    b.d.polygon([(W // 2 - 10, 40), (W // 2 + 10, 40), (W // 2 + 6, 16), (W // 2 - 6, 16)], fill=g(120))
    b.d.ellipse([W // 2 - 14, 0, W // 2 + 14, 20], fill=g(90))
    b.결(18)
    out["협탁"] = b

    b = 붓(3, 16)                                    # 사다리
    W, H = b.W, b.H
    b.판(6, 0, 18, H - 1, 62)
    b.판(W - 19, 0, W - 7, H - 1, 62)
    for y in range(20, H, 40):
        b.판(18, y, W - 19, y + 8, 70, False)
    b.결(19)
    out["사다리"] = b

    b = 붓(3, 4)                                     # 지구본
    W, H = b.W, b.H
    b.원(W // 2, 42, 34, 96, 60)
    b.d.arc([W // 2 - 34, 8, W // 2 + 34, 76], 90, 270, fill=g(130), width=2)
    b.d.line([(W // 2 - 34, 42), (W // 2 + 34, 42)], fill=g(130), width=2)
    b.판(W // 2 - 6, 76, W // 2 + 6, H - 10, 50, False)
    b.판(W // 2 - 22, H - 10, W // 2 + 22, H - 1, 50, False)
    b.결(20)
    out["지구본"] = b

    b = 붓(8, 10)                                    # 선반
    W, H = b.W, b.H
    b.판(0, 0, 12, H - 1, 50)
    b.판(W - 13, 0, W - 1, H - 1, 50)
    r = random.Random(21)
    for k in range(4):
        y = 70 + k * 75
        b.판(0, y, W - 1, y + 10, 64)
        x = 18
        while x < W - 40:
            bw = r.randint(24, 44)
            bh = r.randint(26, 56)
            b.판(x, y - bh, x + bw, y, r.choice([72, 86, 100]))
            x += bw + r.randint(4, 14)
    b.결(21)
    out["선반"] = b

    b = 붓(6, 4)                                     # 상자더미
    W, H = b.W, b.H
    b.판(0, 54, 96, H - 1, 72)
    b.판(96, 70, W - 1, H - 1, 64)
    b.판(20, 0, 110, 54, 80)
    for (x0, y0, x1, y1) in [(0, 54, 96, H - 1), (20, 0, 110, 54)]:
        b.d.line([(x0, y0), (x1, y1)], fill=g(56), width=3)
        b.d.line([(x1, y0), (x0, y1)], fill=g(56), width=3)
    b.결(22)
    out["상자더미"] = b

    b = 붓(10, 4)                                    # 소파
    W, H = b.W, b.H
    b.d.rounded_rectangle([0, 10, W - 1, H - 14], 20, fill=g(70))
    b.d.rounded_rectangle([24, 50, W - 25, H - 20], 12, fill=g(90))
    b.판(20, H - 16, 34, H - 1, 40, False)
    b.판(W - 34, H - 16, W - 20, H - 1, 40, False)
    b.결(23)
    out["소파"] = b

    b = 붓(10, 6)                                    # 피아노
    W, H = b.W, b.H
    b.판(0, 0, W - 1, 120, 34)
    b.판(0, 120, W - 1, 140, 170, False)
    for x in range(8, W - 8, 22):
        b.d.rectangle([x, 120, x + 12, 132], fill=g(20))
    b.판(10, 140, 30, H - 1, 30, False)
    b.판(W - 30, 140, W - 10, H - 1, 30, False)
    b.결(24)
    out["피아노"] = b

    def 벽난로(w, h, 속):
        b = 붓(w, h)
        W, H = b.W, b.H
        if 속:
            b.d.rectangle([0, 0, W - 1, H - 1], fill=g(36))
            for j in range(0, H, 24):
                off = 24 if (j // 24) % 2 else 0
                for i in range(-1, W // 48 + 1):
                    b.d.rectangle([i * 48 + off, j, i * 48 + off + 46, j + 22], outline=g(22), width=2)
            b.d.ellipse([W // 2 - 90, H - 40, W // 2 + 90, H + 20], fill=g(60))     # 재
        else:
            b.판(0, 0, W - 1, 30, 76)
            b.판(10, 30, W - 11, H - 1, 62)
            b.d.rectangle([50, 80, W - 51, H - 1], fill=g(10))
            b.d.ellipse([W // 2 - 50, H - 50, W // 2 + 50, H + 10], fill=g(120))     # 불씨
        b.결(25 if 속 else 26)
        return b
    out["벽난로"] = 벽난로(10, 9, False)
    out["벽난로_속"] = 벽난로(12, 10, True)

    b = 붓(8, 12)                                    # 창문
    W, H = b.W, b.H
    b.판(0, 0, W - 1, H - 1, 56)
    for y in range(16, H - 16):
        t = (y - 16) / (H - 32)
        b.d.line([(16, y), (W - 17, y)], fill=g(200 - t * 50))
    b.d.rectangle([W // 2 - 4, 16, W // 2 + 4, H - 17], fill=g(56))
    b.d.rectangle([16, H // 2 - 4, W - 17, H // 2 + 4], fill=g(56))
    # 커튼
    b.d.polygon([(0, 0), (44, 0), (30, H // 2), (40, H - 1), (0, H - 1)], fill=g(74))
    b.d.polygon([(W - 1, 0), (W - 45, 0), (W - 31, H // 2), (W - 41, H - 1), (W - 1, H - 1)], fill=g(74))
    b.결(27, 4)
    out["창문"] = b

    b = 붓(6, 6)                                     # 액자_팔각
    W, H = b.W, b.H
    def 팔각(r):
        return [(W / 2 + r * math.cos(math.pi / 8 + k * math.pi / 4), H / 2 + r * math.sin(math.pi / 8 + k * math.pi / 4)) for k in range(8)]
    b.d.polygon(팔각(W * 0.48), fill=g(72))
    b.d.polygon(팔각(W * 0.40), fill=g(96))
    b.d.polygon(팔각(W * 0.34), fill=g(84))
    b.결(28)
    out["액자_팔각"] = b

    b = 붓(5, 4)                                     # 액자(초상)
    W, H = b.W, b.H
    b.판(0, 0, W - 1, H - 1, 70)
    b.d.rectangle([12, 12, W - 13, H - 13], fill=g(48))
    b.d.ellipse([W // 2 - 16, 26, W // 2 + 16, 62], fill=g(96))
    b.d.ellipse([W // 2 - 34, 60, W // 2 + 34, H + 30], fill=g(70))
    b.결(29)
    out["액자"] = b

    b = 붓(6, 6)                                     # 샹들리에
    W, H = b.W, b.H
    b.d.line([(W // 2, 0), (W // 2, 70)], fill=g(60), width=4)
    b.d.ellipse([W // 2 - 70, 70, W // 2 + 70, 110], outline=g(74), width=6)
    for k in range(5):
        x = W // 2 - 70 + k * 35
        b.d.line([(x, 90), (x, 120)], fill=g(74), width=4)
        b.d.rectangle([x - 4, 120, x + 4, 140], fill=g(170))
        b.d.ellipse([x - 5, 104, x + 5, 120], fill=g(230))
    b.결(30, 3)
    out["샹들리에"] = b

    b = 붓(2, 3)                                     # 벽등
    W, H = b.W, b.H
    b.판(W // 2 - 8, 30, W // 2 + 8, H - 10, 64)
    b.d.polygon([(W // 2 - 20, 30), (W // 2 + 20, 30), (W // 2 + 12, 6), (W // 2 - 12, 6)], fill=g(190))
    b.결(31, 3)
    out["벽등"] = b

    for 이름, b in out.items():
        assert 이름 in 규격.가구표, 이름
        w칸, h칸, _ = 규격.가구표[이름]
        assert b.im.size == (w칸 * C, h칸 * C), (이름, b.im.size)
        저장(b.im, os.path.join(출력, "가구", f"{이름}.png"))
    빠짐 = set(규격.가구표) - set(out)
    if 빠짐:
        raise SystemExit(f"가구 그림 빠짐: {빠짐}")
    return out


def main():
    벽지_다마스크(); 벽지_줄무늬(); 벽지_꽃무늬(); 벽지_판자(); 벽지_벽돌()
    띠_징두리(); 띠_몰딩(); 띠_걸레받이()
    낡음_그림들()
    가구 = 가구_그리기()
    n = sum(len(fs) for _, _, fs in os.walk(출력))
    print(f"생성: {os.path.relpath(출력, 저장소)} · 파일 {n}개 · 가구 {len(가구)}종")


if __name__ == "__main__":
    main()
