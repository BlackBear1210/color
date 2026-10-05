# -*- coding: utf-8 -*-
"""
쳅터1 도안(JSON) 읽기 · 칸 격자 · 다각형 추출 · 도면 PNG — 2026-10-04 Claude

▣ 도안 JSON 한 장 = 스테이지 하나. 좌표는 전부 **칸**(1칸 = 32px), (0,0) = 방 왼쪽 위.
  {
    "이름": "쳅터1_02_복도_A",          ← 파일 이름 = 씬 이름
    "제목": "2층 복도 A",
    "종류": "복도",                     ← 규격.방_크기표 의 키. "크기": [w,h] 로 덮어쓸 수 있다
    "흐름": "→",                        ← 진행 방향(도면 표시용)
    "벽": {"위":4, "아래":4, "왼":3, "오른":3},   ← 방 테두리 구조 두께
    "연결": [{"이름":"왼쪽", "쪽":"왼", "바닥":34, "높이":5,
             "연결":["쳅터1_01_방_시작방","오른쪽"], "되돌아가기":true, "문장식":false}],
    "지형": [["구조", x,y,w,h], ["검정", x,y,w,h], ["흰", ...], ["유령", ...], ["빈", ...]],
    "가시": [[x, 바닥y, w]],             ← 바닥 칸 y 위에 w칸 너비
    "시작": [x, 바닥y],  "체크": [[x, 바닥y], ...],
    "배경": {"프리셋": "방_다마스크", "낡음": 1},
    "가구": [["책장", x, 바닥y], ...],     ← 배경 레이어(밟을 수 없음)
    "구역": [["A 시작", x,y,w,h], ...],   ← 도면 메모용
    "메모": ["..."]
  }
  - "지형" 은 **순서대로** 칠한다. "빈" 은 지운다(테두리를 파낼 때).
  - "바닥" 은 언제나 **바닥 칸의 y** — 발이 닿는 윗면이 그 칸의 위쪽 선이다.
  - 문은 왼/오른 벽에만 낸다. 문 칸 = (바닥-높이 … 바닥-1) 행을 벽 두께만큼 판다.

▣ 바깥 지형: 도안 밖으로 규격.바깥_가로/세로 만큼 구조를 덧대고, 문 자리는 문_터널 길이만큼 굴로 잇는다.
  → 카메라가 방 끝에 가도 방 밖(빈 배경)이 절대 보이지 않는다.
"""
import json
import os
from collections import defaultdict

import 규격

종류_번호 = {"빈": 0, "구조": 1, "검정": 2, "흰": 3, "유령": 4}
번호_종류 = {v: k for k, v in 종류_번호.items()}


