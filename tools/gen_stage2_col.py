"""
Stage 2 충돌 폴리곤 생성 스크립트
---------------------------------
각 PNG 파일의 알파 채널 윤곽선을 추출해
Godot PackedVector2Array 형식으로 출력합니다.

사용:
    python gen_stage2_col.py
"""

import os, json
import numpy as np
from PIL import Image
from skimage import measure
from scipy import ndimage

# ── 경로 설정 ──────────────────────────────────────────────────
MAP_DIR = os.path.join(
    os.path.dirname(os.path.dirname(__file__)),
    "scenes", "world_1", "map2"
)

GUIDE_PATH = os.path.join(MAP_DIR, "Map_Guide_Zone_B.png")

# ── 흰색 플랫폼 위치를 가이드 이미지에서 자동 탐색 ─────────────
def find_white_platform_positions():
    """
    가이드 이미지에서 검정 동굴 외부의 밝은 영역을 찾아
    각 흰색 플랫폼의 위치를 추정합니다.
    """
    guide = np.array(Image.open(GUIDE_PATH).convert("RGBA"))  # H=5400, W=2400
    black1 = np.array(Image.open(os.path.join(MAP_DIR, "Platform_Black_01.png")).convert("RGBA"))
    black2 = np.array(Image.open(os.path.join(MAP_DIR, "Platform_Black_02.png")).convert("RGBA"))

    H, W = guide.shape[:2]

    # 검정 동굴 마스크 합성 (상반부 + 하반부)
    cave_mask = np.zeros((H, W), dtype=bool)
    cave_mask[:2700, :] = black1[:, :, 3] > 50    # 상반부 불투명 픽셀
    cave_mask[2700:, :] = black2[:, :, 3] > 50    # 하반부 불투명 픽셀

    # 가이드에서 동굴 벽이 아닌 밝은(흰색/회색) 픽셀 찾기
    # - 가이드 알파 > 30  (내용이 있는 픽셀)
    # - 동굴 마스크 = False  (검정 벽이 아닌 픽셀)
    # - RGB 평균 > 180  (밝은 = 흰색 발판 계열)
    guide_alpha = guide[:, :, 3] > 30
    guide_bright = guide[:, :, :3].mean(axis=2) > 180
    white_region = guide_alpha & (~cave_mask) & guide_bright

    # 연결 영역 라벨링
    labeled, n = ndimage.label(white_region)
    print(f"\n[흰색 영역 탐색] 총 {n}개 연결 영역 발견")

    white_png_sizes = {
        "Platform_White_01.png": (289, 210),
        "Platform_White_02.png": (263, 253),
        "Platform_White_03.png": (294, 167),
        "Platform_White_04.png": (576, 317),
        "Platform_White_05.png": (429, 321),
    }

    regions = []
    for i in range(1, n + 1):
        ys, xs = np.where(labeled == i)
        area = len(xs)
        if area < 500:   # 너무 작은 잡음 제외
            continue
        x0, y0 = int(xs.min()), int(ys.min())
        x1, y1 = int(xs.max()), int(ys.max())
        regions.append({
            "x0": x0, "y0": y0, "x1": x1, "y1": y1,
            "w": x1 - x0, "h": y1 - y0,
            "area": area,
            "cx": (x0 + x1) // 2, "cy": (y0 + y1) // 2
        })
    regions.sort(key=lambda r: r["y0"])
    print(f"  유효 영역 {len(regions)}개:")
    for r in regions:
        print(f"    ({r['x0']:4d},{r['y0']:4d}) ~ ({r['x1']:4d},{r['y1']:4d})  "
              f"크기={r['w']}×{r['h']}  면적={r['area']}")
    return regions


# ── 폴리곤 유틸리티 ────────────────────────────────────────────
def douglas_peucker(pts, epsilon):
    """Ramer–Douglas–Peucker 라인 단순화."""
    if len(pts) <= 2:
        return pts
    # 첫 점 ~ 마지막 점 사이 최대 거리 점 찾기
    start, end = np.array(pts[0]), np.array(pts[-1])
    line_len = np.linalg.norm(end - start)
    if line_len == 0:
        dists = [np.linalg.norm(np.array(p) - start) for p in pts[1:-1]]
    else:
        d = end - start
        dists = [abs(np.cross(d, start - np.array(p))) / line_len for p in pts[1:-1]]
    idx = int(np.argmax(dists)) + 1
    max_dist = dists[idx - 1]
    if max_dist > epsilon:
        left  = douglas_peucker(pts[:idx + 1], epsilon)
        right = douglas_peucker(pts[idx:], epsilon)
        return left[:-1] + right
    return [pts[0], pts[-1]]


