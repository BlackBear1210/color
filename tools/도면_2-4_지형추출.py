# -*- coding: utf-8 -*-
"""[2026-10-07 신규] 도형님 uvtt 도면(2-4_403x107)에서 stage_2-4 지형을 뽑는다.

왜 도구로 뽑나
  2-1~2-3 은 도면 칸을 손으로 옮겨 적었다(도면이 215 칸까지라 가능했다).
  2-4 도면은 403 x 107 칸이라 손으로 옮기면 틀린다 — 벽 데이터(line_of_sight)를
  **0.5 칸(=16px) 래스터**로 굽고, 거기서 외곽선을 따 월드 좌표 점 목록으로 만든다.

규약 (tools/하수도_빌더_공통.gd §SS2D 붙이기)
  · 한 칸 = 32px → 0.5 칸 = 16px = 검산의 격자. 그래서 모든 꼭짓점이 16 격자에 떨어진다.
  · 월드 = 도면칸 * 32 + (16, 32).  도면 칸 23.5(시작 방 왼벽) → x 768 (2-1~2-3 과 같은 입구 자리).
  · 시계 방향(화면 좌표계: y 아래로 증가) 으로 돌려 준다.

장치가 되는 윤곽(호퍼·물탱크·격자발판·부서지는 발판·관 …)은 지형에서 뺀다 — 아래 `장치` 표.
큰 덩어리(도면 poly 0)는 x 경계에서 세로로 잘라 여러 조각으로 준다(SS2D 한 덩어리가 12,700px 이 되지 않게).
"""
import json, io, os, sys
from collections import deque

import numpy as np

여기 = os.path.dirname(os.path.abspath(__file__))
기본_도면 = os.path.join(os.path.expanduser('~'), 'Downloads', '2-4_403x107 (1).uvtt')

N = 2                      # 한 칸을 2 등분 = 0.5 칸 = 16px
칸 = 32.0
OX, OY = 16.0, 32.0        # 월드 오프셋

# 도면 윤곽 번호 → 지형이 아닌 것
관 = {32, 34, 41}                                  # 물탱크 → 호퍼 배관(그림만)
호퍼 = {12: 1, 13: 2, 14: 3, 15: 4}
물탱크 = {37: 'A', 39: 'B', 40: 'C'}
버튼 = {33: '발판_1'}
움직이는_지형 = {38: '발판_1_지형'}                 # 발판_1 을 누르면 들어가는 지형
격자 = {16: '검', 17: '검', 18: '검', 19: '검', 20: '검',      # 흰물_2 수갱 지그재그
        21: '검', 22: '검', 23: '검', 24: '검', 25: '검', 26: '검', 27: '검',  # 물탱크 C 사다리(도면 색 표기 없음)
        28: '검', 29: '흰', 30: '검', 31: '흰'}                 # 호퍼 4 앞 지그재그
움직이는_발판 = {35: '위끝', 36: '발판'}            # 위 아래로 움직이는 플랫폼(35 = 위 끝 자리)
부서지는 = {42: 1, 43: 2, 44: 3, 45: 4}

장치 = set(관) | set(호퍼) | set(물탱크) | set(버튼) | set(움직이는_지형) \
     | set(격자) | set(움직이는_발판) | set(부서지는)

# 큰 덩어리를 자르는 x 경계(도면 칸). 전부 그 자리에 세로 벽이 있거나 빈 곳이라 잘라도 모양이 안 바뀐다.
자르는_x = [94.5, 132.0, 157.0, 194.5, 216.5, 233.5]


def 읽기(경로):
    d = json.load(io.open(경로, encoding='utf-8'))
    return d['line_of_sight'], d['resolution']['map_size']['x'], d['resolution']['map_size']['y']


def 래스터(윤곽들, 쓸것, W, H):
    """even-odd 로 굽는다. True = 바위(도면의 회색)."""
    gx = (np.arange(W * N) + 0.5) / N
    gy = (np.arange(H * N) + 0.5) / N
    X, Y = np.meshgrid(gx, gy)
    m = np.zeros(X.shape, bool)
    for i in 쓸것:
        pts = [(p['x'], p['y']) for p in 윤곽들[i]]
        if pts[0] != pts[-1]:
            pts.append(pts[0])
        for (ax, ay), (bx, by) in zip(pts, pts[1:]):
            if ay == by:
                continue
            cond = ((ay > Y) != (by > Y))
            t = (Y - ay) / (by - ay)
            m ^= cond & (X < ax + t * (bx - ax))
    return m


