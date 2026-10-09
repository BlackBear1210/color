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


# ── [2026-10-09 Claude] 새 기믹 — 부서지는판 · 그을음 · 열쇠조각 · 잠긴문 · 레버퍼즐 ─────────────────────────────
#   엔진 노드는 tools/쳅터1/추가기믹.py 가 "추가기믹" 묶음으로 만든다(손으로 고친 씬에도 이 묶음만 갈아 끼운다).
#   도안에 적는 법(좌표는 칸):
#     {"종류": "부서지는판", "x": 40, "y": 30, "장수": 2}       ← 윗면 칸 y · 한 장 = 3칸(96px) · 무색(두 색 다 선다)
#         ⚠ 아래는 가시·낙사·반대색이어야 한다(못 건너면 죽는다 → 죽으면 초기화). 아래가 일부러 안전하면 "아래허용": true
#     {"종류": "그을음", "x": 60, "바닥": 33, "방향": -1}           ← 둥지(잠복 자리) · 발이 닿는 바닥 칸 y
#     {"종류": "열쇠조각", "색": "검정"|"흰", "x": 70.5, "y": 12, "주인": "쳅터1_16_응접실"}  ← 조각 가운데 칸 · 주인 = 문이 있는 스테이지
#         ⚠ 근처(8칸)에 **같은 색으로 설 수 있는 발판**(검정 = 구조·검정판 · 흰 = 흰판 · 유령판은 둘 다)이 있어야 한다(도형님 10-09)
#     {"종류": "잠긴문", "연결": "오른쪽"}                          ← 이 길목을 잠근다(열쇠 스테이지 출구)
#     {"종류": "레버퍼즐", "레버": [[x, 바닥], …], "손잡이": [x, 바닥], "정답": [1, 0, 1],
#      "샹들리에": [x, y천장], "단서": [x, y], "비밀문": {"x": 가운데, "바닥": y, "밀림": 칸}, "제한시간": 초, "양초": [x, 바닥]}

class 부서지는판:
    def __init__(self, g, i, dn=None):
        self.i = i
        self.x, self.y = g["x"], g["y"]
        self.장수 = int(g.get("장수", 1))
        self.아래허용 = bool(g.get("아래허용", False))

    def 칸들(self):
        """판이 차지하는 칸 — 윗면 칸 y 한 줄(판 두께 32px ≈ 1칸). 검사기는 무색 단단한 칸으로 본다."""
        return [(x, self.y) for x in range(self.x, self.x + 3 * self.장수)]

    def 사각(self):
        return (self.x * C, self.y * C, (self.x + 3 * self.장수) * C, (self.y + 1) * C)

    def 엔진값(self):
        return {"판들": [((self.x + 1.5 + 3 * k) * C, self.y * C) for k in range(self.장수)]}


class 그을음:
    def __init__(self, g, i, dn=None):
        self.i = i
        self.x, self.바닥 = g["x"], g["바닥"]
        self.방향 = -1 if int(g.get("방향", -1)) < 0 else 1

    def 엔진값(self):
        return {"원점": ((self.x + 0.5) * C, self.바닥 * C), "방향": self.방향}


class 열쇠조각:
    def __init__(self, g, i, dn=None):
        self.i = i
        self.색 = g["색"]
        self.x, self.y = float(g["x"]), float(g["y"])
        self.주인 = g.get("주인", "")

    def 엔진값(self):
        주인 = f"res://scenes/쳅터1/스테이지/{self.주인}.tscn" if self.주인 else ""
        return {"원점": (self.x * C, self.y * C), "쪽": 0 if self.색 == "검정" else 1, "주인": 주인}


class 잠긴문:
    def __init__(self, g, i, dn=None):
        self.i = i
        self.연결 = g["연결"]


