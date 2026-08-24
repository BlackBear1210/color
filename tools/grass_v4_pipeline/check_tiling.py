# STEP 6 — 반복 패턴 / 이음매 객관 검사.
#
# 눈으로 "보이는 것 같다" 가 아니라 수치로 판정한다.
#
# 1) 좌우 이음매(seam)
#    텍스처는 U 방향으로 반복되므로 마지막 열과 첫 열이 이어져야 한다.
#    [판정] 이음매에서의 열간 차이가 내부 인접 열들의 평균 차이와 비슷하면 안 보이는 것이다.
#    비율 = 이음매차이 / 내부평균차이.  1.0 근처면 PASS, 2.0 넘으면 눈에 띈다.
#
# 2) 내부 반복 모티프
#    텍스처 자체가 절반씩 똑같이 그려졌으면(예: 2x2 모티프) 자기상관이 512 지점에서 튄다.
#    [판정] 정규화 자기상관의 0이 아닌 최대 피크가 0.5 미만이면 반복이 두드러지지 않는다.

import os
# 저장소 안에서 경로를 스스로 찾는다 (다른 PC/노트북에서도 그대로 돌아가야 한다).
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
import numpy as np
from PIL import Image

ROOT = os.path.join(REPO, "assets", "textures", "smartshape", "grass_v4")


def seam_ratio(a, axis):
    """axis=1 이면 좌우, axis=0 이면 상하."""
    if axis == 1:
        interior = np.abs(np.diff(a, axis=1)).mean()
        seam = np.abs(a[:, 0] - a[:, -1]).mean()
    else:
        interior = np.abs(np.diff(a, axis=0)).mean()
        seam = np.abs(a[0, :] - a[-1, :]).mean()
    return seam / max(interior, 1e-6), seam, interior


def autocorr_peak(sig):
    """평균 제거 후 순환 자기상관.

    ★짧은 lag 는 반드시 제외한다. lag 16 같은 곳의 높은 값은 '반복 모티프' 가 아니라
    그냥 이웃 픽셀이 비슷하다는 뜻(국소 부드러움)이라 판정에 쓰면 안 된다.
    모티프 반복이라면 텍스처 크기의 1/8 이상 되는 lag 에서 피크가 나야 한다.
    특히 N/2, N/4 는 '절반씩 같은 그림' 인 경우를 잡는 자리라 따로 본다.
    """
    s = sig - sig.mean()
    n = len(s)
    f = np.fft.rfft(s, n * 2)
    ac = np.fft.irfft(f * np.conj(f))[:n]
    ac /= ac[0] if ac[0] != 0 else 1.0
    lo = n // 8
    idx = int(np.argmax(ac[lo:n // 2])) + lo
    return ac[idx], idx, ac[n // 4], ac[n // 2]


print("=" * 84)
print("1) 좌우/상하 이음매 검사   (비율 1.0 근처 = 안 보임, 2.0 초과 = 눈에 띔)")
print("=" * 84)
for theme in ("black", "white"):
    for n, ax, lbl in [("grass_edge_top", 1, "좌우"), ("grass_edge_bottom", 1, "좌우"),
                       ("grass_edge_left", 1, "좌우"), ("grass_edge_right", 1, "좌우"),
                       ("grass_fill_detail", 1, "좌우"), ("grass_fill_detail", 0, "상하"),
                       ("grass_fill_solid", 1, "좌우"), ("grass_fill_solid", 0, "상하")]:
        p = os.path.join(ROOT, theme, n + ".png")
        im = Image.open(p)
        a = np.asarray(im.convert("RGBA")).astype(np.float64)
        # 엣지는 알파를 곱한 상태(=실제로 보이는 모습)로 재야 의미가 있다
        v = a[..., 0] * (a[..., 3] / 255.0) if im.mode == "RGBA" else a[..., 0]
        r, s, i = seam_ratio(v, ax)
        # 판정은 두 기준 중 하나만 만족하면 PASS 다.
        #  (a) 비율 <= 2.0            : 이음매가 내부 변화에 묻힌다
        #  (b) 절대 차이 < 1.0 / 255  : 0.4% 미만이라 애초에 지각 한계 아래다
        #      (필 solid 처럼 내부가 거의 평평하면 비율은 쉽게 커지지만 눈에는 안 보인다)
        ok = (r <= 2.0) or (s < 1.0)
        why = "" if r <= 2.0 else ("  <- 절대차 %.2f/255 로 지각한계 이하" % s if ok else "")
        print("  %-6s %-20s %s  비율 %5.2f  (이음매 %5.3f / 내부 %5.3f)  %s%s"
              % (theme, n, lbl, r, s, i, "PASS" if ok else "FAIL", why))

print()
print("=" * 84)
print("2) 내부 반복 모티프 검사   (자기상관 피크 0.5 미만 = 반복 두드러지지 않음)")
print("=" * 84)
for theme in ("black",):     # 흰색은 검정의 정확한 반전이라 결과가 동일하다
    for n in ("grass_edge_top", "grass_edge_bottom", "grass_edge_left",
              "grass_fill_detail", "grass_fill_solid"):
        p = os.path.join(ROOT, theme, n + ".png")
        im = Image.open(p)
        a = np.asarray(im.convert("RGBA")).astype(np.float64)
        v = a[..., 0] * (a[..., 3] / 255.0) if im.mode == "RGBA" else a[..., 0]
        colmean = v.mean(axis=0)                    # 가로 방향 신호
        pk, lag, q4, q2 = autocorr_peak(colmean)
        mark = "PASS" if pk < 0.5 else "주의"
        print("  %-20s 가로: 최대피크 %5.2f @ lag %4d/%4d   N/4 %5.2f  N/2 %5.2f   %s"
              % (n, pk, lag, len(colmean), q4, q2, mark))
        if n.startswith("grass_fill"):
            rowmean = v.mean(axis=1)
            pk2, lag2, q4b, q2b = autocorr_peak(rowmean)
            mark2 = "PASS" if pk2 < 0.5 else "주의"
            print("  %-20s 세로: 최대피크 %5.2f @ lag %4d/%4d   N/4 %5.2f  N/2 %5.2f   %s"
                  % ("", pk2, lag2, len(rowmean), q4b, q2b, mark2))
