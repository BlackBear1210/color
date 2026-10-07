"""[2026-09-30 Claude] 하수도 투명(유령)발판을 전부 기본지형 투명발판 v2 프리팹으로 바꾼다.

도형님: "기존 선반 투명발판도 이걸로 다 교체해."

대상 = 하수도 스테이지 씬에서 `"무색일때_통과" = true` 이고 하수도 프리팹 4 종
(기본지형_검정/흰색 · 공중선반_검정/흰색) 중 하나를 인스턴스한 `지형/*` 노드.
  · 기본지형 유령  → 인스턴스만 `하수도_투명발판_기본지형_*` 로 바꾼다(점·재질·충돌 덮어쓰기 그대로).
  · 공중선반 유령  → 인스턴스 교체 + 모양을 **같은 윗면·같은 폭**의 기본지형 직사각형으로 바꾼다.
                     밑면은 원래 선반의 가장 낮은 점(두께 56~64). 선반 전용 재질 덮어쓰기(ledge 텍스처)와
                     캐시 메시 · 클릭사각형 흔적은 지운다(프리팹의 땅 재질을 쓰게). 충돌 덮어쓰기가 있으면 같은 사각형으로.
  · 필요횟수_수동 · 시작상태 · editor_description · 위치 · 일방통행 덮어쓰기는 건드리지 않는다.
  · [2026-09-30 추가] 집 키트(TEMPLATE_WALL_*)로 만든 2-11 유령도 인스턴스만 바꾼다(캐시 메시는 지운다 — 집 키트 재질용).

멱등: 이미 v2 프리팹인 노드는 건너뛴다. 기본은 조사만, `--적용` 이면 쓴다.
  python tools/교체_투명발판_기본지형.py            # 조사
  python tools/교체_투명발판_기본지형.py --적용
"""
import re
import sys
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
SCENES = [ROOT / "scenes" / "world_2_클로드" / f"stage_2-{n}.tscn" for n in (1, 2, 3, 5, 8, 11)]
PREFAB = "res://scenes/지형/하수도/"
BASE = {PREFAB + "하수도_기본지형_검정.tscn": ("black", False), PREFAB + "하수도_기본지형_흰색.tscn": ("white", False),
        PREFAB + "하수도_공중선반_검정.tscn": ("black", True), PREFAB + "하수도_공중선반_흰색.tscn": ("white", True),
        # ★[2026-09-30] 2-11(아스트라 판)은 집 키트 벽체로 유령을 찍었다 — 모양(점)은 그대로 두고 인스턴스만 바꾼다.
        "res://scenes/집/스마트 매쉬 assets/WALL_벽체/TEMPLATE_WALL_SOLID.tscn": ("black", False),
        "res://scenes/집/스마트 매쉬 assets/WALL_벽체/TEMPLATE_WALL_SOLID_WHITE.tscn": ("white", False)}
NEW = {"black": ("ghost_v2_black", PREFAB + "하수도_투명발판_기본지형_검정.tscn"),
       "white": ("ghost_v2_white", PREFAB + "하수도_투명발판_기본지형_흰색.tscn")}


def sub_block(s, rid):
    m = re.search(r'\[sub_resource type="[^"]+" id="%s"\]\n(.*?)(?=\n\[|\Z)' % re.escape(rid), s, re.S)
    return m.group(1) if m else None


def points_of(s, arr_id):
    body = sub_block(s, arr_id)
    out = []
    for pid in re.findall(r'SubResource\("([^"]+)"\)', body or ""):
        m = re.search(r'position = Vector2\(([-\d.e]+), ([-\d.e]+)\)', sub_block(s, pid) or "")
        out.append((float(m.group(1)), float(m.group(2))) if m else (0.0, 0.0))
    return out


def fmt(v):
    return str(int(v)) if float(v).is_integer() else ("%g" % v)