class 레버퍼즐:
    def __init__(self, g, i, dn=None):
        self.i = i
        self.g = g
        self.레버 = [tuple(v) for v in g["레버"]]
        self.손잡이 = tuple(g["손잡이"])
        self.정답 = [bool(v) for v in g.get("정답", [1, 0, 1])]
        self.샹들리에 = tuple(g["샹들리에"]) if g.get("샹들리에") else None
        self.단서 = tuple(g["단서"]) if g.get("단서") else None
        self.비밀문 = g.get("비밀문")
        self.제한시간 = float(g.get("제한시간", 0.0))
        self.양초 = tuple(g["양초"]) if g.get("양초") else None

    def 엔진값(self):
        v = {"레버": [((x + 0.5) * C, y * C) for x, y in self.레버],
             "손잡이": ((self.손잡이[0] + 0.5) * C, self.손잡이[1] * C), "정답": self.정답, "제한시간": self.제한시간}
        if self.샹들리에:
            v["샹들리에"] = (self.샹들리에[0] * C, self.샹들리에[1] * C)
            # [2026-10-09] 샹들리에는 레버 앞에 선 플레이어 화면 안에 보여야 한다(0.6초 예고가 보여야 '왜 죽었는지' 읽힌다).
            #   → 아래끝이 레버 바닥 위 9칸에 오도록 사슬 길이를 정한다(폭 224 정사각 그림 = 키 224 · 화면 위끝 = 발 − 600 근처).
            레버바닥 = min(y for _x, y in self.레버) * C
            v["샹들리에_늘어짐"] = max(96.0, 레버바닥 - 9 * C - self.샹들리에[1] * C - 224.0)
        if self.단서:
            v["단서"] = (self.단서[0] * C, self.단서[1] * C)
        if self.비밀문:
            d = self.비밀문
            v["비밀문"] = {"원점": (d["x"] * C, d["바닥"] * C), "밀림": d.get("밀림", 7) * C}
        if self.양초:
            v["양초"] = ((self.양초[0] + 0.5) * C, self.양초[1] * C)
        return v


# [2026-10-09 거미방] 빛 퍼즐 — 반딧불 몹(움직이는 광원) · 그을음 거미(거미줄로 빛을 가림) · 빛받이(요구색 빛 → 문)
#     {"종류": "반딧불몹", "멈춤": [[x, y], …], "머묾": 3, "색시간": 5, "반경": 200, "순환": "고리"|"왕복",
#      "새장": {"멈춤": 2, "레버": [x, 바닥]}}        ← 멈춤 = 몸 가운데 칸 좌표(실수 가능). 첫 멈춤에서 시작.
#     {"종류": "거미", "x", "바닥", "방향", "거미줄": [{"가": [x, y], "나": [x, y], "처음부터": true}]}
#                                                    ← 그을음 거미(둥지 = 발끝) + 칠 자리. 가 = 위 끝(들보 아래) · 나 = 아래 끝(바닥)
#     {"종류": "빛받이", "x", "y", "색": "흰"|"검정", "유지": true,
#      "문": {"x": 가운데, "바닥": y, "크기": [w, h], "밀림": [dx, dy], "모양": "창살"|"책장"}}
#                                                    ← 렌즈 가운데 칸 좌표 · 문 = 빛을 받으면 열리는 비밀문(창살)
반딧불_반경 = 200.0                    # px — 반딧불몹.gd 반경 기본값(판정·그림 같은 값)


class 반딧불몹:
    def __init__(self, g, i, dn=None):
        self.i = i
        self.멈춤 = [(float(x), float(y)) for x, y in g["멈춤"]]
        self.머묾 = float(g.get("머묾", 3.0))
        self.색시간 = float(g.get("색시간", 5.0))
        self.반경 = float(g.get("반경", 반딧불_반경))
        self.순환 = 1 if g.get("순환") == "왕복" else 0
        self.새장 = g.get("새장")

    def 길(self):
        """날아다니는 선분들(칸) — 고리면 마지막→처음까지."""
        m = self.멈춤
        쌍 = list(zip(m, m[1:]))
        if self.순환 == 0 and len(m) > 2:
            쌍.append((m[-1], m[0]))
        return 쌍

    def 엔진값(self):
        x0, y0 = self.멈춤[0]
        v = {"원점": (x0 * C, y0 * C), "멈춤들": [((x - x0) * C, (y - y0) * C) for x, y in self.멈춤],
             "머묾": self.머묾, "색시간": self.색시간, "반경": self.반경, "순환": self.순환}
        if self.새장:
            lx, ly = self.새장["레버"]
            v["새장_멈춤"] = int(self.새장["멈춤"])
            v["새장_레버"] = ((lx + 0.5) * C, ly * C)
        return v


class 그을음거미:
    """그을음 + 거미줄 자리 — 엔진은 같은 그을음.gd(거미줄들 export)를 쓴다."""
    def __init__(self, g, i, dn=None):
        self.i = i
        self.x, self.바닥 = g["x"], g["바닥"]
        self.방향 = -1 if int(g.get("방향", -1)) < 0 else 1
        self.줄 = [{"가": tuple(map(float, w["가"])), "나": tuple(map(float, w["나"])), "처음부터": bool(w.get("처음부터", False))}
                  for w in g.get("거미줄", [])]

    def 엔진값(self):
        return {"원점": ((self.x + 0.5) * C, self.바닥 * C), "방향": self.방향,
                "줄들": [{"원점": (w["가"][0] * C, w["가"][1] * C),
                         "나": ((w["나"][0] - w["가"][0]) * C, (w["나"][1] - w["가"][1]) * C),
                         "처음부터": w["처음부터"]} for w in self.줄]}


