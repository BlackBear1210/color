# 대비 후보 테스트 시트.
#
# 방식: 감마 곡선 y = x^g 만 쓴다.
#   - 단조증가라 픽셀의 밝기 '순서' 가 절대 안 바뀐다 = 구조 보존
#   - 알파는 전혀 안 건드린다
#   - 해상도/크롭 변경 없음
#   - 흑백 대응: 검정에만 곡선을 걸고 흰색 = 255 - 검정 으로 만든다 -> 구조 대칭이 수식으로 보장
#
# 감마 g > 1 이면 어두워진다. 몸통(현재 63 근처)이 크게 내려가고
# 하이라이트(98~141)는 상대적으로 덜 내려가서 국소 대비는 오히려 커진다.

import os
# 저장소 안에서 경로를 스스로 찾는다 (다른 PC/노트북에서도 그대로 돌아가야 한다).
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.join(REPO, "assets", "textures", "smartshape", "grass_v4")
OUT = HERE

LEVELS = [("현재", 1.00), ("A 약", 1.35), ("B 중", 1.60), ("C 강", 1.90)]


def load(theme, name):
    return np.asarray(Image.open(os.path.join(ROOT, theme, name + ".png")).convert("RGBA")).astype(np.float64)


def gamma(lum, g):
    return np.clip(np.power(np.clip(lum, 0, 255) / 255.0, g) * 255.0, 0, 255)


# 흰색이 정말 검정의 정확한 반전인지 먼저 확인한다 (아니면 대칭 가정이 깨진다)
b = load("black", "grass_edge_top")
w = load("white", "grass_edge_top")
diff = np.abs((255.0 - b[..., 0]) - w[..., 0])
print("white == 255 - black 검증: 최대 오차 %.1f / 255  (평균 %.2f)" % (diff.max(), diff.mean()))
print()

# --- 합성 미리보기: TOP 엣지를 FILL 위에 얹어 실제 지형 표면처럼 보이게 한다 ---
top_b = load("black", "grass_edge_top")
fill_b = np.asarray(Image.open(os.path.join(ROOT, "black", "grass_fill_detail.png")).convert("RGB")).astype(np.float64)

CW, CH = 560, 256          # 미리보기 한 칸 크기
fill_crop = fill_b[0:CH, 0:CW, 0]
top_crop = top_b[0:CH, 0:CW]

rows = []
stats_txt = []
for name, g in LEVELS:
    # 검정 테마
    fb = gamma(fill_crop, g)
    tb_l = gamma(top_crop[..., 0], g)
    ta = top_crop[..., 3] / 255.0
    comp_b = tb_l * ta + fb * (1.0 - ta)
    # 흰색 테마 = 255 - 검정
    comp_w = 255.0 - comp_b

    # 실제 텍스처 전체에 대한 평균도 같이 계산 (미리보기 크롭이 아니라 전체 기준)
    all_b = []
    for n in ("grass_edge_top", "grass_edge_bottom", "grass_edge_left", "grass_edge_right",
              "grass_corner_outer", "grass_corner_inner"):
        a = load("black", n)
        all_b.append(a[..., 0][a[..., 3] > 127])
    a = np.asarray(Image.open(os.path.join(ROOT, "black", "grass_fill_detail.png")).convert("RGB")).astype(np.float64)
    all_b.append(a[..., 0].ravel())
    v = gamma(np.concatenate(all_b), g)
    stats_txt.append("%-5s g=%.2f   BLACK mean %5.1f (p05 %4.1f p50 %4.1f p95 %5.1f)   WHITE mean %5.1f   대비폭 %5.1f"
                     % (name, g, v.mean(), np.percentile(v, 5), np.percentile(v, 50), np.percentile(v, 95),
                        255 - v.mean(), 255 - 2 * v.mean()))
    rows.append((name, g, comp_b, comp_w))

for s in stats_txt:
    print(s)

# --- 시트 그리기 ---
pad, lab = 10, 30
sheet = Image.new("RGB", (2 * CW + 3 * pad, len(rows) * (CH + lab + pad) + pad + 34), (18, 19, 22))
d = ImageDraw.Draw(sheet)
d.text((pad, 8), "왼쪽 = BLACK 테마(밝은 배경 위)      오른쪽 = WHITE 테마(어두운 배경 위)", fill=(200, 200, 210))
for i, (name, g, cb, cw) in enumerate(rows):
    y = 34 + pad + i * (CH + lab + pad)
    d.text((pad, y), "%s  (gamma %.2f)" % (name, g), fill=(150, 230, 150))
    # 검정 테마는 밝은 배경 위에
    bgb = Image.new("RGB", (CW, CH), (168, 172, 178))
    bgb.paste(Image.fromarray(np.dstack([cb] * 3).astype(np.uint8)), (0, 0))
    sheet.paste(bgb, (pad, y + lab))
    # 흰색 테마는 어두운 배경 위에
    bgw = Image.new("RGB", (CW, CH), (26, 28, 33))
    bgw.paste(Image.fromarray(np.dstack([cw] * 3).astype(np.uint8)), (0, 0))
    sheet.paste(bgw, (2 * pad + CW, y + lab))

sheet.save(os.path.join(OUT, "대비_테스트시트.png"))
print("\n시트 저장:", sheet.size)
