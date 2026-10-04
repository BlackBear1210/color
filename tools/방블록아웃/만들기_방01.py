# -*- coding: utf-8 -*-
"""
방 01(천장 서재) 블록아웃 초안 씬 생성기 — 2026-10-01 Claude

왜 Python 인가
  사용자 규칙상 Godot(편집기·콘솔·headless·빌더)을 허용 없이 실행할 수 없다.
  그래서 .tscn 텍스트를 직접 쓴다. 엔진이 하는 일(SS2D 메시 굽기·콜리전 생성)은
  씬을 열 때 `scripts/스마트월드/지형.gd _ready()` 가 `_meshes.clear()` → `force_update()`
  로 점 배열에서 다시 굽는다(2026-08-26 근본 수정). 그래서 여기서는 점만 쓴다.

멱등
  같은 room_layouts.json 이면 바이트 단위로 같은 파일이 나온다(정렬·고정 ID·LF).
  "기존 값 + 여유" 같은 누적 계산이 없다. 결과물 첫 줄에 출력 해시를 남겨
  다음 실행 때 '편집기에서 다시 저장·수정된 씬'이면 덮어쓰지 않고 멈춘다
  (Godot 은 저장할 때 ';' 주석 줄을 지우므로 그 흔적으로 알아챈다).
  강제로 덮어쓰려면 --강제.

기존 씬은 건드리지 않는다
  출력 = scenes/쳅터1/초안_방5종/방01_천장서재_블록아웃.tscn (새 파일)
  scenes/쳅터1/2층방.tscn 은 읽지도 쓰지도 않는다.

사용
  python tools/방블록아웃/만들기_방01.py            # 생성(변경 없으면 그대로)
  python tools/방블록아웃/만들기_방01.py --확인      # 쓰지 않고 차이만 보고
"""
import hashlib
import json
import os
import sys

저장소 = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
입력 = os.path.join(저장소, "scenes", "쳅터1", "초안_방5종", "room_layouts.json")
출력 = os.path.join(저장소, "scenes", "쳅터1", "초안_방5종", "방01_천장서재_블록아웃.tscn")
표식 = "; 생성: tools/방블록아웃/만들기_방01.py"

# ── 외부 리소스 ── uid 는 저장소의 실제 파일에서 읽어 확인한 값(검사.py 가 다시 대조한다)
#   템플릿 경로는 현재 디스크 기준(scenes/쳅터1/…). 사용자가 scenes/집 → scenes/쳅터1 로
#   옮기는 중이며, 현행 2층방.tscn 도 이 경로를 쓴다.
EXT = [
    ("월드", "Script", "uid://b5njrffiq72ba", "res://scripts/스마트월드/월드.gd"),
    ("코어", "Script", "uid://ffbu67cp501b", "res://scripts/스마트월드/페인트_코어.gd"),
    ("통로", "Script", "uid://btb30vjfpe18l", "res://scripts/스마트월드/연결통로.gd"),
    ("검정", "PackedScene", "uid://b743xnor581ga", "res://scenes/집/스마트 매쉬 assets/WOOD_나무/TEMPLATE_WOOD_SOLID.tscn"),
    ("흰", "PackedScene", "uid://525wg1ob0k0p", "res://scenes/집/스마트 매쉬 assets/WOOD_나무/TEMPLATE_WOOD_SOLID_WHITE.tscn"),
    ("유령", "PackedScene", None, "res://scenes/집/스마트 매쉬 assets/GHOST_투명발판/TEMPLATE_GHOST_WOOD.tscn"),
    ("점", "Script", "uid://bwcf4pjgprn0k", "res://addons/rmsmartshape/shapes/point.gd"),
    ("점배열", "Script", "uid://bo5f7qe27jfje", "res://addons/rmsmartshape/shapes/point_array.gd"),
    ("플레이어", "PackedScene", "uid://dk1itr2afb8hv", "res://scenes/player/Player.tscn"),
    ("체크포인트", "PackedScene", None, "res://scenes/장애물/체크포인트.tscn"),
]
# 리소스 id 는 ASCII 로 둔다 — Godot 이 만드는 id 도 ASCII 이고, 파서 차이를 시험할 수 없는 상황이라 위험을 줄인다.
_ASCII = {"월드": "world", "코어": "core", "통로": "passage", "검정": "tpl_black", "흰": "tpl_white", "유령": "tpl_ghost",
          "점": "ss2d_point", "점배열": "ss2d_points", "플레이어": "player", "체크포인트": "checkpoint"}
