# -*- coding: utf-8 -*-
"""체크포인트 — 주철 잉크 성수반 그림 굽기 (엔진 없이 PNG 를 만든다).

왜:
  예전 체크포인트는 "잉크 등불"(lantern.svg) 이었다. 꺼져 있으면 회색 항아리처럼 보였고,
  하수도 벽마다 걸린 철창 벽등(장식)과 "빛 = 체크포인트" 신호가 겹쳤다.
  2026-09-30 도형님 확정(시안 A): **바닥에 선 주철 성수반** — 꺼져 있다가 닿으면 불빛이 나며 흰 잉크가 찬다.
  새로 그리지 않고 가시·톱과 같은 방식으로 **호퍼 원화(주철 아틀라스)의 금속 결·리벳·외곽선**을 조합한다.
  윗단은 호퍼 입구와 같은 "상자 테 + 안쪽 홈" 모양이라 하수도 기물과 한 벌로 읽힌다.

만드는 것: assets/textures/props/checkpoint_font/font_body.png  (96 x 108, 게임 1:1)
  잉크는 그리지 않는다 — 스크립트(scripts/장애물/체크포인트.gd)가 안쪽 홈에 채운다.
  ⚠ 아래 규격(홈 자리 · 바닥 y)을 바꾸면 체크포인트.gd 의 `성수반_*` 상수도 같이 바꿀 것.
    홈   x 13~83 · y 22~28   (그림 왼쪽 위 기준, 게임 px)
    바닥 y 104 = 노드 원점(발판 윗면)

사용:
  python tools/생성_체크포인트_성수반.py                  # 굽는다(씨앗 고정 → 멱등)
  python tools/생성_체크포인트_성수반.py --미리보기 <폴더>   # + 벽돌색 배경 위 6 배 확대
"""
import importlib
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
# 가시 도구의 주철 재료(금속 결·리벳·외곽선/그림자)를 그대로 빌려 쓴다 — 재질이 같아야 한 세계로 보인다.
주철 = importlib.import_module("생성_가시_주철")
S, metal, mask, Layer, outline_and_shadow = 주철.S, 주철.metal, 주철.mask, 주철.Layer, 주철.outline_and_shadow

OUT_DIR = os.path.join(ROOT, "assets", "textures", "props", "checkpoint_font")
OUT = os.path.join(OUT_DIR, "font_body.png")
W, H = 96, 108

# 게임 px 규격(그림 왼쪽 위 기준)
RIM = (6, 20, 90, 34)          # 윗단 상자 테
SLOT = (13, 22, 83, 28)        # 안쪽 홈 = 잉크 자리
BOWL = (14, 34, 82, 36, 60, 60)  # 윗변 x14~82 @y34 → 아랫변 x36~60 @y60
COL = (39, 60, 57, 94)         # 기둥
BASE = (28, 94, 68, 104)       # 받침


def g(v):
    return v * S


