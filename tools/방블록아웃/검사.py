# -*- coding: utf-8 -*-
"""
방 블록아웃 정적 검사 — 2026-10-01 Claude

★ 이 검사는 엔진 검사(레벨검사.gd·check_스마트월드 등)를 대신하지 않는다.
  Godot 실행이 허용되지 않은 상태에서 "구조적으로 말이 되는가"만 미리 거른다.

1) 씬 정적 검사 (.tscn 텍스트)
   ext_resource 경로 존재 · uid 대조 · SubResource/ExtResource 참조 · 부모 경로 · 형제 이름 중복 · Player 위치
2) 도달성 근사 검사 (room_layouts.json 의 r01)
   player.gd 의 공식으로 역산한 중력·점프 초속·이동 속도로 점프/낙하를 60Hz 로 흉내 내고,
   (발판 구간, 몸색) 상태 그래프를 만들어 아래를 본다.
     · G1 칠 상태(무색/검정/흰색)별 출구 도달 여부 — 지형만 보는 레벨검사의 맹점(§5-10)을 대신 본다
     · 숨은 직통 우회: B(관찰 허브)를 지우고도 출구에 닿는가 / 흰 몸이 한 번도 안 되고 닿는가
     · 소프트락: 닿을 수 있는 상태 중 출구로 못 돌아가는 상태
     · 공중 몸색 전환(지원됨)을 허용한 경우와 금지한 경우를 따로 본다
   한계: 공중에서 방향을 바꾸는 조작, 코요테·버퍼, SS2D 모서리 처리, 실제 칠 범위는 흉내 내지 않는다.

사용
  python tools/방블록아웃/검사.py
"""
import json
import math
import os
import re
import sys

저장소 = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
배치파일 = os.path.join(저장소, "scenes", "쳅터1", "초안_방5종", "room_layouts.json")
씬파일 = os.path.join(저장소, "scenes", "쳅터1", "초안_방5종", "방01_천장서재_블록아웃.tscn")

# ── player.gd 공식 그대로 (타일 16 · 높이 10칸 · 거리 20칸 · 속도 390) ──────────
타일, 높이칸, 거리칸, 속도 = 16.0, 10.0, 20.0, 390.0
낙하배수, 컷배수 = 2.4, 0.4
_k = 1.0 + 1.0 / math.sqrt(낙하배수)
중력 = 2.0 * (높이칸 * 타일) * 속도 * 속도 * _k * _k / (거리칸 * 타일) ** 2
점프초속 = -math.sqrt(2.0 * 중력 * (높이칸 * 타일))
몸폭, 몸높이 = 44.0, 97.0
반폭 = 몸폭 / 2
치명낙하 = 1500.0
DT = 1.0 / 60.0

결과 = {"실패": 0, "경고": 0}


def 보고(통과, 글, 경고만=False):
    if 통과:
        print("  ✔", 글)
    elif 경고만:
        결과["경고"] += 1
        print("  △", 글)
    else:
        결과["실패"] += 1
        print("  ✖", 글)


# ════════════════════════════════════════════════════════════════════════════
# 1) 씬 정적 검사
# ════════════════════════════════════════════════════════════════════════════
def res경로(p):
    return os.path.join(저장소, p[len("res://"):].replace("/", os.sep))


def 대상_uid(p):
    f = res경로(p)
    if p.endswith(".gd"):
        u = f + ".uid"
        return open(u, encoding="utf-8").read().strip() if os.path.exists(u) else None
    if p.endswith(".tscn"):
        with open(f, encoding="utf-8") as h:
            for 줄 in h:
                m = re.match(r'\[gd_scene[^\]]*uid="([^"]+)"', 줄)
                if m:
                    return m.group(1)
                if 줄.startswith("[gd_scene"):
                    return None
    return None


