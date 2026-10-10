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
    # [2026-10-10] 손본 씬에 나중에 넣는 옛 종류("추가": true) · 추가가시
    "빛": "res://scenes/쳅터1/기믹/창문빛.tscn",
    "도약대": "res://scenes/집/스마트월드_장애물/도약대.tscn",
    "발판": "res://scenes/집/스마트월드_장애물/움직이는발판.tscn",
    "가시": "res://scenes/장애물/가시.tscn",
}
# [2026-10-09] 씬 리소스 id 는 **영문·숫자·밑줄만** 된다(Godot: "The scene unique ID must contain only letters, numbers,
#   and underscores"). 예전엔 "추가_반딧불" 처럼 한글 id 를 써서 씬을 열 때마다 오류가 쏟아졌다 → 아래 표로 바꿔 쓴다.
#   지울 때는 옛 한글 id("추가_…")와 새 id("add_…")를 둘 다 지운다(이미 끼운 씬도 다시 돌리면 깨끗해진다).
_아스키 = {"판": "plank", "그을음": "soot", "열쇠": "key", "문": "door", "퍼즐": "puzzle", "레버": "lever",
         "샹들리에": "chandelier", "단서": "hint", "비밀문": "secret", "양초": "candle", "반딧불": "firefly",
         "거미줄": "web", "빛받이": "receiver", "누름발판": "plate", "튀어나오는판": "popout", "상자": "box",
         "빛": "light", "도약대": "pad", "발판": "mover", "가시": "spike"}
_지형아스키 = {"흰": "white", "검정": "black", "유령": "ghost", "구조": "struct", "흰구조": "wstruct"}

새종류 = (기믹모듈.부서지는판, 기믹모듈.그을음, 기믹모듈.열쇠조각, 기믹모듈.잠긴문, 기믹모듈.레버퍼즐, 기믹모듈.촛불,
         기믹모듈.반딧불몹, 기믹모듈.그을음거미, 기믹모듈.빛받이, 기믹모듈.누름계단)


def _수(v):
    v = float(v)
    return str(int(v)) if v == int(v) else f"{v:.6g}"


def _V(x, y):
    return f"Vector2({_수(x)}, {_수(y)})"


# [2026-10-10 Claude] 옛 종류(빛줄기·도약대·움직이는발판)도 도안에 "추가": true 를 적으면 이 묶음에 들어간다 —
#   손으로 고친 씬은 생성기가 "장애물" 을 다시 못 쓰기 때문(도형님 10-10 "스테이지마다 기믹 4개 이상").
_옛종류_장면 = {"빛줄기": "빛", "도약대": "도약대", "움직이는발판": "발판"}


def 새기믹(dn):
    return [g for g in 기믹모듈.목록(dn) if isinstance(g, 새종류) or getattr(g, "추가", False)]