def 덩어리들(m):
    lab = np.zeros(m.shape, np.int32)
    cur = 0
    H_, W_ = m.shape
    for y in range(H_):
        for x in range(W_):
            if m[y, x] and lab[y, x] == 0:
                cur += 1
                q = deque([(y, x)])
                lab[y, x] = cur
                while q:
                    cy, cx = q.popleft()
                    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        ny, nx = cy + dy, cx + dx
                        if 0 <= ny < H_ and 0 <= nx < W_ and m[ny, nx] and lab[ny, nx] == 0:
                            lab[ny, nx] = cur
                            q.append((ny, nx))
    return lab, cur


def 외곽선(m):
    """채운 칸 집합의 바깥 외곽선을 칸 모서리를 따라 시계 방향으로 딴다.
    왼쪽이 바깥인 변을 모아 이어 붙이는 방식 — 직각 격자라 항상 닫힌 고리가 된다."""
    H_, W_ = m.shape
    변 = {}
    for y in range(H_):
        for x in range(W_):
            if not m[y, x]:
                continue
            # 화면 좌표(y 아래로) 에서 시계 방향 = 위변 →, 오른변 ↓, 아래변 ←, 왼변 ↑
            if y == 0 or not m[y - 1, x]:
                변[(x, y)] = (x + 1, y)
            if x == W_ - 1 or not m[y, x + 1]:
                변[(x + 1, y)] = (x + 1, y + 1)
            if y == H_ - 1 or not m[y + 1, x]:
                변[(x + 1, y + 1)] = (x, y + 1)
            if x == 0 or not m[y, x - 1]:
                변[(x, y + 1)] = (x, y)
    고리들 = []
    while 변:
        시작 = next(iter(변))
        고리 = [시작]
        p = 시작
        while True:
            q = 변.pop(p, None)
            if q is None:
                break
            if q == 시작:
                break
            고리.append(q)
            p = q
        if len(고리) >= 4:
            고리들.append(고리)
    고리들.sort(key=lambda g: -len(g))
    return 고리들


def 직선_합치기(점들):
    o = []
    n = len(점들)
    for i in range(n):
        a, b, c = 점들[i - 1], 점들[i], 점들[(i + 1) % n]
        if (b[0] - a[0]) * (c[1] - b[1]) != (b[1] - a[1]) * (c[0] - b[0]):
            o.append(b)
    return o


def 월드(점들):
    return [(round(x / N * 칸 + OX, 1), round(y / N * 칸 + OY, 1)) for x, y in 점들]


def 칸좌표(윤곽):
    xs = [p['x'] for p in 윤곽]
    ys = [p['y'] for p in 윤곽]
    return min(xs), min(ys), max(xs), max(ys)


def 사각_월드(윤곽):
    x0, y0, x1, y1 = 칸좌표(윤곽)
    return (round(x0 * 칸 + OX, 1), round(y0 * 칸 + OY, 1),
            round(x1 * 칸 + OX, 1), round(y1 * 칸 + OY, 1))


def 사각_덮기(m):
    """True 칸을 직사각형 몇 개로 덮는다(가로 런 → 세로 병합). 검산의 `빈공간들` 용."""
    H_, W_ = m.shape
    런 = []          # (y, x0, x1)
    for y in range(H_):
        x = 0
        while x < W_:
            if m[y, x]:
                x0 = x
                while x < W_ and m[y, x]:
                    x += 1
                런.append((y, x0, x))
            else:
                x += 1
    # 같은 (x0,x1) 런이 연속한 y 에 있으면 하나의 사각형으로 합친다
    열린 = {}        # (x0,x1) -> y0
    사각 = []
    줄별 = {}
    for y, x0, x1 in 런:
        줄별.setdefault(y, []).append((x0, x1))
    for y in range(H_ + 1):
        이번 = set(줄별.get(y, []))
        for k in list(열린.keys()):
            if k not in 이번:
                y0 = 열린.pop(k)
                사각.append((k[0], y0, k[1], y))
        for k in 이번:
            열린.setdefault(k, y)
    for k, y0 in 열린.items():
        사각.append((k[0], y0, k[1], H_))
    return 사각


