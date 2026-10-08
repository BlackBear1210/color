# -*- coding: utf-8 -*-
"""
쳅터1 도안 도달성 검사 — 2026-10-04 Claude · 2026-10-05 색 전환·기믹 시뮬 추가

엔진을 열지 않고 player.gd 의 점프 물리를 그대로 흉내 낸다(60Hz).
  · 몸 = 44×97 사각형(발바닥 = 원점), 상승 중력 1287 · 낙하 ×2.4 · 점프 초속 642 · 이동 390
  · 점프 키 일찍 떼기(×0.4), 공중에서 방향 바꾸기·멈추기를 섞은 입력 묶음으로 시뮬레이션
  · 바닥 위를 걸을 수 있는 구간(세그먼트)을 노드로 BFS
  · 유령판은 '칠했다고 치고' 밟힌다(기본). --유령없이 로 칠하기 없이도 되는지 본다.
  · 가시에 닿거나 치명 낙하(1500px)면 그 착지는 버린다.

▣ [2026-10-05] 색 전환 시뮬 (도형님: "시뮬도 돌려서 색반전 기믹이나 막히는 구간이 있는지 확인")
  예전엔 "색은 언제든 바꿀 수 있다" 고 보고 색을 무시했다. 그런데 Shift 는 순간이어도
  **사람 손은 순간이 아니다** — 검정 판에서 뛰어 3프레임 만에 흰 판에 닿으면 실제로는 못 바꾼다.
  그래서 비행마다 '몸에 닿은 색' 을 프레임별로 적고,
    · 두 색이 **같은 프레임**에 몸에 닿으면 → 죽음("두 색 동시")
    · 앞 색에서 떨어진 뒤 다음 색에 닿기까지 **색전환_최소_프레임** 보다 짧으면 → 못 감("색 전환 틈")
  으로 잘라 낸다. 닿는 색 = 검정/흰 판 · 고정색 빛줄기(색레이저) · 검정(안 칠한) 움직이는 발판 · 색 도약대.
  구조(중립)·유령(칠했다고 침)은 색이 없다.

▣ [2026-10-05] 기믹
  · 도약대: 밟으면 그 자리에서 '도약 노드' 로 — 거기서 점프 입력 묶음을 도약 초속으로 다시 쏜다.
    색 도약대는 반대색이면 그냥 발판(구간)이고, 그 위에서 색을 바꾸면 튄다(구간 → 도약 노드).
  · 움직이는 발판: 위상 5곳(0·¼·½·¾·끝)의 윗면을 '착지 가능한 판' 으로 보고 발판 하나를 노드 하나로 친다
    (타면 끝에서 끝까지 실려 간다 · 위상을 기다릴 수 있다고 가정). 공중에서는 장애물로 안 친다(얇다).
  · 빛줄기: 주기 0(색 고정)만 막는다. 주기·점멸 빛은 기다리면 되므로 막지 않는다.

▣ 경로 내보내기: 시작 → 각 길목의 실제 비행 목록을 JSON 으로 남긴다(tools/_진단/경로/<이름>.json).
  엔진 재생 시험(tools/시험_경로재생.gd)이 이 입력을 진짜 player.gd 로 다시 뛰어 본다.

⚠ 근사다. 실제 엔진의 move_and_slide·코요테 타임·경사는 다르다 — 그래서 엔진 재생 시험을 같이 돌린다.

사용
  python tools/쳅터1/검사.py                 # 도안 전부
  python tools/쳅터1/검사.py 쳅터1_03_방_서재   # 하나만
"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import 규격  # noqa: E402
import 도안 as 도안모듈  # noqa: E402
import 기믹 as 기믹모듈  # noqa: E402

C = 규격.칸
HW = 규격.몸_폭 / 2
BL, BR = 규격.몸_왼, 규격.몸_오른      # 몸(허리) 사각형 — 벽·머리·색 닿음
FL, FR = 규격.발_왼, 규격.발_오른      # 발바닥 — 서기·착지
# [2026-10-05 엔진 재생 결과] 판 끝에 몇 px 만 걸친 착지는 엔진에서 미끄러져 떨어졌다
#   (방향키를 누른 채 내리고, 검사기와 엔진의 가로 위치가 몇 px 어긋난다).
#   → 서기·착지는 '발바닥 가운데(+3.5px) 좌우 10px' 가 **전부** 판 위여야 인정한다(+ 모따기 8px).
SL, SR = (FR - FL) / 2 - 6, (FR - FL) / 2 + 6        # 원점 기준 [x-2.5, x+9.5] — 서 있기·'편한 손' 도달
# [2026-10-05 2차] 모따기 뒤 엔진 재생에서 '판 끝 4px 여유' 착지가 또 미끄러졌다(움직이며 내리므로).
#   → 엔진 재생에 쓸 '실제 물리' 경로는 착지만 발 가운데 ±10px 로 더 안쪽을 고른다(서 있는 자리는 그대로).
착지_더여유 = 12.0      # 가로로 한 프레임 6.5px 씩 움직이며 내린다 → 두 프레임 몫
# [2026-10-05 2차] 지형 윗면 양 끝을 모양.모따기_윗면(8px) 만큼 비스듬히 깎는다 → 판 끝 8px 는 '없는 땅' 으로 본다.
import 모양  # noqa: E402
SL, SR = SL - 모양.모따기_윗면, SR + 모양.모따기_윗면
# [2026-10-05 2차] 도형님 "점프로도 못 올라가" — 사람 손 기준으로도 되는지 본다:
#   '편한 점프' = 최고 높이 95%(152px) — 90% 로 하면 4칸(128px) 오르기가 전부 막혀 규격(오르기 ≤4칸)과 어긋났다. 모든 길목·모든 바닥이 편한 점프로 닿아야 통과.
편한_점프_높이 = 0.95
BH = 규격.몸_키
DT = 1.0 / 60.0
G = 규격.중력
VJ = 규격.점프_초속
VX = 규격.이동속도

발동_깊이 = 56.0      # scripts/쳅터1/연결구.gd 발동_깊이 기본값
접촉_여유 = 3.0       # scripts/스마트월드/월드.gd 접촉_여유 — 색 사망 판정 때 몸을 부풀리는 값

# 색 전환에 필요한 최소 틈(프레임). 8프레임 = 0.13초 — 미리 알고 누르는 손이라도 이보다 빠르면 무리.
색전환_최소_프레임 = 8
# 이보다 짧으면 '빠듯' 으로 표시만 한다(실패는 아님) — 0.25초
색전환_빠듯_프레임 = 15

저장소 = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
도안폴더 = os.path.join(저장소, "scenes", "쳅터1", "도안")
경로폴더 = os.path.join(저장소, "tools", "_진단", "경로")


class _색기록:
    """한 비행 동안 몸에 닿은 색의 순서. 색이 바뀌는 곳마다 틈(프레임)을 잰다."""

    def __init__(self, 최소=색전환_최소_프레임):
        self.최소 = 최소
        self.색 = None
        self.f = -999
        self.여유 = None          # 색이 바뀐 곳 중 가장 짧은 틈
        self.전환 = []            # 엔진 재생용: Shift 를 누를 프레임
        self.첫색 = None
        self.실패 = None

    def 본다(self, f, 색들):
        if not 색들:
            return True
        if len(색들) >= 2:
            self.실패 = "두 색 동시"
            return False
        c = next(iter(색들))
        if self.첫색 is None:
            self.첫색 = c
        if self.색 is not None and c != self.색:
            틈 = f - self.f
            self.여유 = 틈 if self.여유 is None else min(self.여유, 틈)
            if 틈 < self.최소:
                self.실패 = f"색 전환 틈 {틈}프레임"
                return False
            self.전환.append((self.f + f) // 2)
        self.색 = c
        self.f = f
        return True


반사빛길_발판_x = (120.0, 350.0, 570.0)   # scripts/쳅터1/반사빛길.gd _ready() 의 발판 x(노드 기준 px)
반사빛길_발판_y = 25.0                    # 같은 곳의 발판 y(가운데) — 두께 18 이라 윗면 = y − 9


class 지도:
    def __init__(self, dn, 유령_밟힘=True):
        import numpy as np
        self.dn = dn
        x0, y0, x1, y1 = dn.확장_범위()
        self.x0, self.y0, self.x1, self.y1 = x0, y0, x1, y1
        self.W, self.H = x1 - x0, y1 - y0
        k = np.array([[dn.칸(x, y) for x in range(x0, x1)] for y in range(y0, y1)], dtype=np.int8)
        # [2026-10-07 Claude] 반사빛길(15 집 밖 — Codex 10-06): 거울로 반사광을 수광판에 맞히면 생기는
        #   '굳은 흰 빛' 발판 3장을 **풀린 상태**로 본다. 안 넣으면 다리로만 건너는 구덩이 때문에
        #   "시작 → 오른쪽 도달 못 함" 이 나온다. 여는 과정(거울 회전·가림·소멸)은 엔진 시험
        #   tools/시험_반사와외부.gd 가 따로 검사한다. 숫자 = scripts/쳅터1/반사빛길.gd 의 발판(가운데 x · y 25 · 170×18).
        for bx, by, ox in [(d[0], d[1], o) for d in [dn.d.get("반사빛길")] if d for o in 반사빛길_발판_x]:
            윗면 = by * C + 반사빛길_발판_y - 9
            줄 = round(윗면 / C)
            for cx in range(math.ceil((bx * C + ox - 85) / C), math.floor((bx * C + ox + 85) / C)):
                if 0 <= 줄 - y0 < k.shape[0] and 0 <= cx - x0 < k.shape[1] and k[줄 - y0, cx - x0] == 0:
                    k[줄 - y0, cx - x0] = 3          # 흰 빛 = 흰 몸만 설 수 있다(반사빛길.반대색인가)
        self.k = k
        self.유령 = 유령_밟힘
        self.최소틈 = 색전환_최소_프레임       # 검사() 가 '편한 길(15)' → '빠듯한 길(8)' 순으로 바꿔 가며 쓴다
        self.점프배율 = 1.0                     # 점프 최고 높이 배율(편한 점프 검사 때 0.95)
        self.착지여유 = 0.0                     # 착지 때만 더 안쪽을 요구(px) — 실제 물리 경로에서 착지_더여유
        단단 = (k != 0) & ((k != 4) | 유령_밟힘)
        가시 = np.zeros_like(단단)
        for gx, gy, gw in dn.d.get("가시", []):
            가시[gy - 1 - y0, gx - x0: gx + gw - x0] = True
        # ── 기믹 ──
        self.기믹 = 기믹모듈.목록(dn)
        self.도약대들 = [g for g in self.기믹 if isinstance(g, 기믹모듈.도약대)]
        self.발판들 = [g for g in self.기믹 if isinstance(g, 기믹모듈.움직이는발판)]
        self.빛들 = [(g, 기믹모듈.격자색[g.색]) for g in self.기믹 if isinstance(g, 기믹모듈.빛줄기) and g.고정]
        도약 = np.zeros_like(단단)            # 늘 튀는(무색) 도약대 칸 — 착지하면 튄다
        for g in self.도약대들:
            for x, y in g.칸들():
                단단[y - y0, x - x0] = True
                if not g.색:
                    도약[y - y0, x - x0] = True
        self._S = self._적분(단단)
        self._가시 = self._적분(가시)
        self._도약 = self._적분(도약)
        self._검 = self._적분(k == 2)
        self._흰 = self._적분(k == 3)

    @staticmethod
    def _적분(a):
        import numpy as np
        S = np.zeros((a.shape[0] + 1, a.shape[1] + 1), dtype=np.int32)
        S[1:, 1:] = a.astype(np.int32).cumsum(0).cumsum(1)
        return S.tolist()

    def _합(self, S, l, t, r, b, 밖값):
        cx0 = math.floor(l / C) - self.x0
        cx1 = math.floor((r - 0.001) / C) - self.x0
        cy0 = math.floor(t / C) - self.y0
        cy1 = math.floor((b - 0.001) / C) - self.y0
        if cx0 < 0 or cy0 < 0 or cx1 >= self.W or cy1 >= self.H:
            if 밖값:
                return 1
            cx0, cy0 = max(cx0, 0), max(cy0, 0)
            cx1, cy1 = min(cx1, self.W - 1), min(cy1, self.H - 1)
            if cx1 < cx0 or cy1 < cy0:
                return 0
        return S[cy1 + 1][cx1 + 1] - S[cy0][cx1 + 1] - S[cy1 + 1][cx0] + S[cy0][cx0]

    def 겹침(self, l, t, r, b):
        return self._합(self._S, l, t, r, b, True) > 0

    def 가시_닿음(self, x, y):
        return self._합(self._가시, x - BL, y - BH, x + BR, y - 12, False) > 0

    def 도약대_밟음(self, x, y):
        """발바닥 바로 아래가 (무색) 도약대 칸이면 그 도약대 번호."""
        if self._합(self._도약, x - FL, y, x + FR, y + 1, False) == 0:
            return None
        for n, g in enumerate(self.도약대들):
            l, t, r, b = g.사각()
            if not g.색 and abs(y - t) < 1 and x + FR > l and x - FL < r:
                return n
        return None

    def 닿은_색들(self, x, y):
        s = set()
        # 월드.gd 는 몸을 접촉_여유(3px) 만큼 부풀려 색 사망을 본다 → 검사기도 3px
        l, r, t, b = x - BL - 접촉_여유, x + BR + 접촉_여유, y - BH - 접촉_여유, y + 접촉_여유
        if self._합(self._검, l, t, r, b, False):
            s.add(2)
        if self._합(self._흰, l, t, r, b, False):
            s.add(3)
        for g, c in self.빛들:
            # 빛 띠는 돌아간 사각형일 수 있다(창문 달빛) → 분리축 검사. 빛 판정(Area2D)은 몸 그대로라 여유 없이 본다.
            if g.닿음(x - BL, y - BH, x + BR, y):
                s.add(c)
        return s

    def 설수있나(self, x, y):
        """발바닥 (x,y)에 서 있을 수 있나 — 몸이 비어 있고 발밑 어딘가에 땅."""
        if self.겹침(x - BL, y - BH, x + BR, y):
            return False
        return self.받침(x, y)

    def 받침(self, x, y, 더=0.0):
        """발 가운데 12px(+모따기) 가 전부 바닥 위인가 — 양 끝 두 점에 바닥이 있으면(칸이 32px 라 사이에 틈이 없다)."""
        return self.겹침(x + SL - 더, y, x + SL - 더 + 1, y + 1) and self.겹침(x + SR + 더 - 1, y, x + SR + 더, y + 1)

    # ── 시뮬레이션 ──────────────────────────────────────────────────────────
    def 날기(self, x, y, vx_입력, 바꿈프레임, 바꾼입력, 뗌프레임, 점프, vy0=None, 시작색=()):
        """한 번 뛰기(또는 떨어지기). 반환 (결과, 이유, 색기록)
        결과 = ("착지", x, y) | ("도약", 도약대번호, x) | ("발판", 발판번호, x) | None"""
        vy = vy0 if vy0 is not None else (-VJ * math.sqrt(self.점프배율) if 점프 else 0.0)
        최고 = y
        색 = _색기록(self.최소틈)
        if not 색.본다(0, self.닿은_색들(x, y) | set(시작색)):
            return None, 색.실패, 색
        for f in range(1, 300):
            s = vx_입력 if f < 바꿈프레임 else 바꾼입력
            if f == 뗌프레임 and vy < 0:
                vy *= 규격.점프_끊기
            vy += (G * 규격.낙하_배수 if vy > 0 else G) * DT
            # x 이동
            nx = x + s * VX * DT
            if self.겹침(nx - BL, y - BH, nx + BR, y):
                # [2026-10-05] 막히면 그 자리에 서는 게 아니라 엔진(move_and_slide)처럼 벽에 **딱 붙는다** —
                #   안 붙이면 2px 떨어진 채로 남아 '검정 판 옆면에 닿아 죽는' 경우를 놓친다(엔진 재생에서 발견).
                if s > 0:
                    nx = math.ceil((x + BR) / C) * C - BR - 0.01
                else:
                    nx = math.floor((x - BL) / C) * C + BL + 0.01
                if self.겹침(nx - BL, y - BH, nx + BR, y):
                    nx = x
            x = nx
            # y 이동 — 한 번에 16px 넘게 움직이지 않게 잘라서(빠른 낙하가 얇은 판을 뚫지 않게)
            남은 = vy * DT
            조각 = max(1, math.ceil(abs(남은) / 16.0))
            for _ in range(조각):
                ny = y + 남은 / 조각
                if vy > 0:
                    # 움직이는 발판 윗면을 지나치나(위상 어디든 — 기다려서 맞춘다고 본다)
                    for n, g in enumerate(self.발판들):
                        for l, t, r, b in g.위치들():
                            if y <= t <= ny and x + SL - self.착지여유 >= l and x + SR + self.착지여유 <= r and not self.겹침(x - BL, t - BH, x + BR, t):
                                if t - 최고 > 규격.치명_낙하:
                                    return None, "낙하사", 색
                                if not 색.본다(f, self.닿은_색들(x, t) | {2}):
                                    return None, 색.실패, 색
                                return ("발판", n, x), "착지", 색
                if vy > 0 and self.겹침(x - BL, ny - BH, x + BR, ny):
                    ny = math.floor(ny / C) * C        # 바로 위 칸 경계 = 판 윗면
                    if self.겹침(x - BL, ny - BH, x + BR, ny):
                        return None, "끼임", 색
                    if ny - 최고 > 규격.치명_낙하:
                        return None, "낙하사", 색
                    if self.가시_닿음(x, ny):
                        return None, "가시", 색
                    if not self.받침(x, ny, self.착지여유):
                        # 몸 옆구리만 모서리에 걸쳤다 — 엔진에선 비스듬한 옆면을 타고 미끄러져 떨어진다
                        return None, "미끄러짐", 색
                    if not 색.본다(f, self.닿은_색들(x, ny)):
                        return None, 색.실패, 색
                    n = self.도약대_밟음(x, ny)
                    if n is not None:
                        return ("도약", n, x), "도약", 색
                    return ("착지", x, ny), "착지", 색
                if vy < 0 and self.겹침(x - BL, ny - BH, x + BR, ny):
                    ny = (math.floor((ny - BH) / C) + 1) * C + BH
                    vy = 0.0
                    y = ny
                    break
                y = ny
            최고 = min(최고, y)
            if self.가시_닿음(x, y):
                return None, "가시", 색
            if not 색.본다(f, self.닿은_색들(x, y)):
                return None, 색.실패, 색
            if y > (self.y1) * C:
                return None, "추락", 색
        return None, "시간초과", 색


# ── [2026-10-04 2차] 도형님 규칙 ────────────────────────────────────────────
#   ① 색 비율: 칠할 수 있는 판(검정+흰+유령) 넓이 중 검정 ≤ 70% · 흰 ≤ 30%
#   ② 흰 판 머리 위: "점프하며 색을 바꾼다고 가정" — 흰 판 위 8칸(정점 5 + 몸 3)·좌우 2칸 안에 막는 칸이 없어야 한다
흰_머리위_칸 = 8
흰_옆여유_칸 = 2


def 색_비율(dn):
    셈 = {2: 0, 3: 0, 4: 0}
    for row in dn.g:
        for v in row:
            if v in 셈:
                셈[v] += 1
    합 = sum(셈.values()) or 1
    return {"검정": 셈[2] / 합, "흰": 셈[3] / 합, "유령": 셈[4] / 합, "칸": 합}


def 흰판_머리위(dn):
    문제 = []
    for k, 이름, 점, _n in dn.다각형들():
        if k != "흰":
            continue
        xs = [p[0] // C for p in 점]
        ys = [p[1] // C for p in 점]
        x0, x1, top = int(min(xs)), int(max(xs)) - 1, int(min(ys))
        for x in range(x0 - 흰_옆여유_칸, x1 + 흰_옆여유_칸 + 1):
            for y in range(top - 흰_머리위_칸, top):
                if dn.칸(x, y) != 0:
                    문제.append(f"{이름}(칸 {x0}~{x1}, 윗면 {top}) 머리 위 막힘 @({x},{y})")
                    break
            else:
                continue
            break
    return 문제


# ── [2026-10-04 3차] 연결 높이 맞추기 (도형님: "캐릭터가 걸어 나오니까 어느 정도 높이를 맞춰 줘") ──
#   스테이지가 바뀌어도 플레이어가 **화면의 같은 높이**에서 걸어 나와야 이어진 공간으로 읽힌다.
#   ProtoCamera 는 발 위치 - 60px(EYE_LIFT)을 화면 가운데로 잡고, 방(카메라 리밋) 밖으로는 안 나간다.
#   → 바닥 높이 길목은 화면 위에서 856px, 방 가운데 높이 길목은 600px 에 플레이어가 보인다.
#   나가는 길목과 들어오는 길목의 화면 높이 차가 아래 값을 넘으면 실패로 잡는다.
연결높이_허용 = 96          # px = 3칸
_화면높이 = 1080
_눈높이 = 60


def 화면높이(dn, 문):
    """이 길목에 선 플레이어 발이 화면 위에서 몇 px 에 보이나(줌 1.0 기준)."""
    발 = 문["바닥"] * C
    H = dn.h * C
    if H <= _화면높이:
        가운데 = H / 2
    else:
        가운데 = min(max(발 - _눈높이, _화면높이 / 2), H - _화면높이 / 2)
    return 발 - 가운데 + _화면높이 / 2


def 연결_높이_검사(도안들, 출력=True):
    표 = {d.이름: d for d in 도안들}
    실패, 본 = [], set()
    for d in 도안들:
        for 문 in d.문:
            연 = 문.get("연결") or []
            if not 연 or 연[0] not in 표:
                continue
            열쇠 = tuple(sorted([(d.이름, 문["이름"]), (연[0], 연[1])]))
            if 열쇠 in 본:
                continue
            본.add(열쇠)
            상대 = next((m for m in 표[연[0]].문 if m["이름"] == 연[1]), None)
            if 상대 is None:
                실패.append(f"{d.이름}/{문['이름']} → {연[0]}/{연[1]} 길목 없음")
                continue
            a, b = 화면높이(d, 문), 화면높이(표[연[0]], 상대)
            ok = abs(a - b) <= 연결높이_허용
            if 출력:
                print(f"  {'○' if ok else '×'} {d.이름.replace('쳅터1_', '')}/{문['이름']} {a:.0f}px ↔ {연[0].replace('쳅터1_', '')}/{연[1]} {b:.0f}px (차 {abs(a - b):.0f})")
            if not ok:
                실패.append(f"연결 높이 차 {abs(a - b):.0f}px: {d.이름}/{문['이름']}({a:.0f}) ↔ {연[0]}/{연[1]}({b:.0f})")
    return 실패


def 입력묶음(점프):
    out = []
    for s in (-1, 0, 1):
        조합 = {(999, s)}
        for k in (8, 18):
            조합.add((k, 0))
            조합.add((k, -s))
            if s == 0:
                조합.add((k, 1))
                조합.add((k, -1))
        for 바꿈, s2 in sorted(조합):
            for 뗌 in ((999, 12) if 점프 else (999,)):
                out.append((s, 바꿈, s2, 뗌))
    return out


점프_입력 = 입력묶음(True)
낙하_입력 = 입력묶음(False)


def 구간들(m):
    """걸을 수 있는 바닥 구간 목록 [(행, x왼, x오른)] — 8px 간격으로 훑는다.
    두 색이 같이 닿는 자리 · 가시 · 무색 도약대 위(서 있으면 튄다)는 끊는다."""
    out = []
    for cy in range(1, m.dn.h):
        y = cy * C
        # [2026-10-05] 방 밖 굴(길목 터널)은 연결구 판정 자리라 서 있는 자리로 치지 않는다
        #   (엔진 재생에서 굴 안 출발점이 전환을 일으켜 스테이지가 바뀌었다)
        #   연결구 판정은 벽 안쪽 면에서 바깥으로 발동_깊이(56px) 넘어선 곳부터 → 몸이 거기 안 닿는 데까지만 센다.
        x = m.dn.벽["왼"] * C - 발동_깊이 + BL + 2
        끝x = (m.dn.w - m.dn.벽["오른"]) * C + 발동_깊이 - BR - 2
        시작 = None
        while x <= 끝x:
            ok = (m.설수있나(x, y) and len(m.닿은_색들(x, y)) < 2 and not m.가시_닿음(x, y)
                  and m.도약대_밟음(x, y) is None)
            if ok and 시작 is None:
                시작 = x
            if (not ok) and 시작 is not None:
                out.append((cy, 시작, x - 8))
                시작 = None
            x += 8
        if 시작 is not None:
            out.append((cy, 시작, x - 8))
    return out


def 찾기(구간, x, y):
    cy = round(y / C)
    for i, (r, a, b) in enumerate(구간):
        if r == cy and a - 2 <= x <= b + 2:
            return i
    return None


class 그래프:
    """노드 = 바닥 구간(0..n-1) · 도약대(n..) · 움직이는 발판(n+P..). 간선 = 실제로 시뮬한 비행."""

    def __init__(self, m, 구간):
        self.m, self.구간 = m, 구간
        self.n = len(구간)
        self.P = len(m.도약대들)
        self.M = len(m.발판들)

    def 노드(self, 결과):
        if 결과 is None:
            return None
        if 결과[0] == "착지":
            return 찾기(self.구간, 결과[1], 결과[2])
        if 결과[0] == "도약":
            return self.n + 결과[1]
        return self.n + self.P + 결과[1]

    def 이름(self, 노드):
        if 노드 < self.n:
            cy, a, b = self.구간[노드]
            return f"바닥(행 {cy}, 칸 {a / C:.0f}~{b / C:.0f})"
        if 노드 < self.n + self.P:
            return f"도약대{self.m.도약대들[노드 - self.n].i}"
        return f"움직이는발판{self.m.발판들[노드 - self.n - self.P].i}"

    def 출발들(self, 노드):
        """이 노드에서 쏠 비행들: (x, y, 점프, vy0, 시작색, 입력목록)"""
        m = self.m
        if 노드 < self.n:
            cy, a, b = self.구간[노드]
            y = cy * C
            out = []
            for x in sorted(set([a, b] + list(range(int(a), int(b) + 1, 96)))):
                out.append((x, y, True, None, (), 점프_입력))
            for x, 방향 in ((a, -1), (b, 1)):
                out.append((x + 방향 * 4, y, False, None, (), [i for i in 낙하_입력 if i[0] == 방향]))
            return out
        if 노드 < self.n + self.P:
            g = m.도약대들[노드 - self.n]
            l, t, r, b = g.사각()
            시작색 = (기믹모듈.격자색[g.색],) if g.색 else ()
            return [(x, t, True, -g.속도, 시작색, 점프_입력) for x in (l + FL, (l + r) / 2, r - FR)]
        g = m.발판들[노드 - self.n - self.P]
        out = []
        for l, t, r, b in g.위치들():
            for x in sorted(set([l, r] + list(range(int(l), int(r) + 1, 96)))):
                if not m.겹침(x - BL, t - BH, x + BR, t):
                    out.append((x, t, True, None, (2,), 점프_입력))
            for x, 방향 in ((l - FR - 1, -1), (r + FL + 1, 1)):
                out.append((x + 방향 * 4, t, False, None, (2,), [i for i in 낙하_입력 if i[0] == 방향]))
        return out

    def 덧간선(self, 노드):
        """비행 없이 건너가는 간선 — 색 도약대 위 구간에서 색만 바꾸면 튄다."""
        if 노드 >= self.n:
            return []
        cy, a, b = self.구간[노드]
        out = []
        for k, g in enumerate(self.m.도약대들):
            l, t, r, _b = g.사각()
            if g.색 and abs(cy * C - t) < 1 and b + FR > l and a - FL < r:
                out.append(self.n + k)
        return out

    def 도달(self, 시작노드들):
        본 = {}
        큐 = []
        for i in 시작노드들:
            if i is not None and i not in 본:
                본[i] = None
                큐.append(i)
        while 큐:
            i = 큐.pop(0)
            for j in self.덧간선(i):
                if j not in 본:
                    본[j] = (i, {"종류": "색바꿔튀기"})
                    큐.append(j)
            for x, y, 점프, vy0, 시작색, 입력들 in self.출발들(i):
                for s, 바꿈, s2, 뗌 in 입력들:
                    r, _why, 색 = self.m.날기(x, y, s, 바꿈, s2, 뗌, 점프, vy0, 시작색)
                    j = self.노드(r)
                    if j is not None and j not in 본:
                        본[j] = (i, {"종류": "비행", "출발": [x, y], "점프": 점프, "vy0": vy0,
                                     "입력": [s, 바꿈, s2, 뗌], "첫색": 색.첫색, "전환": 색.전환,
                                     "여유": 색.여유, "끝": list(r[1:]) if r[0] == "착지" else None,
                                     "끝노드": r[0]})
                        큐.append(j)
        return 본

    def 경로(self, 본, 끝):
        out = []
        while 본.get(끝) is not None:
            i, 정보 = 본[끝]
            out.append({**정보, "from": i, "to": 끝})
            끝 = i
        return list(reversed(out))


def 문_도착점(dn, 문):
    i = dn.문_정보(문)
    # 벽 안쪽 면에서 방 안쪽으로 2칸 들어온 곳
    return (i["안쪽면x"] - i["d"] * 2 * C, i["바닥y"])


def 문_나감점(dn, 문):
    """길목에 '닿았다' 고 치는 자리 — 벽 안쪽 면에서 바깥으로 반 칸(연결구 판정 바로 앞)."""
    i = dn.문_정보(문)
    return (i["안쪽면x"] + i["d"] * 0.5 * C, i["바닥y"])


def 검사(dn, 유령=True, 출력=True, 경로_저장=False):
    m = 지도(dn, 유령)
    구간 = 구간들(m)
    gr = 그래프(m, 구간)
    sx, sy = dn.d["시작"]
    시작점 = (sx * C + C / 2, sy * C)
    결과 = {"이름": dn.이름, "구간수": len(구간), "문": {}, "문간": {}, "도달구간": None, "실패": [], "경고": []}
    출발 = {"시작": 시작점}
    for 문 in dn.문:
        출발[문["이름"] + "에서"] = 문_도착점(dn, 문)
    for 이름, 점 in 출발.items():
        if 찾기(구간, *점) is None:
            결과["실패"].append(f"{이름}: 서 있을 수 없는 자리 {점}")
    for w in 기믹모듈.검증(dn, m.기믹):
        결과["실패"].append("기믹: " + w)
    # [2026-10-05] 판정은 두 단계:
    #   A '편한 손' — 색 전환 틈 ≥ 15프레임 · 점프 최고 높이 95%. **모든 길목 + 모든 바닥**이 여기서 닿아야 통과.
    #     (도형님 "점프로도 못 올라가": 물리로는 되는데 사람 손으로는 안 되는 자리, 닿지도 않는데 밟을 것처럼 보이는 판을 잡는다)
    #   B '실제 물리' — 점프 100% · 틈 ≥ 15프레임. 경로 요약·엔진 재생 입력은 이쪽(엔진 점프는 늘 100% 이므로).
    def 한판(최소틈, 점프배율, 착지여유=0.0):
        m.최소틈 = 최소틈
        m.점프배율 = 점프배율
        m.착지여유 = 착지여유
        본_시작 = gr.도달([찾기(구간, *시작점)])
        문결과, 문간, 경로들 = {}, {}, {}
        for 문 in dn.문:
            j = 찾기(구간, *문_나감점(dn, 문))
            문결과[문["이름"]] = j is not None and j in 본_시작
            if 문결과[문["이름"]]:
                경로들["시작→" + 문["이름"]] = gr.경로(본_시작, j)
        for 문 in dn.문:
            본 = gr.도달([찾기(구간, *문_도착점(dn, 문))])
            for 다른 in dn.문:
                if 다른 is 문:
                    continue
                j = 찾기(구간, *문_나감점(dn, 다른))
                ok = j is not None and j in 본
                문간[f"{문['이름']}→{다른['이름']}"] = ok
                if ok:
                    경로들[f"{문['이름']}→{다른['이름']}"] = gr.경로(본, j)
        return 본_시작, 문결과, 문간, 경로들

    본A, 문A, 문간A, _경로A = 한판(색전환_빠듯_프레임, 편한_점프_높이)
    본_시작, 문결과, 문간, 경로들 = 한판(색전환_빠듯_프레임, 1.0, 착지_더여유)
    for k, ok in 문A.items():
        if not ok and 문결과.get(k):
            결과["실패"].append(f"시작 → {k}: 실제 물리로는 되지만 '편한 손'(점프 95%·색 틈 15f)으로는 못 감 — 너무 빠듯")
    for k, ok in 문간A.items():
        if not ok and 문간.get(k):
            결과["경고"].append(f"{k}: 편한 손으로는 못 감(되돌아가기 길)")
    for i, (cy, a, b) in enumerate(구간):
        if b - a >= 24 and i not in 본A:
            결과["실패"].append(f"못 닿는 바닥: 행 {cy} · 칸 {a / C:.0f}~{b / C:.0f} — 밟을 것처럼 보이는데 못 간다(편한 손 기준)")
    결과["도달구간"] = {i for i in 본_시작 if i < gr.n}
    결과["도달기믹"] = {gr.이름(i) for i in 본_시작 if i >= gr.n}
    결과["문"], 결과["문간"] = 문결과, 문간
    for 이름, ok in 문결과.items():
        # [2026-10-05] 닫힌 길목(연결 없음)도 시작에서 닿아야 한다 — 10 굴뚝 꼭대기처럼 '다음 도안 자리' 이기 때문.
        if not ok:
            결과["실패"].append(f"시작 → {이름} 도달 못 함")
    # 기믹을 아무도 못 쓰면(닿지 못하면) 장식일 뿐 — 알려 준다
    for k in range(gr.P + gr.M):
        if gr.n + k not in 본_시작:
            결과["경고"].append(f"{gr.이름(gr.n + k)} 에 시작에서 닿지 못함")
    # 경로 요약: 색 전환이 필요한 비행 · 가장 짧은 틈
    요약 = {}
    for 이름, 길 in 경로들.items():
        전환 = [s for s in 길 if s.get("전환")]
        틈 = [s["여유"] for s in 길 if s.get("여유") is not None]
        기믹 = sorted({gr.이름(s["to"]) for s in 길 if s["to"] >= gr.n})
        요약[이름] = {"비행": len(길), "색전환": len(전환), "최소틈": min(틈) if 틈 else None, "기믹": 기믹}
        if 틈 and min(틈) < 색전환_빠듯_프레임:
            결과["경고"].append(f"{이름}: 색 전환 틈 {min(틈)}프레임(빠듯 — {색전환_빠듯_프레임} 미만)")
    결과["경로요약"] = 요약
    비 = 색_비율(dn)
    결과["색비율"] = 비
    if 비["칸"] > 0 and (비["검정"] > 0.70 + 1e-9 or 비["흰"] > 0.30 + 1e-9):
        결과["실패"].append(f"색 비율 초과: 검정 {비['검정']:.0%} · 흰 {비['흰']:.0%} (최대 70% · 30%)")
    for w in 흰판_머리위(dn):
        결과["실패"].append("흰 판 머리 위: " + w)
    if 경로_저장 and 유령:
        os.makedirs(경로폴더, exist_ok=True)
        with open(os.path.join(경로폴더, dn.이름 + ".json"), "w", encoding="utf-8") as f:
            json.dump({"이름": dn.이름, "씬": f"res://scenes/쳅터1/스테이지/{dn.이름}.tscn",
                       "구간": 구간, "노드수": [gr.n, gr.P, gr.M], "경로": 경로들}, f, ensure_ascii=False)
    if 출력:
        표 = " · ".join(f"{k}{'○' if v else '×'}" for k, v in {**결과["문"], **결과["문간"]}.items())
        print(f"[{'유령칠함' if 유령 else '칠없이'}] {dn.이름}: 구간 {len(구간)} · 닿음 {len(결과['도달구간'])} · 검정 {비['검정']:.0%} 흰 {비['흰']:.0%} 유령 {비['유령']:.0%} · {표}")
        for 이름, s in 요약.items():
            if 이름.startswith("시작→"):
                틈 = f" · 최소 틈 {s['최소틈']}f" if s["최소틈"] is not None else ""
                print(f"    {이름}: 비행 {s['비행']} · 색 전환 {s['색전환']}{틈}" + (f" · 기믹 {', '.join(s['기믹'])}" if s["기믹"] else ""))
        for f in 결과["실패"]:
            print("    ×", f)
        for w in 결과["경고"]:
            print("    ⚠", w)
    결과["구간"] = 구간
    return 결과


def main():
    이름들 = [a for a in sys.argv[1:] if not a.startswith("--")]
    전부 = 도안모듈.모두_읽기(도안폴더)
    실패 = 0
    for dn in 전부:
        if 이름들 and dn.이름 not in 이름들:
            continue
        for w in dn.경고:
            print("    ⚠", w)
        r = 검사(dn, True, 경로_저장=True)
        실패 += len(r["실패"])
        if "--유령없이" in sys.argv:
            검사(dn, False)
    if not 이름들:
        print("연결 높이(화면에서 걸어 나오는 높이):")
        h = 연결_높이_검사(전부)
        for m in h:
            print("    ×", m)
        실패 += len(h)
    print("실패 합계:", 실패)
    return 1 if 실패 else 0


if __name__ == "__main__":
    sys.exit(main())
