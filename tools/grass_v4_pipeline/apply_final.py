# grass_v4 최종 파이프라인 (통합 · 멱등).
#
# 지금까지 따로 돌리던 soften_inner / fix_fill_tone / make_corners 를 하나로 합쳤다.
# 항상 D: 의 원본에서 다시 계산하므로 몇 번을 돌려도 결과가 같다 (CLAUDE.md 규칙 5).
#
# 순서:
#   1) 검정 테마 엣지 : 원본 -> 알파 바닥 제거 -> 감마(대비) -> 안쪽 알파 페이드
#   2) 검정 테마 필   : 원본 -> 감마 -> 엣지 안쪽 톤에 평균 맞추기 -> solid 파생
#   3) 검정 테마 코너 : 위에서 만든 엣지로부터 극좌표 합성 (이음매 단면이 수식으로 일치)
#   4) 흰색 테마      : 검정 결과의 휘도를 그대로 반전 (알파는 복사)
#      -> "흑백 구조 대응" 이 수식으로 보장된다. 흰색을 따로 처리하지 않는다.
#
# 감마만 쓰는 이유:
#   y = x^g 는 단조증가라 픽셀 밝기 '순서' 가 절대 안 바뀐다 = 구조 보존.
#   클리핑이 없어 하이라이트도 안 날아간다. 알파/해상도/크롭은 전혀 안 건드린다.

import os
# 저장소 안에서 경로를 스스로 찾는다 (다른 PC/노트북에서도 그대로 돌아가야 한다).
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
import numpy as np
from PIL import Image, ImageFilter

SRC = os.path.join(HERE, "src")
ROOT = os.path.join(REPO, "assets", "textures", "smartshape", "grass_v4")

GAMMA = 1.60      # 대비 단계 B — 테스트 시트에서 확정
FADE = 0.22       # 엣지 안쪽 알파 페이드 구간 비율
FLOOR = 0.06      # 리샘플 잔여 알파 제거 임계
S = 256           # 코너 텍스처 한 변

# (프로젝트 파일명, D: 원본 꼬리, 좌우반전)
EDGE_MAP = [
    ("grass_edge_top",     "grass_top_B_1024x256.png",  False),
    ("grass_edge_top_alt", "grass_top_A_1024x256.png",  False),
    ("grass_edge_bottom",  "grass_bottom_1024x192.png", False),
    ("grass_edge_left",    "grass_side_1024x256.png",   False),
    ("grass_edge_right",   "grass_side_1024x256.png",   True),
]
EDGES_FOR_TONE = ["grass_edge_top", "grass_edge_bottom", "grass_edge_left", "grass_edge_right"]


def gamma(lum):
    return np.clip(np.power(np.clip(lum, 0, 255) / 255.0, GAMMA) * 255.0, 0, 255)


# ------------------------------------------------------------------ 1) 엣지
def build_edges():
    print("1) 검정 엣지")
    for proj, tail, mirror in EDGE_MAP:
        im = Image.open(os.path.join(SRC, "black_" + tail)).convert("RGBA")
        if mirror:
            im = im.transpose(Image.FLIP_LEFT_RIGHT)
        a = np.asarray(im).astype(np.float64)

        # 알파 바닥 제거: 4K->1024 축소 링잉으로 남은 2~5% 잔여 알파가
        # 어두운 배경에서 도형 주위 사각 단차로 드러난다.
        al = np.clip((a[..., 3] / 255.0 - FLOOR) / (1.0 - FLOOR), 0.0, 1.0)

        # 대비
        lum = gamma(a[..., 0])

        # 안쪽 알파 페이드: 띠가 안쪽에서 뚝 끊기지 않고 뒤의 필로 녹아들게 한다.
        h = a.shape[0]
        n = max(1, int(round(h * FADE)))
        t = np.linspace(0.0, 1.0, n)
        ramp = 0.5 * (1.0 + np.cos(np.pi * t))     # 코사인 이징 (양 끝 기울기 0)
        mask = np.ones(h)
        mask[h - n:] = ramp
        al = al * mask[:, None]

        out = np.dstack([lum, lum, lum, np.clip(al * 255.0, 0, 255)]).astype(np.uint8)
        Image.fromarray(out, "RGBA").save(os.path.join(ROOT, "black", proj + ".png"))
        print("   %-20s %s" % (proj, (a.shape[1], a.shape[0])))


def inner_mean(path, lo=0.55, hi=0.77):
    """엣지 안쪽(페이드 시작 직전) 구간의 알파 가중 평균 휘도.
    필이 이어받아야 할 톤이 바로 이 값이다."""
    a = np.asarray(Image.open(path).convert("RGBA")).astype(np.float64)
    h = a.shape[0]
    band = a[int(h * lo):int(h * hi)]
    w = band[..., 3] / 255.0
    s = w.sum()
    return (band[..., 0] * w).sum() / s if s > 0 else 0.0


