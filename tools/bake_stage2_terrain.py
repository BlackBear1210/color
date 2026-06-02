#!/usr/bin/env python3
"""
tools/bake_stage2_terrain.py
Stage 2 지형 PNG 알파 채널에서 충돌 폴리곤을 자동 생성하여
stage_2.tscn 에 직접 적용합니다.

사용: python tools/bake_stage2_terrain.py
"""

import os, re
import numpy as np
import cv2
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MAP2 = os.path.join(ROOT, "scenes", "world_1", "map2")
TSCN = os.path.join(ROOT, "scenes", "world_1", "stage_2", "stage_2.tscn")

# (node_name, png_file, sprite_dx, sprite_dy, epsilon, min_area)
# epsilon : Douglas-Peucker 허용 오차(px). 클수록 정점 ↓, 모양 거칠어짐
# min_area: 이 픽셀 수보다 작은 연결 영역 무시
TERRAIN = [
    ("BlackCave1",    "Platform_Black_01.png",  0, 0,  8.0, 2000),
    ("BlackCave2",    "Platform_Black_02.png", -1,-1,  8.0, 2000),
    ("BlackCave3",    "Platform_Black_02.png",  0, 0,  8.0, 2000),
    ("WhitePlatform1","Platform_White_01.png",  0, 0,  2.0,  100),
    ("WhitePlatform2","Platform_White_02.png",  0, 0,  2.0,  100),
    ("WhitePlatform3","Platform_White_03.png",  0, 0,  2.0,  100),
    ("WhitePlatform4","Platform_White_04.png",  0, 0,  2.0,  100),
    ("WhitePlatform5","Platform_White_05.png",  0, 0,  2.0,  100),
]


# ── PNG → 이진 마스크 ───────────────────────────────────────────────────
def load_mask(png_path, alpha_threshold=50):
    """PIL 로 PNG 로드 → 알파 이진 마스크(uint8 0/255)와 원본 크기(W,H) 반환"""
    img = Image.open(png_path).convert("RGBA")
    alpha = np.array(img)[:, :, 3]
    mask = (alpha > alpha_threshold).astype(np.uint8) * 255
    return mask, img.size  # (W, H)


