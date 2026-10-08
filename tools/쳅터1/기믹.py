# -*- coding: utf-8 -*-
"""
쳅터1 기믹(장치) — 도안 "기믹" 항목 해석 · 2026-10-05 Claude

도형님 지시(10-05): "장애물 배치들과 기믹들을 추가로 만들고 시뮬도 돌려서 색반전 기믹이나 막히는 구간이 있는지 확인"
→ 도안 JSON 에 "기믹" 목록을 적으면 검사(시뮬)·씬·도면·미리보기가 **이 파일 하나**의 해석을 같이 쓴다.
  (같은 숫자를 네 군데서 따로 계산하면 언젠가 어긋난다 — 그래서 모았다)

▣ 도안에 적는 법 (좌표는 전부 칸, 1칸 = 32px)
  "기믹": [
    {"종류": "빛줄기", "x": 60, "y": 5, "길이": 14, "방향": "아래", "색": "흰", "두께": 2},
        ← 색 빛줄기(색레이저). 빛 안에서 몸 색이 빛 색과 다르면 죽는다.
          x,y = 빛이 차지하는 사각형의 왼쪽 위 칸. "방향" = 빛이 나오는 쪽(아래면 위에서 쏜다).
          "주기": 0(기본) = 색 고정 → 시뮬이 "그 색이어야 지나간다" 로 검사한다.
          "주기": 3 = 3초마다 흑↔백, "점멸": true = 켜짐/꺼짐만 → 기다리면 되므로 시뮬은 막지 않는다.
    {"종류": "도약대", "x": 30, "바닥": 40, "폭": 4, "오름": 12},
        ← 밟으면 튀어 오른다. 바닥 = 도약대가 놓이는 바닥 칸 y. 오름 = 튀어 오르는 높이(칸).
          "색": "검정"|"흰" 을 주면 그 색일 때만 튄다(반대색이면 그냥 발판) — 색 전환 퍼즐.
    {"종류": "움직이는발판", "x": 80, "y": 30, "폭": 5, "방향": "좌우", "거리": 10, "왕복": 4.0},
        ← 사인파 왕복. x,y = 출발 끝(왼쪽/위)의 윗면 왼쪽 칸. 좌우면 오른쪽으로, 상하면 아래로 "거리"칸.
          안 칠하면 검정이다(흰 몸이 타면 죽는다 — 움직이는발판.gd · 색규칙.gd). 시뮬도 검정으로 본다.
  ]

▣ 엔진 쪽 장면 (scenes/집/스마트월드_장애물/ — 공용 키트, 경로 바꾸지 말 것)
  빛줄기 → 색레이저.tscn · 도약대 → 도약대.tscn · 움직이는발판 → 움직이는발판.tscn
"""
import math

import 규격

C = 규격.칸
색번호 = {"검정": 0, "흰": 1}          # ColorDefs.BLACK / WHITE
격자색 = {"검정": 2, "흰": 3}          # 도안 격자의 지형 번호(검사.py 의 색 집합과 같은 번호)
발판_두께 = 28.0                       # 움직이는발판 기본 두께(px) — 윗면이 칸 경계에 오게 가운데를 +14 에 둔다
도약대_높이 = 46.0                     # 도약대.gd 기본값. 실제 발판(StaticBody)은 그 절반(23px)
위상수 = 5                             # 움직이는 발판을 몇 군데 위치로 끊어 보나(0, ¼, ½, ¾, 끝)


def 도약속도(오름칸):
    """오름(칸) 만큼 튀어 오르는 초속(px/s). 상승 중력 = 규격.중력(플레이어 상승_배수 1.0)."""
    return math.sqrt(2.0 * 규격.중력 * 오름칸 * C)


근원번호 = {"창문": 0, "천장틈": 1, "그을음": 2}

# [2026-10-07] 창문 빛 부피 — scripts/쳅터1/창문빛.gd 의 같은 이름 상수와 맞출 것
창문_유리 = (86.0, 61.0, 171.0, 319.0)   # 창문 그림(256×384) 안 유리 바깥틀 l,t,r,b (px)
창문_원점 = (128.0, 192.0)               # 빛 원점 = 창문 그림 이 점
창문_최대 = 2400.0