def main():
    경로 = sys.argv[1] if len(sys.argv) > 1 else 기본_도면
    윤곽, W, H = 읽기(경로)
    지형_윤곽 = [i for i in range(len(윤곽)) if i not in 장치]
    m = 래스터(윤곽, 지형_윤곽, W, H)
    # 입구·출구 통로 자리는 파낸다(하수도_빌더_공통 `입구()`·`출구()` 가 그 사각형을 비워 두라고 한다).
    #   입구 원점 (768,1344) = 도면 칸 (23.5, 41) · 출구 원점 (11792,2272) = 칸 (368, 70)
    for x0, y0, x1, y1 in [(6.5, 31.5, 23.5, 44.0), (368.0, 60.5, 385.5, 73.0)]:
        m[int(y0 * N):int(y1 * N), int(x0 * N):int(x1 * N)] = False
    lab, n = 덩어리들(m)

    조각 = []
    경계 = [0.0] + 자르는_x + [float(W)]
    for c in range(1, n + 1):
        덩 = (lab == c)
        ys, xs = np.where(덩)
        왼, 오 = xs.min() / N, (xs.max() + 1) / N
        # 자르는 것은 제일 큰 덩어리(도면 poly 0 · 폭 273 칸) 하나뿐이다. 작은 조각은 그대로 둔다.
        구간 = [(a, b) for a, b in zip(경계, 경계[1:]) if b > 왼 and a < 오] if (오 - 왼) > 60 else [(왼, 오)]
        if len(구간) == 1:
            조각들 = [덩]
            이름들 = ['덩%02d' % c]
        else:
            조각들, 이름들 = [], []
            for k, (a, b) in enumerate(구간):
                잘린 = 덩.copy()
                잘린[:, :int(a * N)] = False
                잘린[:, int(b * N):] = False
                if 잘린.any():
                    조각들.append(잘린)
                    이름들.append('덩%02d_%d' % (c, k))
        for 조, 이름 in zip(조각들, 이름들):
            # 세로로 자르면 한 덩어리가 여러 조각으로 갈라진다 → 다시 덩어리로 나눠서 각각 외곽선을 딴다.
            하위, hn = 덩어리들(조)
            for s in range(1, hn + 1):
                for j, 고리 in enumerate(외곽선(하위 == s)):
                    점 = 월드(직선_합치기(고리))
                    뒤 = ('' if hn == 1 else chr(ord('a') + s - 1)) + ('' if j == 0 else '_구멍%d' % j)
                    조각.append({'이름': 이름 + 뒤, '점': 점})

    # ── 하늘 채움 ────────────────────────────────────────────────────────────
    #   도면은 바위만 그렸다. 그 위(하늘)는 빈칸이라 카메라에 들어오면 구멍으로 보인다.
    #   → 칸마다 "그 둘레(±24 칸) 에서 가장 높은 내용물 − 머리여유 12 칸" 위를 전부 메운다.
    #     머리여유 12 칸(384px) = 몸 97 + 점프 160 + 여유. 그래서 어떤 발판 위에서도 머리가 안 박힌다.
    #   ⚠ 아래(낙사 존)는 **메우지 않는다** — 메우면 떨어져도 안 죽는다.
    여유칸, 창 = 12 * N, 24 * N
    내용 = m.copy()
    for i in 장치:
        x0, y0, x1, y1 = 칸좌표(윤곽[i])
        내용[int(y0 * N):int(y1 * N), int(x0 * N):int(x1 * N)] = True
    위끝 = np.full(내용.shape[1], 10 ** 6)
    for x in range(내용.shape[1]):
        ys = np.where(내용[:, x])[0]
        if len(ys):
            위끝[x] = ys.min()
    천장 = np.full(내용.shape[1], 10 ** 6)
    for x in range(내용.shape[1]):
        창안 = 위끝[max(0, x - 창):x + 창 + 1]
        v = 창안.min()
        천장[x] = 10 ** 6 if v >= 10 ** 6 else v - 여유칸
    하늘 = np.zeros(m.shape, bool)
    for x in range(내용.shape[1]):
        if 천장[x] < 10 ** 6:
            하늘[:max(0, 천장[x]), x] = True
    # 손으로 더 메우는 곳(도면 칸 x0,y0,x1,y1). 위 자동 규칙은 "둘레에서 가장 높은 내용물" 을 보기 때문에
    # 바위 꼭대기가 계단처럼 뚝 떨어지는 곳(시작 복도 위 · 천장 슬래브 위 · 수갱 입구 위)을 안 메운다.
    # 전부 **플레이어가 올라가는 제일 높은 자리보다 한참 위**라 길을 막지 않는다(머리 여유는 주석에).
    손_하늘 = [
        (0.0, 0.0, 54.0, 21.0),      # 시작 복도 위 바위 꼭대기(복도 천장 32.5 보다 11.5 칸 위)
        (53.5, 0.0, 158.0, 8.5),     # 흰물_1 수갱 위 바위 꼭대기(수갱 천장 18.5 보다 10 칸 위)
        (158.0, 0.0, 216.5, 3.0),    # 물탱크 C 방 천장 슬래브 위(제일 높은 격자발판 14.5 보다 11.5 칸 위)
        (216.5, 0.0, 241.0, 21.0),   # 수갱 입구 위 — 오른쪽 자동 천장(20~21)과 이어 준다(발판 44.5 보다 23 칸 위)
    ]
    for x0, y0, x1, y1 in 손_하늘:
        하늘[int(y0 * N):int(y1 * N), int(x0 * N):int(x1 * N)] = True
    하늘 &= ~m
    print('하늘 채움 칸 %d' % 하늘.sum())

    채움 = []
    clab, cn = 덩어리들(하늘)
    for c in range(1, cn + 1):
        for j, 고리 in enumerate(외곽선(clab == c)):
            if j > 0:
                continue
            채움.append({'이름': '채움%02d' % c, '점': 월드(직선_합치기(고리))})

    빈 = ~(m | 하늘)
    빈공간 = [[round(x0 / N * 칸 + OX, 1), round(y0 / N * 칸 + OY, 1),
               round((x1 - x0) / N * 칸, 1), round((y1 - y0) / N * 칸, 1)]
              for x0, y0, x1, y1 in 사각_덮기(빈)]
    print('채움 조각 %d · 빈공간 사각 %d' % (len(채움), len(빈공간)))

    결과 = {
        '칸': 칸, '오프셋': [OX, OY],
        # 프레임(= 카메라 리밋 · 검산 범위) = 도면 칸이 차지하는 사각형 딱 그만큼.
        # 0,0 에서 시작하면 왼쪽 16 · 위 32 의 여백 칸이 "지형도 빈공간도 아닌 칸" 이 되어 검산이 구멍으로 잡는다.
        '프레임': [OX, OY, W * 칸, H * 칸],
        '지형': 조각,
        '채움': 채움,
        '빈공간': 빈공간,
        '호퍼': {str(v): 사각_월드(윤곽[k]) for k, v in 호퍼.items()},
        '물탱크': {v: 사각_월드(윤곽[k]) for k, v in 물탱크.items()},
        '버튼': {v: 사각_월드(윤곽[k]) for k, v in 버튼.items()},
        '움직이는_지형': {v: 사각_월드(윤곽[k]) for k, v in 움직이는_지형.items()},
        '격자': [{'번호': k, '색': v, '사각': 사각_월드(윤곽[k])} for k, v in sorted(격자.items())],
        '움직이는_발판': {v: 사각_월드(윤곽[k]) for k, v in 움직이는_발판.items()},
        '부서지는': [사각_월드(윤곽[k]) for k in sorted(부서지는)],
    }
    나갈곳 = os.path.join(여기, '도면_2-4_지형.json')
    with io.open(나갈곳, 'w', encoding='utf-8') as f:
        json.dump(결과, f, ensure_ascii=False, indent=1)
    print('지형 조각', len(조각), '→', 나갈곳)
    for s in 조각:
        xs = [p[0] for p in s['점']]
        ys = [p[1] for p in s['점']]
        print('  %-12s 점 %3d  x %7.0f~%-7.0f y %6.0f~%-6.0f' %
              (s['이름'], len(s['점']), min(xs), max(xs), min(ys), max(ys)))


if __name__ == '__main__':
    main()