def 씬_검사(경로):
    print(f"\n[1] 씬 정적 검사 — {os.path.relpath(경로, 저장소)}")
    글 = open(경로, encoding="utf-8").read()
    ext = {}
    for m in re.finditer(r'\[ext_resource type="([^"]+)"(?: uid="([^"]+)")? path="([^"]+)" id="([^"]+)"\]', 글):
        형, uid, p, i = m.groups()
        ext[i] = p
        있음 = os.path.exists(res경로(p))
        보고(있음, f"ext {i}: {p} 존재")
        if 있음 and uid:
            실제 = 대상_uid(p)
            보고(실제 == uid, f"ext {i}: uid {uid} = 대상 {실제}")
    sub = re.findall(r'\[sub_resource type="[^"]+" id="([^"]+)"\]', 글)
    보고(len(sub) == len(set(sub)), f"sub_resource id 중복 없음 ({len(sub)}개)")
    sub_set = set(sub)
    누락s = sorted({r for r in re.findall(r'SubResource\("([^"]+)"\)', 글) if r not in sub_set})
    보고(not 누락s, f"SubResource 참조 전부 정의됨 {누락s[:3] if 누락s else ''}")
    누락e = sorted({r for r in re.findall(r'ExtResource\("([^"]+)"\)', 글) if r not in ext})
    보고(not 누락e, f"ExtResource 참조 전부 정의됨 {누락e[:3] if 누락e else ''}")
    노드들 = re.findall(r'\[node name="([^"]+)"(?: type="[^"]+")?(?: parent="([^"]*)")?', 글)
    경로들 = set()
    루트 = None
    중복 = []
    부모없음 = []
    for 이름, 부모 in 노드들:
        if 루트 is None and not 부모:
            루트 = 이름
            경로들.add(".")
            continue
        if 부모 != "." and 부모 not in 경로들:
            부모없음.append(f"{부모}/{이름}")
        전체 = 이름 if 부모 == "." else f"{부모}/{이름}"
        if 전체 in 경로들:
            중복.append(전체)
        경로들.add(전체)
    보고(not 부모없음, f"모든 부모 경로가 앞에서 정의됨 {부모없음[:3] if 부모없음 else ''}")
    보고(not 중복, f"형제 이름 중복 없음 {중복[:3] if 중복 else ''}")
    보고("Player" in 경로들, "루트 직속 Player (월드.gd 가 get_node_or_null('Player') 로 찾는다)")
    보고(글.count('groups=["페인트코어"]') == 1, "페인트코어 그룹 노드 1개")
    보고("owner" not in 글, "owner 속성을 쓰지 않음(§5-1)")
    # [2026-10-01 엔진 확인] 구조(안칠해짐)에 시작상태를 주면 _ready 가 검정 얼룩을 찍어 흰 몸을 죽인다.
    구조_시작 = re.findall(r'"칠하기_방식" = 2\n[^\[]*?"시작상태" = [1-3]', 글)
    보고(not 구조_시작, f"구조(안칠해짐) 지형에 시작상태 없음 — 있으면 흰 몸이 구조에 닿아 죽는다 ({len(구조_시작)}곳)")
    보고(not re.search(r'type="Camera2D"', 글), "Camera2D 추가 없음(카메라는 월드.gd 가 ProtoCamera 로 만든다)")
    print(f"     노드 {len(노드들)}개 · ext {len(ext)}개 · sub {len(sub)}개")


# ════════════════════════════════════════════════════════════════════════════
# 2) 도달성 근사 검사
# ════════════════════════════════════════════════════════════════════════════
class 판:
    __slots__ = ("x0", "y0", "x1", "y1", "색", "id")

    def __init__(s, x0, y0, x1, y1, 색, id_):
        s.x0, s.y0, s.x1, s.y1, s.색, s.id = x0, y0, x1, y1, 색, id_


def 직교분해(pts):
    """직교 다각형 → 가로 띠 사각형들(짝홀 스캔라인)."""
    ys = sorted({p[1] for p in pts})
    조각 = []
    n = len(pts)
    for a, b in zip(ys, ys[1:]):
        my = (a + b) / 2
        xs = []
        for i in range(n):
            (x1, y1), (x2, y2) = pts[i], pts[(i + 1) % n]
            if x1 == x2 and min(y1, y2) < my < max(y1, y2):
                xs.append(x1)
        xs.sort()
        for i in range(0, len(xs) - 1, 2):
            조각.append((xs[i], a, xs[i + 1], b))
    return 조각


