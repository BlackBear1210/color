# grass_v4 현재 휘도 분포 실측.
#
# 왜 알파 가중인가: 엣지 텍스처는 위쪽 절반이 잔디 술이라 알파가 0~1 사이다.
# 단순 평균을 내면 투명한 배경(=0)이 섞여 "실제로 화면에 보이는 밝기" 와 달라진다.
# 그래서 알파를 가중치로 써서 '실제로 보이는 픽셀의 평균' 을 낸다.

import os
# 저장소 안에서 경로를 스스로 찾는다 (다른 PC/노트북에서도 그대로 돌아가야 한다).
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
import numpy as np
from PIL import Image

ROOT = os.path.join(REPO, "assets", "textures", "smartshape", "grass_v4")
EDGES = ["grass_edge_top", "grass_edge_bottom", "grass_edge_left", "grass_edge_right",
         "grass_corner_outer", "grass_corner_inner"]
FILLS = ["grass_fill_detail", "grass_fill_solid"]


def stats(path, use_alpha):
    a = np.asarray(Image.open(path).convert("RGBA")).astype(np.float64)
    lum = a[..., 0]                       # 이미 순수 그레이스케일이라 R 채널이 곧 휘도
    if use_alpha:
        w = a[..., 3] / 255.0
        m = w > 0.5                       # 실제로 보이는 픽셀만
        if m.sum() == 0:
            return None
        v = lum[m]
    else:
        v = lum.ravel()
    return {
        "mean": v.mean(), "min": v.min(), "max": v.max(),
        "p05": np.percentile(v, 5), "p25": np.percentile(v, 25),
        "p50": np.percentile(v, 50), "p75": np.percentile(v, 75),
        "p95": np.percentile(v, 95), "n": v.size,
        # 하이라이트 = 상위 5% 가 차지하는 밝기, 암부 = 하위 5%
    }


for theme in ("black", "white"):
    print("=" * 78)
    print("[%s]" % theme)
    all_v = []
    for n in EDGES:
        p = os.path.join(ROOT, theme, n + ".png")
        if not os.path.exists(p):
            continue
        s = stats(p, True)
        print("  %-20s mean %6.1f   min %5.1f  max %5.1f   p05 %5.1f  p50 %5.1f  p95 %5.1f"
              % (n, s["mean"], s["min"], s["max"], s["p05"], s["p50"], s["p95"]))
        a = np.asarray(Image.open(p).convert("RGBA")).astype(np.float64)
        all_v.append(a[..., 0][a[..., 3] > 127])
    for n in FILLS:
        p = os.path.join(ROOT, theme, n + ".png")
        s = stats(p, False)
        print("  %-20s mean %6.1f   min %5.1f  max %5.1f   p05 %5.1f  p50 %5.1f  p95 %5.1f"
              % (n, s["mean"], s["min"], s["max"], s["p05"], s["p50"], s["p95"]))
        if n == "grass_fill_detail":
            all_v.append(np.asarray(Image.open(p).convert("RGB")).astype(np.float64)[..., 0].ravel())

    v = np.concatenate(all_v)
    print("  " + "-" * 74)
    print("  ▣ 테마 전체   mean %6.2f   p01 %5.1f  p05 %5.1f  p50 %5.1f  p95 %5.1f  p99 %5.1f"
          % (v.mean(), np.percentile(v, 1), np.percentile(v, 5), np.percentile(v, 50),
             np.percentile(v, 95), np.percentile(v, 99)))
    # 히스토그램(16 구간)
    h, _ = np.histogram(v, bins=16, range=(0, 256))
    h = h / h.sum() * 100
    print("  ▣ 분포(16구간, %):")
    print("     " + " ".join("%4.1f" % x for x in h))
    print("       0   16   32   48   64   80   96  112  128  144  160  176  192  208  224  240")
