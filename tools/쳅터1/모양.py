# -*- coding: utf-8 -*-
"""
쳅터1 지형 다듬기 — 칸 다각형을 '덜 각지고 불규칙하게' · 2026-10-05 Claude

도형님 지시(10-05): "지형도 너무 각지지 않고 불규칙적인 모양으로 바꿔."

▣ 원칙 — **깎기만 한다, 덧붙이지 않는다**
  검사기(검사.py)는 32px 칸 격자로 점프를 흉내 낸다. 지형을 칸 밖으로 부풀리면
  검사기가 못 보는 턱이 생겨 "검사는 통과했는데 엔진에서 머리를 박는" 일이 생긴다.
  그래서 모든 변형은 **지형 안쪽으로만** 들어간다(깎기). 깎으면 공간이 넓어질 뿐이라 검사 결과는 보수적으로 남는다.

▣ 무엇을 깎나
  · 윗면(발 딛는 면): **평평하게 그대로** — 걷기·착지가 흔들리면 안 된다. 양 끝 모서리만 8px 비스듬히(모따기).
    → 검사기는 판 끝 8px 를 '없는 땅' 으로 보고 서기·착지를 판단한다(검사.py 모따기_윗면).
  · 옆면(벽): 40px 안팎마다 점을 넣어 0~5px 안쪽으로 들쭉날쭉. 벽을 타고 미끄러질 때 걸리지 않을 만큼만.
  · 아랫면(천장·판 밑): 0~11px 안쪽으로 크게 들쭉날쭉 — 낡아 떨어져 나간 느낌. 아래 모서리는 14px 모따기.
  · 빈칸이 아닌 것(다른 판·구조)과 맞닿은 변, 구멍 잇기 틈(반 칸 좌표)은 건드리지 않는다 — 맞닿은 두 다각형이 벌어지지 않게.

▣ 같은 도안이면 같은 모양(씨앗 = 도안 이름 + 다각형 이름) → 생성기 멱등 유지.
"""
import hashlib
import random

C = 32
모따기_윗면 = 8.0        # px — 검사.py 가 같은 값을 쓴다
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
    """점 = [(px,py)...] 시계방향 닫힌 다각형(마지막 점 ≠ 첫 점). 다듬은 점 목록을 돌려준다."""
    n = len(점)
    if n < 4:
        return list(점)
    r = _랜덤(씨앗)
    변 = [_변_종류(dn, 점[i], 점[(i + 1) % n]) for i in range(n)]
    out = []
    for i in range(n):
        a, b = 점[i], 점[(i + 1) % n]
        종류, 빈 = 변[i]
        앞종류, 앞빈 = 변[i - 1]
        # ── 꼭짓점 a: 볼록 모서리이고 양쪽 변이 다 빈칸을 향하면 모따기 ──
        p = 점[i - 1]
        볼록 = ((a[0] - p[0]) * (b[1] - a[1]) - (a[1] - p[1]) * (b[0] - a[0])) > 0
        길이_앞 = abs(a[0] - p[0]) + abs(a[1] - p[1])
        길이 = abs(b[0] - a[0]) + abs(b[1] - a[1])
        if 볼록 and 빈 and 앞빈 and _격자점(a):
            c = 모따기_아랫면 if "아래" in (종류, 앞종류) else 모따기_윗면
            c = min(c, 길이_앞 / 3, 길이 / 3)
            ux, uy = (a[0] - p[0]) / 길이_앞, (a[1] - p[1]) / 길이_앞
            vx, vy = (b[0] - a[0]) / 길이, (b[1] - a[1]) / 길이
            out.append((a[0] - ux * c, a[1] - uy * c))
            시작 = (a[0] + vx * c, a[1] + vy * c)
            out.append(시작)
        else:
            시작 = a
            out.append(a)
        # ── 변 a→b: 옆면·아랫면이 빈칸을 향하면 안쪽으로 들쭉날쭉 ──
        if 빈 and 종류 != "위":
            폭 = 아래_흔들 if 종류 == "아래" else 옆_흔들
            간격 = (28, 52) if 종류 == "아래" else (36, 60)
            ix, iy = _안쪽(종류)
            ux, uy = (b[0] - a[0]) / 길이, (b[1] - a[1]) / 길이
            # 끝 모서리 모따기 몫은 남겨 둔다
            d = 20.0
            while d < 길이 - 20.0:
                깊이 = r.uniform(0.0, 폭)
                if 종류 == "아래" and r.random() < 0.15:
                    깊이 = 아래_패임
                out.append((a[0] + ux * d + ix * 깊이, a[1] + uy * d + iy * 깊이))
                d += r.uniform(*간격)
    # 같은 점·일직선 점 정리
    정리 = []
    for q in out:
        if not 정리 or abs(q[0] - 정리[-1][0]) > 1e-6 or abs(q[1] - 정리[-1][1]) > 1e-6:
            정리.append((round(q[0], 2), round(q[1], 2)))
    if len(정리) > 1 and 정리[0] == 정리[-1]:
        정리.pop()
    return 정리


def 다각형들(dn):
    """도안의 칸 다각형 → 다듬은 다각형 [(종류, 이름, 점, 칸수)]. 씬·미리보기가 같이 쓴다."""
    return [(k, 이름, 다듬기(dn, 점, dn.이름 + "/" + 이름), n) for k, 이름, 점, n in dn.다각형들()]
