# -*- coding: utf-8 -*-
"""
쳅터1 스테이지 생성기 — 2026-10-04 Claude

  도안(JSON) ──▶ 검사(점프 물리 흉내) ──▶ 도면 PNG ──▶ Godot 씬(.tscn) ──▶ 미리보기 PNG

사용
  python tools/쳅터1/만들기.py                  # 전부
  python tools/쳅터1/만들기.py 쳅터1_03_방_서재   # 하나만
  python tools/쳅터1/만들기.py --강제            # 에디터에서 저장된 씬도 덮어쓴다(손댄 것 사라짐!)

입력   scenes/쳅터1/도안/<이름>.json
출력   scenes/쳅터1/도안/<이름>.png                 도면(Dungeon Scrawl 느낌)
       scenes/쳅터1/스테이지/<이름>.tscn            플레이 씬
       scenes/쳅터1/도안/미리보기/<이름>.png         배경+지형 합성(엔진 아님) · 전체도
       assets/background/쳅터1/프리셋/<프리셋>.tres   배경 프리셋

멱등: 같은 도안이면 같은 바이트. 씬 첫 줄의 해시가 안 맞으면(에디터에서 저장·수정됨) 멈춘다.
⚠ 씬을 에디터에서 손보고 싶으면 → 도안을 고치고 다시 생성하는 것이 원칙. 손으로 고친 씬은 --강제 없이는 안 덮는다.
"""
import hashlib
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import 규격  # noqa: E402
import 도안 as 도안모듈  # noqa: E402
import 검사 as 검사모듈  # noqa: E402
import 도면  # noqa: E402
import 기믹 as 기믹모듈  # noqa: E402
import 모양  # noqa: E402

저장소 = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
도안폴더 = os.path.join(저장소, "scenes", "쳅터1", "도안")
씬폴더 = os.path.join(저장소, "scenes", "쳅터1", "스테이지")
미리폴더 = os.path.join(도안폴더, "미리보기")
레이어 = "res://assets/background/쳅터1/레이어_v01/"
프리셋폴더 = os.path.join(저장소, "assets", "background", "쳅터1", "프리셋")
C = 규격.칸
표식 = "; 생성: tools/쳅터1/만들기.py"

# ── 구조(테두리·선반) 색 규칙 ──
#   "중립" = 시작상태를 비운다 → 색 규칙 밖(흰 몸도 안전). 2026-10-01 방01 초안과 같은 선택.
#   "검정" = 현행 2층방처럼 시작상태 1 → 흰 몸이 닿으면 죽는다(CLAUDE.md "안 칠한 지형은 검정").
#   ★도형님 결정 대기 — 바꾸려면 이 한 줄만 고치고 다시 생성.
구조_색 = "중립"

# ── 배경 프리셋표 ──
프리셋표 = {
    "방_다마스크": {"벽지": "벽지/다마스크.png", "벽지_밝기": 1.0, "징두리": "띠/징두리_판넬.png", "걸레받이": "띠/걸레받이.png", "천장_몰딩": "띠/천장_몰딩.png", "낡음": 1},
    "방_서재": {"벽지": "벽지/다마스크.png", "벽지_밝기": 0.82, "징두리": "띠/징두리_판넬.png", "걸레받이": "띠/걸레받이.png", "천장_몰딩": "띠/천장_몰딩.png", "낡음": 2},
    "방_꽃무늬": {"벽지": "벽지/꽃무늬.png", "벽지_밝기": 0.95, "징두리": "띠/징두리_판넬.png", "걸레받이": "띠/걸레받이.png", "천장_몰딩": "띠/천장_몰딩.png", "낡음": 2},
    "방_판자": {"벽지": "벽지/판자.png", "벽지_밝기": 0.9, "징두리": None, "걸레받이": "띠/걸레받이.png", "천장_몰딩": None, "낡음": 3},
    "복도_줄무늬": {"벽지": "벽지/줄무늬.png", "벽지_밝기": 1.0, "징두리": "띠/징두리_판넬.png", "걸레받이": "띠/걸레받이.png", "천장_몰딩": "띠/천장_몰딩.png", "낡음": 1},
    "굴뚝_벽돌": {"벽지": "벽지/벽돌.png", "벽지_밝기": 0.8, "징두리": None, "걸레받이": None, "천장_몰딩": None, "낡음": 3},
}

