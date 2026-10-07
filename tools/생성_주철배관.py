# -*- coding: utf-8 -*-
"""하수도 주철 배관 부품 굽기 (엔진 없이 PNG 를 만든다).

왜 (2026-09-30 도형님: "배관 디자인이 우리 게임 분위기와 조금 다르다"):
  회색 배관 SS2D 키트(pipe_v1)는
    ① 밝고 균일한 회색 — 어두운 주철 세계(호퍼·격자·가시·톱)에서 장치보다 먼저 튄다
    ② 매끈한 몸통 + 같은 간격의 띠 — 공장 강관/PVC 처럼 깨끗하다
    ③ SS2D 가 모서리를 칼로 자른 직각(miter)으로 잇는다 — 배경 원화의 둥근 엘보와 나란히 보이면 어긋난다
    ④ 조명을 받지 않는 평면 그림이다
  → 배경 원화(wall.png)에 그려진 검은 주철관을 기준으로 다시 굽는다:
    ① 어두운 주철(배경관보다 한 단계만 밝게 — "밸브와 연결된 기능 관" 이 읽히게)
    ② 호퍼 원화의 주철 결 + 볼트 박힌 벽 고정 밴드 + 끝 플랜지
    ③ 둥근 엘보(4 방향 따로 구움 — 돌려 쓰면 빛 방향이 같이 돌아간다)
    ④ 원통 법선을 해석적으로 계산해 **노멀맵**도 같이 굽는다 → 벽등 빛이 관 둥근 면을 따라 흐른다
  금속 결은 가시 도구(생성_가시_주철.py)의 `plate_metal`(호퍼 원화 · 좌우 이음매 없음)을 빌린다.

규격(게임 px): 관 지름 40 · 엘보 중심선 반지름 36 · 직관 타일 256. 2 배로 굽는다(그릴 때 0.5 배).
  ⚠ 바꾸면 scripts/스마트월드/하수도_주철배관.gd 의 상수도 같이 바꿀 것.

만드는 것: assets/textures/obstacles/pipe/cast_iron_v1/
  straight_h / straight_v            직관 타일(가로 512x96 · 세로 96x512, 이음매 없이 반복)
  elbow_pp / elbow_pn / elbow_np / elbow_nn   엘보(사분면 부호: x 부호 · y 부호, 원 중심 기준)
  band_h / band_v                    벽 고정 밴드(관에 수직, 양쪽 귀에 볼트)
  flange_h / flange_v                끝 플랜지
  각 파일마다 *_n.png = 노멀맵(+X 오른쪽 · +Y 위쪽, 프로젝트 generate_normal_maps.gd 와 같은 관례)

사용:
  python tools/생성_주철배관.py                  # 굽는다(씨앗 고정 → 멱등)
  python tools/생성_주철배관.py --미리보기 <폴더>
"""
import importlib
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
주철 = importlib.import_module("생성_가시_주철")
OUT = os.path.join(ROOT, "assets", "textures", "obstacles", "pipe", "cast_iron_v1")

B = 2                    # 굽는 배율(게임 px → 그림 px)
R_PIPE = 20 * B          # 관 반지름
R_ELBOW = 36 * B         # 엘보 중심선 반지름
TILE = 256 * B
PAD = 8 * B              # 외곽선·그림자 여유
OL = 1.6 * B             # 외곽선 두께
LIGHT = np.array([-0.42, -0.70, 0.58]); LIGHT = LIGHT / np.linalg.norm(LIGHT)   # 왼쪽 위에서(화면 y 아래)