EXT_ID = {k: f"{i + 1}_{_ASCII[k]}" for i, (k, *_r) in enumerate(EXT)}

# 지형 종류 → (템플릿, 덧쓸 속성). 2층방의 벽_섬(구조)·발판(검정)·사다리(흰)·유령 설정을 그대로 따른다.
#   구조 = 칠하기_방식 2(안칠해짐) → 색규칙 밖. 현행 규칙의 "칠할 수 없는 구조물 제외"를 보존한다.
종류표 = {
    # ★[2026-10-01 엔진 확인] 구조에 `시작상태 = 1(검정)` 을 주면 안 된다.
    #   `지형._ready()` 가 `_전체_즉시(검정)` 으로 검정 얼룩을 통째로 찍어서, 칠하기_방식이 안칠해짐이어도
    #   `위치색` 이 검정으로 읽혀 **흰 몸이 구조물에 닿으면 죽는다**(현행 2층방 벽_껍데기·벽_섬도 같은 상태).
    #   시작상태를 비워(무색) 두면 기본_아트색 = -1 → 색 규칙 밖. 그림은 어차피 검정 원화다.
    "구조": ("검정", [('"칠하기_허용"', "false"), ('"칠하기_방식"', "2"), ('"위치별_판정"', "true")], "구조"),
    "검정목재": ("검정", [('"시작상태"', "1"), ('"위치별_판정"', "true")], "플랫폼"),
    "흰템플릿": ("흰", [('"위치별_판정"', "true")], "플랫폼"),
    "유령": ("유령", [], "플랫폼"),
}


def 수(v):
    """정수면 소수점 없이, 아니면 Godot 식 실수 표기."""
    f = float(v)
    return str(int(f)) if f == int(f) else repr(f)


def V(x, y):
    return f"Vector2({수(x)}, {수(y)})"


def 문자열(s):
    return '"' + str(s).replace("\\", "\\\\").replace('"', '\\"') + '"'


def 꼭짓점(고체):
    """rect 또는 polygon → 화면 좌표 시계방향 점 목록(템플릿과 같은 방향: 위 → 오른쪽 → 아래 → 왼쪽)."""
    if "rect" in 고체:
        x, y, w, h = 고체["rect"]
        pts = [(x, y), (x + w, y), (x + w, y + h), (x, y + h)]
    else:
        pts = [tuple(p) for p in 고체["polygon"]]
    면적 = sum(pts[i][0] * pts[(i + 1) % len(pts)][1] - pts[(i + 1) % len(pts)][0] * pts[i][1] for i in range(len(pts)))
    if 면적 < 0:      # y 아래 좌표계에서 양수 = 시계방향. 템플릿과 방향을 맞춘다.
        pts.reverse()
    return pts


def 중심(pts):
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    # 노드 위치 = 외접 사각형 중심(정수). 점은 이 위치 기준 로컬 좌표.
    return (int(round((min(xs) + max(xs)) / 2)), int(round((min(ys) + max(ys)) / 2)))


def 카메라_화면(중앙, 리밋, 줌=1.0):
    """기본 줌 화면(W×H/줌)을 리밋 안으로 밀어 넣은 사각형 — 설계표식용."""
    w, h = 1920 / 줌, 1080 / 줌
    lx, ly, lw, lh = 리밋
    cx = min(max(중앙[0], lx + w / 2), lx + lw - w / 2)
    cy = min(max(중앙[1], ly + h / 2), ly + lh - h / 2)
    return (cx - w / 2, cy - h / 2, w, h)