EXT = [
    ("월드", "Script", "uid://b5njrffiq72ba", "res://scripts/스마트월드/월드.gd"),
    ("코어", "Script", "uid://ffbu67cp501b", "res://scripts/스마트월드/페인트_코어.gd"),
    ("검정", "PackedScene", None, "res://scenes/지형/목재/목재_데크_검정.tscn"),
    ("흰", "PackedScene", None, "res://scenes/지형/목재/목재_데크_흰색.tscn"),
    ("유령", "PackedScene", None, "res://scenes/지형/목재/목재_데크_투명.tscn"),
    ("점", "Script", "uid://bwcf4pjgprn0k", "res://addons/rmsmartshape/shapes/point.gd"),
    ("점배열", "Script", "uid://bo5f7qe27jfje", "res://addons/rmsmartshape/shapes/point_array.gd"),
    ("플레이어", "PackedScene", "uid://dk1itr2afb8hv", "res://scenes/player/Player.tscn"),
    ("체크포인트", "PackedScene", None, "res://scenes/장애물/체크포인트.tscn"),
    ("가시", "PackedScene", None, "res://scenes/장애물/가시.tscn"),
    ("연결구", "Script", None, "res://scripts/쳅터1/연결구.gd"),
    ("배경", "Script", None, "res://scripts/쳅터1/방배경.gd"),
]
_ASCII = {"월드": "world", "코어": "core", "검정": "tpl_black", "흰": "tpl_white", "유령": "tpl_ghost", "점": "ss2d_point",
          "점배열": "ss2d_points", "플레이어": "player", "체크포인트": "checkpoint", "가시": "spike", "연결구": "link", "배경": "bg"}

구조_속성 = [('"칠하기_허용"', "false"), ('"칠하기_방식"', "2"), ('"위치별_판정"', "true")]
if 구조_색 == "검정":
    구조_속성.insert(2, ('"시작상태"', "1"))
종류표 = {
    "구조": ("검정", 구조_속성, "구조"),
    "검정": ("검정", [('"시작상태"', "1"), ('"위치별_판정"', "true")], "플랫폼"),
    "흰": ("흰", [('"위치별_판정"', "true")], "플랫폼"),
    "유령": ("유령", [], "플랫폼"),
}


def 수(v):
    f = float(v)
    return str(int(f)) if f == int(f) else repr(round(f, 4))


def V(x, y):
    return f"Vector2({수(x)}, {수(y)})"


def 문자열(s):
    return '"' + str(s).replace("\\", "\\\\").replace('"', '\\"') + '"'


# ── 프리셋 .tres ────────────────────────────────────────────────────────────
def 프리셋_쓰기():
    os.makedirs(프리셋폴더, exist_ok=True)
    for 이름, p in 프리셋표.items():
        ext = ['[ext_resource type="Script" path="res://scripts/쳅터1/방배경_프리셋.gd" id="1_script"]']
        본 = ['[resource]', 'script = ExtResource("1_script")']
        n = 2
        for 칸이름 in ("벽지", "징두리", "걸레받이", "천장_몰딩"):
            if p.get(칸이름):
                ext.append(f'[ext_resource type="Texture2D" path="{레이어}{p[칸이름]}" id="{n}_tex"]')
                본.append(f'"{칸이름}" = ExtResource("{n}_tex")')
                n += 1
        본.append(f'"벽지_밝기" = {수(p["벽지_밝기"])}')
        본.append(f'"낡음" = {p["낡음"]}')
        글 = (f'[gd_resource type="Resource" script_class="방배경_프리셋" load_steps={n} format=3]\n\n'
             + "\n".join(ext) + "\n\n" + "\n".join(본) + "\n")
        경로 = os.path.join(프리셋폴더, f"{이름}.tres")
        if not os.path.exists(경로) or open(경로, encoding="utf-8").read() != 글:
            with open(경로, "w", encoding="utf-8", newline="\n") as f:
                f.write(글)


# ── 씬 ──────────────────────────────────────────────────────────────────────
def 문장식_가구(dn):
    """[2차] "문장식": true 인 길목에만 열린 문 그림을 배경에 붙인다(길 안내용 장식 · 판정 없음)."""
    out = []
    for 문 in dn.문:
        if 문.get("문장식"):
            i = dn.문_정보(문)
            x = i["안쪽면x"] / C - i["d"] * 3.5
            out.append(["문_열림", x, 문["바닥"]])
    return out


# [2026-10-05] 기믹 장면 — 공용 키트(scenes/집/스마트월드_장애물) 그대로 인스턴스한다. 쓰는 것만 ext 에 싣는다.
기믹_장면 = {
    # [2026-10-05 2차] 쳅터1 빛은 창문빛.tscn(색레이저.gd 상속 — 판정 같음, 그림만 창문 달빛·빛 기둥·그을음)
    "빛줄기": ("light", "res://scenes/쳅터1/기믹/창문빛.tscn"),
    "도약대": ("pad", "res://scenes/집/스마트월드_장애물/도약대.tscn"),
    "움직이는발판": ("mover", "res://scenes/집/스마트월드_장애물/움직이는발판.tscn"),
}


