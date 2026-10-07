"""[2026-09-30 Claude] 하수도 스테이지 전부: 회색 배관 키트 → 주철 배관 · 선반형 공중발판 → 기본지형 공중발판.

도형님: "다른 스테이지도 주철 배관으로 변경해. 그리고 공중발판이랑 투명 발판도 적용해."
(투명발판은 `tools/교체_투명발판_기본지형.py` 가 맡는다 — 2-11 집 키트 유령까지 넓혔다.)

■ 배관 — ★발견: 2-1~2-8 의 회색 배관 45 개는 **전부 경로를 잃고 월드 원점(0,0)에 뭉쳐 있었다.**
  빌더(`하수도_빌더_공통.배관`)가 경로 점을 인스턴스 안쪽 자식 `경로` 에 넣었는데, 그 인스턴스가
  `[editable]` 이 아니어서 저장 때 점이 버려졌다 → 게임에서 배관이 제자리에 없었다.
  원래 경로는 빌더를 **저장 없이** 돌려 뽑았다: `tools/배관경로_빌더추출_2026-09-30.json`
  (공통 모듈을 상속한 임시 모듈이 `배관()` 호출만 기록하고 `저장()` 은 건너뜀 — 씬은 안 바뀐다).
  2-10 · 2-11 은 경로가 살아 있어(노드 위치 + 템플릿 기본 896 직선) 그 모양 그대로 옮긴다.
  새 노드 = `하수도_주철배관.gd` · 이름·부모 그대로 · z_index −1(지형 뒤 — 천장·벽 속 구간은 가려지고 입구만 보인다).
■ 공중발판 — `하수도_공중선반_*` 인스턴스(무색일때_통과 아닌 것) → `하수도_공중발판_기본지형_*`.
  윗면 높이·좌우 끝 그대로, 두께 = 원래 선반의 가장 낮은 점까지(기본지형 7 점 모따기 사각형).
  선반 전용 재질 덮어쓰기·캐시 메시·클릭사각형 흔적은 지우고, **충돌 덮어쓰기(일방통행)는 남겨** polygon 만 사각형으로.

멱등: 이미 바뀐 노드는 건너뛴다. 기본은 조사만, `--적용` 이면 쓴다.
  python tools/교체_하수도_주철배관_공중발판.py [--적용]
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
DIR = ROOT / "scenes" / "world_2_클로드"
빌더경로 = json.loads((ROOT / "tools" / "배관경로_빌더추출_2026-09-30.json").read_text(encoding="utf-8"))
# 2-10 · 2-11: 실행 중 실측(노드 위치 + 템플릿 기본 경로)
실측경로 = {
    "2-10": {"급수배관": [[4128, 8176], [5024, 8176]]},
    "2-11": {"구역1_폭포1_급수관": [[1344, 512], [2240, 512]], "구역1_폭포2_급수관": [[1792, 512], [2688, 512]],
             "구역4_폭포1_급수관": [[11328, 5120], [12224, 5120]], "구역4_폭포2_급수관": [[11776, 5120], [12672, 5120]],
             "구역5_폭포1_급수관": [[14656, 6656], [15552, 6656]], "구역5_폭포2_급수관": [[15104, 6656], [16000, 6656]]},
}
PIPE_TPL = "TEMPLATE_PIPE_OPEN_GRAY.tscn"
LEDGE = {"res://scenes/지형/하수도/하수도_공중선반_검정.tscn": "black", "res://scenes/지형/하수도/하수도_공중선반_흰색.tscn": "white"}
NEW_LEDGE = {"black": ("air_v2_black", "res://scenes/지형/하수도/하수도_공중발판_기본지형_검정.tscn"),
             "white": ("air_v2_white", "res://scenes/지형/하수도/하수도_공중발판_기본지형_흰색.tscn")}
CAST = ("cast_pipe", "res://scripts/스마트월드/하수도_주철배관.gd")


def sub_block(s, rid):
    m = re.search(r'\[sub_resource type="[^"]+" id="%s"\]\n(.*?)(?=\n\[|\Z)' % re.escape(rid), s, re.S)
    return m.group(1) if m else None


def points_of(s, arr_id):
    out = []
    for pid in re.findall(r'SubResource\("([^"]+)"\)', sub_block(s, arr_id) or ""):
        m = re.search(r'position = Vector2\(([-\d.e]+), ([-\d.e]+)\)', sub_block(s, pid) or "")
        out.append((float(m.group(1)), float(m.group(2))) if m else (0.0, 0.0))
    return out


def fmt(v):
    return str(int(v)) if float(v).is_integer() else ("%g" % v)


def add_ext(s, rid, path, kind):
    if f'id="{rid}"' in s:
        return s
    last = list(re.finditer(r"^\[ext_resource[^\n]*\]$", s, re.M))[-1]
    return s[:last.end()] + f'\n[ext_resource type="{kind}" path="{path}" id="{rid}"]' + s[last.end():]


def process(tag, apply):
    path = DIR / f"stage_{tag}.tscn"
    raw = path.read_bytes()
    crlf = b"\r\n" in raw
    s = raw.decode("utf-8").replace("\r\n", "\n")
    ext = {m.group(2): m.group(1) for m in re.finditer(r'\[ext_resource[^\n]*path="([^"]+)"[^\n]*id="([^"]+)"\]', s)}
    point_id = next((k for k, v in ext.items() if v.endswith("/shapes/point.gd")), None)
    array_id = next((k for k, v in ext.items() if v.endswith("/shapes/point_array.gd")), None)
    경로표 = {d["이름"]: d["점들"] for d in 빌더경로.get(tag, [])}
    경로표.update(실측경로.get(tag, {}))
    blocks = re.split(r"\n(?=\[)", s)
    rep, subs, need, 지울자식 = [], [], set(), set()
    for i, b in enumerate(blocks):
        m = re.match(r'\[node name="([^"]+)" parent="([^"]+)"([^\n]*)instance=ExtResource\("([^"]+)"\)\]', b)
        if not m:
            continue
        name, parent, mid, rid = m.groups()
        src = ext.get(rid, "")
        # ── 배관 ──
        if src.endswith(PIPE_TPL):
            pts = 경로표.get(name)
            if pts is None:
                rep.append(f"  ! 배관 {name}: 경로를 모른다 — 그대로 둔다")
                continue
            uid = re.search(r"unique_id=\d+ ", mid)
            head = f'[node name="{name}" type="Node2D" parent="{parent}" {uid.group(0) if uid else ""}]'.replace(" ]", "]")
            body = [head, "z_index = -1", f'script = ExtResource("{CAST[0]}")',
                    '"점들" = PackedVector2Array(' + ", ".join(f"{fmt(x)}, {fmt(y)}" for x, y in pts) + ")",
                    'editor_description = "2026-09-30: 회색 배관 키트 → 주철 배관. 경로는 빌더 원래 좌표(키트는 저장 때 경로를 잃어 원점에 뭉쳐 있었다)."']
            blocks[i] = "\n".join(body) + "\n"
            지울자식.add(f"{parent}/{name}")
            need.add("cast")
            rep.append(f"  * 배관 {name}: {len(pts)} 점")
        # ── 선반 → 기본지형 공중발판 ──
        elif src in LEDGE and '"무색일때_통과" = true' not in b:
            color = LEDGE[src]
            nid = NEW_LEDGE[color][0]
            need.add(color)
            b = b.replace(f'instance=ExtResource("{rid}")]', f'instance=ExtResource("{nid}")]', 1)
            am = re.search(r'^_points = SubResource\("([^"]+)"\)$', b, re.M)
            pts = points_of(s, am.group(1)) if am else []
            if not pts:
                # 점 덮어쓰기가 없으면 프리팹 기본 모양(0..340 · 0..~60)이다
                pts = [(0, 0), (340, 0), (340, 60), (0, 60)]
            x0, x1 = min(p[0] for p in pts), max(p[0] for p in pts)
            top, bot = min(p[1] for p in pts), round(max(p[1] for p in pts))
            rect = [(x0 + 4, top), (x1 - 4, top), (x1, top + 4), (x1, bot), (x0, bot), (x0, top + 5), (x0 + 4, top)]
            if point_id is None or array_id is None:
                rep.append(f"  ! 선반 {name}: 점 스크립트 ext 없음 — 건너뜀")
                continue
            tag_id = f"air_v2_{len(subs) // 8}"
            ids = []
            for k, (x, y) in enumerate(rect):
                pid = f"{tag_id}_p{k}"
                ids.append(pid)
                subs.append(f'[sub_resource type="Resource" id="{pid}"]\nresource_local_to_scene = true\n'
                            f'script = ExtResource("{point_id}")\nposition = Vector2({fmt(x)}, {fmt(y)})\n')
            subs.append(f'[sub_resource type="Resource" id="{tag_id}_pts"]\nresource_local_to_scene = true\n'
                        f'script = ExtResource("{array_id}")\n_points = {{\n'
                        + ",\n".join(f'{k}: SubResource("{p}")' for k, p in enumerate(ids))
                        + '\n}\n_point_order = PackedInt32Array(0, 1, 2, 3, 4, 5, 6)\n_constraints = {\nVector2i(0, 6): 15\n}\n_next_key = 7\n')
            if am:
                b = b.replace(am.group(0), f'_points = SubResource("{tag_id}_pts")')
            else:
                b = b.rstrip("\n") + f'\n_points = SubResource("{tag_id}_pts")\n'
            b = re.sub(r'^(_meshes|shape_material) = [^\n]*\n?', "", b, flags=re.M)
            blocks[i] = b
            poly = "PackedVector2Array(" + ", ".join(f"{fmt(x)}, {fmt(y)}" for x, y in rect[:-1]) + ")"
            for j, c in enumerate(blocks):
                if c.startswith('[node name="CollisionPolygon2D"') and f'parent="{parent}/{name}/StaticBody2D"' in c:
                    blocks[j] = re.sub(r"^polygon = [^\n]*$", f"polygon = {poly}", c, flags=re.M)
            지울자식.add(("클릭", f"{parent}/{name}"))
            rep.append(f"  * 선반 {name}({color}): x {fmt(x0)}~{fmt(x1)} · 윗면 {fmt(top)} · 두께 {fmt(bot - top)}")
    # 배관 인스턴스의 자식 덮어쓰기·editable 표시, 선반의 클릭사각형 흔적 제거
    out = []
    for c in blocks:
        cm = re.match(r'\[node name="([^"]+)" parent="([^"]+)"', c)
        if cm and any(isinstance(k, str) and (cm.group(2) == k or cm.group(2).startswith(k + "/")) for k in 지울자식):
            continue
        if cm and cm.group(1).startswith("@ColorRect") and ("클릭", cm.group(2)) in 지울자식:
            continue
        out.append(c)
    s2 = "\n".join(out)
    for k in 지울자식:
        if isinstance(k, str):
            s2 = s2.replace(f'[editable path="{k}"]\n', "")
    if "cast" in need:
        s2 = add_ext(s2, CAST[0], CAST[1], "Script")
    for color in ("black", "white"):
        if color in need:
            s2 = add_ext(s2, NEW_LEDGE[color][0], NEW_LEDGE[color][1], "PackedScene")
    if subs:
        first = s2.index("\n[node ")
        s2 = s2[:first] + "\n\n" + "\n".join(subs).rstrip("\n") + s2[first:]
    # 더는 안 쓰는 회색 키트 ext_resource 는 지운다
    for rid, v in ext.items():
        if v.endswith(PIPE_TPL) and f'ExtResource("{rid}")' not in s2:
            s2 = re.sub(r'^\[ext_resource[^\n]*id="%s"\]\n' % re.escape(rid), "", s2, flags=re.M)
    print(f"stage_{tag}  배관 {sum('배관' in r and '*' in r for r in rep)} · 선반 {sum('선반' in r and '*' in r for r in rep)}")
    for r in rep:
        if r.startswith("  !"):
            print(r)
    if apply and s2 != s:
        path.write_bytes((s2.replace("\n", "\r\n") if crlf else s2).encode("utf-8"))
        print("  → 저장")
    return rep


if __name__ == "__main__":
    for t in ["2-1", "2-2", "2-3", "2-4", "2-5", "2-6", "2-7", "2-8", "2-9", "2-10", "2-11"]:
        r = process(t, "--적용" in sys.argv)
        if "--자세히" in sys.argv:
            print("\n".join(r))