def 판들_만들기(방, 유령색):
    """색: None = 구조(색 규칙 밖), 'B' 검정, 'W' 흰색. 유령색 None 이면 G1 은 통과(판 아님)."""
    판들 = []
    for s in 방["solids"]:
        k = s["kind"]
        if k == "유령":
            if 유령색 is None:
                continue
            색 = 유령색
        else:
            색 = {"구조": None, "검정목재": "B", "흰템플릿": "W"}.get(k, "X")
            if 색 == "X":
                continue
        if "rect" in s:
            x, y, w, h = s["rect"]
            판들.append(판(x, y, x + w, y + h, 색, s["id"]))
        else:
            for (x0, y0, x1, y1) in 직교분해(s["polygon"]):
                판들.append(판(x0, y0, x1, y1, 색, s["id"]))
    return 판들


def 겹침(px, py, p):
    """몸(중심 px, 발 py)과 판 p 가 엄밀히 겹치는가."""
    return px - 반폭 < p.x1 and px + 반폭 > p.x0 and py - 몸높이 < p.y1 and py > p.y0


def 구간들(판들):
    """서 있을 수 있는 (y, 중심x 구간) 목록. 같은 높이의 맞닿은 판은 하나로 합친다."""
    높이별 = {}
    for p in 판들:
        높이별.setdefault(p.y0, []).append((p.x0 - 반폭 + 0.5, p.x1 + 반폭 - 0.5))
    결과_ = []
    for y, 목록 in 높이별.items():
        목록.sort()
        합 = []
        for a, b in 목록:
            if 합 and a <= 합[-1][1] + 1:
                합[-1][1] = max(합[-1][1], b)
            else:
                합.append([a, b])
        # 몸이 다른 판과 겹치는 중심 x 를 뺀다(머리 위 판·옆 벽·위에 얹힌 덩어리)
        막힘 = []
        for p in 판들:
            if y - 몸높이 < p.y1 and y > p.y0:
                막힘.append((p.x0 - 반폭, p.x1 + 반폭))
        for a, b in 합:
            조각 = [(a, b)]
            for c, d in 막힘:
                새 = []
                for e, f in 조각:
                    if d <= e or c >= f:
                        새.append((e, f))
                        continue
                    if c > e:
                        새.append((e, c))
                    if d < f:
                        새.append((d, f))
                조각 = 새
            for e, f in 조각:
                if f - e >= 1:
                    결과_.append((y, e, f))
    결과_.sort()
    return 결과_


def 받침색(판들, x, y):
    return {p.색 for p in 판들 if p.y0 == y and p.x0 < x + 반폭 and p.x1 > x - 반폭}


def 받침id(판들, x, y):
    return {p.id for p in 판들 if p.y0 == y and p.x0 < x + 반폭 and p.x1 > x - 반폭}


def 비행(판들, x, y, vx, vy, 컷=False):
    """한 번의 점프/낙하. 반환 (착지 y, 착지 x, 비행 중 닿은 색 집합, 낙하거리) 또는 None."""
    최고 = y
    닿음 = set()
    t = 0.0
    for _ in range(int(3.5 / DT)):
        t += DT
        if 컷 and vy < 0 and t >= 0.10:
            vy *= 컷배수
            컷 = False
        # 가로 이동
        nx = x + vx * DT
        for p in 판들:
            if 겹침(nx, y, p):
                닿음.add(p.색)
                nx = p.x0 - 반폭 if vx > 0 else p.x1 + 반폭
                vx = 0.0
        x = nx
        # 세로 이동
        vy += 중력 * (1.0 if vy < 0 else 낙하배수) * DT
        ny = y + vy * DT
        착지 = None
        for p in 판들:
            if 겹침(x, ny, p):
                if vy > 0:
                    if 착지 is None or p.y0 < 착지:
                        착지 = p.y0
                else:
                    닿음.add(p.색)
                    ny = p.y1 + 몸높이
                    vy = 0.0
        if 착지 is not None:
            return (착지, x, 닿음, 착지 - 최고)
        y = ny
        최고 = min(최고, y)
        if y > 3400:
            return None
    return None