def 기믹_노드들(dn, ids):
    """기믹 → 씬 노드 글. 좌표·속성 계산은 기믹.py 의 엔진값() 한 곳에서만."""
    out = []
    for g in 기믹모듈.목록(dn):
        k = type(g).__name__
        e = g.엔진값()
        머리 = f'[node name="{k}{g.i:02d}" parent="장애물" instance=ExtResource("{ids["기믹:" + k]}")]'
        if k == "빛줄기":
            본 = [f"position = {V(*e['원점'])}", f'"길이" = {수(e["길이"])}', f'"두께" = {수(e["두께"])}',
                 f'"각도" = {수(e["각도"])}', f'"시작색" = {기믹모듈.색번호[g.색]}', f'"주기" = {수(g.주기)}',
                 f'"위상" = {수(g.위상)}', f'"점멸" = {"true" if g.점멸 else "false"}', f'"근원" = {e["근원"]}']
        elif k == "도약대":
            본 = [f"position = {V(*e['원점'])}", f'"폭" = {수(e["폭"])}', f'"도약속도" = {수(round(e["속도"], 1))}',
                 f'"색_제한" = {"true" if g.색 else "false"}']
            if g.색:
                본.append(f'"색" = {기믹모듈.색번호[g.색]}')
        else:
            본 = [f"position = {V(*e['원점'])}", f'"크기" = {V(*e["크기"])}', f'"이동거리" = {수(e["이동거리"])}',
                 f'"이동방향" = {e["이동방향"]}', f'"왕복시간" = {수(g.왕복)}', f'"시작지연" = {수(g.지연)}']
        out.append("\n".join([머리] + 본) + "\n")
    return out


def 창문_가구(dn):
    """[2026-10-05 2차] 근원이 "창문" 인 빛 → 빛이 나오는 점에 창문 그림(배경 가구)을 붙인다.
    창문(8×12칸, 기준 '천장' = y 가 윗변) 의 가운데가 빛 원점에 오게."""
    out = []
    for g in 기믹모듈.목록(dn):
        if isinstance(g, 기믹모듈.빛줄기) and g.근원 == "창문":
            w, h, _기준 = 규격.가구표["창문"]
            out.append(["창문", g.원점[0] / C, g.원점[1] / C - h / 2])
    return out


def _안에(pt, 다각형):
    """[2026-10-06] 점이 다각형(px) 안인가 — 무늬 줄을 담을 구조 다각형을 고른다(짝수-홀수 규칙)."""
    x, y = pt
    안 = False
    n = len(다각형)
    for i in range(n):
        (x1, y1), (x2, y2) = 다각형[i], 다각형[(i + 1) % n]
        if (y1 > y) != (y2 > y) and x < (x2 - x1) * (y - y1) / (y2 - y1) + x1:
            안 = not 안
    return 안


