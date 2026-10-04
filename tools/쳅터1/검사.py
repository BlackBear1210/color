# -*- coding: utf-8 -*-
"""
쳅터1 도안 도달성 검사 — 2026-10-04 Claude

엔진을 열지 않고 player.gd 의 점프 물리를 그대로 흉내 낸다(60Hz).
  · 몸 = 44×97 사각형(발바닥 = 원점), 상승 중력 1287 · 낙하 ×2.4 · 점프 초속 642 · 이동 390
  · 점프 키 일찍 떼기(×0.4), 공중에서 방향 바꾸기·멈추기를 섞은 입력 묶음으로 시뮬레이션
  · 바닥 위를 걸을 수 있는 구간(세그먼트)을 노드로 BFS
  · 유령판은 '칠했다고 치고' 밟힌다(기본). --유령없이 로 칠하기 없이도 되는지 본다.
  · 색은 언제든 바꿀 수 있으므로 무시한다. 대신 '검정과 흰이 동시에 몸에 닿는 자리'는 죽는 자리로 뺀다.
  · 가시에 닿거나 치명 낙하(1500px)면 그 착지는 버린다.

⚠ 근사다. 실제 엔진의 move_and_slide·코요테 타임·경사는 다르다 — "엔진 미실행 정적 검사".

사용
  python tools/쳅터1/검사.py                 # 도안 전부
  python tools/쳅터1/검사.py 쳅터1_03_방_서재   # 하나만
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import 규격  # noqa: E402
import 도안 as 도안모듈  # noqa: E402

C = 규격.칸
HW = 규격.몸_폭 / 2
BH = 규격.몸_키
DT = 1.0 / 60.0
G = 규격.중력
VJ = 규격.점프_초속
VX = 규격.이동속도

저장소 = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
도안폴더 = os.path.join(저장소, "scenes", "쳅터1", "도안")


class 지도:
    def __init__(self, dn, 유령_밟힘=True):
        import numpy as np
        self.dn = dn
        x0, y0, x1, y1 = dn.확장_범위()
        self.x0, self.y0, self.x1, self.y1 = x0, y0, x1, y1
        self.W, self.H = x1 - x0, y1 - y0
        k = np.array([[dn.칸(x, y) for x in range(x0, x1)] for y in range(y0, y1)], dtype=np.int8)
        self.k = k
        self.유령 = 유령_밟힘
        단단 = (k != 0) & ((k != 4) | 유령_밟힘)
        가시 = np.zeros_like(단단)
        for gx, gy, gw in dn.d.get("가시", []):
            가시[gy - 1 - y0, gx - x0: gx + gw - x0] = True
        self._S = self._적분(단단)
        self._가시 = self._적분(가시)
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
        return self._합(self._가시, x - HW, y - BH, x + HW, y - 12, False) > 0

    def 닿은_색들(self, x, y):
        s = set()
        l, r, t, b = x - HW - 1, x + HW + 1, y - BH - 1, y + 1
        if self._합(self._검, l, t, r, b, False):
            s.add(2)
        if self._합(self._흰, l, t, r, b, False):
            s.add(3)
        return s

    def 설수있나(self, x, y):
        """발바닥 (x,y)에 서 있을 수 있나 — 몸이 비어 있고 발밑 어딘가에 땅."""
        if self.겹침(x - HW, y - BH, x + HW, y):
            return False
        return self.겹침(x - HW, y, x + HW, y + 1)

    # ── 시뮬레이션 ──────────────────────────────────────────────────────────
    def 날기(self, x, y, vx_입력, 바꿈프레임, 바꾼입력, 뗌프레임, 점프):
        vy = -VJ if 점프 else 0.0
        최고 = y
        for f in range(300):
            s = vx_입력 if f < 바꿈프레임 else 바꾼입력
            if 점프 and f == 뗌프레임 and vy < 0:
                vy *= 규격.점프_끊기
            vy += (G * 규격.낙하_배수 if vy > 0 else G) * DT
            # x 이동
            nx = x + s * VX * DT
            if self.겹침(nx - HW, y - BH, nx + HW, y):
                nx = x
            x = nx
            # y 이동 — 한 번에 16px 넘게 움직이지 않게 잘라서(빠른 낙하가 얇은 판을 뚫지 않게)
            남은 = vy * DT
            조각 = max(1, math.ceil(abs(남은) / 16.0))
            for _ in range(조각):
                ny = y + 남은 / 조각
                if vy > 0 and self.겹침(x - HW, ny - BH, x + HW, ny):
                    ny = math.floor(ny / C) * C        # 바로 위 칸 경계 = 판 윗면
                    if self.겹침(x - HW, ny - BH, x + HW, ny):
                        return None, "끼임"
                    if ny - 최고 > 규격.치명_낙하:
                        return None, "낙하사"
                    if self.가시_닿음(x, ny):
                        return None, "가시"
                    return (x, ny), "착지"
                if vy < 0 and self.겹침(x - HW, ny - BH, x + HW, ny):
                    ny = (math.floor((ny - BH) / C) + 1) * C + BH
                    vy = 0.0
                    y = ny
                    break
                y = ny
            최고 = min(최고, y)
            if self.가시_닿음(x, y):
                return None, "가시"
            if y > (self.y1) * C:
                return None, "추락"
        return None, "시간초과"


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
    """걸을 수 있는 바닥 구간 목록 [(행, x왼, x오른)] — 4px 간격으로 훑는다."""
    out = []
    for cy in range(1, m.dn.h):
        y = cy * C
        x = -규격.문_터널 * C + HW
        시작 = None
        while x <= (m.dn.w + 규격.문_터널) * C - HW:
            ok = m.설수있나(x, y) and len(m.닿은_색들(x, y)) < 2 and not m.가시_닿음(x, y)
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


def 도달(m, 구간, 시작들):
    본 = set()
    큐 = []
    for x, y in 시작들:
        i = 찾기(구간, x, y)
        if i is not None and i not in 본:
            본.add(i)
            큐.append(i)
    while 큐:
        i = 큐.pop()
        cy, a, b = 구간[i]
        y = cy * C
        점들 = sorted(set([a, b] + list(range(int(a), int(b) + 1, 96))))
        for x in 점들:
            for s, 바꿈, s2, 뗌 in 점프_입력:
                r, _ = m.날기(x, y, s, 바꿈, s2, 뗌, True)
                if r:
                    j = 찾기(구간, *r)
                    if j is not None and j not in 본:
                        본.add(j)
                        큐.append(j)
        for x, 방향 in ((a, -1), (b, 1)):
            for s, 바꿈, s2, 뗌 in 낙하_입력:
                if s != 방향:
                    continue
                r, _ = m.날기(x + 방향 * 4, y, s, 바꿈, s2, 뗌, False)
                if r:
                    j = 찾기(구간, *r)
                    if j is not None and j not in 본:
                        본.add(j)
                        큐.append(j)
    return 본


def 문_도착점(dn, 문):
    i = dn.문_정보(문)
    # 벽 안쪽 면에서 방 안쪽으로 2칸 들어온 곳
    return (i["안쪽면x"] - i["d"] * 2 * C, i["바닥y"])


def 문_나감점(dn, 문):
    i = dn.문_정보(문)
    return (i["안쪽면x"] + i["d"] * 1 * C, i["바닥y"])


def 검사(dn, 유령=True, 출력=True):
    m = 지도(dn, 유령)
    구간 = 구간들(m)
    sx, sy = dn.d["시작"]
    시작점 = (sx * C + C / 2, sy * C)
    결과 = {"이름": dn.이름, "구간수": len(구간), "문": {}, "문간": {}, "도달구간": None, "실패": []}
    출발 = {"시작": 시작점}
    for 문 in dn.문:
        출발[문["이름"] + "에서"] = 문_도착점(dn, 문)
    for 이름, 점 in 출발.items():
        if 찾기(구간, *점) is None:
            결과["실패"].append(f"{이름}: 서 있을 수 없는 자리 {점}")
    도달_시작 = 도달(m, 구간, [시작점])
    결과["도달구간"] = 도달_시작
    for 문 in dn.문:
        j = 찾기(구간, *문_나감점(dn, 문))
        ok = j is not None and j in 도달_시작
        결과["문"][문["이름"]] = ok
        if not ok and 문.get("연결"):
            결과["실패"].append(f"시작 → {문['이름']} 도달 못 함")
    for 문 in dn.문:
        본 = 도달(m, 구간, [문_도착점(dn, 문)])
        for 다른 in dn.문:
            if 다른 is 문:
                continue
            j = 찾기(구간, *문_나감점(dn, 다른))
            ok = j is not None and j in 본
            결과["문간"][f"{문['이름']}→{다른['이름']}"] = ok
    비 = 색_비율(dn)
    결과["색비율"] = 비
    if 비["칸"] > 0 and (비["검정"] > 0.70 + 1e-9 or 비["흰"] > 0.30 + 1e-9):
        결과["실패"].append(f"색 비율 초과: 검정 {비['검정']:.0%} · 흰 {비['흰']:.0%} (최대 70% · 30%)")
    for m in 흰판_머리위(dn):
        결과["실패"].append("흰 판 머리 위: " + m)
    if 출력:
        표 = " · ".join(f"{k}{'○' if v else '×'}" for k, v in {**결과["문"], **결과["문간"]}.items())
        print(f"[{'유령칠함' if 유령 else '칠없이'}] {dn.이름}: 구간 {len(구간)} · 닿음 {len(도달_시작)} · 검정 {비['검정']:.0%} 흰 {비['흰']:.0%} 유령 {비['유령']:.0%} · {표}")
        for f in 결과["실패"]:
            print("    ×", f)
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
        r = 검사(dn, True)
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