class 빛받이:
    def __init__(self, g, i, dn=None):
        self.i = i
        self.x, self.y = float(g["x"]), float(g["y"])
        self.색 = g.get("색", "흰")
        self.유지 = bool(g.get("유지", True))
        self.문 = g.get("문")

    def 엔진값(self):
        v = {"원점": (self.x * C, self.y * C), "요구색": 색번호[self.색], "유지": self.유지}
        if self.문:
            d = self.문
            w, h = d.get("크기", [3, 5])
            dx, dy = d.get("밀림", [0, -h])
            v["문"] = {"원점": (d["x"] * C, d["바닥"] * C), "크기": (w * C, h * C), "밀림": (dx * C, dy * C),
                      "모양": 1 if d.get("모양", "창살") == "창살" else 0}
        return v


# [2026-10-09] 누름계단 — 하수도 2-5 의 '발판을 누르면 벽에서 계단이 튀어나온다' (도형님: 쳅터2 장치를 다른 스테이지에)
#     {"종류": "누름계단", "발판": [x, 바닥, 폭], "작동": "누르는동안"|"유지", "상자": [x, 바닥],
#      "판들": [{"x", "y", "w", "h", "나옴": 칸, "지연": 초}, …]}
#     ← 발판 = 바닥 칸 x..x+폭-1 **윗면 위**에 얹은 얇은 철판(도형님: "지형 윗면에 설치된 것처럼" — 홈을 파지 않는다).
#        판 = **다 나온 자리**(칸 사각). 처음엔 오른쪽으로 '나옴' 칸 밀려 벽 속에 숨어 있다(음수면 왼쪽).
#        상자 = 무게(주철 궤짝 · 죽으면 제자리). 검사기는 판을 '다 나온 채'로 본다(문·책장처럼).
class 누름계단:
    def __init__(self, g, i, dn=None):
        self.i = i
        self.발판 = tuple(g["발판"])
        self.유지 = g.get("작동") == "유지"
        self.상자 = tuple(g["상자"]) if g.get("상자") else None
        self.판들 = [dict(p) for p in g["판들"]]

    def 나온_칸들(self):
        out = []
        for p in self.판들:
            out += [(x, y) for y in range(p["y"], p["y"] + p["h"]) for x in range(p["x"], p["x"] + p["w"])]
        return out

    def 숨은_칸들(self, p):
        return [(x + p["나옴"], y) for y in range(p["y"], p["y"] + p["h"]) for x in range(p["x"], p["x"] + p["w"])]

    def 엔진값(self):
        x, 바닥, 폭 = self.발판
        v = {"발판": ((x + 폭 / 2) * C, 바닥 * C), "발판폭": 폭 * C, "유지": self.유지,
             "판들": [{"원점": ((p["x"] + p["나옴"]) * C, p["y"] * C), "크기": (p["w"] * C, p["h"] * C),
                      "이동": (-p["나옴"] * C, 0.0), "지연": float(p.get("지연", 0.0))} for p in self.판들]}
        if self.상자:
            v["상자"] = ((self.상자[0] + 0.5) * C, self.상자[1] * C)
        return v


class 촛불:
    """꺼지지 않는 큰 양초 — 둘레(반경 170px)가 '태우는 빛' = 그을음 안전지대. {"종류": "촛불", "x", "바닥"}"""
    def __init__(self, g, i, dn=None):
        self.i = i
        self.x, self.바닥 = g["x"], g["바닥"]

    def 엔진값(self):
        return {"원점": ((self.x + 0.5) * C, self.바닥 * C)}


_종류 = {"빛줄기": 빛줄기, "도약대": 도약대, "움직이는발판": 움직이는발판,
        "부서지는판": 부서지는판, "그을음": 그을음, "열쇠조각": 열쇠조각, "잠긴문": 잠긴문, "레버퍼즐": 레버퍼즐, "촛불": 촛불,
        "반딧불몹": 반딧불몹, "거미": 그을음거미, "빛받이": 빛받이, "누름계단": 누름계단}