def 씬_글(dn):
    d = dn.d
    ext = list(EXT)
    for k in sorted({type(g).__name__ for g in 기믹모듈.목록(dn)}):
        ext.append((f"기믹:{k}", "PackedScene", None, 기믹_장면[k][1]))
    프리셋 = d.get("배경", {}).get("프리셋", "방_판자")      # [2차] 도형님 선택 D = 판자·폐허
    ext.append(("프리셋", "Resource", None, f"res://assets/background/쳅터1/프리셋/{프리셋}.tres"))
    가구들 = [g for g in d.get("가구", []) if g[0] in 규격.가구표] + 문장식_가구(dn) + 창문_가구(dn)
    가구종류 = sorted({g[0] for g in 가구들})
    for i, 이름 in enumerate(가구종류):
        ext.append((f"가구:{이름}", "Texture2D", None, f"{레이어}가구/{이름}.png"))
    ids = {}
    for i, (k, *_r) in enumerate(ext):
        if k in _ASCII:
            ids[k] = f"{i + 1}_{_ASCII[k]}"
        elif k == "프리셋":
            ids[k] = f"{i + 1}_preset"
        elif k.startswith("기믹:"):
            ids[k] = f"{i + 1}_{기믹_장면[k.split(':', 1)[1]][0]}"
        else:
            ids[k] = f"{i + 1}_furn{가구종류.index(k.split(':', 1)[1])}"

    서브, 노드 = [], []
    # [2026-10-05] 칸 다각형을 덜 각지게(모따기·안쪽으로만 들쭉날쭉) — tools/쳅터1/모양.py
    for k, 이름, 점, _n in 모양.다각형들(dn):
        xs = [p[0] for p in 점]
        ys = [p[1] for p in 점]
        cx, cy = int(round((min(xs) + max(xs)) / 2)), int(round((min(ys) + max(ys)) / 2))
        로컬 = [(px - cx, py - cy) for px, py in 점] + [(점[0][0] - cx, 점[0][1] - cy)]
        sid = 이름
        sid_a = {"구조": "S", "검정판": "B", "흰판": "W", "유령판": "G"}[이름.rstrip("0123456789")] + 이름[-2:]
        pids = []
        for i, (lx, ly) in enumerate(로컬):
            pid = f"P_{sid_a}_{i}"
            pids.append(pid)
            서브.append(f'[sub_resource type="Resource" id="{pid}"]\nscript = ExtResource("{ids["점"]}")\nposition = {V(lx, ly)}\n')
        n = len(로컬)
        사전 = ",\n".join(f'{i}: SubResource("{p}")' for i, p in enumerate(pids))
        서브.append(
            f'[sub_resource type="Resource" id="PA_{sid_a}"]\nscript = ExtResource("{ids["점배열"]}")\n'
            f"_points = {{\n{사전}\n}}\n_point_order = PackedInt32Array({', '.join(str(i) for i in range(n))})\n"
            f"_constraints = {{\nVector2i(0, {n - 1}): 15\n}}\n_next_key = {n}\n")
        템플릿, 속성, 역할 = 종류표[k]
        본 = [f'[node name="{sid}" parent="지형" instance=ExtResource("{ids[템플릿]}")]', f"position = {V(cx, cy)}"]
        본 += [f"{a} = {b}" for a, b in 속성]
        본 += [f'_points = SubResource("PA_{sid_a}")', "collision_size = 0.0",
              f"metadata/role = {문자열(역할)}", f"metadata/design_kind = {문자열(k)}"]
        # [2026-10-06 Claude] 하수도식 흑백 맞물림 — 이 구조 다각형 안에 든 무늬 줄을 노드 로컬 Rect2 로 넘긴다.
        #   목재_데크지형.내부_무늬 → 셰이더 wood_inlay_rects 가 구조 앞면에만 흰 판자로 그린다(구조는 칠하기 금지).
        if k == "구조":
            무늬 = [(x0 * C - cx, yy * C - cy, (x1 - x0) * C, C) for x0, yy, x1 in getattr(dn, "무늬", [])
                   if _안에(((x0 + x1) / 2 * C, (yy + 0.5) * C), 점)]
            if 무늬:
                본.append('"내부_무늬" = Array[Rect2]([' + ", ".join(
                    f"Rect2({수(a)}, {수(b)}, {수(c)}, {수(e)})" for a, b, c, e in 무늬[:48]) + "])")
        노드.append("\n".join(본) + "\n")

    W, H = dn.w * C, dn.h * C
    sx, sy = d["시작"]
    시작 = (sx * C + C / 2, sy * C)
    줄 = []
    줄.append("\n".join([
        f'[node name="{dn.이름}" type="Node2D"]',
        f'script = ExtResource("{ids["월드"]}")',
        f'"스테이지_이름" = {문자열(dn.제목)}',
        f'"카메라_리밋" = Rect2(0, 0, {W}, {H})',
        '"카메라_줌" = 1.0',
        f'"시작_위치" = {V(*시작)}',
        f'"낙사_y" = {수((dn.h + 규격.바깥_세로) * C - C)}',
        f'"치명_낙하거리" = {수(규격.치명_낙하)}',
        f'metadata/blueprint = {문자열("res://scenes/쳅터1/도안/" + dn.이름 + ".json")}',
        f'metadata/frame_only = {"true" if d.get("큰틀") else "false"}',
    ]) + "\n")
    줄.append(f'[node name="페인트코어" type="Node" parent="." groups=["페인트코어"]]\nscript = ExtResource("{ids["코어"]}")\n')
    # 배경 명도는 배경 노드에서 조절하고, 공통 조명은 순수 회색으로 색 번짐을 막는다.
    줄.append('[node name="어둠" type="CanvasModulate" parent="."]\ncolor = Color(0.74, 0.74, 0.74, 1)\n')

    # 배경
    b = dn.벽
    줄.append("\n".join([
        '[node name="배경" type="Node2D" parent="."]',
        f'script = ExtResource("{ids["배경"]}")',
        f'"프리셋" = ExtResource("{ids["프리셋"]}")',
        f'"방_크기" = {V(W, H)}',
        f'"바닥_y" = {수((dn.h - b["아래"]) * C)}',
        f'"천장_y" = {수(b["위"] * C)}',
        f'"낡음_덮어쓰기" = {int(d.get("배경", {}).get("낡음", -1))}',
        f'"씨앗" = {int(hashlib.md5(dn.이름.encode()).hexdigest()[:6], 16) % 100000}',
        # 다시 생성해도 방별 어두움과 레이어 움직임 설정을 보존한다.
        f'"배경_명도" = {float(d.get("배경", {}).get("명도", 0.62))}',
        '"레이어_움직임" = true',
    ]) + "\n")
    줄.append('[node name="가구" type="Node2D" parent="배경"]\nz_index = -90\n')
    세기 = {}
    for 이름, x, y, *_ in 가구들:
        x0, y0, w, h = 규격.가구_사각(이름, x, y)
        세기[이름] = 세기.get(이름, 0) + 1
        줄.append(f'[node name="{이름}{세기[이름]}" type="Sprite2D" parent="배경/가구"]\nposition = {V(x0 * C, y0 * C)}\n'
                 f'texture = ExtResource("{ids["가구:" + 이름]}")\ncentered = false\n')

    줄.append('[node name="지형" type="Node2D" parent="."]\n')
    줄.extend(노드)

    # 연결구 — 스테이지 사이 길목(가까운 전경 띠 + 반딧불이 + 판정). 문 그림은 "문장식" 일 때만 배경에.
    줄.append('[node name="연결" type="Node2D" parent="."]\n')
    for 문 in dn.문:
        i = dn.문_정보(문)
        연결 = 문.get("연결") or []
        다음 = f"res://scenes/쳅터1/스테이지/{연결[0]}.tscn" if 연결 else ""
        줄.append("\n".join([
            f'[node name="{문["이름"]}" type="Node2D" parent="연결"]',
            f"position = {V(i['안쪽면x'], i['바닥y'])}",
            f'script = ExtResource("{ids["연결구"]}")',
            f'"방향" = {i["d"]}',
            f'"높이" = {수(i["높이"])}',
            f'"벽두께" = {수(i["벽두께"])}',
            f'"다음_씬" = {문자열(다음)}',
            f'"다음_연결" = {문자열(연결[1] if 연결 else "")}',
            f'"되돌아가기" = {"true" if 문.get("되돌아가기", True) and 연결 else "false"}',
        ]) + "\n")

    # 가시 · 기믹 — 둘 다 "장애물" 노드 아래
    가시들 = d.get("가시", [])
    기믹줄 = 기믹_노드들(dn, ids)
    if 가시들 or 기믹줄:
        줄.append('[node name="장애물" type="Node2D" parent="."]\n')
    if 가시들:
        k = 0
        for gx, gy, gw in 가시들:
            x = gx
            while x < gx + gw:
                n = min(20, gx + gw - x)
                k += 1
                줄.append(f'[node name="가시{k:02d}" parent="장애물" instance=ExtResource("{ids["가시"]}")]\n'
                         f"position = {V((x + n / 2) * C, gy * C)}\n\"칸수\" = {n}\n")
                x += n
    줄.extend(기믹줄)

    줄.append('[node name="체크포인트" type="Node2D" parent="."]\n')
    for j, (cx, cy) in enumerate(d.get("체크", [])):
        줄.append(f'[node name="체크{j + 1:02d}" parent="체크포인트" instance=ExtResource("{ids["체크포인트"]}")]\n'
                 f"position = {V(cx * C + C / 2, cy * C)}\ncollision_layer = 0\n")

    줄.append(f'[node name="Player" parent="." instance=ExtResource("{ids["플레이어"]}")]\nposition = {V(*시작)}\n"점프_거리_칸" = 20.0\n')

    ext줄 = []
    for k, 형, uid, 경로 in ext:
        u = f' uid="{uid}"' if uid else ""
        ext줄.append(f'[ext_resource type="{형}"{u} path="{경로}" id="{ids[k]}"]')
    몸 = (f"[gd_scene load_steps={len(ext) + len(서브) + 1} format=3]\n\n" + "\n".join(ext줄) + "\n\n"
         + "\n".join(서브) + "\n" + "\n".join(줄))
    해시 = hashlib.sha256(몸.encode("utf-8")).hexdigest()[:16]
    return f"{표식} · out={해시} · 손으로 고치지 말고 도안({dn.이름}.json)을 고친 뒤 다시 생성\n" + 몸


