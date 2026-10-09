# -*- coding: utf-8 -*-
"""
쳅터1 새 기믹 → 씬 노드 글 · 손으로 고친 씬에 '추가기믹' 묶음만 갈아 끼우기 — 2026-10-09 Claude

▣ 왜 따로 있나
  쳅터1 씬 15 장 중 14 장은 도안 생성기(만들기.py)가 더는 통째로 다시 쓰지 못한다 — 목재 v03 부분 갱신·에디터 저장으로
  손본 흔적이 있어 `씬_쓰기` 가 "멈춤" 한다(덮으면 손본 값이 날아간다 · CLAUDE.md 규칙 4).
  그래서 새 기믹(부서지는판 · 그을음 · 열쇠조각 · 잠긴문 · 레버퍼즐)은 **"추가기믹" 노드 하나 아래에만** 만들고,
    · 새로 만드는 스테이지 → 만들기.py 씬_글 이 이 파일의 `노드_글()` 을 그대로 넣는다.
    · 이미 있는 스테이지 → 이 파일을 실행하면 씬 안의 "추가기믹" 묶음(과 그 ext_resource)만 지우고 새로 넣는다.
  다른 노드·지형은 한 글자도 안 건드린다. 몇 번 돌려도 결과가 같다(멱등).

▣ 실행
  python tools/쳅터1/추가기믹.py                 # 도안에 새 기믹이 있는(또는 묶음이 이미 있는) 스테이지 전부
  python tools/쳅터1/추가기믹.py 쳅터1_04_복도_B   # 하나만
  ⚠ 에디터에 그 씬이 열려 있으면 닫고(또는 저장하지 말고) 돌릴 것 — 에디터가 옛 내용으로 덮어쓴다.
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import 규격  # noqa: E402
import 도안 as 도안모듈  # noqa: E402
import 기믹 as 기믹모듈  # noqa: E402

C = 규격.칸
저장소 = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
도안폴더 = os.path.join(저장소, "scenes", "쳅터1", "도안")
씬폴더 = os.path.join(저장소, "scenes", "쳅터1", "스테이지")

장면 = {
    "판": "res://scenes/장애물/썩은마루판.tscn",
    "그을음": "res://scenes/장애물/그을음.tscn",
    "열쇠": "res://scenes/장애물/반반열쇠_조각.tscn",
    "문": "res://scenes/장애물/잠긴문.tscn",
    "퍼즐": "res://scenes/쳅터1/기믹/레버퍼즐.tscn",
    "레버": "res://scenes/쳅터1/기믹/벽레버.tscn",
    "샹들리에": "res://scenes/쳅터1/기믹/샹들리에함정.tscn",
    "단서": "res://scenes/쳅터1/기믹/단서판.tscn",
    "비밀문": "res://scenes/쳅터1/기믹/비밀문.tscn",
    "양초": "res://scenes/쳅터1/기믹/타이머양초.tscn",
    # [2026-10-09 거미방]
    "반딧불": "res://scenes/쳅터1/기믹/반딧불몹.tscn",
    "거미줄": "res://scenes/쳅터1/기믹/거미줄.tscn",
    "빛받이": "res://scenes/쳅터1/기믹/빛받이.tscn",
    "누름발판": "res://scenes/쳅터1/기믹/누름발판.tscn",
    "튀어나오는판": "res://scenes/쳅터1/기믹/튀어나오는판.tscn",
    "상자": "res://scenes/집/스마트월드_장애물/박스.tscn",
}
# [2026-10-09] 씬 리소스 id 는 **영문·숫자·밑줄만** 된다(Godot: "The scene unique ID must contain only letters, numbers,
#   and underscores"). 예전엔 "추가_반딧불" 처럼 한글 id 를 써서 씬을 열 때마다 오류가 쏟아졌다 → 아래 표로 바꿔 쓴다.
#   지울 때는 옛 한글 id("추가_…")와 새 id("add_…")를 둘 다 지운다(이미 끼운 씬도 다시 돌리면 깨끗해진다).
_아스키 = {"판": "plank", "그을음": "soot", "열쇠": "key", "문": "door", "퍼즐": "puzzle", "레버": "lever",
         "샹들리에": "chandelier", "단서": "hint", "비밀문": "secret", "양초": "candle", "반딧불": "firefly",
         "거미줄": "web", "빛받이": "receiver", "누름발판": "plate", "튀어나오는판": "popout", "상자": "box"}
_지형아스키 = {"흰": "white", "검정": "black", "유령": "ghost", "구조": "struct"}

새종류 = (기믹모듈.부서지는판, 기믹모듈.그을음, 기믹모듈.열쇠조각, 기믹모듈.잠긴문, 기믹모듈.레버퍼즐, 기믹모듈.촛불,
         기믹모듈.반딧불몹, 기믹모듈.그을음거미, 기믹모듈.빛받이, 기믹모듈.누름계단)


def _수(v):
    v = float(v)
    return str(int(v)) if v == int(v) else f"{v:.6g}"


def _V(x, y):
    return f"Vector2({_수(x)}, {_수(y)})"


def 새기믹(dn):
    return [g for g in 기믹모듈.목록(dn) if isinstance(g, 새종류)]


def 노드_글(dn):
    """(ext 목록 [(id, 경로)], 노드 글) — 새 기믹이 없으면 ([], "")."""
    gs = 새기믹(dn)
    if not gs:
        return [], ""
    쓰는 = set()
    줄 = ['[node name="추가기믹" type="Node2D" parent="."]\n']
    for g in gs:
        e = g.엔진값() if hasattr(g, "엔진값") else {}
        if isinstance(g, 기믹모듈.부서지는판):
            쓰는.add("판")
            for k, (x, y) in enumerate(e["판들"]):
                줄.append(f'[node name="부서지는판{g.i:02d}_{k + 1}" parent="추가기믹" instance=ExtResource("추가_판")]\n'
                         f"position = {_V(x, y)}\n")
        elif isinstance(g, 기믹모듈.촛불):
            쓰는.add("양초")
            # 꺼지지 않는 양초 = 그을음 안전지대(타이머양초 · 켜둠 + 영원)
            줄.append(f'[node name="촛불{g.i:02d}" parent="추가기믹" instance=ExtResource("추가_양초")]\n'
                     f'position = {_V(*e["원점"])}\n"켜둠" = true\n"영원" = true\n')
        elif isinstance(g, 기믹모듈.그을음거미):
            # [2026-10-09] 그을음 거미 = 같은 그을음 장면 + 칠 자리(거미줄 노드는 형제로 둔다 — 거미가 타도 줄 노드는 남아야 한다)
            쓰는.update(["그을음", "거미줄"])
            줄경로 = ", ".join(f'NodePath("../거미{g.i:02d}_줄{k + 1}")' for k in range(len(e["줄들"])))
            줄.append(f'[node name="거미{g.i:02d}" parent="추가기믹" instance=ExtResource("추가_그을음")]\n'
                     f'position = {_V(*e["원점"])}\n"방향" = {e["방향"]}\n"거미줄들" = Array[NodePath]([{줄경로}])\n')
            for k, w in enumerate(e["줄들"]):
                줄.append(f'[node name="거미{g.i:02d}_줄{k + 1}" parent="추가기믹" instance=ExtResource("추가_거미줄")]\n'
                         f'position = {_V(*w["원점"])}\n"나" = {_V(*w["나"])}\n"처음부터" = {"true" if w["처음부터"] else "false"}\n')
        elif isinstance(g, 기믹모듈.반딧불몹):
            # [2026-10-09] 반딧불 몹 — 멈춤들은 첫 정지점 기준 로컬 · 새장 레버는 형제 노드(레버만 따로 옮겨도 이어진다)
            쓰는.add("반딧불")
            n = f"반딧불{g.i:02d}"
            멈춤 = ", ".join(f"{_수(x)}, {_수(y)}" for x, y in e["멈춤들"])
            본 = [f'[node name="{n}" parent="추가기믹" instance=ExtResource("추가_반딧불")]', f"position = {_V(*e['원점'])}",
                 f'"멈춤들" = PackedVector2Array({멈춤})', f'"순환" = {e["순환"]}', f'"머묾" = {_수(e["머묾"])}',
                 f'"반경" = {_수(e["반경"])}', f'"색_시간" = {_수(e["색시간"])}']
            if "새장_멈춤" in e:
                본 += [f'"새장_멈춤" = {e["새장_멈춤"]}', f'"새장_레버" = NodePath("../{n}_새장레버")']
            줄.append("\n".join(본) + "\n")
            if "새장_멈춤" in e:
                쓰는.add("레버")
                줄.append(f'[node name="{n}_새장레버" parent="추가기믹" instance=ExtResource("추가_레버")]\n'
                         f'position = {_V(*e["새장_레버"])}\n')
        elif isinstance(g, 기믹모듈.빛받이):
            # [2026-10-09] 빛받이 + 그 문(비밀문 · 창살 모양) — 문은 형제 노드 "<이름>_문"
            쓰는.add("빛받이")
            n = f"빛받이{g.i:02d}"
            본 = [f'[node name="{n}" parent="추가기믹" instance=ExtResource("추가_빛받이")]', f"position = {_V(*e['원점'])}",
                 f'"요구색" = {e["요구색"]}', f'"유지" = {"true" if e["유지"] else "false"}']
            if "문" in e:
                본.append(f'"열것들" = Array[NodePath]([NodePath("../{n}_문")])')
            줄.append("\n".join(본) + "\n")
            if "문" in e:
                쓰는.add("비밀문")
                d = e["문"]
                줄.append(f'[node name="{n}_문" parent="추가기믹" instance=ExtResource("추가_비밀문")]\n'
                         f'position = {_V(*d["원점"])}\n"크기" = {_V(*d["크기"])}\n"밀림" = {_V(*d["밀림"])}\n"모양" = {d["모양"]}\n')
        elif isinstance(g, 기믹모듈.누름계단):
            # [2026-10-09] 압력 발판(공용 압력버튼.gd) + 튀어나오는 판들 + (있으면) 상자 — 판은 형제 노드, 발판이 경로로 움직인다
            쓰는.update(["누름발판", "튀어나오는판"])
            n = f"누름계단{g.i:02d}"
            판경로 = ", ".join(f'NodePath("../{n}_판{k + 1}")' for k in range(len(e["판들"])))
            이동 = ", ".join(_V(*p["이동"]) for p in e["판들"])
            지연 = ", ".join(_수(p["지연"]) for p in e["판들"])
            줄.append(f'[node name="{n}_발판" parent="추가기믹" instance=ExtResource("추가_누름발판")]\n'
                     f'position = {_V(*e["발판"])}\n"생김새" = 1\n"그림_깊이" = 7.0\n"밟는면_충돌" = false\n'
                     f'"폭" = {_수(e["발판폭"])}\n"높이" = 12.0\n'
                     f'"작동방식" = {1 if e["유지"] else 0}\n"누름_가능_그룹" = PackedStringArray("player", "박스")\n'
                     f'"이동속도" = 360.0\n"대상들" = Array[NodePath]([{판경로}])\n'
                     f'"대상_이동량들" = Array[Vector2]([{이동}])\n"대상_지연들" = Array[float]([{지연}])\n')
            for k, p in enumerate(e["판들"]):
                줄.append(f'[node name="{n}_판{k + 1}" parent="추가기믹" instance=ExtResource("추가_튀어나오는판")]\n'
                         f'position = {_V(*p["원점"])}\n"크기" = {_V(*p["크기"])}\n')
            if "상자" in e:
                쓰는.add("상자")
                줄.append(f'[node name="{n}_상자" parent="추가기믹" instance=ExtResource("추가_상자")]\n'
                         f'position = {_V(*e["상자"])}\n"생김새" = 1\n"부활하면_제자리" = true\n"낙사_y" = 2400.0\n')
        elif isinstance(g, 기믹모듈.그을음):
            쓰는.add("그을음")
            줄.append(f'[node name="그을음{g.i:02d}" parent="추가기믹" instance=ExtResource("추가_그을음")]\n'
                     f'position = {_V(*e["원점"])}\n"방향" = {e["방향"]}\n')
        elif isinstance(g, 기믹모듈.열쇠조각):
            쓰는.add("열쇠")
            줄.append(f'[node name="열쇠조각{g.i:02d}" parent="추가기믹" instance=ExtResource("추가_열쇠")]\n'
                     f'position = {_V(*e["원점"])}\n"쪽" = {e["쪽"]}\n"주인_씬" = "{e["주인"]}"\n')
        elif isinstance(g, 기믹모듈.잠긴문):
            쓰는.add("문")
            # 문은 실행 때 길목 노드를 찾아 붙는다(관리자가 붙이기) — 자리는 길목이 정한다
            줄.append(f'[node name="잠긴문{g.i:02d}" parent="추가기믹" instance=ExtResource("추가_문")]\n'
                     f'"길목" = NodePath("../../연결/{g.연결}")\n')
        elif isinstance(g, 기믹모듈.레버퍼즐):
            쓰는.update(["퍼즐", "레버"])
            p = f"레버퍼즐{g.i:02d}"
            부 = f"추가기믹/{p}"
            레버경로 = ", ".join(f'NodePath("레버{k + 1}")' for k in range(len(g.레버)))
            정답 = ", ".join("true" if v else "false" for v in g.정답)
            본 = [f'[node name="{p}" parent="추가기믹" instance=ExtResource("추가_퍼즐")]',
                 f'"레버들" = Array[NodePath]([{레버경로}])', '"손잡이" = NodePath("손잡이")',
                 f'"정답" = Array[bool]([{정답}])', f'"제한시간" = {_수(g.제한시간)}']
            if "샹들리에" in e:
                본.append('"샹들리에" = NodePath("샹들리에")')
            if "비밀문" in e:
                본.append('"열것들" = Array[NodePath]([NodePath("비밀문")])')
                본.append('"비출_점" = NodePath("비밀문")')
            if "양초" in e:
                본.append('"양초" = NodePath("양초")')
            줄.append("\n".join(본) + "\n")
            for k, (x, y) in enumerate(e["레버"]):
                줄.append(f'[node name="레버{k + 1}" parent="{부}" instance=ExtResource("추가_레버")]\nposition = {_V(x, y)}\n')
            줄.append(f'[node name="손잡이" parent="{부}" instance=ExtResource("추가_레버")]\n'
                     f'position = {_V(*e["손잡이"])}\n"손잡이형" = true\n')
            if "샹들리에" in e:
                쓰는.add("샹들리에")
                줄.append(f'[node name="샹들리에" parent="{부}" instance=ExtResource("추가_샹들리에")]\n'
                         f'position = {_V(*e["샹들리에"])}\n"폭" = 224.0\n"늘어짐" = {_수(e["샹들리에_늘어짐"])}\n')
            if "단서" in e:
                쓰는.add("단서")
                줄.append(f'[node name="단서판" parent="{부}" instance=ExtResource("추가_단서")]\n'
                         f'position = {_V(*e["단서"])}\n"퍼즐" = NodePath("..")\n')
            if "비밀문" in e:
                쓰는.add("비밀문")
                b = e["비밀문"]
                줄.append(f'[node name="비밀문" parent="{부}" instance=ExtResource("추가_비밀문")]\n'
                         f'position = {_V(*b["원점"])}\n"밀림" = {_V(b["밀림"], 0)}\n')
            if "양초" in e:
                쓰는.add("양초")
                줄.append(f'[node name="양초" parent="{부}" instance=ExtResource("추가_양초")]\n'
                         f'position = {_V(*e["양초"])}\n"시간" = {_수(max(g.제한시간, 1.0))}\n')
    글 = "\n".join(줄)
    for k in 쓰는:
        글 = 글.replace(f'ExtResource("추가_{k}")', f'ExtResource("add_{_아스키[k]}")')
    ext = [(f"add_{_아스키[k]}", 장면[k]) for k in sorted(쓰는)]
    return ext, 글


# ── [2026-10-09] 추가지형 — 손으로 고친 씬에 새 판(흰·검정·유령)만 얹기 ─────────────────────────────
#   도안 "추가지형" 사각형 → SS2D 지형 노드(+ 점 sub_resource). 템플릿·점 스크립트는 그 씬이 이미 쓰는 ext id 를 찾아 쓴다
#   (쳅터1 씬은 모두 같은 목재 템플릿 3_tpl_black · 4_tpl_white · 5_tpl_ghost 와 SS2D 점 스크립트를 싣고 있다).
#   다각형 = 사각형 네 꼭짓점(시계방향 · 생성기와 같은 순서) · 속성 = 만들기.py 종류표(흰 = 위치별_판정 · 검정 = 시작상태 1).
_템플릿경로 = {"검정": "res://scenes/지형/목재/목재_데크_검정.tscn", "구조": "res://scenes/지형/목재/목재_데크_검정.tscn",
             "흰": "res://scenes/지형/목재/목재_데크_흰색.tscn", "유령": "res://scenes/지형/목재/목재_데크_투명.tscn"}
_점경로 = "res://addons/rmsmartshape/shapes/point.gd"
_점배열경로 = "res://addons/rmsmartshape/shapes/point_array.gd"


def _ext_id(글, 경로):
    m = re.search(r'^\[ext_resource [^\n]*path="' + re.escape(경로) + r'"[^\n]*id="([^"]+)"', 글, re.M)
    return m.group(1) if m else None


def 지형_글(dn, 글):
    """(새 ext [(id, 종류, 경로)], sub_resource 글, 노드 글) — 추가지형이 없으면 ([], "", "")."""
    import 만들기 as 만들기모듈       # 종류표(속성) — 함수 안에서 읽는다(만들기.py 도 이 파일을 부른다)
    if not getattr(dn, "추가지형", None):
        return [], "", ""
    새ext = []
    ids = {}
    for 이름, 경로, 형 in [("점", _점경로, "Script"), ("점배열", _점배열경로, "Script")] + \
            [(k, v, "PackedScene") for k, v in _템플릿경로.items()]:
        i = _ext_id(글, 경로)
        if i is None:
            i = "add_" + ("ss2d_point" if 이름 == "점" else "ss2d_points" if 이름 == "점배열" else "tpl_" + _지형아스키[이름])
            if all(i != e[0] for e in 새ext):
                새ext.append((i, 형, 경로))
        ids[이름] = i
    서브, 노드 = [], ['[node name="추가지형" type="Node2D" parent="."]\n']
    세기 = {}
    for k, x, y, w, h in dn.추가지형:
        세기[k] = 세기.get(k, 0) + 1
        x0, y0, x1, y1 = x * C, y * C, (x + w) * C, (y + h) * C
        cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
        점 = [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]
        로컬 = [(px - cx, py - cy) for px, py in 점] + [(x0 - cx, y0 - cy)]
        sid = f"add_t_{_지형아스키[k]}{세기[k]:02d}"
        pids = []
        for i, (lx, ly) in enumerate(로컬):
            pid = f"{sid}_P{i}"
            pids.append(pid)
            서브.append(f'[sub_resource type="Resource" id="{pid}"]\nscript = ExtResource("{ids["점"]}")\nposition = {_V(lx, ly)}\n')
        n = len(로컬)
        사전 = ",\n".join(f'{i}: SubResource("{q}")' for i, q in enumerate(pids))
        서브.append(f'[sub_resource type="Resource" id="{sid}_PA"]\nscript = ExtResource("{ids["점배열"]}")\n'
                   f"_points = {{\n{사전}\n}}\n_point_order = PackedInt32Array({', '.join(str(i) for i in range(n))})\n"
                   f"_constraints = {{\nVector2i(0, {n - 1}): 15\n}}\n_next_key = {n}\n")
        _템플릿, 속성, 역할 = 만들기모듈.종류표[k]
        본 = [f'[node name="{ {"흰": "흰판", "검정": "검정판", "유령": "유령판", "구조": "구조"}[k] }추가{세기[k]:02d}" parent="추가지형" instance=ExtResource("{ids[k]}")]',
             f"position = {_V(cx, cy)}"]
        본 += [f"{a} = {b}" for a, b in 속성]
        본 += [f'_points = SubResource("{sid}_PA")', "collision_size = 0.0",
              f'metadata/role = "{역할}"', f'metadata/design_kind = "{k}"']
        노드.append("\n".join(본) + "\n")
    return 새ext, "\n".join(서브), "\n".join(노드)


def 지형_갈아끼우기(글, 새ext, 서브, 노드):
    """옛 추가지형(노드 · 추가_ sub_resource · 추가_ 스크립트/템플릿 ext)을 지우고 새로 넣는다. 멱등."""
    지울 = []
    for a, b, 머리 in _블록들(글):
        if 머리.startswith("[sub_resource") and ('id="추가_' in 머리 or 'id="add_t_' in 머리):
            지울.append((a, b))
        elif 머리.startswith("[ext_resource") and any(f'id="{q}' in 머리 for q in ("추가_점", "추가_tpl_", "add_ss2d_", "add_tpl_")):
            지울.append((a, b))
        elif 머리.startswith("[node "):
            이름 = re.search(r'name="([^"]+)"', 머리).group(1)
            부모 = re.search(r'parent="([^"]*)"', 머리)
            부모 = 부모.group(1) if 부모 else None
            if (이름 == "추가지형" and 부모 == ".") or 부모 == "추가지형":
                지울.append((a, b))
    for a, b in reversed(지울):
        글 = 글[:a] + 글[b:]
    if not 노드:
        return re.sub(r"\n{3,}", "\n\n", 글)
    if 새ext:
        ext글 = "".join(f'[ext_resource type="{형}" path="{경로}" id="{i}"]\n' for i, 형, 경로 in 새ext)
        블 = _블록들(글)
        마지막ext = max((b for a, b, h in 블 if h.startswith("[ext_resource")), default=None)
        a = 글.rindex("[ext_resource", 0, 마지막ext)
        줄끝 = 글.index("\n", a) + 1
        글 = 글[:줄끝] + ext글 + 글[줄끝:]
    # sub_resource — 첫 [node 앞(씬 뿌리 노드보다 먼저 와야 한다)
    m = re.search(r"^\[node ", 글, re.M)
    글 = 글[:m.start()] + 서브 + "\n" + 글[m.start():]
    # 노드 — "지형" 노드 묶음 바로 뒤가 좋지만 위치는 상관없다 → Player 앞
    m = re.search(r'^\[node name="Player"', 글, re.M)
    자리 = m.start() if m else len(글)
    글 = 글[:자리] + 노드 + "\n" + 글[자리:]
    if re.search(r"load_steps=\d+", 글):
        n = len(re.findall(r"^\[(?:ext_resource|sub_resource) ", 글, re.M)) + 1
        글 = re.sub(r"load_steps=\d+", f"load_steps={n}", 글, count=1)
    return re.sub(r"\n{3,}", "\n\n", 글)


# ── 이미 있는 씬에 갈아 끼우기 ─────────────────────────────────────────────────
_노드머리 = re.compile(r'^\[node name="([^"]+)"[^\n]*?(?:parent="([^"]*)")?[^\n]*\]$', re.M)


def _블록들(글):
    """씬 글 → [(시작, 끝, 머리줄)] — 각 [ ... ] 블록(ext/sub/node) 의 범위."""
    머리들 = [m for m in re.finditer(r"^\[[^\n]*\]$", 글, re.M)]
    out = []
    for i, m in enumerate(머리들):
        끝 = 머리들[i + 1].start() if i + 1 < len(머리들) else len(글)
        out.append((m.start(), 끝, m.group()))
    return out


def 갈아끼우기(글, ext, 노드):
    # 1) 예전 묶음 지우기 — ext id "추가_…" · 노드 "추가기믹" 과 그 아래
    지울 = []
    for a, b, 머리 in _블록들(글):
        if 머리.startswith("[ext_resource") and ('id="추가_' in 머리 or 'id="add_' in 머리):
            지울.append((a, b))
        elif 머리.startswith("[node "):
            이름 = re.search(r'name="([^"]+)"', 머리).group(1)
            부모 = re.search(r'parent="([^"]*)"', 머리)
            부모 = 부모.group(1) if 부모 else None
            if (이름 == "추가기믹" and 부모 == ".") or (부모 and (부모 == "추가기믹" or 부모.startswith("추가기믹/"))):
                지울.append((a, b))
    for a, b in reversed(지울):
        글 = 글[:a] + 글[b:]
    if not 노드:
        return re.sub(r"\n{3,}", "\n\n", 글)
    # 2) ext — 마지막 ext_resource 블록 뒤
    ext글 = "".join(f'[ext_resource type="PackedScene" path="{경로}" id="{i}"]\n' for i, 경로 in ext)
    블 = _블록들(글)
    마지막ext = max((b for a, b, h in 블 if h.startswith("[ext_resource")), default=None)
    if 마지막ext is None:
        첫 = 글.index("\n\n") + 2
        글 = 글[:첫] + ext글 + "\n" + 글[첫:]
    else:
        # 블록 끝은 다음 머리 시작이다 — ext 줄 바로 뒤(빈 줄 앞)에 붙인다
        a = 글.rindex("[ext_resource", 0, 마지막ext)
        줄끝 = 글.index("\n", a) + 1
        글 = 글[:줄끝] + ext글 + 글[줄끝:]
    # 3) 노드 — Player 앞(없으면 끝)
    m = re.search(r'^\[node name="Player"', 글, re.M)
    자리 = m.start() if m else len(글)
    글 = 글[:자리] + 노드 + "\n" + 글[자리:]
    # 3') ext 묶음과 다음 블록 사이 빈 줄 한 줄(다시 돌릴 때 지운 ext 블록의 빈 줄까지 같이 지워진다 → 되살린다)
    글 = re.sub(r"(\[ext_resource [^\n]*\]\n)(\[(?:sub_resource|node) )", r"\1\n\2", 글)
    # 4) load_steps(있으면) = ext + sub + 1
    if re.search(r"load_steps=\d+", 글):
        n = len(re.findall(r"^\[(?:ext_resource|sub_resource) ", 글, re.M)) + 1
        글 = re.sub(r"load_steps=\d+", f"load_steps={n}", 글, count=1)
    return re.sub(r"\n{3,}", "\n\n", 글)


def 적용(이름들=()):
    바뀜 = []
    for 파일 in sorted(os.listdir(도안폴더)):
        if not 파일.endswith(".json"):
            continue
        dn = 도안모듈.도안(os.path.join(도안폴더, 파일))
        if 이름들 and dn.이름 not in 이름들:
            continue
        경로 = os.path.join(씬폴더, dn.이름 + ".tscn")
        if not os.path.exists(경로):
            continue
        # 작업 사본은 CRLF 일 수 있다(.gitattributes eol=lf · autocrlf) — LF 로 맞춰 다룬다(저장소에는 어차피 LF 로 들어간다)
        옛 = open(경로, encoding="utf-8", newline="").read().replace(chr(13) + chr(10), chr(10))
        # 생성기가 통째로 쓰는 씬(첫 줄 표식 · 손안댐)은 만들기.py 가 이미 같은 묶음을 넣었다 — 건드리면 생성기의
        #   '손안댐' 해시가 깨져 다음 생성이 멈춘다(2026-10-09 겪음). 새 스테이지(16·17·18)가 여기에 해당.
        if 옛.startswith("; 생성: tools/쳅터1/만들기.py"):
            continue
        ext, 노드 = 노드_글(dn)
        새 = 옛
        if 노드 or "추가기믹" in 옛:
            새 = 갈아끼우기(새, ext, 노드)
        # [2026-10-09] 추가지형(새 흰·검정 판) — 손으로 고친 씬에만(생성기 소유 씬은 만들기.py 가 격자에서 같이 만든다)
        t_ext, t_서브, t_노드 = 지형_글(dn, 새)
        if t_노드 or "추가지형" in 새:
            새 = 지형_갈아끼우기(새, t_ext, t_서브, t_노드)
        if 새 != 옛:
            # 편집기·색인기가 파일을 잠깐 잡고 있으면 바로 쓰기가 실패한다(Errno 22) → 임시 파일 + 바꿔치기 + 재시도(만들기.py 와 같은 방법)
            import time
            임시 = 경로 + ".임시"
            with open(임시, "w", encoding="utf-8", newline="\n") as f:
                f.write(새)
            for _ in range(40):
                try:
                    os.replace(임시, 경로)
                    break
                except OSError:
                    time.sleep(0.25)
            else:
                os.replace(임시, 경로)
            바뀜.append(dn.이름)
            print(f"  추가기믹 → {dn.이름} (기믹 {len(새기믹(dn))} · 추가지형 {len(getattr(dn, '추가지형', []))})")
    return 바뀜


if __name__ == "__main__":
    적용(tuple(a for a in sys.argv[1:] if not a.startswith("--")))