def build():
    w, h = g(W), g(H)
    lay = Layer(w, h)
    tex = metal(w, h, 4242)
    # ── 받침 · 기둥 · 대야 몸통 ── 아래에서 위로 쌓는다(위 것이 아래 것의 외곽을 덮게)
    base = mask(w, h, lambda d: d.polygon([(g(BASE[0]) + g(2), g(BASE[1])), (g(BASE[2]) - g(2), g(BASE[1])),
                                           (g(BASE[2]), g(BASE[1]) + g(3)), (g(BASE[2]), g(BASE[3])),
                                           (g(BASE[0]), g(BASE[3])), (g(BASE[0]), g(BASE[1]) + g(3))], fill=255))
    lay.fill(base, tex * 0.72)
    lay.bevel(base)
    col = mask(w, h, lambda d: d.rectangle([g(COL[0]), g(COL[1]), g(COL[2]), g(COL[3])], fill=255))
    v = np.clip((np.arange(h)[:, None] - g(COL[1])) / g(COL[3] - COL[1]), 0, 1)
    lay.fill(col, tex * (0.95 - 0.35 * v)[..., None])
    lay.bevel(col)
    # 기둥의 후드 문장(새김) — "플레이어의 자리". 파인 홈이라 어둡고, 아래·오른쪽 가장자리가 빛을 받는다.
    cx = (COL[0] + COL[2]) / 2
    hood = mask(w, h, lambda d: d.polygon([(g(cx), g(65)), (g(cx + 4.5), g(71)), (g(cx + 5.5), g(85)),
                                           (g(cx - 5.5), g(85)), (g(cx - 4.5), g(71))], fill=255))
    lay.rgb = lay.rgb * (1 - hood[..., None] * 0.62)
    up = np.zeros_like(hood); up[S * 2:, :] = hood[:-S * 2, :]
    lay.rgb += (np.clip(up - hood, 0, 1) * 55)[..., None]
    face = mask(w, h, lambda d: d.ellipse([g(cx - 2.6), g(72), g(cx + 2.6), g(77)], fill=255))
    lay.rgb = lay.rgb * (1 - face[..., None] * 0.5)
    bowl = mask(w, h, lambda d: d.polygon([(g(BOWL[0]), g(BOWL[1])), (g(BOWL[2]), g(BOWL[1])),
                                           (g(BOWL[4]), g(BOWL[5])), (g(BOWL[3]), g(BOWL[5]))], fill=255))
    vb = np.clip((np.arange(h)[:, None] - g(BOWL[1])) / g(BOWL[5] - BOWL[1]), 0, 1)
    lay.fill(bowl, tex * (1.05 - 0.45 * vb)[..., None] + 6)
    lay.bevel(bowl)
    # 대야 윗줄 리벳(호퍼 깔때기와 같은 문법)
    for x in (22, 35, 48, 61, 74):
        lay.rivet(g(x), g(BOWL[1] + 3.2), 0.5 * S / 3)
    # ── 윗단 상자 테 + 안쪽 홈 ──
    rim = mask(w, h, lambda d: d.rectangle([g(RIM[0]), g(RIM[1]), g(RIM[2]), g(RIM[3])], fill=255))
    lay.fill(rim, tex * 1.12 + 10)
    lay.bevel(rim)
    slot = mask(w, h, lambda d: d.rectangle([g(SLOT[0]), g(SLOT[1]), g(SLOT[2]), g(SLOT[3])], fill=255))
    vs = np.clip((np.arange(h)[:, None] - g(SLOT[1])) / g(SLOT[3] - SLOT[1]), 0, 1)
    lay.fill(slot, np.zeros_like(tex) + (14 + 16 * vs)[..., None])   # 마른 홈 — 안쪽 벽이 아래로 조금 밝다
    top = np.zeros_like(slot); top[g(SLOT[1]):g(SLOT[1]) + S * 2, g(SLOT[0]):g(SLOT[2])] = 1
    lay.rgb = lay.rgb * (1 - top[..., None]) + 4 * top[..., None]    # 테 안쪽 그늘
    for x in (RIM[0] + 3.2, RIM[2] - 3.2):
        lay.rivet(g(x), g((RIM[1] + RIM[3]) / 2 + 1.5), 0.5 * S / 3)
    outline_and_shadow(lay, np.maximum.reduce([base, col, bowl, rim]))
    return 주철.to_rgba(lay, W, H)


def preview(img, folder):
    bg = Image.new("RGBA", img.size, (42, 42, 44, 255))
    bg.alpha_composite(img)
    lit = img.copy()
    px = np.asarray(lit).copy()
    px[22:29, 13:84, :3] = 236; px[22:29, 13:84, 3] = 255     # 잉크가 찬 모습(대충)
    bg2 = Image.new("RGBA", img.size, (42, 42, 44, 255)); bg2.alpha_composite(Image.fromarray(px))
    both = Image.new("RGB", (img.width * 2 + 8, img.height), (20, 20, 20))
    both.paste(bg.convert("RGB"), (0, 0)); both.paste(bg2.convert("RGB"), (img.width + 8, 0))
    both.resize((both.width * 6, both.height * 6), Image.NEAREST).save(os.path.join(folder, "체크포인트_성수반_확대.png"))


def main():
    img = build()
    os.makedirs(OUT_DIR, exist_ok=True)
    img.save(OUT)
    print("->", OUT)
    if "--미리보기" in sys.argv:
        folder = sys.argv[sys.argv.index("--미리보기") + 1]
        os.makedirs(folder, exist_ok=True)
        preview(img, folder)
        print("미리보기 ->", folder)


if __name__ == "__main__":
    main()
