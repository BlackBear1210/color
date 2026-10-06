# -*- coding: utf-8 -*-
"""목재 v03: 접합부와 윗면을 보존하고 천장 점을 줄인다. 일부 판자 밑면만 파손한다."""
import hashlib
import random

C = 32
모따기_윗면 = 0.0        # px — 검사.py 가 같은 값을 쓴다
모따기_아랫면 = 18.0
옆_흔들 = 7.0
아래_흔들 = 16.0
아래_패임 = 28.0          # 아랫면에 가끔(15%) 깊게 패인 자리 — 부서진 판자 끝 느낌


def _랜덤(씨앗):
    return random.Random(int(hashlib.md5(씨앗.encode("utf-8")).hexdigest()[:8], 16))


def _격자점(p):
    return abs(p[0] / C - round(p[0] / C)) < 1e-6 and abs(p[1] / C - round(p[1] / C)) < 1e-6


def _변_종류(dn, a, b):
    """변 a→b (축 정렬, px) 의 종류와 '바깥이 전부 빈칸인가'.
    다각형은 화면 기준 시계방향 → 진행 방향 오른쪽이 안쪽. 바깥 법선 = (dy, -dx)."""
    dx, dy = b[0] - a[0], b[1] - a[1]
    if dx > 0:
        종류 = "위"
    elif dx < 0:
        종류 = "아래"
    elif dy > 0:
        종류 = "오른"
    else:
        종류 = "왼"
    # 구멍 잇기 틈(세로, 반 칸 x)만 건너뛴다. 틈 끝점이 반 칸이어도 가로변(천장)은 격자선 위라 다듬는다.
    import math
    if 종류 in ("위", "아래"):
        if abs(a[1] / C - round(a[1] / C)) > 1e-6:
            return 종류, False
        lo, hi = sorted((a[0], b[0]))
        ax, bx = math.floor(lo / C + 1e-6), math.ceil(hi / C - 1e-6)
        if 종류 == "아래":
            ax, bx = bx, ax
        ay = by = round(a[1] / C)
    else:
        if abs(a[0] / C - round(a[0] / C)) > 1e-6:
            return 종류, False
        lo, hi = sorted((a[1], b[1]))
        ay, by = math.floor(lo / C + 1e-6), math.ceil(hi / C - 1e-6)
        if 종류 == "왼":
            ay, by = by, ay
        ax = bx = round(a[0] / C)
    칸들 = []
    if 종류 == "위":
        칸들 = [(x, ay - 1) for x in range(ax, bx)]
    elif 종류 == "아래":
        칸들 = [(x, ay) for x in range(bx, ax)]
    elif 종류 == "오른":
        칸들 = [(ax, y) for y in range(ay, by)]
    else:
        칸들 = [(ax - 1, y) for y in range(by, ay)]
    x0, y0, x1, y1 = dn.확장_범위()
    빈 = all(dn.칸(x, y) == 0 for x, y in 칸들 if x0 <= x < x1 and y0 <= y < y1)
    # 바깥 지형 끝(확장 범위 밖)을 향한 변은 화면에 안 나오므로 굳이 깎지 않는다
    if any(not (x0 <= x < x1 and y0 <= y < y1) for x, y in 칸들):
        빈 = False
    return 종류, 빈


def _안쪽(종류):
    return {"위": (0, 1), "아래": (0, -1), "오른": (-1, 0), "왼": (1, 0)}[종류]


def 다듬기(dn, 점, 씨앗):
    """발 디딤선·접합선은 유지하고 일부 독립 판자 밑에만 얕은 파손을 낸다."""
    # 긴 천장을 톱니로 분할하면 충돌·메시 비용과 시각적 잡음이 함께 늘어난다.
    r = _랜덤(씨앗)
    if "구조" in 씨앗.split("/")[-1] or r.random() > .32:
        return list(점)
    out = []
    chipped = False
    for i, a in enumerate(점):
        b = 점[(i + 1) % len(점)]
        out.append(a)
        종류, 빈 = _변_종류(dn, a, b)
        length = a[0] - b[0]
        # 전체 판마다 반복되는 삼각 톱니 대신 넓고 비대칭인 작은 결손 한 곳만 쓴다.
        if not chipped and 빈 and 종류 == "아래" and length >= 128:
            width = min(72., length * .28)
            start = (length - width) * r.uniform(.3, .7)
            depth = r.uniform(5., 10.)
            out.extend([(round(a[0]-start,2),a[1]),
                        (round(a[0]-start-width*.3,2),round(a[1]-depth,2)),
                        (round(a[0]-start-width*.76,2),round(a[1]-depth*.6,2)),
                        (round(a[0]-start-width,2),a[1])])
            chipped = True
    return out


def 다각형들(dn):
    """도안의 칸 다각형 → 다듬은 다각형 [(종류, 이름, 점, 칸수)]. 씬·미리보기가 같이 쓴다."""
    return [(k, 이름, 다듬기(dn, 점, dn.이름 + "/" + 이름), n) for k, 이름, 점, n in dn.다각형들()]