# ------------------------------------------------------------------ 2) 필
def build_fill():
    print("2) 검정 필")
    target = float(np.mean([inner_mean(os.path.join(ROOT, "black", e + ".png"))
                            for e in EDGES_FOR_TONE]))
    src = np.asarray(Image.open(os.path.join(SRC, "black_grass_fill_1024.png"))
                     .convert("RGB")).astype(np.float64)[..., 0]
    g = gamma(src)
    shift = target - g.mean()          # 감마 이후에 평균을 맞춘다
    detail = np.clip(g + shift, 0, 255)
    Image.fromarray(np.dstack([detail] * 3).astype(np.uint8)).save(
        os.path.join(ROOT, "black", "grass_fill_detail.png"))

    # solid = detail 을 강하게 흐리고 대비를 20% 로 눌러 만든다 -> 평균이 자동으로 같다.
    # ★블러는 반드시 순환(wrap)이어야 한다. PIL 의 GaussianBlur 는 가장자리를 복제 처리해서
    #   그대로 쓰면 좌우/상하 끝이 어긋나고, 타일링했을 때 격자선이 생긴다 (실측으로 잡았다).
    #   3x3 로 깔아서 흐린 뒤 가운데만 잘라내면 순환 블러가 된다.
    # 축소도 순환이어야 한다. LANCZOS 는 가장자리에서 커널이 잘려 끝 픽셀이 어긋난다.
    # 3x3 로 깔아 축소한 뒤 가운데만 잘라내면 순환 축소가 된다.
    big = np.tile(np.dstack([detail] * 3), (3, 3, 1)).astype(np.uint8)
    small_big = Image.fromarray(big).resize((S * 3, S * 3), Image.LANCZOS)
    small = Image.fromarray(np.asarray(small_big)[S:2 * S, S:2 * S])
    b = np.asarray(small).astype(np.float64)
    m = b.mean()
    tiled = np.tile(b, (3, 3, 1)).astype(np.uint8)
    blurred = np.asarray(Image.fromarray(tiled).filter(
        ImageFilter.GaussianBlur(S / 24.0))).astype(np.float64)
    blur = blurred[S:2 * S, S:2 * S]
    solid = np.clip(m + (blur - m) * 0.20, 0, 255).astype(np.uint8)
    Image.fromarray(solid).save(os.path.join(ROOT, "black", "grass_fill_solid.png"))
    print("   엣지 안쪽 목표 %.2f  ->  필 평균 %.2f (보정 %+.2f)" % (target, detail.mean(), shift))


# ------------------------------------------------------------------ 3) 코너
def sample(tex, u, v):
    h, w = tex.shape[0], tex.shape[1]
    x = (u % 1.0) * w - 0.5
    y = np.clip(v, 0.0, 1.0) * (h - 1)
    x0 = np.floor(x).astype(int); y0 = np.floor(y).astype(int)
    fx = (x - x0)[..., None]; fy = (y - y0)[..., None]
    x0m = x0 % w; x1m = (x0 + 1) % w
    y0c = np.clip(y0, 0, h - 1); y1c = np.clip(y0 + 1, 0, h - 1)
    a = tex[y0c, x0m] * (1 - fx) + tex[y0c, x1m] * fx
    b = tex[y1c, x0m] * (1 - fx) + tex[y1c, x1m] * fx
    return a * (1 - fy) + b * fy


def blend_premul(a, b, w):
    w = w[..., None]
    aa = a[..., 3:4] / 255.0; ba = b[..., 3:4] / 255.0
    outa = aa * w + ba * (1 - w)
    outpm = (a[..., :3] * aa) * w + (b[..., :3] * ba) * (1 - w)
    rgb = np.where(outa > 0.002, outpm / np.maximum(outa, 0.002), 0.0)
    out = np.zeros_like(a)
    out[..., :3] = np.clip(rgb, 0, 255)
    out[..., 3] = np.clip(outa[..., 0] * 255.0, 0, 255)
    return out


