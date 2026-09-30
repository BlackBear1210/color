# -*- coding: utf-8 -*-
"""물줄기 v3 프레임 굽기 (엔진 없이 파이썬으로 PNG 를 만든다).

왜 굽나:
  v2 는 착수 물보라를 셰이더 안에서 12 개 물방울 루프로 그렸다. 그 결과 둥근 점이
  자갈처럼 보였고(2026-09-27 시안 비교), 모양을 다듬으려면 셰이더를 계속 고쳐야 했다.
  v3 는 모양이 복잡한 부분(왕관 물막 · 눈물 모양 물방울 · 잔거품 · 잔물결)만 **프레임으로 굽고**,
  폭·높이·색처럼 인스턴스마다 다른 것은 셰이더가 계산한다.

만드는 것 (assets/textures/obstacles/liquid/stream_v3/):
  flow_v3.png          128x512  세로로 길쭉한 흐름 줄무늬. 가로·세로 모두 이음매 없이 반복.
  splash_v3_sheet.png  4x4 = 16 프레임, 한 칸 384x128. 기준 물줄기 폭 64px 에서 그렸다.
                       한 바퀴 돌면 처음 프레임과 이어진다(모든 입자 수명이 주기 안에서 돈다).
                       채널: R = 밝기 단계(0 = 거품 어두운 쪽 · 1 = 가장 밝은 반사)
                             G = 물막 비율(1 이면 R 대신 물 몸통 색을 쓴다 — 바닥에 퍼진 얇은 물)
                             B = 사용 안 함(0)
                             A = 덮임
                       색(검정/회색/흰)은 셰이더가 R·G 를 보고 입힌다 → 한 장으로 세 색을 쓴다.
                       착수점 = 칸 안 (192, 112). 112 가 바닥 윗면.

멱등: 씨앗이 고정이라 몇 번 돌려도 같은 PNG 가 나온다.

사용:
  python tools/생성_물줄기_v3_프레임.py            # PNG 를 굽는다
  python tools/생성_물줄기_v3_프레임.py --미리보기 <폴더>   # 굽고, 프레임 확인용 확대 시트도 그 폴더에 둔다
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "assets", "textures", "obstacles", "liquid", "stream_v3")

# ---- 시트 규격 (셰이더 water_stream_v3.gdshader 의 상수와 반드시 같아야 한다) ----
FRAMES = 16
COLS = 4
FW, FH = 384, 128
CX, GY = 192, 112          # 착수점
REF_W = 64.0               # 기준 물줄기 폭
SS = 4                     # 4 배로 그려서 줄인다(계단 현상 제거)


def periodic_noise(h, w, cells_y, cells_x, seed):
    """가로·세로 모두 이음매 없이 반복되는 값 노이즈(격자를 감싸서 보간)."""
    r = np.random.default_rng(seed).random((cells_y, cells_x)).astype(np.float32)
    ys = np.arange(h, dtype=np.float32) / h * cells_y
    xs = np.arange(w, dtype=np.float32) / w * cells_x
    y0 = np.floor(ys).astype(int); x0 = np.floor(xs).astype(int)
    fy = ys - y0; fx = xs - x0
    fy = fy * fy * (3 - 2 * fy); fx = fx * fx * (3 - 2 * fx)
    y1 = (y0 + 1) % cells_y; x1 = (x0 + 1) % cells_x
    y0 %= cells_y; x0 %= cells_x
    a = r[y0][:, x0]; b = r[y0][:, x1]; c = r[y1][:, x0]; d = r[y1][:, x1]
    fx = fx[None, :]; fy = fy[:, None]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def make_flow():
    # 세로로 길게 늘어난 줄(세로 칸 수를 적게) 두 겹. 셰이더는 R 을 세제곱해서 밝은 줄만 남긴다.
    h, w = 512, 128
    n = periodic_noise(h, w, 11, 40, 11) * 0.65 + periodic_noise(h, w, 28, 64, 12) * 0.35
    n = (n - n.min()) / (n.max() - n.min())
    # G: 잔 무늬(물결 왜곡·미세 얼룩용), 셰이더에서 ±로 쓴다
    g = periodic_noise(h, w, 128, 32, 13)
    img = np.zeros((h, w, 4), np.uint8)
    img[..., 0] = (n * 255).astype(np.uint8)
    img[..., 1] = (g * 255).astype(np.uint8)
    img[..., 3] = 255
    return Image.fromarray(img, "RGBA")


class Canvas:
    """한 프레임을 4 배 해상도로 그린다. R(밝기)·G(물막)·A(덮임) 를 따로 그린 뒤 합친다."""

    def __init__(self):
        self.a = Image.new("L", (FW * SS, FH * SS), 0)
        self.l = Image.new("L", (FW * SS, FH * SS), 0)
        self.da = ImageDraw.Draw(self.a)
        self.dl = ImageDraw.Draw(self.l)

    @staticmethod
    def P(x, y):
        return (x * SS, y * SS)

    def poly(self, pts, alpha, light):
        pts = [self.P(*p) for p in pts]
        self.da.polygon(pts, fill=int(255 * alpha))
        self.dl.polygon(pts, fill=int(255 * light))

    def line(self, p, q, width, alpha, light):
        wdt = max(1, int(round(width * SS)))
        self.da.line([self.P(*p), self.P(*q)], fill=int(255 * alpha), width=wdt)
        self.dl.line([self.P(*p), self.P(*q)], fill=int(255 * light), width=wdt)

    def dot(self, x, y, rad, alpha, light):
        box = [*self.P(x - rad, y - rad), *self.P(x + rad, y + rad)]
        self.da.ellipse(box, fill=int(255 * alpha))
        self.dl.ellipse(box, fill=int(255 * light))

    def result(self):
        a = np.asarray(self.a.resize((FW, FH), Image.LANCZOS)).astype(np.float32) / 255
        l = np.asarray(self.l.resize((FW, FH), Image.LANCZOS)).astype(np.float32) / 255
        # 밝기는 덮인 만큼으로 나눠서 가장자리 반투명 픽셀이 어두워지지 않게 한다
        l = np.where(a > 1e-3, np.clip(l / np.maximum(a, 1e-3), 0, 1), 0)
        return a, l


def make_splash_frames():
    rng = np.random.default_rng(5)
    w = REF_W
    # 입자 표는 한 번만 뽑는다 → 모든 프레임이 같은 입자를 다른 나이로 그린다(루프가 이어진다)
    drops = []
    for i in range(18):
        drops.append(dict(
            dirn=-1 if i % 2 else 1,
            reach=w * rng.uniform(0.6, 1.6),
            peak=w * rng.uniform(0.35, 0.95),
            phase=rng.uniform(0, 1),
            life=rng.uniform(0.45, 0.85),     # 한 주기 중 날아다니는 비율
            ln=rng.uniform(4.5, 12.0),
            rad=rng.uniform(1.0, 2.1),
            light=rng.uniform(0.75, 1.0),
        ))
    spray = []
    for i in range(34):
        spray.append(dict(
            ang=rng.uniform(-np.pi * 0.95, -np.pi * 0.05),
            dist=w * rng.uniform(0.45, 1.35),
            phase=rng.uniform(0, 1),
            life=rng.uniform(0.25, 0.5),
            rad=rng.uniform(0.5, 1.0),
        ))
    crown_phase = rng.uniform(0, 1, size=(2, 3))

    YY, XX = np.mgrid[0:FH, 0:FW].astype(np.float32)
    bubble_a = periodic_noise(FH, FW, 64, 192, 21)
    bubble_b = periodic_noise(FH, FW, 64, 192, 22)
    frames = []
    for f in range(FRAMES):
        t = f / FRAMES
        cv = Canvas()

        # 1) 왕관 물막: 착수점 양옆으로 휘어 오르는 얇은 막 세 겹. 높이가 주기적으로 숨쉰다.
        for si, s in enumerate((-1, 1)):
            for layer in range(3):
                breathe = 0.78 + 0.22 * np.sin(2 * np.pi * (t + crown_phase[si, layer]))
                n = 16
                pts = []
                for j in range(n + 1):
                    k = j / n
                    x = CX + s * (w * (0.42 + 0.08 * layer) + k * w * (0.55 - 0.1 * layer))
                    y = GY - 1 - (k * (1.5 - k)) * w * (0.55 - 0.12 * layer) * breathe
                    pts.append((x, y, k))
                for j in range(n):
                    (x1, y1, k1), (x2, y2, _) = pts[j], pts[j + 1]
                    cv.line((x1, y1), (x2, y2), (2.6 - 2.0 * k1) * (1 - 0.25 * layer),
                            (1 - 0.75 * k1) * (1 - 0.3 * layer), 0.9 - 0.15 * layer)

        # 2) 눈물 모양 물방울: 포물선을 따라 날고, 머리는 둥글고 꼬리는 속도 반대쪽으로 뾰족
        for d in drops:
            age = ((t + d["phase"]) % 1.0) / d["life"]
            if age >= 1.0:
                continue
            a = 0.12 + 0.86 * age
            hx = CX + d["dirn"] * (w * 0.5 + a * d["reach"])
            hy = GY - 4 * d["peak"] * a * (1 - a)
            vx = d["dirn"] * d["reach"]; vy = -4 * d["peak"] * (1 - 2 * a)
            nrm = (vx * vx + vy * vy) ** 0.5 + 1e-6
            ux, uy = vx / nrm, vy / nrm
            tx, ty = hx - ux * d["ln"], hy - uy * d["ln"]
            nx, ny = -uy * d["rad"], ux * d["rad"]
            fade = min(1.0, age / 0.08) * (1.0 - max(0.0, (age - 0.85) / 0.15))
            cv.poly([(tx, ty), (hx + nx, hy + ny), (hx - nx, hy - ny)], 0.7 * fade, d["light"])
            cv.dot(hx, hy, d["rad"], fade, d["light"])

        # 3) 잔 물보라 점: 짧게 튀었다 사라진다
        for p in spray:
            age = ((t + p["phase"]) % 1.0) / p["life"]
            if age >= 1.0:
                continue
            r = p["dist"] * (0.35 + 0.65 * age)
            px = CX + np.cos(p["ang"]) * r
            py = GY - 2 + np.sin(p["ang"]) * r * 0.55 + 18 * age * age
            cv.dot(px, py, p["rad"], 0.9 * (1 - age), 0.8)

        a, l = cv.result()
        g = np.zeros_like(a)

        # 4) 잔거품: 낮고 납작한 띠. 두 노이즈를 주기로 섞어서 한 바퀴 뒤 원래대로 돌아온다
        mix = np.sin(np.pi * t) ** 2
        bub = bubble_a * (1 - mix) + bubble_b * mix
        fe = np.exp(-(((XX - CX) / (w * 0.58)) ** 2 + ((YY - GY + 3) / 5.0) ** 2) ** 1.4)
        fe = np.clip(fe * (0.35 + 0.9 * (bub > 0.45) * bub), 0, 1) * (YY < GY + 1)
        fl = 0.35 + 0.5 * bub
        l = np.where(fe > a, fl, l); a = np.maximum(a, fe)

        # 5) 바닥 물막(물 몸통 색) + 윗면 반사 한 줄 + 바깥으로 번지는 잔물결 두 줄
        spread = np.clip(1 - np.abs(XX - CX) / (w * 2.6), 0, 1) ** 0.6
        film = ((YY >= GY - 3) & (YY < GY + 1)) * spread * 0.85
        new_a = film + a * (1 - film)
        g = np.where(new_a > 1e-3, film / np.maximum(new_a, 1e-3), 0)
        a = new_a
        hl = spread * (YY == GY - 3) * 0.75
        for k in range(2):
            rad = w * (0.9 + 1.4 * ((t + k * 0.5) % 1.0))
            fade = 1 - ((t + k * 0.5) % 1.0)
            ring = np.clip(1.6 - np.abs(np.abs(XX - CX) - rad), 0, 1) * (YY == GY - 4) * 0.55 * fade
            hl = np.maximum(hl, ring)
        # 반사선은 가장 밝게, 물막 위에 얹는다
        l = np.where(hl > 0.05, 1.0, l); g = np.where(hl > 0.05, g * (1 - hl), g)
        a = np.maximum(a, hl)

        frames.append((l, g, a))
    return frames


def pack_sheet(frames):
    rows = FRAMES // COLS
    sheet = np.zeros((FH * rows, FW * COLS, 4), np.uint8)
    for i, (l, g, a) in enumerate(frames):
        y0 = (i // COLS) * FH; x0 = (i % COLS) * FW
        sheet[y0:y0 + FH, x0:x0 + FW, 0] = (l * 255).astype(np.uint8)
        sheet[y0:y0 + FH, x0:x0 + FW, 1] = (np.clip(g, 0, 1) * 255).astype(np.uint8)
        sheet[y0:y0 + FH, x0:x0 + FW, 3] = (np.clip(a, 0, 1) * 255).astype(np.uint8)
    return Image.fromarray(sheet, "RGBA")


def preview(frames, folder):
    # 확인용: 검정·회색·흰 세 색으로 입힌 프레임을 어두운 벽색 위에 2 배로 늘어놓는다
    tones = {"black": (45, 140, 10), "gray": (150, 225, 128), "white": (190, 222, 232)}
    rows = []
    for lo, hi, body in tones.values():
        row = []
        for l, g, a in frames[::2]:
            col = lo + (hi - lo) * l
            col = col * (1 - g) + body * g
            out = 38 * (1 - a) + col * a
            row.append(out[40:, 60:324])
        rows.append(np.concatenate(row, axis=1))
    img = Image.fromarray(np.concatenate(rows, axis=0).clip(0, 255).astype(np.uint8))
    img = img.resize((img.width * 2 // 2, img.height * 2 // 2), Image.NEAREST)
    img.save(os.path.join(folder, "splash_v3_프레임_미리보기.png"))


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    make_flow().save(os.path.join(OUT_DIR, "flow_v3.png"))
    frames = make_splash_frames()
    pack_sheet(frames).save(os.path.join(OUT_DIR, "splash_v3_sheet.png"))
    print("flow_v3.png / splash_v3_sheet.png ->", OUT_DIR)
    if "--미리보기" in sys.argv:
        folder = sys.argv[sys.argv.index("--미리보기") + 1]
        os.makedirs(folder, exist_ok=True)
        preview(frames, folder)
        print("미리보기 ->", folder)


if __name__ == "__main__":
    main()