class 도안:
    def __init__(self, 경로):
        self.경로 = 경로
        with open(경로, encoding="utf-8") as f:
            self.d = json.load(f)
        d = self.d
        self.이름 = d["이름"]
        self.제목 = d.get("제목", self.이름)
        self.종류 = d.get("종류", "방_M")
        self.w, self.h = d.get("크기") or 규격.방_크기표[self.종류]
        # [2026-10-04 2차] 큰 지형 부피를 키웠다(도형님 지시) — 테두리 기본 위5·아래7·좌우5칸
        self.벽 = {"위": 5, "아래": 7, "왼": 5, "오른": 5, **d.get("벽", {})}
        # [2026-10-04 2차] "문" → "연결"(문은 장식일 뿐 — 길목만 있으면 된다). 옛 키도 읽는다
        self.문 = d.get("연결") or d.get("문", [])
        self.경고 = []
        self._격자_만들기()

    # ── 격자 ────────────────────────────────────────────────────────────────
    def _격자_만들기(self):
        w, h = self.w, self.h
        g = [[0] * w for _ in range(h)]
        b = self.벽
        for y in range(h):
            for x in range(w):
                if y < b["위"] or y >= h - b["아래"] or x < b["왼"] or x >= w - b["오른"]:
                    g[y][x] = 1
        for 항목 in _계단_펼치기(self.d.get("지형", [])):
            k, x, y, ww, hh = 항목[:5]
            v = 종류_번호[k]
            for yy in range(y, y + hh):
                for xx in range(x, x + ww):
                    if 0 <= xx < w and 0 <= yy < h:
                        g[yy][xx] = v
                    else:
                        self.경고.append(f"지형 {항목} 이 도안 밖으로 나감")
        # 문 파기
        for 문 in self.문:
            x0, x1 = (0, b["왼"]) if 문["쪽"] == "왼" else (w - b["오른"], w)
            for yy in range(문["바닥"] - 문["높이"], 문["바닥"]):
                for xx in range(x0, x1):
                    g[yy][xx] = 0
            if 문["높이"] < 규격.규칙["통로_최소높이"]:
                self.경고.append(f"문 {문['이름']} 높이 {문['높이']}칸 < 통로 최소 {규격.규칙['통로_최소높이']}칸")
        self.g = g
        if self.d.get("목재_맞물림", False):
            self._목재_맞물림()

    def _목재_맞물림(self):
        """바닥 안에 박힌 흰 판자만 엇갈려 물린다. 밟는 윗선과 빈 공간은 그대로 둔다."""
        source = [row[:] for row in self.g]
        for item in _계단_펼치기(self.d.get("지형", [])):
            k, x, y, w, h = item[:5]
            if k != "흰" or h < 2 or y+h+2 >= self.h or x < 2 or x+w+2 >= self.w:
                continue
            # 공중 흰 발판이나 다른 기믹을 침범하지 않고, 구조 안에 묻힌 색 경계만 바꾼다.
            if not all(source[y+h][xx] == 1 for xx in range(x,x+w)):
                continue
            for row in range(1,h+2):
                yy=y+row
                left = (-1,1,0,2)[row%4]
                right = (1,-1,2,0)[row%4]
                if row >= h:
                    left += row-h+1
                    right -= row-h+1
                lo, hi = x+left, x+w+right
                for xx in range(max(1,x-2),min(self.w-1,x+w+2)):
                    # 노출된 면의 색은 바꾸지 않아 점프·사망 판정의 기존 경계를 유지한다.
                    surrounded=all(source[yy+dy][xx+dx] != 0 for dx,dy in ((-1,0),(1,0),(0,-1),(0,1)))
                    if not surrounded: continue
                    if source[yy][xx] == 3 and x <= xx < x+w and row < h:
                        self.g[yy][xx] = 3 if lo <= xx < hi else 1
                    elif source[yy][xx] == 1 and lo <= xx < hi:
                        self.g[yy][xx] = 3
        # 장식용 연장 때문에 제작 규격(흰색 30%)을 넘지 않도록 묻힌 행의 끝만 줄인다.
        black_and_ghost=sum(v in (2,4) for row in self.g for v in row)
        limit=int(black_and_ghost*3/7)
        count=sum(v == 3 for row in self.g for v in row)
        while count > limit:
            trimmed=False
            for item in _계단_펼치기(self.d.get("지형", [])):
                k,x,y,w,h=item[:5]
                if k != '흰': continue
                for yy in range(y+1,min(y+h+2,self.h-1)):
                    xs=[xx for xx in range(max(1,x-2),min(self.w-1,x+w+2)) if self.g[yy][xx] == 3]
                    if len(xs) <= 2: continue
                    for xx in (xs[0],xs[-1]):
                        if count <= limit: break
                        if not all(source[yy+dy][xx+dx] != 0 for dx,dy in ((-1,0),(1,0),(0,-1),(0,1))): continue
                        # 윗행이나 아랫행과 연결되는 중심부는 남기고 끝 한 칸씩만 정리한다.
                        self.g[yy][xx]=1
                        count-=1
                        trimmed=True
            if not trimmed: break

    def 칸(self, x, y):
        """도안 좌표(바깥 포함). 바깥은 구조, 단 문 터널은 빈칸."""
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.g[y][x]
        for 문 in self.문:
            if 문["바닥"] - 문["높이"] <= y < 문["바닥"]:
                if 문["쪽"] == "왼" and -규격.문_터널 <= x < 0:
                    return 0
                if 문["쪽"] == "오른" and self.w <= x < self.w + 규격.문_터널:
                    return 0
        return 1

    def 확장_범위(self):
        """바깥 지형까지 포함한 칸 범위 (x0, y0, x1, y1) — x1/y1 미포함."""
        return (-규격.바깥_가로, -규격.바깥_세로, self.w + 규격.바깥_가로, self.h + 규격.바깥_세로)

    # ── 다각형 ──────────────────────────────────────────────────────────────
    def 다각형들(self):
        """[(종류, 이름, [(px,py)...]) ...] — 구멍은 세로 틈(keyhole)으로 바깥 둘레에 잇는다.
        점 순서 = 화면 기준 시계방향(위 → 오른쪽 → 아래 → 왼쪽) = SS2D 템플릿과 같다."""
        x0, y0, x1, y1 = self.확장_범위()
        본 = set()
        결과 = []
        세기 = defaultdict(int)
        for y in range(y0, y1):
            for x in range(x0, x1):
                v = self.칸(x, y)
                if v == 0 or (x, y) in 본:
                    continue
                덩어리 = _채우기(self, x, y, v, 본, (x0, y0, x1, y1))
                고리들 = _둘레(덩어리)
                바깥 = [r for r in 고리들 if _면적(r) > 0]
                구멍 = [r for r in 고리들 if _면적(r) < 0]
                if len(바깥) != 1:
                    raise RuntimeError(f"{self.이름}: 덩어리 바깥 둘레가 {len(바깥)}개")
                점 = _구멍_잇기(바깥[0], 구멍)
                점 = [(px * 규격.칸, py * 규격.칸) for px, py in 점]
                k = 번호_종류[v]
                세기[k] += 1
                이름 = {"구조": "구조", "검정": "검정판", "흰": "흰판", "유령": "유령판"}[k] + f"{세기[k]:02d}"
                결과.append((k, 이름, 점, len(덩어리)))
        return 결과

    # ── 표시 정보 ───────────────────────────────────────────────────────────
    def 문_정보(self, 문):
        """문 하나의 월드 좌표 정보(px). 바닥선 y · 벽 안쪽 면 x · 바깥 방향 d(+1 오른쪽)."""
        b = self.벽
        d = -1 if 문["쪽"] == "왼" else 1
        안쪽면 = b["왼"] * 규격.칸 if d < 0 else (self.w - b["오른"]) * 규격.칸
        끝 = 0 if d < 0 else self.w * 규격.칸
        return {"d": d, "바닥y": 문["바닥"] * 규격.칸, "안쪽면x": 안쪽면, "끝x": 끝,
                "높이": 문["높이"] * 규격.칸, "벽두께": (b["왼"] if d < 0 else b["오른"]) * 규격.칸}