def 생성(배치):
    방 = next(r for r in 배치["rooms"] if r["room_id"] == "r01")
    리밋 = (-144, -144, 4404, 2664)
    줄 = []
    서브 = []
    노드 = []

    # ── 지형 서브리소스 + 노드 ───────────────────────────────────────────
    for 고체 in 방["solids"]:
        종류 = 고체["kind"]
        if 종류 not in 종류표:
            continue
        sid = 고체["id"]
        pts = 꼭짓점(고체)
        cx, cy = 중심(pts)
        로컬 = [(p[0] - cx, p[1] - cy) for p in pts] + [(pts[0][0] - cx, pts[0][1] - cy)]   # 닫는 점 = 첫 점 복제(템플릿과 같은 구조)
        점ids = []
        for i, (lx, ly) in enumerate(로컬):
            pid = f"P_{sid}_{i}"
            점ids.append(pid)
            서브.append(f'[sub_resource type="Resource" id="{pid}"]\nscript = ExtResource("{EXT_ID["점"]}")\nposition = {V(lx, ly)}\n')
        n = len(로컬)
        사전 = ",\n".join(f'{i}: SubResource("{p}")' for i, p in enumerate(점ids))
        순서 = ", ".join(str(i) for i in range(n))
        서브.append(
            f'[sub_resource type="Resource" id="PA_{sid}"]\nscript = ExtResource("{EXT_ID["점배열"]}")\n'
            f"_points = {{\n{사전}\n}}\n_point_order = PackedInt32Array({순서})\n"
            f"_constraints = {{\nVector2i(0, {n - 1}): 15\n}}\n_next_key = {n}\n"
        )
        템플릿, 속성, 역할 = 종류표[종류]
        본문 = [f'[node name="{고체["name"]}" parent="지형" instance=ExtResource("{EXT_ID[템플릿]}")]', f"position = {V(cx, cy)}"]
        본문 += [f"{k} = {v}" for k, v in 속성]
        본문 += [
            f'_points = SubResource("PA_{sid}")',
            # 2층방과 같이 0 — 템플릿 기본 24 면 콜리전이 그림보다 24px 부풀어 틈·단차가 설계값과 달라진다.
            "collision_size = 0.0",
            f"metadata/role = {문자열(역할)}",
            f"metadata/design_id = {문자열(sid)}",
            f"metadata/design_kind = {문자열(종류)}",
        ]
        if "note" in 고체:
            본문.append(f"metadata/design_note = {문자열(고체['note'])}")
        노드.append("\n".join(본문) + "\n")

    # ── 루트 ─────────────────────────────────────────────────────────────
    sp = 방["spawn"]["foot"]
    루트 = [
        '[node name="방01_천장서재" type="Node2D"]',
        f'script = ExtResource("{EXT_ID["월드"]}")',
        '"스테이지_이름" = "2층 방 01 · 천장 서재 (블록아웃 초안)"',
        f'"카메라_리밋" = Rect2({", ".join(수(v) for v in 리밋)})',
        '"카메라_줌" = 1.0',
        f'"시작_위치" = {V(*sp)}',
        '"낙사_y" = 3000.0',
        # 현행 2층방 값 유지(미확정). 설계 경로는 이 값에 의존하지 않는다 — room_layouts.json fatal_fall.
        f'"치명_낙하거리" = {float(방["fatal_fall"]["value"])!r}',
        'metadata/room_id = "r01"',
        f'metadata/layout_source = {문자열("res://scenes/쳅터1/초안_방5종/room_layouts.json")}',
        'metadata/draft_status = "블록아웃 초안 v1 — 엔진 미검증 · 기존 2층방.tscn 대체 아님"',
    ]
    줄.append("\n".join(루트) + "\n")
    줄.append(f'[node name="페인트코어" type="Node" parent="." groups=["페인트코어"]]\nscript = ExtResource("{EXT_ID["코어"]}")\n')

    # ── 배경 블록아웃: 월드 고정 Node2D(패럴랙스 없음). 낮은 대비 단색 3장만 ──
    #   작업안 L1 = 방 골격은 월드 고정. 약한 실내 시차(0.02~0.55)를 쓰지 않는다.
    줄.append('[node name="배경_블록아웃" type="Node2D" parent="."]\nz_index = -20\nmetadata/layer = "L1 월드 고정 — 아트 전 단색 자리표시"\n')
    배경 = [
        ("뒷벽", (0, 0, 3840, 2376), "Color(0.3, 0.3, 0.31, 1)"),
        ("중앙창_자리", (1824, 96, 528, 816), "Color(0.5, 0.51, 0.53, 1)"),
        ("우측창_자리", (3456, 192, 336, 528), "Color(0.56, 0.57, 0.59, 1)"),
    ]
    for 이름, (x, y, w, h), 색 in 배경:
        poly = ", ".join(수(v) for v in (x, y, x + w, y, x + w, y + h, x, y + h))
        줄.append(f'[node name="{이름}" type="Polygon2D" parent="배경_블록아웃"]\ncolor = {색}\npolygon = PackedVector2Array({poly})\n')

    줄.append('[node name="지형" type="Node2D" parent="."]\n')
    줄.extend(노드)

    # ── 연결: 출구 통로 + 진입/출구 Marker ────────────────────────────────
    줄.append('[node name="연결" type="Node2D" parent="."]\n')
    출구 = 방["exits"][0]
    줄.append(
        f'[node name="출구_쥐구멍" type="Area2D" parent="연결"]\nposition = {V(*출구["mouth_foot"])}\n'
        f'script = ExtResource("{EXT_ID["통로"]}")\n'
        '"높이" = 144.0\n"깊이" = 420.0\n'
        # 통로가 스스로 그리는 '암반'(납작한 어두운 사각형)이 SS2D 벽 그림을 덮어서 0 으로 끈다(06 캡처에서 확인).
        '"암반_위" = 0.0\n"암반_아래" = 0.0\n'
        # 다음_씬 은 비워 둔다 — 복도 씬이 아직 없다. 밟으면 연결통로가 경고만 내고 넘어가지 않는다.
        f"metadata/exit_id = {문자열(출구['id'])}\n"
        f"metadata/corridor_target_scene = {문자열(방['corridor_target']['scene'])}\n"
        f"metadata/corridor_target_marker = {문자열(방['corridor_target']['entry_marker'])}\n"
        f"metadata/status = {문자열(방['corridor_target']['status'])}\n"
    )
    for 진입 in 방["entries"]:
        줄.append(
            f'[node name="{진입["marker"]}" type="Marker2D" parent="연결"]\nposition = {V(*진입["foot"])}\n'
            f"metadata/entry_id = {문자열(진입['id'])}\nmetadata/kind = {문자열(진입['kind'])}\n"
            + (f"metadata/status = {문자열(진입['status'])}\n" if "status" in 진입 else "")
        )
    줄.append(
        f'[node name="{출구["marker"]}" type="Marker2D" parent="연결"]\nposition = {V(*출구["mouth_foot"])}\n'
        f"metadata/exit_id = {문자열(출구['id'])}\nmetadata/kind = {문자열(출구['kind'])}\n"
    )

    # ── 체크포인트(전부 구조물 위 — 칠할 수 있는 면 위에 두면 부활 즉사 위험) ──
    줄.append('[node name="체크포인트" type="Node2D" parent="."]\n')
    for cp in 방["checkpoint_candidates"]:
        줄.append(
            f'[node name="{cp["id"]}" parent="체크포인트" instance=ExtResource("{EXT_ID["체크포인트"]}")]\n'
            f"position = {V(*cp['foot'])}\ncollision_layer = 0\nmetadata/reason = {문자열(cp['reason'])}\n"
        )

    # ── 설계표식: 에디터에서만 보이는 ReferenceRect(카메라 구역·화면 크기) + 경로 Marker ──
    #   mouse_filter = 2(무시) — 런타임에도 노드는 남으므로 조준 클릭을 가로채지 않게 한다.
    줄.append('[node name="설계표식" type="Node2D" parent="."]\nmetadata/note = "에디터 전용 표시. 런타임에 그려지지 않음(ReferenceRect.editor_only)"\n')

    def 사각(이름, r, 색, 굵기):
        x, y, w, h = r
        return (
            f'[node name="{이름}" type="ReferenceRect" parent="설계표식"]\nmouse_filter = 2\n'
            f"offset_left = {수(x)}\noffset_top = {수(y)}\noffset_right = {수(x + w)}\noffset_bottom = {수(y + h)}\n"
            f"border_color = {색}\nborder_width = {수(굵기)}\n"
        )

    for z in 방["camera_zones"]:
        줄.append(사각(f"CAM_{z['id']}", z["rect"], "Color(1, 0.55, 0.1, 0.9)", 8))
    시점 = [("화면_A시작", (240, 383)), ("화면_M발코니", (1632, 959)), ("화면_B허브", (2640, 911)), ("화면_d3", (3360, 1583)), ("화면_D출구", (3360, 2015))]
    for 이름, c in 시점:
        x, y, w, h = 카메라_화면(c, 리밋)
        줄.append(사각(이름, (round(x), round(y), round(w), round(h)), "Color(0.3, 0.8, 1, 0.6)", 4))
    for 이름, 발 in [("경로_S_A", (240, 432)), ("경로_M", (1632, 1008)), ("경로_B", (2640, 960)), ("경로_W", (3624, 768)), ("경로_C", (2568, 1872)), ("경로_E", (3840, 2376))]:
        줄.append(f'[node name="{이름}" type="Marker2D" parent="설계표식"]\nposition = {V(*발)}\n')

    # ── 플레이어 ── 현행 2층방과 같은 오버라이드(점프_거리_칸 20 = 수평 320px, 높이는 Player.tscn 10칸 = 160px)
    줄.append(f'[node name="Player" parent="." instance=ExtResource("{EXT_ID["플레이어"]}")]\nposition = {V(*sp)}\n"점프_거리_칸" = 20.0\n')

    ext줄 = []
    for k, 형, uid, 경로 in EXT:
        u = f' uid="{uid}"' if uid else ""
        ext줄.append(f'[ext_resource type="{형}"{u} path="{경로}" id="{EXT_ID[k]}"]')
    load_steps = len(EXT) + len(서브) + 1
    몸 = f"[gd_scene load_steps={load_steps} format=3]\n\n" + "\n".join(ext줄) + "\n\n" + "\n".join(서브) + "\n" + "\n".join(줄)
    해시 = hashlib.sha256(몸.encode("utf-8")).hexdigest()[:16]
    return f"{표식} · out={해시} · 수정하지 말고 room_layouts.json 을 고친 뒤 다시 생성\n" + 몸