def 씬_쓰기(dn, 강제):
    경로 = os.path.join(씬폴더, f"{dn.이름}.tscn")
    새것 = 씬_글(dn)
    if os.path.exists(경로):
        옛것 = open(경로, encoding="utf-8", newline="").read()
        if 옛것 == 새것:
            return "같음"
        첫줄, _, 나머지 = 옛것.partition("\n")
        손안댐 = 첫줄.startswith(표식) and ("out=" + hashlib.sha256(나머지.encode("utf-8")).hexdigest()[:16]) in 첫줄
        if not 손안댐 and not 강제:
            return "멈춤(에디터에서 저장된 흔적 — --강제 로만 덮음)"
    os.makedirs(씬폴더, exist_ok=True)
    # [2026-10-05] 편집기가 열려 있으면 바뀐 파일을 다시 읽느라 잠깐 잡고 있다 → 임시 파일 + 바꿔치기 + 재시도
    import time
    임시 = 경로 + ".임시"
    with open(임시, "w", encoding="utf-8", newline="\n") as f:
        f.write(새것)
    for _ in range(40):
        try:
            os.replace(임시, 경로)
            return "생성"
        except OSError:
            time.sleep(0.25)
    os.replace(임시, 경로)
    return "생성"


# ── 미리보기(엔진 아님) ─────────────────────────────────────────────────────
_그림캐시 = {}