def _계단_펼치기(목록):
    """["계단", 종류, x, y, 단수, 방향, 단폭, 단높이, (틈)] → 두께 2칸 발판 여러 개.
    x,y = 첫 단의 왼쪽 위. 방향 +1 = 오른쪽으로 오르며, -1 = 왼쪽으로 오르며.
    단높이를 음수로 주면 내려가는 계단."""
    out = []
    for 항목 in 목록:
        if 항목[0] != "계단":
            out.append(항목)
            continue
        _, k, x, y, n, d, w, h = 항목[:8]
        틈 = 항목[8] if len(항목) > 8 else 0
        for i in range(n):
            out.append([k, x + d * i * (w + 틈), y - i * h, w, 2])
    return out


def _채우기(dn, sx, sy, v, 본, 범위):
    x0, y0, x1, y1 = 범위
    stack = [(sx, sy)]
    본.add((sx, sy))
    out = []
    while stack:
        x, y = stack.pop()
        out.append((x, y))
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if x0 <= nx < x1 and y0 <= ny < y1 and (nx, ny) not in 본 and dn.칸(nx, ny) == v:
                본.add((nx, ny))
                stack.append((nx, ny))
    return out


def _둘레(셀들):
    """칸 집합의 경계 → 고리 목록. 안쪽(채움)이 진행 방향의 오른쪽(화면 y 아래 기준)."""
    s = set(셀들)
    나감 = defaultdict(list)
    for x, y in s:
        if (x, y - 1) not in s:
            나감[(x, y)].append((x + 1, y))
        if (x + 1, y) not in s:
            나감[(x + 1, y)].append((x + 1, y + 1))
        if (x, y + 1) not in s:
            나감[(x + 1, y + 1)].append((x, y + 1))
        if (x - 1, y) not in s:
            나감[(x, y + 1)].append((x, y))
    남은 = {(a, b) for a, bs in 나감.items() for b in bs}
    고리들 = []
    while 남은:
        a, b = min(남은)
        고리 = [a]
        남은.discard((a, b))
        prev, cur = a, b
        while cur != a:
            고리.append(cur)
            후보 = [n for n in 나감[cur] if (cur, n) in 남은]
            if len(후보) > 1:
                # 대각선으로만 맞닿은 꼭짓점 — 오른쪽으로 꺾어 4방향 연결 덩어리를 지킨다
                dx, dy = cur[0] - prev[0], cur[1] - prev[1]
                오른 = (-dy, dx)
                후보.sort(key=lambda n: 0 if (n[0] - cur[0], n[1] - cur[1]) == 오른 else 1)
            n = 후보[0]
            남은.discard((cur, n))
            prev, cur = cur, n
        고리들.append(_곧은점_빼기(고리))
    return 고리들