def _볼록껍질(점):
    """모노톤 체인 볼록 껍질(시계/반시계 상관없이 닫히지 않은 목록)."""
    p = sorted(set(점))
    if len(p) < 3:
        return p
    def 외적(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    아래, 위 = [], []
    for q in p:
        while len(아래) >= 2 and 외적(아래[-2], 아래[-1], q) <= 0:
            아래.pop()
        아래.append(q)
    for q in reversed(p):
        while len(위) >= 2 and 외적(위[-2], 위[-1], q) <= 0:
            위.pop()
        위.append(q)
    return 아래[:-1] + 위[:-1]


def _볼록_사각_겹침(다각형, l, t, r, b):
    """볼록 다각형 ↔ 축정렬 사각형 분리축 검사. 맞닿기만 하면 겹침 아님(엔진 Area2D 와 같은 쪽으로)."""
    사각 = [(l, t), (r, t), (r, b), (l, b)]
    축들 = [(1.0, 0.0), (0.0, 1.0)]
    n = len(다각형)
    for i in range(n):
        x1, y1 = 다각형[i]
        x2, y2 = 다각형[(i + 1) % n]
        축들.append((y1 - y2, x2 - x1))
    for ax, ay in 축들:
        a = [x * ax + y * ay for x, y in 다각형]
        c = [x * ax + y * ay for x, y in 사각]
        if max(a) <= min(c) or max(c) <= min(a):
            return False
    return True


class 빛줄기:
    """[2026-10-05 2차] 창문 달빛 · 천장 틈 빛 기둥 · 그을음 기둥 — 비스듬한 빛도 된다.
    도안: {"종류":"빛줄기","근원":"창문","x":40,"y":9,"각도":68,"두께":3}
      x,y = 빛이 나오는 점(칸, 소수 가능) · 각도 = 0 오른쪽 · 90 아래 · 180 왼쪽 · "길이" 를 안 주면
      빛이 처음 닿는 지형(구조·검정·흰 — 유령판은 통과)까지 **자동**으로 뻗는다.
      "색" 을 안 주면 그을음 = 검정, 나머지 = 흰. "점멸": true = 구름이 달을 가리듯 켜졌다 꺼짐.
    옛 형식({"방향":"아래","x","y"= 왼쪽 위 칸,"길이"})도 그대로 읽는다."""

    def __init__(self, g, i, dn=None):
        self.i = i
        self.주기 = float(g.get("주기", 0))
        self.위상 = float(g.get("위상", 0))
        self.점멸 = bool(g.get("점멸", False))
        self.두께 = g.get("두께", 2)
        if "근원" in g:
            self.근원 = g["근원"]
            self.색 = g.get("색", "검정" if self.근원 == "그을음" else "흰")
            self.원점 = (g["x"] * C, g["y"] * C)
            self.각도 = float(g.get("각도", 90))
            self.길이 = g["길이"] * C if "길이" in g else self._자동길이(dn)
            # ★[2026-10-07 Claude] 창문 빛 = 창유리 전체가 빛 방향으로 쓸고 간 부피(엔진 scripts/쳅터1/창문빛.gd 와 같은 계산).
            #   도형님 "빛이 기둥으로 보인다 — 창문 레이어에 맞게, 창틀에서 새어 나오게" → 판정도 그 부피다.
            #   창문 그림(256×384)은 만들기.py 창문_가구 가 원점 = 그림 (128,192) 이 되게 건다.
            self.빛면 = self._창문_부피(dn) if self.근원 == "창문" and dn is not None else None
        else:
            # 옛 형식: x,y = 빛 사각형 왼쪽 위 칸
            self.근원 = "천장틈"
            self.색 = g.get("색", "흰")
            방향 = g.get("방향", "아래")
            세로 = 방향 in ("아래", "위")
            w, h = (self.두께, g["길이"]) if 세로 else (g["길이"], self.두께)
            l, t, r, b = g["x"] * C, g["y"] * C, (g["x"] + w) * C, (g["y"] + h) * C
            self.원점, self.각도 = {"아래": (((l + r) / 2, t), 90), "위": (((l + r) / 2, b), 270),
                                 "오른": ((l, (t + b) / 2), 0)}.get(방향, ((r, (t + b) / 2), 180))
            self.길이 = g["길이"] * C
            self.빛면 = None

    # ── [2026-10-07] 창문 빛 부피 ────────────────────────────────────────────
    def _창문_부피(self, dn):
        """유리 바깥틀 네 꼭짓점 + (빛에 수직인 방향으로 가장 바깥) 두 꼭짓점에서 쏜 광선의 착지점 → 볼록 껍질(px)."""
        ox, oy = self.원점
        l, t = ox - 창문_원점[0] + 창문_유리[0], oy - 창문_원점[1] + 창문_유리[1]
        r, b = ox - 창문_원점[0] + 창문_유리[2], oy - 창문_원점[1] + 창문_유리[3]
        구석 = [(l, t), (r, t), (r, b), (l, b)]
        (ux, uy), (vx, vy) = self._축()
        최소 = min(구석, key=lambda p: p[0] * vx + p[1] * vy)
        최대 = max(구석, key=lambda p: p[0] * vx + p[1] * vy)
        점 = list(구석)
        for sx, sy in (최소, 최대):
            d = self._광선길이(dn, sx, sy, ux, uy)
            점.append((sx + ux * d, sy + uy * d))
        return _볼록껍질(점)

    @staticmethod
    def _광선길이(dn, sx, sy, ux, uy):
        """(sx,sy) 에서 (ux,uy) 로 지형(구조·검정·흰 — 유령판은 통과)까지(px). 엔진 창문_최대 2400px 와 같은 상한."""
        d = 2.0
        단단 = lambda dd: dn.칸(math.floor((sx + ux * dd) / C), math.floor((sy + uy * dd) / C)) in (1, 2, 3)
        while d < 창문_최대 and 단단(d):        # 창틀 모서리가 천장 속이면 빠져나올 때까지 건너뛴다
            d += 2.0
        while d < 창문_최대:
            if 단단(d):
                return d
            d += 2.0
        return 창문_최대

    def _축(self):
        a = math.radians(self.각도)
        return (math.cos(a), math.sin(a)), (-math.sin(a), math.cos(a))

    def _자동길이(self, dn):
        (ux, uy), _ = self._축()
        ox, oy = self.원점
        d = 4.0
        while d < 200 * C:
            x, y = ox + ux * d, oy + uy * d
            if dn.칸(math.floor(x / C), math.floor(y / C)) in (1, 2, 3):
                return d
            d += 4.0
        return d

    @property
    def 고정(self):
        """색이 고정이고 늘 켜져 있으면 True — 시뮬이 '이 색이어야 지나간다' 로 본다."""
        return self.주기 <= 0 and not self.점멸

    def 꼭짓점(self):
        if self.빛면:
            return list(self.빛면)          # [2026-10-07] 창문 빛 = 유리가 쓸고 간 부피
        (ux, uy), (vx, vy) = self._축()
        ox, oy = self.원점
        h = self.두께 * C / 2
        L = self.길이
        return [(ox + vx * h, oy + vy * h), (ox + ux * L + vx * h, oy + uy * L + vy * h),
                (ox + ux * L - vx * h, oy + uy * L - vy * h), (ox - vx * h, oy - vy * h)]

    def 사각(self):
        xs = [p[0] for p in self.꼭짓점()]
        ys = [p[1] for p in self.꼭짓점()]
        return (min(xs), min(ys), max(xs), max(ys))

    def 닿음(self, l, t, r, b):
        """몸 사각형(l,t,r,b)과 빛 띠(돌아간 사각형)가 겹치나 — 분리축 검사(축 4개)."""
        L0, T0, R0, B0 = self.사각()
        if r <= L0 or l >= R0 or b <= T0 or t >= B0:
            return False
        if self.빛면:
            return _볼록_사각_겹침(self.빛면, l, t, r, b)
        (ux, uy), (vx, vy) = self._축()
        ox, oy = self.원점
        h = self.두께 * C / 2
        구석 = [(l, t), (r, t), (r, b), (l, b)]
        pu = [(x - ox) * ux + (y - oy) * uy for x, y in 구석]
        if max(pu) <= 0 or min(pu) >= self.길이:
            return False
        pv = [(x - ox) * vx + (y - oy) * vy for x, y in 구석]
        if max(pv) <= -h or min(pv) >= h:
            return False
        return True

    def 지나는_칸(self, 끝여유=20.0):
        """빛 가운데·양 가장자리가 지나는 칸(끝 20px 제외) — 벽을 뚫는지 검증용."""
        if self.빛면:
            return set()   # [2026-10-07] 창문 빛은 광선이 지형에서 멈추도록 계산되어 뚫지 않는다(창문 그림 자리는 배경)
        (ux, uy), (vx, vy) = self._축()
        ox, oy = self.원점
        h = self.두께 * C / 2 - 2
        out = set()
        d = 2.0
        while d < self.길이 - 끝여유:
            for s in (-h, 0.0, h):
                x, y = ox + ux * d + vx * s, oy + uy * d + vy * s
                out.add((math.floor(x / C), math.floor(y / C)))
            d += 6.0
        return out

    def 엔진값(self):
        """색레이저.gd(창문빛.gd): 원점 = 빛이 나오는 점, 각도 방향으로 길이만큼, 두께는 가운데 정렬."""
        return {"원점": self.원점, "각도": self.각도, "길이": self.길이, "두께": self.두께 * C,
                "근원": 근원번호.get(self.근원, 1)}


class 도약대:
    def __init__(self, g, i, dn=None):
        self.i = i
        self.x, self.바닥, self.폭 = g["x"], g["바닥"], g.get("폭", 4)
        self.오름 = g.get("오름", 12)
        self.색 = g.get("색")              # None = 누구나
        self.속도 = 도약속도(self.오름)

    def 칸들(self):
        """격자에서 단단한 칸으로 칠할 자리 — 바닥 바로 위 한 줄(실제 발판 23px ≈ 1칸으로 근사)."""
        return [(x, self.바닥 - 1) for x in range(self.x, self.x + self.폭)]

    def 사각(self):
        return (self.x * C, (self.바닥 - 1) * C, (self.x + self.폭) * C, self.바닥 * C)

    def 엔진값(self):
        return {"원점": ((self.x + self.폭 / 2) * C, self.바닥 * C), "폭": self.폭 * C - 8, "속도": -self.속도}


class 움직이는발판:
    def __init__(self, g, i, dn=None):
        self.i = i
        self.x, self.y, self.폭 = g["x"], g["y"], g.get("폭", 5)
        self.방향 = g.get("방향", "좌우")
        self.거리 = g.get("거리", 8)
        self.왕복 = float(g.get("왕복", 4.0))
        self.지연 = float(g.get("지연", 0.0))

    def 위치들(self):
        """위상별 윗면 사각 (l, t, r, b) px — 0, ¼ … 끝."""
        out = []
        for k in range(위상수):
            d = self.거리 * C * k / (위상수 - 1)
            dx, dy = (d, 0) if self.방향 == "좌우" else (0, d)
            l, t = self.x * C + dx, self.y * C + dy
            out.append((l, t, l + self.폭 * C, t + 발판_두께))
        return out

    def 쓸고간_칸들(self):
        """발판이 지나가는 칸 전부(지형과 겹치면 경고)."""
        x1 = self.x + self.폭 + (self.거리 if self.방향 == "좌우" else 0)
        y1 = self.y + 1 + (self.거리 if self.방향 == "상하" else 0)
        return [(x, y) for y in range(self.y, y1) for x in range(self.x, x1)]

    def 엔진값(self):
        return {"원점": ((self.x + self.폭 / 2) * C, self.y * C + 발판_두께 / 2), "크기": (self.폭 * C, 발판_두께),
                "이동거리": self.거리 * C, "이동방향": 0 if self.방향 == "좌우" else 1}


_종류 = {"빛줄기": 빛줄기, "도약대": 도약대, "움직이는발판": 움직이는발판}


def 목록(dn):
    """도안의 "기믹" → 객체 목록. 모르는 종류는 dn.경고 에 남기고 건너뛴다."""
    out = []
    세기 = {}
    for g in dn.d.get("기믹", []):
        k = g.get("종류")
        if k not in _종류:
            dn.경고.append(f"모르는 기믹 종류 {k}")
            continue
        세기[k] = 세기.get(k, 0) + 1
        out.append(_종류[k](g, 세기[k], dn))
    return out


def 검증(dn, 기믹들):
    """배치 실수 잡기 — 지형에 묻힌 기믹, 받쳐 주는 바닥 없는 도약대."""
    문제 = []
    for g in 기믹들:
        if isinstance(g, 도약대):
            for x, y in g.칸들():
                if dn.칸(x, y) != 0:
                    문제.append(f"도약대{g.i} 가 지형에 묻힘 @({x},{y})")
                    break
            if any(dn.칸(x, g.바닥) == 0 for x in range(g.x, g.x + g.폭)):
                문제.append(f"도약대{g.i} 아래 바닥이 비어 있음(바닥 {g.바닥})")
        elif isinstance(g, 움직이는발판):
            for x, y in g.쓸고간_칸들():
                if dn.칸(x, y) != 0:
                    문제.append(f"움직이는발판{g.i} 길에 지형 @({x},{y})")
                    break
            if g.왕복 < 3.0:
                문제.append(f"움직이는발판{g.i} 왕복 {g.왕복}초 < 3초(장애물 카탈로그 규칙)")
        elif isinstance(g, 빛줄기):
            # 빛은 벽에 가려지지 않고 그대로 그려진다 → 지형을 뚫고 지나가면 벽 속에 빛이 보인다
            묻힘 = sorted(c for c in g.지나는_칸() if dn.칸(*c) in (1, 2, 3))
            if 묻힘:
                문제.append(f"빛줄기{g.i} 가 지형을 뚫고 지나감 @{묻힘[0]} — 원점·각도·길이를 바꿔 빈칸에서 끝내기")
            if g.두께 * C < 규격.몸_폭:
                문제.append(f"빛줄기{g.i} 두께 {g.두께}칸 — 몸 폭보다 얇아 스쳐 지나갈 수 있다")
    return 문제