def get_contours_from_png(img_path, offset_x=0, offset_y=0,
                           alpha_threshold=50, simplify=3.0,
                           min_area=200, max_verts=400):
    """
    PNG 알파 채널에서 skimage marching-squares 로 윤곽선을 추출합니다.

    Parameters
    ----------
    img_path       : PNG 파일 경로
    offset_x/y     : 씬 내 위치 오프셋 (픽셀)
    alpha_threshold: 이 값 이상이면 "불투명(지형)" 으로 처리 (0-255)
    simplify       : Douglas-Peucker 허용 오차 (픽셀)
    min_area       : 이보다 작은 연결 영역은 무시
    max_verts      : 폴리곤 최대 정점 수

    Returns
    -------
    list of list[(x, y)]  — 씬 좌표 기준 폴리곤 목록
    """
    img = Image.open(img_path).convert("RGBA")
    alpha = np.array(img)[:, :, 3]
    mask = (alpha > alpha_threshold).astype(np.float64)

    # 연결 영역별로 처리
    labeled, n = ndimage.label(mask)
    polygons = []

    for i in range(1, n + 1):
        region_mask = (labeled == i).astype(np.float64)
        area = int(region_mask.sum())
        if area < min_area:
            continue

        # 이미지 경계에 닿은 영역은 open contour가 생겨 폴리곤이 잘못 닫힘.
        # 1픽셀 zero-padding으로 모든 등고선이 닫히도록 보장.
        padded = np.pad(region_mask, pad_width=1, mode='constant', constant_values=0)

        # marching squares 윤곽선 (row=y, col=x) — padded 좌표계
        contours = measure.find_contours(padded, 0.5)
        if not contours:
            continue

        # 가장 긴 윤곽선 사용 (외곽선)
        contour = max(contours, key=len)

        # 서브샘플 → D-P 단순화
        step = max(1, len(contour) // max_verts)
        contour = contour[::step]
        # padding 1픽셀 빼서 원본 이미지 좌표로 복원 (col-1, row-1)
        pts = [(float(col) - 1.0, float(row) - 1.0) for row, col in contour]
        pts = douglas_peucker(pts, simplify)

        # 오프셋 적용
        pts = [(x + offset_x, y + offset_y) for x, y in pts]

        if len(pts) >= 3:
            polygons.append(pts)

    return polygons


def fmt_poly(pts):
    """Godot PackedVector2Array 형식으로 변환."""
    inner = ", ".join(f"{x:.0f}, {y:.0f}" for x, y in pts)
    return f"PackedVector2Array({inner})"


# ── 메인 ──────────────────────────────────────────────────────
if __name__ == "__main__":

    # 1) 흰색 발판 위치 자동 탐색
    print("=" * 60)
    print("흰색 발판 위치 탐색 중...")
    white_regions = find_white_platform_positions()

    # 2) 각 PNG별 충돌 폴리곤 추출
    print("\n" + "=" * 60)
    print("충돌 폴리곤 추출 중...\n")

    # 처리할 파일 목록: (파일명, offset_x, offset_y, 레이어, simplify)
    # 레이어: BLACK=0 / WHITE=1 / GRAY=2 / THORN=thorn
    PIECES = [
        # ── 검정 동굴 벽 ────────────────────────────────────────
        ("Platform_Black_01.png",  0,    0,    "BLACK",  5.0),
        ("Platform_Black_02.png",  0,    2700, "BLACK",  5.0),
        # ── 경사로 몸체 (검정 충돌체) ────────────────────────────
        ("Slope_Body_01.png",      1540, 900,  "BLACK",  3.0),
        ("Slope_Body_02.png",      490,  3720, "BLACK",  3.0),
        ("Slope_Body_03.png",      1400, 3900, "BLACK",  3.0),
        # ── 경사로 표면 (회색 = 미끄러움) ───────────────────────
        ("Slope_Surface_01.png",   1540, 900,  "GRAY",   3.0),
        ("Slope_Surface_02.png",   490,  3720, "GRAY",   3.0),
        ("Slope_Surface_03.png",   1400, 3900, "GRAY",   3.0),
        # ── 흰색 발판 ────────────────────────────────────────────
        ("Platform_White_01.png",  620,  2820, "WHITE",  2.0),
        ("Platform_White_02.png",  80,   2960, "WHITE",  2.0),
        ("Platform_White_03.png",  180,  3170, "WHITE",  2.0),
        ("Platform_White_04.png",  820,  3350, "WHITE",  2.0),
        ("Platform_White_05.png",  340,  3520, "WHITE",  2.0),
        # ── 가시 장애물 (ThornObstacle → thorn 레이어) ──────────
        ("Platform_Thorn_01.png",  1000, 1060, "THORN",  2.0),
        ("Platform_Thorn_02.png",  425,  2450, "THORN",  2.0),
    ]

    results = {}
    for fname, ox, oy, layer, simp in PIECES:
        path = os.path.join(MAP_DIR, fname)
        if not os.path.exists(path):
            print(f"  [SKIP] {fname} 없음")
            continue

        print(f"  처리중: {fname}  offset=({ox},{oy})  layer={layer}")
        polys = get_contours_from_png(
            path, ox, oy,
            alpha_threshold=50,
            simplify=simp,
            min_area=300,
            max_verts=250
        )
        print(f"    → 폴리곤 {len(polys)}개, 정점수: "
              + ", ".join(str(len(p)) for p in polys))

        results[fname] = {
            "layer": layer,
            "offset": (ox, oy),
            "polygons": [fmt_poly(p) for p in polys]
        }

    # 3) 결과 저장 (JSON + 텍스트 리포트)
    out_json = os.path.join(os.path.dirname(__file__), "stage2_col_data.json")
    with open(out_json, "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=2)
    print(f"\n[완료] 결과 저장: {out_json}")

    # 4) 텍스트 요약 출력 (tscn 작성용 참고)
    print("\n" + "=" * 60)
    print("Godot 복붙용 요약")
    print("=" * 60)
    for fname, data in results.items():
        print(f"\n; ── {fname}  layer={data['layer']}  offset={data['offset']}")
        for i, poly in enumerate(data["polygons"]):
            # 처음 120자만 미리보기
            preview = poly[:120] + ("..." if len(poly) > 120 else "")
            print(f"  Col{i}: {preview}")
