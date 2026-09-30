# -*- coding: utf-8 -*-
"""ver.2 8단계 — 2-9 에서 완성한 재질·조명·물 설정을 world_2_클로드 나머지 스테이지에 옮긴다.
씬 텍스트만 고친다. 기본은 미리보기, `--적용` 일 때만 쓴다. 멱등(이미 된 곳은 건너뛴다).

옮기는 것 (2-9 에서 확인된 값 그대로 — 2026-09-29):
  1. 배경  하수도_벽돌배경_v05.tscn → 하수도_벽돌배경_2_9_조정.tscn  (실시간 벽등 + sewer_wall_realtime 셰이더 + 명도 곡선)
  2. 지형  하수도_기본지형_검정/흰색 인스턴스에 "시안_명도조율" = true  (2-9 처럼 공중선반은 제외)
  3. 웅덩이 스크립트 웅덩이_흰물v2.gd → 웅덩이_하수도29.gd · 수심 32(바닥 고정 = position 은 아랫변이라 그대로) ·
           "받아주는_최소수심" = 32  (2-9 A_낙하물받이와 같은 값). 차오르는 웅덩이는 건드리지 않는다.
  4. 호퍼  주철 호퍼(호퍼_주철*.gd 스크립트/씬)에 "주철_명도" = 0.88  (2-9 C_혼합호퍼와 같은 값)

⚠ 웅덩이 수심이 바뀌면 게임플레이가 바뀐다(깊은 구덩이 물이 얕아짐). 적용 후 주행검사로 확인한다.
사용:  python tools/apply_2_9기준_전스테이지.py [--적용] [stage_2-1.tscn ...]
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
D = os.path.join(ROOT, "scenes", "world_2_클로드")
STAGES = ["stage_2-%d.tscn" % i for i in (1, 2, 3, 4, 5, 6, 7, 8, 10, 11)]

BG_OLD = "res://scenes/배경/하수도_벽돌배경_v05.tscn"
BG_NEW = "res://scenes/배경/하수도_벽돌배경_2_9_조정.tscn"
POOL_OLD = "res://scripts/스마트월드/웅덩이_흰물v2.gd"
POOL_NEW = "res://scripts/스마트월드/웅덩이_하수도29.gd"
TERRAIN = ("res://scenes/지형/하수도/하수도_기본지형_검정.tscn", "res://scenes/지형/하수도/하수도_기본지형_흰색.tscn")
DEPTH = 32


def ext_ids(text):
    return {m.group(2): m.group(1) for m in re.finditer(r'\[ext_resource [^\]]*path="([^"]+)" id="([^"]+)"\]', text)}


def process(name, apply):
    path = os.path.join(D, name)
    text = open(path, encoding="utf-8", newline="").read()
    nl = "\r\n" if "\r\n" in text else "\n"
    log = []
    # 1) 배경 경로
    if BG_OLD in text:
        text = text.replace('path="%s"' % BG_OLD, 'path="%s"' % BG_NEW)
        log.append("배경 v05→2_9_조정")
    ids = ext_ids(text)
    pool_script_ids = [k for k, v in ids.items() if v == POOL_OLD]
    # 웅덩이 스크립트 경로를 바꾼다(같은 ext_resource 를 쓰는 노드 전부) — 2-9 는 이 파생 스크립트만 쓴다
    if pool_script_ids:
        text = re.sub(r'(\[ext_resource [^\]]*path=")%s(")' % re.escape(POOL_OLD), r'\g<1>%s\2' % POOL_NEW, text)
        # uid 가 옛 스크립트를 가리키면 Godot 가 옛 파일을 연다 → uid 속성을 지운다(경로로 찾게)
        text = re.sub(r'(\[ext_resource type="Script") uid="[^"]+"( path="%s")' % re.escape(POOL_NEW), r'\1\2', text)
        log.append("웅덩이 스크립트→하수도29")
    ids = ext_ids(text)
    terrain_ids = {k for k, v in ids.items() if v in TERRAIN}
    pool_ids = {k for k, v in ids.items() if v == POOL_NEW}
    # 주철_명도 는 호퍼_주철.gd 에만 있다 → 주철 씬이거나 주철 스크립트로 덮어쓴 호퍼만(옛 코드 그림 호퍼는 제외)
    hopper_scene_ids = {k for k, v in ids.items() if "호퍼_주철" in v and v.endswith(".tscn")}
    hopper_script_ids = {k for k, v in ids.items() if "호퍼_주철" in v and v.endswith(".gd")}
    blocks = re.split(r'(?=^\[)', text, flags=re.M)
    n_t = n_p = n_h = 0
    for i, b in enumerate(blocks):
        head = re.match(r'\[node name="([^"]+)"([^\]]*)\]', b)
        if not head:
            continue
        attrs = head.group(2)
        inst = re.search(r'instance=ExtResource\("([^"]+)"\)', attrs)
        scr = re.search(r'^script = ExtResource\("([^"]+)"\)', b, re.M)
        endh = head.end()
        # 2) 지형 명도
        if inst and inst.group(1) in terrain_ids and 'parent="지형"' in attrs and "시안_명도조율" not in b:
            b = b[:endh] + nl + '"시안_명도조율" = true' + b[endh:]
            n_t += 1
        # 3) 웅덩이 수심
        if scr and scr.group(1) in pool_ids and "차오름_켜기\" = true" not in b and "차오름_켜기 = true" not in b:
            sm = re.search(r'^("?크기"?) = Vector2\(([-\d.]+), ([-\d.]+)\)(?=\r?$)', b, re.M)
            if sm and float(sm.group(3)) != DEPTH:
                b = b[:sm.start()] + '%s = Vector2(%s, %d)' % (sm.group(1), sm.group(2), DEPTH) + b[sm.end():]
                n_p += 1
                log.append("  웅덩이 %s 수심 %s→%d" % (head.group(1), sm.group(3), DEPTH))
            if "받아주는_최소수심" not in b:
                e = re.match(r'\[node [^\]]*\]', b).end()
                b = b[:e] + nl + '"받아주는_최소수심" = %d.0' % DEPTH + b[e:]
        # 4) 호퍼 명도
        is_hopper = (inst and inst.group(1) in hopper_scene_ids) or (scr and scr.group(1) in hopper_script_ids)
        if is_hopper and "주철_명도" not in b:
            e = re.match(r'\[node [^\]]*\]', b).end()
            b = b[:e] + nl + '"주철_명도" = 0.88' + b[e:]
            n_h += 1
        blocks[i] = b
    text = "".join(blocks)
    log.append("지형 명도조율 %d · 웅덩이 수심 %d · 호퍼 명도 %d" % (n_t, n_p, n_h))
    print("== %s" % name)
    for l in log:
        print("  " + l)
    if apply:
        open(path, "w", encoding="utf-8", newline="").write(text)


def main():
    apply = "--적용" in sys.argv
    targets = [a for a in sys.argv[1:] if a.endswith(".tscn")] or STAGES
    for s in targets:
        process(s, apply)
    print("적용함" if apply else "미리보기만 (--적용 으로 씀)")


if __name__ == "__main__":
    main()