# ── Bridge: outer + holes → 단일 polygon ───────────────────────────────
def bridge_with_holes(outer, holes):
    """
    Outer contour 에 각 Hole contour 를 bridge 로 이어 단일 simple polygon 반환.
    동굴 벽 같이 solid 안에 hole(통로)이 있을 때 solid 영역 전체를 하나의
    non-convex polygon 으로 표현하는 데 사용한다.
    """
    result = list(outer)
    for hole in holes:
        if len(hole) < 3:
            continue
        # 현재 result 와 hole 사이 최근접 점 쌍 탐색 (샘플링으로 속도 향상)
        r_step = max(1, len(result) // 300)
        h_step = max(1, len(hole) // 300)
        best = (float('inf'), 0, 0)
        for ri in range(0, len(result), r_step):
            rx, ry = result[ri]
            for hi in range(0, len(hole), h_step):
                hx, hy = hole[hi]
                d = (rx - hx) ** 2 + (ry - hy) ** 2
                if d < best[0]:
                    best = (d, ri, hi)
        _, ri, hi = best
        # bridge: result[:ri+1] → hole[hi:] → hole[:hi+1] → result[ri:]
        result = (result[:ri + 1] +
                  list(hole[hi:]) + list(hole[:hi + 1]) +
                  result[ri:])
    return result


# ── 핵심: PNG → polygon 리스트 ─────────────────────────────────────────
def extract_polygons(png_path, sprite_dx=0, sprite_dy=0,
                     epsilon=4.0, min_area=100, alpha_threshold=50):
    """
    PNG 알파 모양 → Godot centered 좌표계 polygon 리스트 반환.

    Sprite2D centered=true 기준: 이미지 중심 = (0,0).
    sprite_dx/dy: Sprite2D 의 position offset (StaticBody2D 로컬 기준).

    동굴 벽처럼 solid 안에 hole 이 있는 경우 bridge 로 연결해
    하나의 non-convex polygon 으로 만든다. (두 영역이 물리적으로 분리된 경우만
    별개 polygon 반환)
    """
    mask, (W, H) = load_mask(png_path, alpha_threshold)
    cx, cy = W / 2.0, H / 2.0

    # 1px 패딩: 이미지 경계에 붙어있는 solid 의 외곽 contour 가 올바르게 검출되도록
    padded = np.pad(mask, 1, mode='constant', constant_values=0)

    # RETR_CCOMP: outer + hole 계층 구조
    contours, hierarchy = cv2.findContours(
        padded, cv2.RETR_CCOMP, cv2.CHAIN_APPROX_SIMPLE)

    if hierarchy is None or len(contours) == 0:
        return []

    hierarchy = hierarchy[0]  # (N, 4): [next, prev, first_child, parent]

    def to_pts(cv_contour):
        """cv2 contour (N,1,2) → [(x,y)...] Godot centered coords"""
        return [
            (float(p[0][0]) - 1.0 - cx + sprite_dx,
             float(p[0][1]) - 1.0 - cy + sprite_dy)
            for p in cv_contour
        ]

    def simplify(cv_contour):
        return cv2.approxPolyDP(cv_contour, epsilon, True)

    result = []
    for i, contour in enumerate(contours):
        # outer contour 만 처리 (parent == -1)
        if hierarchy[i][3] != -1:
            continue
        if cv2.contourArea(contour) < min_area:
            continue

        outer_pts = to_pts(simplify(contour))
        if len(outer_pts) < 3:
            continue

        # 이 outer 의 children (holes) 수집
        holes = []
        child = hierarchy[i][2]  # first_child
        while child != -1:
            h_contour = contours[child]
            if cv2.contourArea(h_contour) >= max(100, min_area // 10):
                h_pts = to_pts(simplify(h_contour))
                if len(h_pts) >= 3:
                    holes.append(h_pts)
            child = hierarchy[child][0]  # next sibling

        if holes:
            combined = bridge_with_holes(outer_pts, holes)
            result.append(combined)
        else:
            result.append(outer_pts)

    return result


# ── 출력 포맷 ──────────────────────────────────────────────────────────
def fmt_poly(pts):
    vals = ", ".join(f"{x:.1f}, {y:.1f}" for x, y in pts)
    return f"PackedVector2Array({vals})"


def col_section(parent_path, idx, pts, uid):
    return (
        f'[node name="AutoCol{idx}" type="CollisionPolygon2D" '
        f'parent="{parent_path}" unique_id={uid}]\n'
        f'polygon = {fmt_poly(pts)}'
    )


# ── TSCN 갱신 ─────────────────────────────────────────────────────────
def update_tscn(tscn_path, terrain_list):
    with open(tscn_path, 'r', encoding='utf-8') as f:
        text = f.read()

    terrain_map = {t[0]: t[1:] for t in terrain_list}
    sections = text.split('\n\n')

    uid_counter = [200000000]
    def next_uid():
        u = uid_counter[0]; uid_counter[0] += 1; return u

    new_sections = []
    for sec in sections:
        first_line = sec.split('\n')[0]

        # 기존 수동 CollisionPolygon2D 제거
        m_col = re.match(
            r'\[node [^]]*type="CollisionPolygon2D" parent="MapPhysics/([^"]+)"',
            first_line)
        if m_col and m_col.group(1) in terrain_map:
            continue

        new_sections.append(sec)

        # Sprite2D 뒤에 자동 생성 Col 삽입
        m_spr = re.match(
            r'\[node name="Sprite2D" type="Sprite2D" parent="MapPhysics/([^"]+)"',
            first_line)
        if m_spr:
            node_name = m_spr.group(1)
            if node_name in terrain_map:
                png_file, dx, dy, eps, min_a = terrain_map[node_name]
                png_path = os.path.join(MAP2, png_file)
                print(f"  [{node_name}] {png_file} 처리 중...", end=' ', flush=True)
                polys = extract_polygons(png_path, dx, dy, eps, min_a)
                verts = [len(p) for p in polys]
                print(f"폴리곤 {len(polys)}개  정점 수: {verts}")
                parent_path = f"MapPhysics/{node_name}"
                for idx, pts in enumerate(polys):
                    new_sections.append(col_section(parent_path, idx, pts, next_uid()))

    with open(tscn_path, 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n\n'.join(new_sections))
    print(f"\n[완료] {os.path.basename(tscn_path)} 저장 완료")


# ──────────────────────────────────────────────────────────────────────
if __name__ == '__main__':
    print("Stage 2 지형 충돌 자동 생성")
    print("=" * 55)
    update_tscn(TSCN, TERRAIN)