def 노드_글(dn):
    """(ext 목록 [(id, 경로)], 노드 글) — 새 기믹이 없으면 ([], "")."""
    gs = 새기믹(dn)
    가시들 = getattr(dn, "추가가시", [])
    if not gs and not 가시들:
        return [], ""
    쓰는 = set()
    줄 = ['[node name="추가기믹" type="Node2D" parent="."]\n']
    # [2026-10-10] 추가가시 — 생성기 "장애물" 의 가시와 같은 글(20칸씩 끊는다)
    k = 0
    for gx, gy, gw in 가시들:
        쓰는.add("가시")
        x = gx
        while x < gx + gw:
            n = min(20, gx + gw - x)
            k += 1
            줄.append(f'[node name="추가가시{k:02d}" parent="추가기믹" instance=ExtResource("추가_가시")]\n'
                     f'position = {_V((x + n / 2) * C, gy * C)}\n"칸수" = {n}\n')
            x += n
    for g in gs:
        e = g.엔진값() if hasattr(g, "엔진값") else {}
        종류 = type(g).__name__
        if getattr(g, "추가", False) and 종류 in _옛종류_장면:
            # 속성 줄은 생성기와 같은 함수(만들기.기믹_본) — 노드 이름도 생성기와 같게(빛줄기03 …) 해서 시험이 찾게 한다
            import 만들기 as 만들기모듈
            쓰는.add(_옛종류_장면[종류])
            줄.append("\n".join([f'[node name="{종류}{g.i:02d}" parent="추가기믹" instance=ExtResource("추가_{_옛종류_장면[종류]}")]']
                                + 만들기모듈.기믹_본(g)) + "\n")
        elif isinstance(g, 기믹모듈.부서지는판):
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
                     f'position = {_V(*e["원점"])}\n"방향" = {e["방향"]}\n'
                     # 도안에 적은 첫 만남의 예고·영역을 씬에도 전달해야 설계와 실제 거미 난도가 일치한다.
                     + "".join(f'"{k}" = {_수(v)}\n' for k, v in g.설정.items()))
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
             "흰구조": "res://scenes/지형/목재/목재_데크_흰색.tscn",
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
        본 = [f'[node name="{ {"흰": "흰판", "검정": "검정판", "유령": "유령판", "구조": "구조", "흰구조": "흰구조"}[k] }추가{세기[k]:02d}" parent="추가지형" instance=ExtResource("{ids[k]}")]',
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


def _내_ext(머리):
    """이 ext 줄이 추가기믹 묶음 것인가. ⚠ 추가지형 것(add_ss2d_* · add_tpl_* · 옛 추가_점 · 추가_tpl_)은 아니다 —
    [2026-10-10] 예전엔 "add_" 로 시작하면 다 지워서, 추가지형을 다시 안 쓰는 씬에선 그 템플릿 ext 가 사라질 뻔했다."""
    m = re.search(r'id="([^"]+)"', 머리)
    i = m.group(1) if m else ""
    if i.startswith("추가_"):
        return not (i.startswith("추가_점") or i.startswith("추가_tpl"))
    return i in {"add_" + v for v in _아스키.values()}


def _묶음인가(머리):
    이름 = re.search(r'name="([^"]+)"', 머리).group(1)
    부모 = re.search(r'parent="([^"]*)"', 머리)
    부모 = 부모.group(1) if 부모 else None
    return (이름 == "추가기믹" and 부모 == ".") or bool(부모 and (부모 == "추가기믹" or 부모.startswith("추가기믹/")))


def 갈아끼우기(글, ext, 노드):
    # [2026-10-10] **제자리에서** 바꾼다 — 예전엔 묶음을 지우고 Player 앞에 다시 넣어서, 바뀐 게 없어도
    #   씬마다 수십 줄이 옮겨졌다(04·05·08·10·11·13·18). 이제 ① 같은 묶음이면 그대로 ② 다르면 옛 자리에 새 글
    #   ③ ext 는 그대로 쓰는 줄은 두고, 안 쓰는 줄만 빼고, 없는 줄만 마지막 ext 뒤에 붙인다.
    필요 = dict(ext)
    블 = _블록들(글)
    옛묶음 = "".join(글[a:b] for a, b, h in 블 if h.startswith("[node ") and _묶음인가(h))
    정리 = lambda t: re.sub(r"\n{2,}", "\n", re.sub(r" unique_id=\d+", "", t)).strip()
    if 옛묶음 and 정리(옛묶음) == 정리(노드):
        노드 = None                          # 노드는 그대로 둔다(에디터가 붙인 unique_id 도 보존)
    자리표 = "\x00추가기믹자리\x00"
    부분 = [글[:블[0][0]] if 블 else 글]
    있는ext = set()
    넣음 = False
    for a, b, 머리 in 블:
        t = 글[a:b]
        if 머리.startswith("[ext_resource") and _내_ext(머리):
            i = re.search(r'id="([^"]+)"', 머리).group(1)
            경로 = re.search(r'path="([^"]+)"', 머리)
            if 필요.get(i) == (경로.group(1) if 경로 else None) and i not in 있는ext:
                있는ext.add(i)
                부분.append(t)
            continue
        if 머리.startswith("[node ") and _묶음인가(머리) and 노드 is not None:
            if not 넣음:
                부분.append(자리표)
                넣음 = True
            continue
        부분.append(t)
    글 = "".join(부분)
    if 노드 is None:                         # 묶음이 같다 — ext 만 정리했다
        return re.sub(r"\n{3,}", "\n\n", 글)
    if not 노드:
        return re.sub(r"\n{3,}", "\n\n", 글.replace(자리표, ""))
    # 2) 없는 ext — 마지막 ext_resource 줄 뒤
    빠진 = [(i, 경로) for i, 경로 in ext if i not in 있는ext]
    if 빠진:
        ext글 = "".join(f'[ext_resource type="PackedScene" path="{경로}" id="{i}"]\n' for i, 경로 in 빠진)
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
    # 3) 노드 — 옛 묶음 자리(없으면 Player 앞 · 그것도 없으면 끝)
    if 넣음:
        글 = 글.replace(자리표, 노드 + "\n")
    else:
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


_빛_동작키 = ('"시작색"', '"주기"', '"위상"', '"점멸"')


def _같은값(a, b):
    a, b = a.strip(), b.strip()
    try:
        return float(a) == float(b)
    except ValueError:
        return a == b


def 장애물_맞추기(dn, 글):
    """[2026-10-10 Claude] 손으로 고친 씬의 "장애물/빛줄기NN"(생성기가 만든 옛 빛)에 도안의 **동작 값**만 옮긴다.
    도형님 05 제보로 구조가 검정이 되며 10·12 의 고정 흰 빛을 점멸로 바꿔야 했다 — 그 한 줄을 도안에서 씬으로.
    ⚠ 자리·각도·길이는 안 건드린다(Codex 가 창문 그림에 맞춰 손본 값일 수 있다). 노드가 없으면 그냥 지나간다."""
    import 만들기 as 만들기모듈
    for g in 기믹모듈.목록(dn):
        if not isinstance(g, 기믹모듈.빛줄기) or getattr(g, "추가", False):
            continue
        머리 = re.search(r'^\[node name="빛줄기%02d" parent="장애물"[^\n]*\]$' % g.i, 글, re.M)
        if not 머리:
            continue
        끝 = 글.find("\n[", 머리.end())
        끝 = len(글) if 끝 < 0 else 끝 + 1
        블록 = 글[머리.start():끝]
        새블록 = 블록
        for 줄 in 만들기모듈.기믹_본(g):
            키, 값 = 줄.split(" = ", 1)
            if 키 not in _빛_동작키:
                continue
            m = re.search(r"^" + re.escape(키) + r" = (.*)$", 새블록, re.M)
            if m and _같은값(m.group(1), 값):
                continue                  # 에디터는 0 을 0.0 으로 쓴다 — 값이 같으면 글자도 그대로
            새블록 = re.sub(r"^" + re.escape(키) + r" = .*$", 줄.replace("\\", "\\\\"), 새블록, count=1, flags=re.M)
        if 새블록 != 블록:
            print(f"    {dn.이름}/장애물/빛줄기{g.i:02d}: 동작 값 맞춤")
            글 = 글[:머리.start()] + 새블록 + 글[끝:]
    return 글


def 지형_맞추기(dn, 글):
    """[2026-10-10] 추가지형을 **조금씩** 맞춘다 — 같은 이름·같은 자리의 판은 글자 하나 안 건드리고,
    바뀌었거나 도안에서 빠진 판만 지우고(점 sub_resource 까지), 새 판만 붙인다.
    왜: 에디터가 저장한 씬(01)의 추가지형 판에는 구운 메시·재질·unique_id 가 붙어 있다 — 통째로 다시 쓰면 날아간다."""
    t_ext, t_서브, t_노드 = 지형_글(dn, 글)
    if not t_노드:
        return 지형_갈아끼우기(글, t_ext, t_서브, t_노드) if "추가지형" in 글 else 글
    원함 = {}
    for 블 in re.split(r"\n(?=\[node )", t_노드.strip() + "\n"):
        m = re.search(r'name="([^"]+)" parent="추가지형"', 블)
        if m:
            원함[m.group(1)] = 블.rstrip("\n") + "\n"
    서브블 = {}
    for 블 in re.split(r"\n(?=\[sub_resource )", t_서브.strip() + "\n"):
        m = re.search(r'id="(add_t_[a-z]+\d\d)_', 블)
        if m:
            서브블.setdefault(m.group(1), []).append(블.rstrip("\n") + "\n")
    자리 = lambda t: (re.search(r"^position = (.*)$", t, re.M) or [None, None])[1]
    지울, 남김 = [], set()
    블 = _블록들(글)
    for a, b, 머리 in 블:
        if not (머리.startswith("[node ") and 'parent="추가지형"' in 머리):
            continue
        이름 = re.search(r'name="([^"]+)"', 머리).group(1)
        if 이름 in 원함 and 자리(글[a:b]) == 자리(원함[이름]):
            남김.add(이름)
            continue
        지울.append((a, b))
        m = re.search(r'_points = SubResource\("([^"]+)_PA"\)', 글[a:b])
        if m:
            앞 = m.group(1)
            지울 += [(c, d) for c, d, h in 블 if h.startswith("[sub_resource") and
                    (f'id="{앞}_PA"' in h or re.search(r'id="' + re.escape(앞) + r'_P\d+"', h))]
    for a, b in sorted(set(지울), reverse=True):
        글 = 글[:a] + 글[b:]
    새노드 = [원함[n] for n in 원함 if n not in 남김]
    if not 새노드:
        return re.sub(r"\n{3,}", "\n\n", 글)
    새서브 = []
    for n in 원함:
        if n in 남김:
            continue
        m = re.search(r'_points = SubResource\("([^"]+)_PA"\)', 원함[n])
        새서브 += 서브블.get(m.group(1), []) if m else []
    # ext — 씬에 없는 것만(지형_글 이 이미 있는 id 를 찾아 쓴다)
    빠진ext = [(i, 형, 경로) for i, 형, 경로 in t_ext if f'id="{i}"' not in 글]
    if 빠진ext:
        ext글 = "".join(f'[ext_resource type="{형}" path="{경로}" id="{i}"]\n' for i, 형, 경로 in 빠진ext)
        마지막ext = max((b for a, b, h in _블록들(글) if h.startswith("[ext_resource")), default=None)
        a = 글.rindex("[ext_resource", 0, 마지막ext)
        줄끝 = 글.index("\n", a) + 1
        글 = 글[:줄끝] + ext글 + 글[줄끝:]
    m = re.search(r"^\[node ", 글, re.M)
    글 = 글[:m.start()] + "\n".join(새서브) + "\n" + 글[m.start():]
    # 노드 — 추가지형 묶음 끝(없으면 묶음째 Player 앞)
    블 = _블록들(글)
    묶음끝 = max((b for a, b, h in 블 if h.startswith("[node ") and
                 ('parent="추가지형"' in h or (re.search(r'name="추가지형"', h) and 'parent="."' in h))), default=None)
    if 묶음끝 is None:
        m = re.search(r'^\[node name="Player"', 글, re.M)
        넣을곳 = m.start() if m else len(글)
        글 = 글[:넣을곳] + '[node name="추가지형" type="Node2D" parent="."]\n\n' + "\n".join(새노드) + "\n" + 글[넣을곳:]
    else:
        글 = 글[:묶음끝].rstrip("\n") + "\n\n" + "\n".join(새노드) + "\n" + 글[묶음끝:]
    if re.search(r"load_steps=\d+", 글):
        n = len(re.findall(r"^\[(?:ext_resource|sub_resource) ", 글, re.M)) + 1
        글 = re.sub(r"load_steps=\d+", f"load_steps={n}", 글, count=1)
    return re.sub(r"\n{3,}", "\n\n", 글)


def _생성기_소유(글):
    """첫 줄 표식 + 해시가 맞는 씬 = 만들기.py 가 통째로 다시 쓸 수 있다(이 파일은 건드리지 않는다)."""
    import hashlib
    if not 글.startswith("; 생성: tools/쳅터1/만들기.py"):
        return False
    첫줄, _, 나머지 = 글.partition("\n")
    return ("out=" + hashlib.sha256(나머지.encode("utf-8")).hexdigest()[:16]) in 첫줄


def _지형에_구워짐(글, 항목):
    """이 추가지형 사각형이 이미 "지형" 노드(생성기가 구운 판)로 있나 — 같은 종류 · 가운데 자리가 같은 노드."""
    k, x, y, w, h = 항목[:5]
    cx, cy = (x * C + (x + w) * C) // 2, (y * C + (y + h) * C) // 2
    for a, b, 머리 in _블록들(글):
        if 머리.startswith("[node ") and 'parent="지형"' in 머리:
            t = 글[a:b]
            m = re.search(r"^position = Vector2\(([-\d.]+), ([-\d.]+)\)", t, re.M)
            if m and abs(float(m.group(1)) - cx) < 1 and abs(float(m.group(2)) - cy) < 1 and \
                    f'metadata/design_kind = "{k}"' in t:
                return True
    return False


def _추가지형_같나(dn, 글):
    """씬의 추가지형 노드(이름 · position)가 도안 추가지형과 같은가."""
    있음 = {}
    for a, b, 머리 in _블록들(글):
        if 머리.startswith("[node ") and 'parent="추가지형"' in 머리:
            이름 = re.search(r'name="([^"]+)"', 머리).group(1)
            m = re.search(r"^position = Vector2\(([-\d.]+), ([-\d.]+)\)", 글[a:b], re.M)
            있음[이름] = (float(m.group(1)), float(m.group(2))) if m else None
    원함 = {}
    세기 = {}
    for k, x, y, w, h in getattr(dn, "추가지형", []):
        세기[k] = 세기.get(k, 0) + 1
        이름 = {"흰": "흰판", "검정": "검정판", "유령": "유령판", "구조": "구조", "흰구조": "흰구조"}[k] + f"추가{세기[k]:02d}"
        원함[이름] = (float((x * C + (x + w) * C) // 2), float((y * C + (y + h) * C) // 2))
    return 있음 == 원함


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
        #   ★[2026-10-10] 단, 표식이 있어도 해시가 깨진 씬(15·16·17·19 — 생성 뒤 Codex·손으로 고침)은 생성기도 멈춘다 →
        #   여기서 갈아 끼운다(그러지 않으면 17 의 추가지형 4 장처럼 도안에만 있고 씬에는 영영 안 들어간다).
        if _생성기_소유(옛):
            continue
        ext, 노드 = 노드_글(dn)
        새 = 옛
        # [2026-10-10] 에디터가 저장한 묶음(unique_id 가 붙음 · 18 숨은서재)엔 손으로 넣은 값(양초 z_index · 판 collision_mask)이
        #   있다 — 다시 쓰면 사라진다. 도안과 다르면 알리고 건너뛴다(--에디터씬도 를 주면 덮는다).
        옛묶음 = "".join(옛[a:b] for a, b, h in _블록들(옛) if h.startswith("[node ") and _묶음인가(h))
        정리 = lambda t: re.sub(r"\n{2,}", "\n", re.sub(r" unique_id=\d+", "", t)).strip()
        if "unique_id=" in 옛묶음 and "--에디터씬도" not in sys.argv and 정리(옛묶음) != 정리(노드):
            print(f"  ⚠ {dn.이름}: 에디터가 저장한 추가기믹 묶음이 도안과 다르다 — 묶음은 건너뜀(--에디터씬도 로 덮음)")
        elif 노드 or "추가기믹" in 옛:
            새 = 갈아끼우기(새, ext, 노드)
        # [2026-10-10] 생성기가 만든 "장애물" 빛줄기의 **동작 값**(점멸·주기·위상·시작색)만 도안에 맞춘다
        새 = 장애물_맞추기(dn, 새)
        # [2026-10-09] 추가지형(새 흰·검정 판) — 손으로 고친 씬에만(생성기 소유 씬은 만들기.py 가 격자에서 같이 만든다)
        #   [2026-10-10] 이미 같은 판(이름·자리)이 들어 있으면 건드리지 않는다 — 에디터가 저장한 씬(18)은
        #   추가지형 노드에 구운 재질이 붙어 있어 다시 쓰면 그것까지 날아간다.
        # [2026-10-10] 생성기가 만든 씬(첫 줄 표식 · 15~19)은 만들 때 이미 추가지형을 격자에 넣어 "지형" 노드로 구웠다 →
        #   그 판은 빼고 맞춘다(안 빼면 17 응접실처럼 같은 자리에 판이 두 겹 — 검사_쳅터1_지형겹침 이 잡았다).
        if 옛.startswith("; 생성: tools/쳅터1/만들기.py"):
            dn.추가지형 = [t for t in dn.추가지형 if not _지형에_구워짐(새, t)]
        if not _추가지형_같나(dn, 새):
            새 = 지형_맞추기(dn, 새)
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