def _곧은점_빼기(고리):
    out = []
    n = len(고리)
    for i in range(n):
        a, b, c = 고리[i - 1], 고리[i], 고리[(i + 1) % n]
        if (b[0] - a[0]) * (c[1] - b[1]) - (b[1] - a[1]) * (c[0] - b[0]) != 0:
            out.append(b)
    return out


def _면적(고리):
    s = 0
    for i in range(len(고리)):
        x1, y1 = 고리[i]
        x2, y2 = 고리[(i + 1) % len(고리)]
        s += x1 * y2 - x2 * y1
    return s / 2


def _구멍_잇기(바깥, 구멍들):
    """구멍마다 맨 위 변에서 위로 세로 틈을 내어 바깥 둘레에 잇는다(반 칸 지점 = 꼭짓점과 안 겹친다).
    세로 틈은 법선이 옆을 향해 목재 데크(윗면 전용)가 그려지지 않는다."""
    poly = [(float(x), float(y)) for x, y in 바깥]
    for 구멍 in sorted(구멍들, key=lambda r: (min(p[1] for p in r), min(p[0] for p in r))):
        vy = min(p[1] for p in 구멍)
        vx = min(p[0] for p in 구멍 if p[1] == vy)
        i = 구멍.index((vx, vy))
        들어옴 = 구멍[i - 1]
        assert 들어옴[1] == vy and 들어옴[0] > vx, "구멍 윗변 방향이 예상과 다르다"
        sx = vx + 0.5
        # 구멍 고리를 s 에서 시작하도록: s → v → … → 들어옴 → s
        돌기 = [(float(sx), float(vy))] + [(float(p[0]), float(p[1])) for p in 구멍[i:] + 구멍[:i]] + [(float(sx), float(vy))]
        # 위쪽으로 가장 가까운 가로 변(왼→오른) 찾기
        best = None
        for j in range(len(poly)):
            a, b = poly[j], poly[(j + 1) % len(poly)]
            if a[1] == b[1] and a[1] < vy and a[0] < sx < b[0]:
                if best is None or a[1] > poly[best][1]:
                    best = j
        if best is None:
            raise RuntimeError("구멍 위로 이을 변을 못 찾음")
        ey = poly[best][1]
        p = (float(sx), float(ey))
        poly = poly[: best + 1] + [p] + 돌기 + [p] + poly[best + 1:]
    return poly


def 모두_읽기(폴더):
    out = []
    for f in sorted(os.listdir(폴더)):
        if f.endswith(".json") and not f.startswith("_"):
            out.append(도안(os.path.join(폴더, f)))
    return out