def _그림(rel):
    if rel not in _그림캐시:
        p = os.path.join(저장소, "assets", "background", "쳅터1", "레이어_v01", *rel.split("/"))
        _그림캐시[rel] = Image.open(p).convert("RGBA")
    return _그림캐시[rel]


def 미리보기(dn, 배율=0.25, 플레이어="시작"):
    """배경 레이어 + 지형 + 연결구(전경 띠·반딧불이)를 대충 합성. 게임 화면이 아니다(빛·셰이더·SS2D 데크 없음)."""
    W, H = dn.w * C, dn.h * C
    w, h = int(W * 배율), int(H * 배율)
    p = 프리셋표[dn.d.get("배경", {}).get("프리셋", "방_판자")]
    낡음 = dn.d.get("배경", {}).get("낡음", p["낡음"])
    img = Image.new("RGBA", (w, h))
    벽 = _그림(p["벽지"]).resize((int(512 * 배율), int(512 * 배율)))
    for y in range(0, h, 벽.height):
        for x in range(0, w, 벽.width):
            img.alpha_composite(벽, (x, y))
    밝기 = p["벽지_밝기"] * (1 - 0.05 * 낡음)
    img = Image.eval(img, lambda v: int(v * 밝기)).convert("RGBA")
    바닥 = (dn.h - dn.벽["아래"]) * C * 배율
    천장 = dn.벽["위"] * C * 배율
    import random
    rr = random.Random(dn.이름)
    조각 = {1: ["얼룩_1", "얼룩_2"], 2: ["얼룩_3", "금_1", "벗겨짐_1", "벗겨짐_2"], 3: ["얼룩_4", "금_2", "벗겨짐_3", "찢김_1", "찢김_2"]}
    for 단 in range(1, 낡음 + 1):
        for _ in range(int(W * H / 262144 * 0.2)):
            t = _그림("낡음/" + rr.choice(조각[단]) + ".png")
            s = rr.uniform(0.45, 0.95) * 배율
            t2 = t.resize((max(1, int(t.width * s)), max(1, int(t.height * s))))
            img.alpha_composite(t2, (int(rr.uniform(0, w)) - t2.width // 2, int(rr.uniform(천장, 바닥 - 40 * 배율)) - t2.height // 2))
    for 칸이름, y위치 in (("징두리", lambda t: 바닥 - t.height), ("걸레받이", lambda t: 바닥 - t.height), ("천장_몰딩", lambda t: 천장)):
        if p.get(칸이름):
            t = _그림(p[칸이름])
            t = t.resize((int(t.width * 배율), max(1, int(t.height * 배율))))
            for x in range(0, w, t.width):
                img.alpha_composite(t, (x, int(y위치(t))))
    for 이름, x, y, *_ in dn.d.get("가구", []) + 창문_가구(dn):
        if 이름 not in 규격.가구표:
            continue
        x0, y0, fw, fh = 규격.가구_사각(이름, x, y)
        t = _그림(f"가구/{이름}.png")
        t = t.resize((max(1, int(t.width * 배율)), max(1, int(t.height * 배율))))
        img.alpha_composite(t, (int(x0 * C * 배율), int(y0 * C * 배율)))
    d = ImageDraw.Draw(img, "RGBA")
    색 = {"구조": (24, 21, 19), "검정": (10, 10, 10), "흰": (226, 224, 218), "유령": (200, 200, 210, 70)}
    for k, 이름, 점, _n in 모양.다각형들(dn):
        pts = [(px * 배율, py * 배율) for px, py in 점]
        d.polygon(pts, fill=색[k])
    # 윗면 마감선(데크 입술 흉내) — 칸 단위로 위가 비어 있는 면
    for cy in range(dn.h):
        for cx in range(dn.w):
            v = dn.칸(cx, cy)
            if v and not dn.칸(cx, cy - 1) and v != 4:
                y = cy * C * 배율
                d.line([(cx * C * 배율, y + 1), ((cx + 1) * C * 배율, y + 1)],
                       fill=(120, 108, 92) if v in (1, 2) else (255, 255, 255), width=max(1, int(6 * 배율)))
            if v == 4 and not dn.칸(cx, cy - 1):
                y = cy * C * 배율
                d.line([(cx * C * 배율, y), ((cx + 1) * C * 배율, y)], fill=(230, 230, 240, 160), width=1)
    for gx, gy, gw in dn.d.get("가시", []):
        for xx in range(gx, gx + gw):
            x, y = xx * C * 배율, gy * C * 배율
            d.polygon([(x, y), (x + C * 배율 / 2, y - 22 * 배율), (x + C * 배율, y)], fill=(110, 106, 100))
    # [2026-10-05] 기믹 — 빛줄기(반투명 띠) · 도약대(사다리꼴) · 움직이는 발판(출발 자리 + 지나가는 길 점선)
    for g in 기믹모듈.목록(dn):
        if isinstance(g, 기믹모듈.빛줄기):
            c = (250, 250, 240) if g.색 == "흰" else (0, 0, 0)
            d.polygon([(x * 배율, y * 배율) for x, y in g.꼭짓점()], fill=c + (110 if g.고정 else 50,))
        elif isinstance(g, 기믹모듈.도약대):
            l, t, r, b = [v * 배율 for v in g.사각()]
            d.polygon([(l, b), (l + (r - l) * 0.15, t + (b - t) * 0.3), (r - (r - l) * 0.15, t + (b - t) * 0.3), (r, b)],
                      fill=(90, 84, 76) if not g.색 else ((20, 20, 20) if g.색 == "검정" else (230, 228, 220)), outline=(200, 190, 170))
        else:
            칸들 = g.위치들()
            l0, t0, r0, b0 = 칸들[0]
            l1, t1, r1, b1 = 칸들[-1]
            d.rectangle([l0 * 배율, t0 * 배율, r1 * 배율, b1 * 배율], outline=(150, 140, 120, 120))
            d.rectangle([l0 * 배율, t0 * 배율, r0 * 배율, b0 * 배율], fill=(16, 16, 16), outline=(120, 108, 92))
    # 플레이어 — 전경 띠보다 먼저 그려서 길목 전경 뒤로 가려지게
    if 플레이어:
        if 플레이어 == "시작":
            sx, sy = dn.d["시작"]
            px, py = (sx + 0.5) * C * 배율, sy * C * 배율
        else:
            px, py = 플레이어[0] * 배율, 플레이어[1] * 배율
        d.rounded_rectangle([px - 22 * 배율, py - 97 * 배율, px + 22 * 배율, py], radius=int(10 * 배율), fill=(12, 12, 12), outline=(235, 235, 235))
    # 연결구 — 가까운 전경 띠(바깥으로 진해짐 · 위로 옅어짐) + 반딧불이 점
    import random as _r
    for 문 in dn.문:
        i = dn.문_정보(문)
        dd = i["d"]
        열림 = bool(문.get("연결")) and 문.get("되돌아가기", True)
        진 = 0.85 if 열림 else 1.0
        번 = (96 if 열림 else 173) * 배율
        x면 = i["안쪽면x"] * 배율
        x벽 = (i["안쪽면x"] + dd * i["벽두께"]) * 배율
        x끝 = (i["안쪽면x"] + dd * (i["벽두께"] + 384)) * 배율
        허리 = (i["바닥y"] - i["높이"]) * 배율
        위 = (i["바닥y"] - i["높이"] * 1.9) * 배율
        아래 = (i["바닥y"] + 48) * 배율
        구간 = [(x면 - dd * 번, x면, 0.0, 진 * 0.55), (x면, x벽, 진 * 0.55, 진), (x벽, x끝, 진, 1.0)]
        for xa, xb, a0, a1 in 구간:
            n = 10
            for k in range(n):
                t0, t1 = k / n, (k + 1) / n
                a = a0 + (a1 - a0) * (t0 + t1) / 2
                x0, x1 = xa + (xb - xa) * t0, xa + (xb - xa) * t1
                d.rectangle([min(x0, x1), 허리, max(x0, x1), 아래], fill=(8, 7, 7, int(255 * a)))
                for j in range(6):
                    y0 = 위 + (허리 - 위) * j / 6
                    y1 = 위 + (허리 - 위) * (j + 1) / 6
                    d.rectangle([min(x0, x1), y0, max(x0, x1), y1], fill=(8, 7, 7, int(255 * a * (j + 0.5) / 6)))
        if 열림:
            rr = _r.Random(dn.이름 + 문["이름"])
            cx, cy = (i["안쪽면x"] - dd * 150) * 배율, (i["바닥y"] - i["높이"] * 0.75) * 배율
            for _ in range(7):
                fx, fy = cx + rr.uniform(-120, 120) * 배율, cy + rr.uniform(-80, 80) * 배율
                for rad, al in ((15, 18), (7, 60), (2.6, 250)):
                    rr2 = max(1, rad * 배율 * 1.6)
                    d.ellipse([fx - rr2, fy - rr2, fx + rr2, fy + rr2], fill=(255, 248, 220, al))
    # 챕터 어둠(CanvasModulate 0.72)
    img = Image.eval(img.convert("RGB"), lambda v: int(v * 0.74)).convert("RGBA")
    return img


def 화면_자르기(dn, 큰그림, 배율):
    """시작 위치의 첫 화면(1920×1080)을 잘라낸다."""
    vw, vh = 1920, 1080
    sx, sy = dn.d["시작"]
    cx = min(max((sx + 0.5) * C - vw / 2, 0), max(dn.w * C - vw, 0))
    cy = min(max(sy * C - 64 - vh / 2, 0), max(dn.h * C - vh, 0))
    return 큰그림.crop((int(cx * 배율), int(cy * 배율), int((cx + vw) * 배율), int((cy + vh) * 배율)))


def 전체도(결과들):
    """스테이지 연결 한 장 — 도면 축소판을 흐름 순서로."""
    폭 = 1800
    칸들 = []
    for dn, r in 결과들:
        im = Image.open(os.path.join(도안폴더, f"{dn.이름}.png")).convert("RGB")
        s = min(560 / im.width, 300 / im.height)
        칸들.append((dn, r, im.resize((int(im.width * s), int(im.height * s)))))
    열 = 3
    셀w, 셀h = 600, 360
    줄수 = (len(칸들) + 열 - 1) // 열
    판 = Image.new("RGB", (폭, 120 + 줄수 * 셀h), (237, 231, 219))
    d = ImageDraw.Draw(판)
    f = ImageFont.truetype(r"C:\Windows\Fonts\malgunbd.ttf", 30)
    f2 = ImageFont.truetype(r"C:\Windows\Fonts\malgun.ttf", 16)
    d.text((20, 18), "쳅터1 스테이지 연결도 — 2층 방 → 복도 → … → 계단 → 거실 → 굴뚝", font=f, fill=(40, 34, 28))
    d.text((22, 62), "도안 scenes/쳅터1/도안/*.json · 씬 scenes/쳅터1/스테이지/*.tscn · ↔ = 되돌아가기 가능 · 큰 틀 = 지형 미배치(임시 길)", font=f2, fill=(70, 60, 50))
    for i, (dn, r, im) in enumerate(칸들):
        x, y = 20 + (i % 열) * 셀w, 110 + (i // 열) * 셀h
        판.paste(im, (x, y + 30))
        ok = not r["실패"]
        d.text((x, y), dn.제목, font=f2, fill=(40, 120, 60) if ok else (180, 40, 40))
        if i + 1 < len(칸들):
            ax = x + 560
            d.text((ax + 4, y + 150), "→", font=f, fill=(210, 120, 10))
    경로 = os.path.join(미리폴더, "_쳅터1_연결도.png")
    판.save(경로, optimize=True)
    return 경로


def main():
    강제 = "--강제" in sys.argv
    이름들 = [a for a in sys.argv[1:] if not a.startswith("--")]
    프리셋_쓰기()
    os.makedirs(미리폴더, exist_ok=True)
    gdi = os.path.join(미리폴더, ".gdignore")
    if not os.path.exists(gdi):
        open(gdi, "w").close()
    결과들 = []
    실패 = 0
    for dn in 도안모듈.모두_읽기(도안폴더):
        if 이름들 and dn.이름 not in 이름들:
            continue
        for w in dn.경고:
            print("  ⚠", dn.이름, w)
        r = 검사모듈.검사(dn, True, True, 경로_저장=True)
        실패 += len(r["실패"])
        도면.그리기(dn, r, os.path.join(도안폴더, f"{dn.이름}.png"))
        상태 = 씬_쓰기(dn, 강제)
        큰 = 미리보기(dn, 0.25)
        큰.save(os.path.join(미리폴더, f"{dn.이름}_전체.png"), optimize=True)
        중 = 미리보기(dn, 0.5)
        화면_자르기(dn, 중, 0.5).save(os.path.join(미리폴더, f"{dn.이름}_첫화면.png"), optimize=True)
        print(f"  → 씬 {상태} · 도면/미리보기 갱신")
        결과들.append((dn, r))
    if not 이름들:
        print("연결도:", os.path.relpath(전체도(결과들), 저장소))
        print("연결 높이(화면에서 걸어 나오는 높이 · 허용 96px):")
        h = 검사모듈.연결_높이_검사([dn for dn, _r in 결과들])
        for m in h:
            print("    ×", m)
        실패 += len(h)
    print("검사 실패 합계:", 실패)
    return 1 if 실패 else 0


if __name__ == "__main__":
    sys.exit(main())