def process(path, apply):
    raw = path.read_bytes()
    crlf = b"\r\n" in raw
    s = raw.decode("utf-8").replace("\r\n", "\n")
    ext = {m.group(2): m.group(1) for m in re.finditer(r'\[ext_resource[^\n]*path="([^"]+)"[^\n]*id="([^"]+)"\]', s)}
    point_id = next(k for k, v in ext.items() if v.endswith("/shapes/point.gd"))
    array_id = next(k for k, v in ext.items() if v.endswith("/shapes/point_array.gd"))
    report, new_subs, need_ext = [], [], set()
    blocks = re.split(r'\n(?=\[)', s)
    ledge_names = set()
    for i, b in enumerate(blocks):
        m = re.match(r'\[node name="([^"]+)" parent="지형"([^\n]*)instance=ExtResource\("([^"]+)"\)\]', b)
        if not m or '"무색일때_통과" = true' not in b:
            continue
        name, rid = m.group(1), m.group(3)
        if rid in ("ghost_v2_black", "ghost_v2_white"):
            report.append(f"  = {name}: 이미 v2")
            continue
        if ext.get(rid) not in BASE:
            report.append(f"  - {name}: 대상 아님({ext.get(rid)})")
            continue
        color, ledge = BASE[ext[rid]]
        nid = NEW[color][0]
        need_ext.add(color)
        b = b.replace(f'instance=ExtResource("{rid}")]', f'instance=ExtResource("{nid}")]', 1)
        if ledge:
            ledge_names.add(name)
            arr = re.search(r'^_points = SubResource\("([^"]+)"\)$', b, re.M).group(1)
            pts = points_of(s, arr)
            x0, x1 = min(p[0] for p in pts), max(p[0] for p in pts)
            top, bot = min(p[1] for p in pts), round(max(p[1] for p in pts))
            # 기본지형 프리팹과 같은 7 점(윗모서리 모따기 4/5px) — 마감 메시가 같은 모양으로 나온다.
            rect = [(x0 + 4, top), (x1 - 4, top), (x1, top + 4), (x1, bot), (x0, bot), (x0, top + 5), (x0 + 4, top)]
            # 리소스 id 는 영문·숫자·밑줄만 된다(한글 노드 이름을 넣으면 로드 때 ERROR 가 난다 — 실측).
            tag = str(len(ledge_names))
            ids = []
            for k, (x, y) in enumerate(rect):
                pid = f"ghost_v2_{tag}_p{k}"
                ids.append(pid)
                new_subs.append(f'[sub_resource type="Resource" id="{pid}"]\nresource_local_to_scene = true\n'
                                f'script = ExtResource("{point_id}")\nposition = Vector2({fmt(x)}, {fmt(y)})\n')
            aid = f"ghost_v2_{tag}_pts"
            new_subs.append(f'[sub_resource type="Resource" id="{aid}"]\nresource_local_to_scene = true\n'
                            f'script = ExtResource("{array_id}")\n_points = {{\n'
                            + ",\n".join(f'{k}: SubResource("{p}")' for k, p in enumerate(ids))
                            + f'\n}}\n_point_order = PackedInt32Array({", ".join(str(k) for k in range(7))})\n'
                            f'_constraints = {{\nVector2i(0, 6): 15\n}}\n_next_key = 7\n')
            b = re.sub(r'^_points = SubResource\("[^"]+"\)$', f'_points = SubResource("{aid}")', b, flags=re.M)
            b = re.sub(r'^(_meshes|shape_material) = [^\n]*\n?', "", b, flags=re.M)
            poly = f'PackedVector2Array({", ".join(f"{fmt(x)}, {fmt(y)}" for x, y in rect[:-1])})'
            report.append(f"  * {name}: 선반 → 기본지형 투명발판 {color} · x {fmt(x0)}~{fmt(x1)} · 윗면 {fmt(top)} · 두께 {fmt(bot - top)}")
            for j, c in enumerate(blocks):
                if f'parent="지형/{name}/StaticBody2D"' in c and c.startswith('[node name="CollisionPolygon2D"'):
                    blocks[j] = re.sub(r'^polygon = [^\n]*$', f'polygon = {poly}', c, flags=re.M)
        else:
            if "TEMPLATE_WALL" in ext[rid]:
                # 집 키트 캐시 메시(집 재질)는 새 하수도 재질과 안 맞는다 → 지우면 SS2D 가 다시 만든다
                b = re.sub(r'^_meshes = [^\n]*\n?', "", b, flags=re.M)
                ledge_names.add(name)   # 클릭사각형 흔적도 같이 정리
            report.append(f"  * {name}: 기본지형 유령 → 투명발판 v2 {color}(모양 그대로)")
        blocks[i] = b
    # 선반이던 노드의 클릭사각형 흔적은 지운다(새 프리팹에는 그 자식이 없다 — 남기면 "vanished" 경고).
    blocks = [c for c in blocks if not any(c.startswith('[node name="@ColorRect') and f'parent="지형/{n}"' in c for n in ledge_names)]
    s2 = "\n".join(blocks)
    for color in sorted(need_ext):
        nid, npath = NEW[color]
        if f'id="{nid}"' not in s2:
            last = list(re.finditer(r'^\[ext_resource[^\n]*\]$', s2, re.M))[-1]
            s2 = s2[:last.end()] + f'\n[ext_resource type="PackedScene" path="{npath}" id="{nid}"]' + s2[last.end():]
    if new_subs:
        first_node = s2.index("\n[node ")
        s2 = s2[:first_node] + "\n\n" + "\n".join(new_subs).rstrip("\n") + s2[first_node:]
    print(path.name)
    print("\n".join(report) if report else "  (유령 없음)")
    if apply and s2 != s:
        path.write_bytes((s2.replace("\n", "\r\n") if crlf else s2).encode("utf-8"))
        print("  → 저장")


if __name__ == "__main__":
    for p in SCENES:
        process(p, "--적용" in sys.argv)