def main():
    확인만 = "--확인" in sys.argv
    강제 = "--강제" in sys.argv
    with open(입력, encoding="utf-8") as f:
        배치 = json.load(f)
    새것 = 생성(배치)
    if os.path.exists(출력):
        with open(출력, encoding="utf-8", newline="") as f:
            옛것 = f.read()
        if 옛것 == 새것:
            print("변경 없음:", os.path.relpath(출력, 저장소))
            return 0
        첫줄, _, 나머지 = 옛것.partition("\n")
        손안댐 = 첫줄.startswith(표식) and ("out=" + hashlib.sha256(나머지.encode("utf-8")).hexdigest()[:16]) in 첫줄
        if not 손안댐 and not 강제:
            print("멈춤: 기존 씬이 편집기에서 저장·수정된 흔적이 있다(생성 표식/해시 불일치). 덮어쓰려면 --강제")
            return 2
    if 확인만:
        print("쓰기 생략(--확인): 생성 결과가 기존 파일과 다르다")
        return 1
    os.makedirs(os.path.dirname(출력), exist_ok=True)
    with open(출력, "w", encoding="utf-8", newline="\n") as f:
        f.write(새것)
    print("생성:", os.path.relpath(출력, 저장소), f"({len(새것.encode('utf-8'))} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
