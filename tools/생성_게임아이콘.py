# -*- coding: utf-8 -*-
"""
게임 아이콘(Gray.exe · 창 · 작업 표시줄) 만들기 — 2026-10-10 Claude

  python -X utf8 tools/생성_게임아이콘.py

▣ 그림
  주인공(물감통 머리 · 검정 몸) 을 **흰 종이 | 먹** 으로 반씩 나눈 배경 위에 둔다 — "내 색과 다르면 죽는다" 는 흑백 규칙.
  몸이 검정이라 먹 쪽에 묻히므로 회색 띠 + 옅은 빛으로 테두리를 둘러 양쪽 모두에서 읽히게 한다.
  원본 캐릭터 그림(assets/characters/paint_head_a/black_idle.png 첫 칸)은 읽기만 한다.

▣ 크기마다 다른 그림
  256·128 = 상반신(물감총까지) · 64 이하 = 머리만 크게. 16·32px 에서 상반신은 뭉개져 무엇인지 안 읽혔다(시안 비교).

▣ 결과
  assets/icon/gray_icon.ico  — 내보내기 프리셋 `application/icon`(exe 아이콘) · `windows_native_icon`
  assets/icon/gray_icon.png  — 1024 상반신판 · 프로젝트 `config/icon`(실행 중 창 아이콘)
  멱등: 매번 원본에서 새로 그린다(난수 씨앗 고정).
"""
import math
import os
import random

from PIL import Image, ImageChops, ImageDraw, ImageFilter

저장소 = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
원본 = os.path.join(저장소, "assets", "characters", "paint_head_a", "black_idle.png")
폴더 = os.path.join(저장소, "assets", "icon")
N = 1024


def 배경() -> Image.Image:
    random.seed(7)
    먹 = Image.new("RGBA", (N, N), (20, 20, 20, 255))
    종이 = Image.new("RGBA", (N, N), (232, 229, 222, 255))
    # 붓으로 그은 듯 살짝 흔들리는 세로 경계(가운데)
    m = Image.new("L", (N, N), 0)
    점 = [(0, 0)]
    for y in range(0, N + 1, 16):
        점.append((N * 0.5 + math.sin(y * 0.009) * 10 + random.uniform(-5, 5), y))
    점.append((0, N))
    ImageDraw.Draw(m).polygon(점, fill=255)
    bg = Image.composite(종이, 먹, m.filter(ImageFilter.GaussianBlur(2.5)))
    # 아주 옅은 결(밋밋한 평면색 방지)
    결 = Image.effect_noise((N, N), 18).convert("L")
    return Image.blend(bg, Image.merge("RGBA", [결, 결, 결, Image.new("L", (N, N), 255)]), 0.06)


def 아이콘(자르기, 배율, 위치, 띠) -> Image.Image:
    bg = 배경()
    칸 = Image.open(원본).crop((0, 0, 640, 640))     # 대기 시트 첫 칸(640 격자)
    W = int((자르기[2] - 자르기[0]) * 배율)
    H = int((자르기[3] - 자르기[1]) * 배율)
    몸 = 칸.crop(자르기).resize((W, H), Image.LANCZOS)
    알파 = 몸.split()[3]
    테 = 알파.filter(ImageFilter.MaxFilter(띠))
    빛 = 테.filter(ImageFilter.GaussianBlur(14))
    off = 위치(W, H)
    판 = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    g = Image.new("RGBA", (W, H), (150, 148, 144, 0))
    g.putalpha(빛.point(lambda v: int(v * 0.55)))
    판.alpha_composite(g, off)
    r = Image.new("RGBA", (W, H), (128, 126, 122, 0))
    r.putalpha(테)
    판.alpha_composite(r, off)
    판.alpha_composite(몸, off)
    bg.alpha_composite(판)
    # 둥근 사각(2배로 그려 줄여 가장자리를 매끈하게)
    틀 = Image.new("L", (N * 2, N * 2), 0)
    ImageDraw.Draw(틀).rounded_rectangle((0, 0, N * 2 - 1, N * 2 - 1), radius=int(N * 2 * 0.18), fill=255)
    bg.putalpha(ImageChops.multiply(bg.split()[3], 틀.resize((N, N), Image.LANCZOS)))
    return bg


def main():
    os.makedirs(폴더, exist_ok=True)
    큰 = 아이콘((140, 40, 500, 470), 2.15, lambda W, H: ((N - W) // 2 + 8, N - H + 40), 21)
    작은 = 아이콘((195, 45, 415, 290), 3.9, lambda W, H: ((N - W) // 2 + 10, (N - H) // 2 + 40), 41)
    큰.save(os.path.join(폴더, "gray_icon.png"))
    크기들 = [(256, 큰), (128, 큰), (64, 작은), (48, 작은), (32, 작은), (24, 작은), (16, 작은)]
    판들 = [그림.resize((s, s), Image.LANCZOS) for s, 그림 in 크기들]
    판들[0].save(os.path.join(폴더, "gray_icon.ico"), format="ICO",
               sizes=[(s, s) for s, _ in 크기들], append_images=판들[1:])
    print("저장:", os.path.join(폴더, "gray_icon.ico"), "·", os.path.join(폴더, "gray_icon.png"))


if __name__ == "__main__":
    main()
