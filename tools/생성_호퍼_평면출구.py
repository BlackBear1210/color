# -*- coding: utf-8 -*-
"""주철 호퍼 아틀라스 → 평면 출구판 굽기 (엔진 없이 PNG 를 만든다).

왜:
  원화 직하 노즐은 끝이 아래에서 올려다본 **둥근 입구(타원)** 라 안쪽 검은 구멍이 보인다.
  이 게임의 지형·발판·배관은 전부 **정면 옆모습**이라 노즐만 시점이 어긋났고, 물이 그 구멍에서
  나오지 않고 관 아래 허공에서 시작하는 것처럼 보였다(2026-09-27 도형님 결정: 평면 출구).

어떻게 (새로 그리지 않고 원화 재질만 쓴다 — 따로 붙인 판때기처럼 안 보이게):
  · 관 몸통(y 591~686)은 원화 그대로.
  · 둥근 입구 자리(y 687~)를 **깔때기 아랫단 띠**(y 577~590: 금속 → 밝은 경사 모서리 → 검은 외곽선)로
    마감한다. 관보다 좌우 4px 넓게 → 관 끝 테두리. 튀어나온 부분에는 원화처럼 검은 외곽선.
  · 그 아래(둥근 입구의 나머지)는 투명으로 지운다.
  · 좌하·우하 칸(1·2)은 손대지 않는다(곡선 출수는 이번 범위 밖).

원본 hopper_atlas.png 는 그대로 두고 hopper_atlas_flat.png 를 새로 쓴다.
항상 원본에서 다시 계산하므로 몇 번 돌려도 결과가 같다(멱등).

좌표(아틀라스 px, 칸 0) — 2026-09-27 원화 실측:
  관 바깥 x 208~304 · 관 안지름 약 80 (= 호퍼 폭 400 기준 → 폭 × 0.2)
  ⚠ 안지름을 바꾸면 scripts/스마트월드/호퍼_주철.gd 의 `노즐_안지름_비율` 도 같이 바꿀 것.

사용:
  python tools/생성_호퍼_평면출구.py                  # 굽는다
  python tools/생성_호퍼_평면출구.py --미리보기 <폴더>   # 굽고, 전/후 비교 그림도 둔다
"""
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIR = os.path.join(ROOT, "assets", "textures", "obstacles", "hopper", "cast_iron_v1")
SRC = os.path.join(DIR, "hopper_atlas.png")
OUT = os.path.join(DIR, "hopper_atlas_flat.png")

BAND_Y0, BAND_Y1 = 577, 591          # 깔때기 아랫단 띠(리벳 아래부터 — 위로 올리면 리벳 반쪽이 딸려 온다)
BAND_X0, BAND_X1 = 196, 316          # 띠의 가로로 곧은 부분(끝의 비스듬한 모서리는 뺀다)
PIPE_X0, PIPE_X1 = 208, 305          # 관 바깥(끝 포함 +1)
RIM_Y0 = 687                         # 둥근 입구가 시작하던 줄 = 관 끝 테두리 시작
CLEAR_X0, CLEAR_X1 = 150, 362        # 둥근 입구 잔여를 지울 가로 범위
OUTLINE = (6, 6, 6, 255)


def build():
    atlas = Image.open(SRC).convert("RGBA")
    a = np.asarray(atlas).copy()
    rim_x0, rim_x1 = PIPE_X0 - 4, PIPE_X1 + 4
    band = atlas.crop((BAND_X0, BAND_Y0, BAND_X1, BAND_Y1)).resize((rim_x1 - rim_x0, BAND_Y1 - BAND_Y0), Image.LANCZOS)
    band = np.asarray(band).copy()
    band[..., 3] = 255
    rim_y1 = RIM_Y0 + band.shape[0]
    # 1) 둥근 입구 자리를 지운다(투명)
    a[RIM_Y0:720, CLEAR_X0:CLEAR_X1, 3] = 0
    # 2) 관 끝 테두리 = 깔때기 아랫단 띠
    a[RIM_Y0:rim_y1, rim_x0:rim_x1] = band
    # 3) 외곽선: 원화 관 옆선이 5~7px 이라 같은 두께(OL)로 두른다.
    #    테두리를 바깥으로 OL 만큼 넓히고, 윗선(관 밖 부분)·옆선·아랫선을 검게 — 띠 자체의 아랫선(3px)에 더해진다.
    OL = 5
    a[RIM_Y0:rim_y1 + OL - 3, rim_x0 - OL:rim_x0] = OUTLINE
    a[RIM_Y0:rim_y1 + OL - 3, rim_x1:rim_x1 + OL] = OUTLINE
    a[RIM_Y0 - 1:RIM_Y0 + 2, rim_x0 - OL:PIPE_X0 + 2] = OUTLINE
    a[RIM_Y0 - 1:RIM_Y0 + 2, PIPE_X1 - 2:rim_x1 + OL] = OUTLINE
    a[rim_y1:rim_y1 + OL - 3, rim_x0 - OL:rim_x1 + OL] = OUTLINE
    out = Image.fromarray(a, "RGBA")
    out.save(OUT)
    return atlas, out


def preview(before, after, folder):
    box = (140, 520, 372, 724)
    def on_gray(im):
        c = im.crop(box)
        bg = Image.new("RGBA", c.size, (70, 70, 70, 255)); bg.alpha_composite(c)
        return bg.convert("RGB").resize((c.width * 3, c.height * 3), Image.NEAREST)
    b, f = on_gray(before), on_gray(after)
    sheet = Image.new("RGB", (b.width * 2 + 12, b.height), (18, 18, 20))
    sheet.paste(b, (0, 0)); sheet.paste(f, (b.width + 12, 0))
    sheet.save(os.path.join(folder, "호퍼_평면출구_아틀라스_전후.png"))


def main():
    before, after = build()
    print("->", OUT)
    if "--미리보기" in sys.argv:
        folder = sys.argv[sys.argv.index("--미리보기") + 1]
        os.makedirs(folder, exist_ok=True)
        preview(before, after, folder)
        print("미리보기 ->", folder)


if __name__ == "__main__":
    main()