def build_corners():
    print("3) 검정 코너 (엣지에서 극좌표 합성)")
    top = np.asarray(Image.open(os.path.join(ROOT, "black", "grass_edge_top.png"))
                     .convert("RGBA")).astype(np.float64)
    side = np.asarray(Image.open(os.path.join(ROOT, "black", "grass_edge_right.png"))
                      .convert("RGBA")).astype(np.float64)
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float64)
    px, py = xx + 0.5, yy + 0.5

    for kind in ("outer", "inner"):
        if kind == "outer":
            # 중심 = UV(0,1) = 지형 안쪽 구석. 표면은 반지름 S/2 사분원.
            dx, dy = px, (S - py)
            r = np.hypot(dx, dy)
            v_eq = 1.0 - r / S
            phi = np.arctan2(dy, np.maximum(dx, 1e-6))
        else:
            # 중심 = UV(1,0) = 바깥(빈) 구석.
            dx, dy = (S - px), py
            r = np.hypot(dx, dy)
            v_eq = r / S
            phi = np.arctan2(np.maximum(dx, 1e-6), np.maximum(dy, 1e-6))

        # 각도 블렌드는 중심 근처에서 축퇴한다. smoothstep 으로 이음매에서 포화시켜
        # 왼쪽 열/아래 행에는 반대쪽 텍스처가 절대 안 섞이게 한다.
        t = np.clip((np.clip(phi / (np.pi * 0.5), 0, 1) - 0.15) / 0.70, 0.0, 1.0)
        w_top = t * t * (3.0 - 2.0 * t)

        # u 는 반드시 호 길이에 비례해야 한다 (각도 비례면 방사형으로 뭉갠다).
        # 코너 256px = 월드 90px, TOP 1024px = 월드 358px -> 코너 1px = 텍스처 1px.
        u_top = 0.31 + ((np.pi * 0.5 - phi) * r) / float(top.shape[1])
        u_side = 0.62 - (phi * r) / float(side.shape[1])

        out = blend_premul(sample(top, u_top, v_eq), sample(side, u_side, v_eq), w_top)
        if kind == "outer":
            out[..., 3] = np.where(v_eq < 0.0, 0.0, out[..., 3])
        Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA").save(
            os.path.join(ROOT, "black", "grass_corner_%s.png" % kind))
        print("   grass_corner_%s.png" % kind)


# ------------------------------------------------------------------ 4) 흰색 = 검정 반전
def build_white():
    print("4) 흰색 테마 = 검정의 휘도 반전 (알파 그대로)")
    names = [m[0] for m in EDGE_MAP] + ["grass_corner_outer", "grass_corner_inner",
                                        "grass_fill_detail", "grass_fill_solid"]
    for n in names:
        p = os.path.join(ROOT, "black", n + ".png")
        im = Image.open(p)
        a = np.asarray(im.convert("RGBA")).astype(np.float64)
        inv = 255.0 - a[..., 0]
        if im.mode == "RGB" or a[..., 3].min() == 255:
            out = Image.fromarray(np.dstack([inv] * 3).astype(np.uint8), "RGB")
        else:
            out = Image.fromarray(np.dstack([inv, inv, inv, a[..., 3]]).astype(np.uint8), "RGBA")
        out.save(os.path.join(ROOT, "white", n + ".png"))
    print("   %d 장" % len(names))


if __name__ == "__main__":
    print("GAMMA = %.2f\n" % GAMMA)
    build_edges()
    build_fill()
    build_corners()
    build_white()

    # ---- 검증 ----
    print("\n검증:")
    allv = []
    for n in EDGES_FOR_TONE + ["grass_corner_outer", "grass_corner_inner"]:
        a = np.asarray(Image.open(os.path.join(ROOT, "black", n + ".png"))
                       .convert("RGBA")).astype(np.float64)
        allv.append(a[..., 0][a[..., 3] > 127])
    a = np.asarray(Image.open(os.path.join(ROOT, "black", "grass_fill_detail.png"))
                   .convert("RGB")).astype(np.float64)
    allv.append(a[..., 0].ravel())
    v = np.concatenate(allv)
    print("  BLACK mean %.2f  p05 %.1f  p50 %.1f  p95 %.1f  max %.0f"
          % (v.mean(), np.percentile(v, 5), np.percentile(v, 50), np.percentile(v, 95), v.max()))
    print("  WHITE mean %.2f  (정확히 255 - BLACK)" % (255 - v.mean()))
    print("  대비 폭 %.1f / 255" % (255 - 2 * v.mean()))

    fd = np.asarray(Image.open(os.path.join(ROOT, "black", "grass_fill_detail.png"))
                    .convert("RGB")).astype(np.float64)[..., 0]
    print("  필 내부 디테일 범위 p05~p95 = %.1f ~ %.1f  (%d 단계)"
          % (np.percentile(fd, 5), np.percentile(fd, 95),
             int(np.percentile(fd, 95) - np.percentile(fd, 5))))

    # 흑백 반전 정확도
    b = np.asarray(Image.open(os.path.join(ROOT, "black", "grass_edge_top.png")).convert("RGBA")).astype(np.float64)
    w = np.asarray(Image.open(os.path.join(ROOT, "white", "grass_edge_top.png")).convert("RGBA")).astype(np.float64)
    m = b[..., 3] > 127
    print("  흑백 반전 오차: max %.1f  알파 차이 %.0f"
          % (np.abs((255 - b[..., 0]) - w[..., 0])[m].max(), np.abs(b[..., 3] - w[..., 3]).max()))