def 도달성(방, 유령색, 공중전환):
    판들 = 판들_만들기(방, 유령색)
    구 = 구간들(판들)

    def 구간찾기(y, x):
        for i, (gy, a, b) in enumerate(구):
            if gy == y and a - 0.5 <= x <= b + 0.5:
                return i
        return None

    간선 = {}   # (i, 색) -> set((j, 색2))
    최대낙하 = (0.0, -1, -1)
    for i, (y, a, b) in enumerate(구):
        표본 = sorted({a, b, *[a + k * 48 for k in range(1, int((b - a) // 48) + 1) if a + k * 48 < b]})
        시도 = []
        for x in 표본:
            for vx in (-390, -260, -130, 0, 130, 260, 390):
                시도.append((x, vx, 점프초속, False))
                시도.append((x, vx, 점프초속, True))
        시도.append((a, -속도, 0.0, False))      # 왼끝에서 걸어 떨어지기
        시도.append((b, 속도, 0.0, False))       # 오른끝에서 걸어 떨어지기
        for (x, vx, vy, 컷) in 시도:
            # 걸어 떨어지기는 몸이 받침을 벗어난 다음부터 낙하
            sx = x + (1 if vx > 0 else -1) * (0.0 if vy != 0 else 1.0)
            r = 비행(판들, sx, y, vx, vy, 컷)
            if r is None:
                continue
            ly, lx, 닿음, 낙하 = r
            j = 구간찾기(ly, lx)
            if j is None or (j == i and abs(lx - x) < 1):
                continue
            if 낙하 > 치명낙하:
                continue
            받 = 받침색(판들, lx, ly)
            for c in ("B", "W"):
                몸 = c
                if 공중전환:
                    # 공중에서 착지면 색으로 바꿀 수 있다(색이 섞인 받침이면 불가)
                    유색 = {k for k in 받 if k}
                    if len(유색) > 1:
                        continue
                    몸 = 유색.pop() if 유색 else c
                    if any(k and k != c and k != 몸 for k in 닿음):
                        continue
                else:
                    if any(k and k != c for k in 닿음 | 받):
                        continue
                간선.setdefault((i, c), set()).add((j, 몸))
                최대낙하 = max(최대낙하, (낙하, i, j))
        # 구조(색 규칙 밖) 받침 위에서는 서서 몸색을 바꿔도 안전
        중간 = (a + b) / 2
        if 받침색(판들, 중간, y) == {None}:
            간선.setdefault((i, "B"), set()).add((i, "W"))
            간선.setdefault((i, "W"), set()).add((i, "B"))
    return 판들, 구, 간선, 최대낙하


def 탐색(시작들, 간선, 금지=lambda n: False):
    본 = set()
    큐 = [n for n in 시작들 if not 금지(n)]
    while 큐:
        n = 큐.pop()
        if n in 본:
            continue
        본.add(n)
        for m in 간선.get(n, ()):
            if m not in 본 and not 금지(m):
                큐.append(m)
    return 본


def 이름(판들, 구, i):
    y, a, b = 구[i]
    ids = sorted({p.id for p in 판들 if p.y0 == y and p.x0 < b + 반폭 and p.x1 > a - 반폭})
    return f"{'/'.join(ids)}@y{int(y)}[{int(a)}~{int(b)}]"


def 도달성_검사(방):
    print("\n[2] 도달성 근사 검사 — r01 천장 서재")
    print(f"     중력 {중력:.0f} · 점프초속 {점프초속:.0f} · 명목 상승 {점프초속 ** 2 / (2 * 중력):.0f} · 몸 {몸폭:.0f}×{몸높이:.0f} · 치명낙하 {치명낙하:.0f}")
    sx, sy = 방["spawn"]["foot"]

    def 출구인가(구, i):
        y, a, b = 구[i]
        return y == 2376 and b >= 3700

    표 = {}
    for 유령색, 표기 in ((None, "G1 무색"), ("B", "G1 검정칠"), ("W", "G1 흰칠")):
        for 공중 in (False, True):
            판들, 구, 간선, 최대낙하 = 도달성(방, 유령색, 공중)
            시작 = next(i for i, (y, a, b) in enumerate(구) if y == sy and a <= sx <= b)
            본 = 탐색([(시작, "B")], 간선)
            닿음 = any(출구인가(구, i) for i, c in 본)
            표[(유령색, 공중)] = (판들, 구, 간선, 본, 시작, 최대낙하)
            낙, fi, fj = 최대낙하
            print(f"     {표기:8s} · 공중전환 {'허용' if 공중 else '금지'} → 출구 {'도달' if 닿음 else '불가'} · 상태 {len(본)} · 최대 낙하 {낙:.0f} ({이름(판들, 구, fi).split('@')[0]}→{이름(판들, 구, fj).split('@')[0]})")

    def 출구(k):
        _, 구, _, 본, _, _ = 표[k]
        return any(출구인가(구, i) for i, c in 본)

    보고(not 출구((None, False)) and not 출구((None, True)), "G1 을 칠하지 않으면 공중전환을 써도 출구에 못 간다(T1 이 필수)")
    보고(출구(("B", False)), "G1 검정칠 + 공중전환 없이 출구 도달(첫 방 의도 경로)")
    # [2026-10-01] M·r1 을 구조로 바꾼 뒤로 흰칠도 건널 수 있다 — 구조 위 흰 전환이라는 다른 풀이(오칠 복구).
    보고(출구(("W", False)), "G1 을 흰색으로 잘못 칠해도 M·r1(구조) 위 흰 전환으로 건널 수 있다(공중전환 불필요)")

    판들, 구, 간선, 본, 시작, _ = 표[("B", False)]
    B면 = {i for i, (y, a, b) in enumerate(구) if "bookcase_R" in 받침id(판들, (a + b) / 2, y) or "books_w1" in 받침id(판들, (a + b) / 2, y) or "sill_W" in 받침id(판들, (a + b) / 2, y)}
    for 공중 in (False, True):
        판들2, 구2, 간선2, _, 시작2, _ = 표[("B", 공중)]
        B면2 = {i for i, (y, a, b) in enumerate(구2) if 받침id(판들2, (a + b) / 2, y) & {"bookcase_R", "books_w1", "sill_W"}}
        우회 = 탐색([(시작2, "B")], 간선2, 금지=lambda n: n[0] in B면2)
        보고(not any(출구인가(구2, i) for i, c in 우회), f"B 허브(책장R·w1·W)를 거치지 않는 출구 우회 없음 (공중전환 {'허용' if 공중 else '금지'})")
    검정만 = 탐색([(시작, "B")], 간선, 금지=lambda n: n[1] == "W")
    보고(not any(출구인가(구, i) for i, c in 검정만), "흰 몸이 한 번도 되지 않고는 출구에 못 간다(T2 가 필수)")
    # 소프트락: 닿을 수 있는 모든 상태에서 출구로 갈 수 있는가
    역 = {}
    for n, ms in 간선.items():
        for m in ms:
            역.setdefault(m, set()).add(n)
    출구상태 = [n for n in 본 if 출구인가(구, n[0])]
    되돌 = 탐색(출구상태, 역)
    갇힘 = sorted(n for n in 본 if n not in 되돌)
    갇힘_이름 = sorted({이름(판들, 구, i) for i, c in 갇힘})
    보고(not 갇힘, f"소프트락 없음 (갇힘 상태 {len(갇힘)}){' — ' + ', '.join(갇힘_이름[:4]) if 갇힘 else ''}")
    # 닿지 않는 발판(죽은 발판)
    닿은면 = {i for i, c in 본}
    죽은 = [이름(판들, 구, i) for i in range(len(구)) if i not in 닿은면 and 구[i][0] < 2376 and 구[i][0] > 0]
    보고(not 죽은, f"모든 발판 윗면에 닿는다 {죽은[:4] if 죽은 else ''}", 경고만=True)
    print("     구간 목록:")
    for i, (y, a, b) in enumerate(구):
        if y <= 0:
            continue
        표시 = "●" if i in 닿은면 else "○"
        print(f"       {표시} {이름(판들, 구, i)}  폭 {int(b - a + 몸폭)}")


def 기하_검사(방, 배치):
    print("\n[3] 설계 규칙 검사 — r01")
    W, H = 배치["source_units"]["W"], 배치["source_units"]["H"]
    b = 방["bounds"]
    보고(abs(b["w"] / W - 2.0) < 1e-6 and abs(b["h"] / H - 2.2) < 1e-6, f"외곽 {b['w']}×{b['h']} = 2.0W × 2.2H")
    판들 = 판들_만들기(방, "B")
    # 의도하지 않은 겹침(면적 > 0)
    겹 = []
    for i, p in enumerate(판들):
        for q in 판들[i + 1:]:
            if p.id == q.id:
                continue
            if p.x0 < q.x1 and q.x0 < p.x1 and p.y0 < q.y1 and q.y0 < p.y1:
                겹.append(f"{p.id}×{q.id}")
    보고(not 겹, f"판끼리 면적 겹침 없음 {겹[:4] if 겹 else ''}")
    # 착지면 폭: 몸폭 3배(132) 이상, 색 과제 직후(B·C) 5배(220) 이상
    for s in 방["solids"]:
        if "landing_w" in s:
            최소 = 220 if s["id"] in ("bookcase_R", "desk_C") else 132
            보고(s["landing_w"] >= 최소, f"착지면 {s['name']} 폭 {s['landing_w']} ≥ {최소}")
    # 벽 두께 ≥ 가장 넓은 화면의 반폭/반높이 + 흔들림 (§5-12: 리밋만으로 벽 너머를 못 가린다)
    넓 = 배치["source_units"]["가장_넓은_화면"]
    반w, 반h = 넓["크기"][0] / 2 + 넓["흔들림_px"], 넓["크기"][1] / 2 + 넓["흔들림_px"]
    두께 = {s["id"]: s["rect"] for s in 방["solids"] if s["id"].startswith("shell_")}
    보고(두께["shell_left"][2] >= 반w and 두께["shell_right"][2] >= 반w, f"좌우 벽 두께 1200 ≥ 반폭 {반w:.0f}")
    보고(두께["shell_top"][3] >= 반h and 두께["shell_bottom"][3] >= 반h, f"천장·바닥 두께 768 ≥ 반높이 {반h:.0f}")
    # 카메라 리밋 안에서 화면이 껍데기 밖을 비추지 않는가
    lx, ly, lw, lh = -144, -144, 4404, 2664
    보고(lw >= 넓["크기"][0] and lh >= 넓["크기"][1], f"리밋 {lw}×{lh} 이 가장 넓은 화면 {넓['크기'][0]}×{넓['크기'][1]} 보다 큼(리밋이 화면을 가둔다)")
    보고(lx >= -1200 and lx + lw <= 5040 and ly >= -768 and ly + lh <= 3144, "리밋 사각형이 껍데기 바깥 테두리 안")
    # 주 경로의 다음 착지면이 기본 줌 한 화면 안에 보이는가
    print("     다음 착지면 동시 노출(줌 1.0, 리밋 고려):")
    순서 = [("A 시작", (240, 383), (1008, 624)), ("a2", (1368, 767), (1632, 1008)), ("M", (1632, 959), (2400, 960)),
          ("B", (2640, 911), (3216, 1248)), ("w1", (3120, 815), (3408, 768)), ("d1", (3360, 1199), (3600, 1440)),
          ("d2", (3720, 1391), (3216, 1632)), ("d3", (3360, 1583), (3120, 1872)), ("C", (2568, 1823), (3216, 2064)),
          ("D", (3360, 2015), (3840, 2376))]
    for 이름_, c, 목표 in 순서:
        w, h = 1920, 1080
        cx = min(max(c[0], lx + w / 2), lx + lw - w / 2)
        cy = min(max(c[1], ly + h / 2), ly + lh - h / 2)
        안 = cx - w / 2 <= 목표[0] <= cx + w / 2 and cy - h / 2 <= 목표[1] <= cy + h / 2
        보고(안, f"{이름_} 에서 다음 착지점 {목표} 이 화면 안", 경고만=True)


def main():
    배치 = json.load(open(배치파일, encoding="utf-8"))
    방 = next(r for r in 배치["rooms"] if r["room_id"] == "r01")
    씬_검사(씬파일)
    기하_검사(방, 배치)
    도달성_검사(방)
    print(f"\n결과: 실패 {결과['실패']} · 경고 {결과['경고']}  (엔진 검사 미실행 — 이 결과는 정적 근사)")
    return 1 if 결과["실패"] else 0


if __name__ == "__main__":
    sys.exit(main())