# 공용 키트 인스턴스로 만드는 옛 기믹(만들기.py 기믹_노드들) — 나머지는 추가기믹.py 가 만든다
옛_기믹 = ("빛줄기", "도약대", "움직이는발판")


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
        elif isinstance(g, 부서지는판):
            for x, y in g.칸들():
                if dn.칸(x, y) != 0:
                    문제.append(f"부서지는판{g.i} 이 지형에 묻힘 @({x},{y})")
                    break
            # v3 레벨 규칙: 아래는 가시·낙사여야 한다(살아서 내려서면 갇힐 수 있다)
            if not g.아래허용:
                가시칸 = {(gx + k, gy - 1) for gx, gy, gw in dn.d.get("가시", []) for k in range(gw)}
                for x, _y in g.칸들():
                    yy = g.y + 1
                    while yy < dn.h and dn.칸(x, yy) == 0 and (x, yy) not in 가시칸:
                        yy += 1
                    낙하 = (yy - g.y) * C
                    if (x, yy) not in 가시칸 and 낙하 < float(dn.d.get("치명_낙하", 규격.치명_낙하)):
                        문제.append(f"부서지는판{g.i} 아래 칸 {x} 에 살아서 내려설 바닥(행 {yy} · {낙하:.0f}px) — 가시·낙사로 하거나 \"아래허용\"")
                        break
        elif isinstance(g, 촛불):
            if dn.칸(g.x, g.바닥) == 0 or dn.칸(g.x, g.바닥 - 1) != 0:
                문제.append(f"촛불{g.i} 이 바닥 위가 아님 @({g.x},{g.바닥})")
        elif isinstance(g, 그을음):
            if dn.칸(g.x, g.바닥) == 0 or dn.칸(g.x, g.바닥 - 1) != 0:
                문제.append(f"그을음{g.i} 둥지가 바닥 위가 아님 @({g.x},{g.바닥})")
        elif isinstance(g, 열쇠조각):
            # 도형님 10-09: "열쇠 근처에는 같은 색의 발판이 있어야 색을 바꾸기 쉽다" — 8칸 안에 같은 색으로 설 수 있는 윗면
            같은 = {1, 2, 4} if g.색 == "검정" else {3, 4}
            cx, cy = int(g.x), int(g.y)
            찾음 = False
            for yy in range(cy - 8, cy + 9):
                for xx in range(cx - 8, cx + 9):
                    if dn.칸(xx, yy) in 같은 and dn.칸(xx, yy - 1) == 0:
                        찾음 = True
                        break
                if 찾음:
                    break
            if not 찾음:
                문제.append(f"열쇠조각{g.i}({g.색}) 8칸 안에 같은 색으로 설 발판이 없다 @({g.x},{g.y})")
            if dn.칸(cx, cy) != 0:
                문제.append(f"열쇠조각{g.i} 가 지형에 묻힘 @({g.x},{g.y})")
        elif isinstance(g, 잠긴문):
            if not any(문["이름"] == g.연결 for 문 in dn.문):
                문제.append(f"잠긴문{g.i} 의 길목 '{g.연결}' 이 없다")
        elif isinstance(g, 레버퍼즐):
            for x, y in g.레버 + [g.손잡이]:
                if dn.칸(x, y) == 0 or dn.칸(x, y - 1) != 0:
                    문제.append(f"레버퍼즐{g.i} 레버 자리 @({x},{y}) 가 바닥 위가 아님")
            if len(g.정답) != len(g.레버):
                문제.append(f"레버퍼즐{g.i} 정답 수({len(g.정답)}) ≠ 레버 수({len(g.레버)})")
            if g.샹들리에:
                # 샹들리에(폭 6칸)가 레버들을 덮어야 '틀리면 머리 위로 떨어진다' 가 된다
                l, r = g.샹들리에[0] - 3, g.샹들리에[0] + 3
                for x, _y in g.레버:
                    if not (l - 0.5 <= x + 0.5 <= r + 0.5):
                        문제.append(f"레버퍼즐{g.i} 샹들리에(폭 6칸)가 레버 칸 {x} 를 덮지 못함")
        elif isinstance(g, 반딧불몹):
            # 정지점은 빈칸 · 날아다니는 길은 지형을 뚫지 않는다(몸이 벽 속을 지나가 보이면 안 된다)
            for k, (x, y) in enumerate(g.멈춤):
                if dn.칸(int(x), int(y)) in (1, 2, 3):
                    문제.append(f"반딧불몹{g.i} 정지점 {k} 가 지형 속 @({x},{y})")
            for (ax, ay), (bx, by) in g.길():
                n = max(2, int(math.hypot(bx - ax, by - ay) * 4))
                for t in range(n + 1):
                    px, py = ax + (bx - ax) * t / n, ay + (by - ay) * t / n
                    if dn.칸(int(px), int(py)) in (1, 2, 3):
                        문제.append(f"반딧불몹{g.i} 길이 지형을 뚫음 @({px:.1f},{py:.1f})")
                        break
            if g.새장:
                lx, ly = g.새장["레버"]
                if dn.칸(lx, ly) == 0 or dn.칸(lx, ly - 1) != 0:
                    문제.append(f"반딧불몹{g.i} 새장 레버 자리 @({lx},{ly}) 가 바닥 위가 아님")
                if not (0 <= int(g.새장["멈춤"]) < len(g.멈춤)):
                    문제.append(f"반딧불몹{g.i} 새장 정지점 번호가 없음")
        elif isinstance(g, 그을음거미):
            if dn.칸(g.x, g.바닥) == 0 or dn.칸(g.x, g.바닥 - 1) != 0:
                문제.append(f"거미{g.i} 둥지가 바닥 위가 아님 @({g.x},{g.바닥})")
            for k, w in enumerate(g.줄):
                # 두 끝은 지형에 붙어 있어야 한다(허공에 걸린 줄 금지) — 끝점 둘레 네 칸 중 하나가 지형
                for 끝 in (w["가"], w["나"]):
                    ex, ey = 끝
                    둘레 = {(int(ex - 0.5), int(ey - 0.5)), (int(ex + 0.4), int(ey - 0.5)), (int(ex - 0.5), int(ey + 0.4)), (int(ex + 0.4), int(ey + 0.4))}
                    if not any(dn.칸(cx, cy) in (1, 2, 3) for cx, cy in 둘레):
                        문제.append(f"거미{g.i} 줄{k + 1} 끝 {끝} 이 지형에 안 붙음")
                # 거미가 같은 바닥을 걸어 줄 발밑까지 가야 한다
                발x = int(w["가"][0] if w["가"][1] > w["나"][1] else w["나"][0])
                for xx in range(min(g.x, 발x), max(g.x, 발x) + 1):
                    if dn.칸(xx, g.바닥) == 0 or dn.칸(xx, g.바닥 - 1) != 0:
                        문제.append(f"거미{g.i} 둥지 → 줄{k + 1} 발밑(칸 {발x}) 사이 바닥이 끊김 @({xx},{g.바닥})")
                        break
        elif isinstance(g, 누름계단):
            x, 바닥, 폭 = g.발판
            for xx in range(x, x + 폭):
                if dn.칸(xx, 바닥) == 0 or dn.칸(xx, 바닥 - 1) != 0:
                    문제.append(f"누름계단{g.i} 발판 @({xx},{바닥}) 이 바닥 윗면 위가 아님")
                    break
            for p in g.판들:
                for c in g.숨은_칸들(p):
                    if dn.칸(*c) == 0:
                        문제.append(f"누름계단{g.i} 판 숨은 자리가 벽 밖 @{c} — 판이 처음부터 보인다")
                        break
                for xx in range(p["x"], p["x"] + p["w"]):
                    if dn.칸(xx, p["y"]) != 0:
                        문제.append(f"누름계단{g.i} 판 나온 자리가 지형에 묻힘 @({xx},{p['y']})")
                        break
            if g.상자:
                sx, sb = g.상자
                if dn.칸(sx, sb) == 0 or any(dn.칸(xx, yy) != 0 for xx in (sx - 1, sx, sx + 1) for yy in (sb - 3, sb - 2, sb - 1)):
                    문제.append(f"누름계단{g.i} 상자 자리 @({sx},{sb}) 가 바닥 위 빈 3×3 이 아님")
        elif isinstance(g, 빛받이):
            if dn.칸(int(g.x), int(g.y)) in (1, 2, 3):
                문제.append(f"빛받이{g.i} 가 지형 속 @({g.x},{g.y})")
            if g.문:
                d = g.문
                w, h = d.get("크기", [3, 5])
                if dn.칸(int(d["x"]), int(d["바닥"])) == 0:
                    문제.append(f"빛받이{g.i} 문 아래가 바닥이 아님 @({d['x']},{d['바닥']})")
                for yy in range(int(d["바닥"]) - h, int(d["바닥"])):
                    for xx in range(int(math.floor(d["x"] - w / 2)), int(math.ceil(d["x"] + w / 2))):
                        if dn.칸(xx, yy) != 0:
                            문제.append(f"빛받이{g.i} 문 자리가 지형에 묻힘 @({xx},{yy})")
                            break
                    else:
                        continue
                    break
    return 문제