_GRAIN = 주철.plate_metal(TILE, TILE).mean(axis=2) / 255.0      # 가로로 이음매 없는 주철 결
# 원 결을 그대로 쓰면 호퍼 조각이 네모 블록으로 반복돼 보였다(실측) → 살짝 뭉개고 세로로 한 번 더 섞어 블록 경계를 지운다
from PIL import ImageFilter as _F
_g8 = Image.fromarray((np.clip(_GRAIN, 0, 1) * 255).astype(np.uint8)).filter(_F.GaussianBlur(1.5 * B))
_GRAIN = np.asarray(_g8).astype(np.float64) / 255.0
_GRAIN = 0.6 * _GRAIN + 0.4 * np.roll(_GRAIN, TILE // 3, axis=0)
_GRAIN = (_GRAIN - _GRAIN.mean()) / (_GRAIN.std() + 1e-6)


def grain(h, w, along_x=True):
    g = np.tile(_GRAIN, (h // TILE + 2, w // TILE + 2))
    g = g[:h, :w] if along_x else np.tile(_GRAIN.T, (h // TILE + 2, w // TILE + 2))[:h, :w]
    return g


def shade(s, perp, g, radius_scale=1.0, base=0.0):
    """s: 중심선에서의 부호 거리/반지름(−1..1), perp: (…,2) 바깥 방향 단위벡터. → (rgb, alpha, normal)"""
    s = np.asarray(s, np.float64)
    inside = np.abs(s) <= 1.0
    sc = np.clip(s, -1, 1)
    nz = np.sqrt(np.clip(1 - sc ** 2, 0, 1))
    n = np.stack([perp[..., 0] * sc, perp[..., 1] * sc, nz], -1)
    diff = np.clip(n @ LIGHT, 0, 1)
    refl = 2 * (n @ LIGHT)[..., None] * n - LIGHT
    spec = np.clip(refl[..., 2], 0, 1) ** 18
    # 어두운 주철: 배경 원화 관(몸통 ≈26)보다 한 단계 밝게(≈45), 하이라이트는 결 따라 끊겨 반짝인다
    alb = 36 + base + 6 * g
    lum = alb * (0.38 + 0.95 * diff) + spec * (120 + 30 * np.clip(g, -1, 2))
    lum = lum * (0.55 + 0.45 * nz ** 0.6)                    # 가장자리 어둡게(원통 가림)
    rgb = np.stack([lum * 1.00, lum * 0.985, lum * 0.96], -1)  # 호퍼처럼 아주 약간 따뜻한 쇳빛
    edge = np.abs(s) * radius_scale
    a = np.clip((1.0 + OL / R_PIPE - np.abs(s)) * R_PIPE / 1.2, 0, 1)
    ring = (np.abs(s) > 1.0) & (a > 0)
    rgb[ring] = 8                                             # 외곽선 = 거의 검정(배경에서 떼어 낸다)
    n[~inside] = [0, 0, 1]
    return rgb, a, n


def to_png(rgb, a, n, name):
    os.makedirs(OUT, exist_ok=True)
    img = np.dstack([np.clip(rgb, 0, 255), np.clip(a, 0, 1) * 255]).astype(np.uint8)
    Image.fromarray(img, "RGBA").save(os.path.join(OUT, name + ".png"))
    nm = np.dstack([n[..., 0] * 0.5 + 0.5, -n[..., 1] * 0.5 + 0.5, n[..., 2] * 0.5 + 0.5]) * 255   # +Y 위쪽
    Image.fromarray(np.dstack([nm, np.clip(a, 0, 1) * 255]).astype(np.uint8), "RGBA").save(os.path.join(OUT, name + "_n.png"))


def straight():
    H = 2 * (R_PIPE + PAD)
    y = np.arange(H)[:, None] + 0.5 - H / 2
    s = np.repeat(y / R_PIPE, TILE, 1)
    perp = np.zeros((H, TILE, 2)); perp[..., 1] = 1
    rgb, a, n = shade(s, perp, grain(H, TILE))
    to_png(rgb, a, n, "straight_h")
    to_png(rgb.transpose(1, 0, 2), a.T, n.transpose(1, 0, 2)[..., [1, 0, 2]], "straight_v")


def elbow():
    E = R_ELBOW + R_PIPE + PAD
    for sx, tag_x in ((1, "p"), (-1, "n")):
        for sy, tag_y in ((1, "p"), (-1, "n")):
            yy, xx = np.mgrid[0:E, 0:E] + 0.5
            vx, vy = xx * sx, yy * sy                          # 원 중심(그림 모서리)에서 사분면 방향
            d = np.hypot(vx, vy) + 1e-6
            s = (d - R_ELBOW) / R_PIPE
            perp = np.stack([vx / d, vy / d], -1)
            g = np.tile(_GRAIN, (2, 2))[:E, :E] * 0.8
            rgb, a, n = shade(s, perp, g)
            # 원 중심이 그림 왼쪽 위(0,0)가 되도록 그렸다 → 음수 사분면은 뒤집어 저장(원 중심이 오른쪽/아래 모서리)
            if sx < 0:
                rgb, a, n = rgb[:, ::-1], a[:, ::-1], n[:, ::-1]
            if sy < 0:
                rgb, a, n = rgb[::-1], a[::-1], n[::-1]
            to_png(rgb, a, n, "elbow_%s%s" % (tag_x, tag_y))


def collar(length, radius_mul, ears, name):
    """관에 수직인 고리(밴드/플랜지). 가로 관용으로 만들고 세로 관용은 전치한다.
    ears: 관 바깥으로 나온 볼트 귀(벽 고정 밴드) — 그림 위아래로 붙는다."""
    rr = R_PIPE * radius_mul
    ear = 7 * B if ears else 0
    H = int(2 * (rr + ear + PAD)); W = int(length + 2 * PAD)
    yy, xx = np.mgrid[0:H, 0:W] + 0.5
    cy = H / 2
    s = (yy - cy) / rr
    perp = np.zeros((H, W, 2)); perp[..., 1] = 1
    g = grain(H, W) * 0.6
    rgb, a, n = shade(s, perp, g, base=8)
    inx = (xx >= PAD) & (xx <= W - PAD)
    a = a * inx
    # 고리 양끝 모서리: 왼쪽 밝게 · 오른쪽 어둡게(두께감)
    rgb[(xx >= PAD) & (xx < PAD + 1.5 * B)] *= 1.35
    rgb[(xx > W - PAD - 1.5 * B) & (xx <= W - PAD)] *= 0.55
    if ears:
        for side in (-1, 1):
            ey0 = cy + side * rr
            m = (np.abs(yy - (ey0 + side * ear / 2)) <= ear / 2) & inx
            flat = np.zeros((H, W, 2)); flat[..., 1] = side
            e_rgb, _, e_n = shade(np.full((H, W), 0.35), flat, g, base=6)
            rgb[m] = e_rgb[m]; n[m] = e_n[m]; a[m] = 1
            # 볼트 머리
            by, bx = ey0 + side * ear * 0.55, W / 2
            bm = np.hypot(yy - by, xx - bx) <= 2.6 * B
            bd = np.hypot(yy - by, xx - bx)
            bperp = np.stack([(xx - bx) / (bd + 1e-6), (yy - by) / (bd + 1e-6)], -1)
            b_rgb, _, b_n = shade(bd / (2.6 * B), bperp, g * 0, base=20)
            rgb[bm] = b_rgb[bm]; n[bm] = b_n[bm]
            # 귀 외곽선
            o = (np.abs(yy - (ey0 + side * ear / 2)) <= ear / 2 + OL) & (xx >= PAD - OL) & (xx <= W - PAD + OL) & ~m & (a < 0.5)
            rgb[o] = 8; a[o] = 1
    to_png(rgb, a, n, name + "_h")
    to_png(rgb.transpose(1, 0, 2), a.T, n.transpose(1, 0, 2)[..., [1, 0, 2]], name + "_v")


def _over(dst, src):
    """알파 합성(src 가 위)."""
    rgb, a, n = dst
    r2, a2, n2 = src
    k = a2[..., None]
    return rgb * (1 - k) + r2 * k, np.maximum(a, a2), np.where(k > 0.5, n2, n)


def _cyl(H, W, horizontal, c, radius, t0, t1, g, base=0.0):
    """축에 나란한 짧은 원통(가로면 x 가 t0~t1, 세로면 y 가 t0~t1)."""
    yy, xx = np.mgrid[0:H, 0:W] + 0.5
    if horizontal:
        s = (yy - c[1]) / radius; perp = np.zeros((H, W, 2)); perp[..., 1] = 1; along = xx
    else:
        s = (xx - c[0]) / radius; perp = np.zeros((H, W, 2)); perp[..., 0] = 1; along = yy
    rgb, a, n = shade(s * radius / R_PIPE * (R_PIPE / radius), perp, g, base=base)
    # shade() 의 외곽선 두께는 R_PIPE 기준이라 굵은 원통도 같은 선 굵기가 되도록 s 를 반지름으로 정규화했다
    a = a * ((along >= t0) & (along <= t1))
    # 끊긴 양끝: 왼쪽/위 끝은 밝게 · 오른쪽/아래 끝은 어둡게(두께감) + 검은 끝선
    rgb = rgb.copy()
    rgb[(along >= t0) & (along < t0 + 1.5 * B)] *= 1.3
    rgb[(along > t1 - 1.5 * B) & (along <= t1)] *= 0.5
    return rgb, a, n


def tee():
    """T 자 이음쇠(티)와 십자. 들어오는 관들은 이음쇠 가운데까지 그려지고, 이음쇠가 그 위를 덮는다.
    왜: 한 관이 엘보로 꺾이는 점에서 다른 관이 따로 시작하면 엘보 모서리와 관 끝이 어긋나 끊겨 보였다(도형님 지적)."""
    RR = 1.08 * R_PIPE          # 몸통(허브) 반지름 — 관보다 약간 굵다
    HALF = 1.65 * R_PIPE        # 허브 반길이 = 가지 길이. 1.25 로는 가지가 허브 밖으로 거의 안 나와 네모 상자로 보였다(실측)
    RING = 1.24 * R_PIPE        # 입구 고리 반지름
    RL = 5 * B                  # 고리 길이
    E = int(HALF + RL + PAD)
    S = 2 * E
    c = (E, E)
    g = np.tile(_GRAIN, (2, 2))[:S, :S] * 0.6
    empty = (np.zeros((S, S, 3)), np.zeros((S, S)), np.dstack([np.zeros((S, S)), np.zeros((S, S)), np.ones((S, S))]))
    # 가지 방향 → (관통축 가로?, 가지 원통 구간)
    가지들 = {"l": (False, ("h", E - HALF - RL, E)), "r": (False, ("h", E, E + HALF + RL)),
            "u": (True, ("v", E - HALF - RL, E)), "d": (True, ("v", E, E + HALF + RL))}
    for 이름, (관통_가로, (축, t0, t1)) in list(가지들.items()) + [("x", (True, ("v", E - HALF - RL, E + HALF + RL)))]:
        lay = empty
        # 1) 가지(관통축에 수직) — 허브 아래에 깔린다
        lay = _over(lay, _cyl(S, S, 축 == "h", c, RR, t0 + (RL if t0 < E else 0), t1 - (RL if t1 > E else 0), g, base=6))
        # 2) 허브(관통축)
        lay = _over(lay, _cyl(S, S, 관통_가로, c, RR, E - HALF, E + HALF, g, base=8))
        # 3) 입구 고리 — 관통 양끝 + 가지 끝(십자는 네 끝)
        끝들 = [(관통_가로, E - HALF - RL, E - HALF), (관통_가로, E + HALF, E + HALF + RL)]
        if 이름 == "x":
            끝들 += [(not 관통_가로, E - HALF - RL, E - HALF), (not 관통_가로, E + HALF, E + HALF + RL)]
        else:
            끝들 += [(축 == "h", t0, t0 + RL) if t0 < E else (축 == "h", t1 - RL, t1)]
        for 가로, a0, a1 in 끝들:
            lay = _over(lay, _cyl(S, S, 가로, c, RING, a0, a1, g * 0.4, base=14))
        # 4) 허브 가운데 리벳 두 개 — 호퍼 이음과 같은 문법
        rgb, a, n = lay
        for k in (-1, 1):
            off = (k * RR * 0.45, 0) if 관통_가로 else (0, k * RR * 0.45)
            yy, xx = np.mgrid[0:S, 0:S] + 0.5
            bd = np.hypot(yy - (c[1] + off[1]), xx - (c[0] + off[0]))
            bm = bd <= 2.4 * B
            bperp = np.stack([(xx - c[0] - off[0]) / (bd + 1e-6), (yy - c[1] - off[1]) / (bd + 1e-6)], -1)
            b_rgb, _, b_n = shade(bd / (2.4 * B), bperp, g * 0, base=22)
            rgb[bm] = b_rgb[bm]; n[bm] = b_n[bm]
        to_png(rgb, a, n, "tee_" + 이름)


def preview(folder):
    os.makedirs(folder, exist_ok=True)
    names = ["straight_h", "elbow_pp", "elbow_np", "band_h", "flange_h", "tee_l", "tee_u", "tee_x", "straight_v", "band_v"]
    ims = [Image.open(os.path.join(OUT, n + ".png")) for n in names]
    W = sum(i.width for i in ims) + 20 * len(ims); H = max(i.height for i in ims)
    bg = Image.new("RGBA", (W, H), (40, 40, 42, 255)); x = 0
    for im in ims:
        bg.alpha_composite(im, (x, 0)); x += im.width + 20
    bg.convert("RGB").save(os.path.join(folder, "주철배관_부품.png"))


def main():
    straight(); elbow(); tee()
    collar(10 * B, 1.12, True, "band")
    collar(12 * B, 1.28, False, "flange")
    print("->", OUT)
    if "--미리보기" in sys.argv:
        f = sys.argv[sys.argv.index("--미리보기") + 1]
        preview(f); print("미리보기 ->", f)


if __name__ == "__main__":
    main()
