# -*- coding: utf-8 -*-
"""2026-10-10: 짧은 방 이름·초반 학습 순서·색 전환 착지를 도안과 기존 씬에 멱등 적용한다.

씬 전체 생성은 하지 않는다. 추가지형/추가기믹 전용 도구가 에디터에서 고친 나머지 노드를 보존한다.
"""
import json
import os
import re
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PLANS = ROOT / "scenes/쳅터1/도안"
STAGES = ROOT / "scenes/쳅터1/스테이지"
NAMES = {1: "시작방", 2: "달빛 복도", 3: "서재", 4: "긴 복도", 5: "침실", 6: "유령 복도",
         7: "수납실", 8: "무너진 마루", 9: "중앙 계단", 10: "현관", 11: "거실", 12: "식당",
         13: "그을린 복도", 14: "굴뚝", 15: "뒷마당", 16: "썩은 마루", 17: "응접실",
         18: "숨은 서재", 19: "거미방"}
NOTE = "[2026-10-10 Codex 재검토]"


def save(path, content):
    # 같은 파일은 열지 않고, Godot 가져오기 잠금이 있어도 원본을 비우지 않도록 임시 파일로 원자 교체한다.
    if path.read_bytes() == content:
        return
    temporary = path.with_name(path.name + ".임시")
    temporary.write_bytes(content)
    for attempt in range(40):
        try:
            os.replace(temporary, path)
            return
        except OSError:
            if attempt == 39:
                raise
            time.sleep(0.25)


def write_members(path, updates):
    # JSON의 수정한 최상위 값만 교체해 들여쓰기·줄바꿈과 다른 작업자의 도안 내용을 보존한다.
    raw = path.read_bytes()
    text = raw.decode("utf-8")
    decoder = json.JSONDecoder()
    cursor = text.index("{") + 1
    spans = {}
    while True:
        while text[cursor].isspace() or text[cursor] == ",":
            cursor += 1
        if text[cursor] == "}":
            end = cursor
            break
        key, cursor = decoder.raw_decode(text, cursor)
        while text[cursor].isspace() or text[cursor] == ":":
            cursor += 1
        begin = cursor
        _, cursor = decoder.raw_decode(text, cursor)
        spans[key] = (begin, cursor)
    old = json.loads(text)
    changes = []
    additions = []
    for key, value in updates.items():
        if key in old and old[key] == value:
            continue
        encoded = json.dumps(value, ensure_ascii=False, indent=2).replace("\n", "\n  ")
        if key in spans:
            changes.append((*spans[key], encoded))
        else:
            additions.append(f'  {json.dumps(key, ensure_ascii=False)}: {encoded}')
    if additions:
        # 마지막 기존 멤버 뒤에 새 키를 붙인다. 값이 같으면 아무 것도 다시 쓰지 않는다.
        begin = end
        while begin > 0 and text[begin - 1].isspace():
            begin -= 1
        changes.append((begin, end, ",\n" + ",\n".join(additions) + "\n"))
    for begin, finish, value in sorted(changes, reverse=True):
        text = text[:begin] + value + text[finish:]
    if b"\r\n" in raw:
        text = text.replace("\r\n", "\n").replace("\n", "\r\n")
    json.loads(text)  # 손으로 고친 JSON을 잘못 끊었으면 씬 적용 전에 중단한다.
    if text.encode("utf-8") != raw:
        save(path, text.encode("utf-8"))


def add_terrain(data, rect):
    # 내용 자체를 키로 삼아 재실행해도 지형이 쌓이지 않게 한다.
    terrain = data.setdefault("추가지형", [])
    if rect not in terrain:
        terrain.append(rect)


def checkpoint(scene, name, x, y):
    text = scene.read_text(encoding="utf-8")
    if f'[node name="{name}"' in text:
        return
    resource = re.search(r'\[ext_resource[^\n]*path="res://scenes/장애물/체크포인트.tscn"[^\n]*id="([^"]+)"', text)[1]
    # 새 촛불만 더한다. 기존 촛불의 번호·owner·구운 충돌은 건드리지 않는다.
    text += (f'\n[node name="{name}" parent="체크포인트" instance=ExtResource("{resource}")]\n'
             f'position = Vector2({x * 32 + 16}, {y * 32})\ncollision_layer = 0\n')
    save(scene, text.encode("utf-8"))


def apply():
    board_path = ROOT / "scenes/lobby/퍼즐보드_쳅터1.json"
    board = json.loads(board_path.read_text(encoding="utf-8"))
    cards = board["조각"]
    for card in cards:
        card["이름"] = NAMES[int(card["id"])]
    write_members(board_path, {"조각": cards})
    chapter_path = ROOT / "scripts/스마트월드/챕터.gd"
    text = chapter_path.read_text(encoding="utf-8")
    # 번호와 씬 경로는 저장된 진행의 식별자다. 표시 이름만 바꿔 선택창·HUD·일시정지에 같은 짧은 이름을 쓴다.
    for number, name in NAMES.items():
        pattern = rf'("번호": {number}, "챕터": 1, "이름": ")[^"]*(")'
        text = re.sub(pattern, lambda m: m[1] + f"{number} · {name}" + m[2], text)
    comment = "\t# [2026-10-10] 사진 카드 폭에 맞춰 층·기믹 부제는 빼고 장소 이름만 표시한다. 진행 번호·순서는 유지한다.\n"
    if comment not in text:
        text = text.replace('\t{"번호": 1, "챕터": 1,', comment + '\t{"번호": 1, "챕터": 1,', 1)
    save(chapter_path, text.encode("utf-8"))
    for path in sorted(PLANS.glob("*.json")):
        data = json.loads(path.read_text(encoding="utf-8"))
        number = int(path.stem.split("_")[1])
        data["제목"] = f"{number:02d} · {NAMES[number]}"
        reasons = []
        if number in (1, 3, 4, 5, 6, 7, 9, 16):
            # 거미의 추격은 색 전환 학습 뒤에 나온다. 공용 몹을 바꾸지 않고 해당 방의 배치만 제거한다.
            data["기믹"] = [g for g in data.get("기믹", []) if g["종류"] not in ("그을음", "거미")]
            reasons.append("2층과 첫 계단에서는 거미 추격 없이 색·빛·지형을 먼저 익힌다. 첫 거미는 1층 거실에서 만난다.")
        if number == 1:
            data["기믹"] = [g for g in data["기믹"] if g["종류"] != "반딧불몹"]
            for gimmick in data["기믹"]:
                if gimmick["종류"] == "부서지는판":
                    # 첫 판은 죽음보다 붕괴를 익히는 자리다. 검사기도 의도적인 회복 바닥으로 구분한다.
                    gimmick["아래허용"] = True
                    gimmick["장수"] = 1
            # 옆 판이 남아 머리를 막지 않도록 첫 구덩이를 3칸 한 장으로 좁힌다. 연속판은 썩은 마루에서 배운다.
            add_terrain(data, ["구조", 73, 49, 3, 3])
            data["추가가시"] = []
            if [56, 49] not in data["체크"]:
                data["체크"].append([56, 49])
            checkpoint(STAGES / (path.stem + ".tscn"), "체크_색전환", 56, 49)
            reasons.append("첫 붕괴판을 한 장으로 줄이고 아래 가시를 없애 3칸 아래에서 다시 뛰어 나오게 한다. 첫 흰빛 앞 촛불에서 재시도한다.")
        if number == 3:
            add_terrain(data, ["흰구조", 76, 53, 6, 3])
            for gimmick in data["기믹"]:
                if gimmick["종류"] == "빛줄기":
                    gimmick["주기"] = 4.0
            reasons.append("큰 낙하 뒤 빛 아래 흰 선반을 둔다. 빛의 흰 구간에 흰 몸으로 착지하고 검은 바닥으로 나갈 때 다시 바꾼다.")
        if number == 4:
            beam = {"종류": "빛줄기", "근원": "천장틈", "x": 27, "y": 5, "각도": 90, "두께": 2, "추가": True,
                    "_설계": "흰 디딤판 위 고정 빛으로 색 전환을 유도하고 이어지는 검정 점멸 구간에서 기다리기를 복습한다."}
            if not any(g.get("_설계") == beam["_설계"] for g in data["기믹"]):
                data["기믹"].append(beam)
            reasons.append(beam["_설계"])
        if number in (5, 7):
            for gimmick in data["기믹"]:
                if gimmick["종류"] == "빛줄기" and gimmick.get("주기", 0) and not gimmick.get("점멸"):
                    gimmick["주기"] = 4.0
            reasons.append("색 변화 빛을 4초 주기로 늦춰 점프·공중 색 전환·유령판 칠하기를 읽고 수행할 시간을 확보한다.")
        if number == 9:
            add_terrain(data, ["흰구조", 41, 58, 8, 3])
            reasons.append("층계참에 폭 8칸 흰 선반을 놓아 내려가기만 하는 계단에 색 전환 선택을 만든다. 낙하 중 색을 바꾸고 검정 계단으로 빠져나온다.")
        if number == 11:
            candle = {"종류": "촛불", "x": 141, "바닥": 65, "_설계": "첫 거미 앞의 빛 피난처"}
            existing = next((g for g in data["기믹"] if g.get("_설계") == candle["_설계"]), None)
            if existing is None:
                data["기믹"].append(candle)
            else:
                existing.update(candle)
            for gimmick in data["기믹"]:
                if gimmick["종류"] == "그을음":
                    gimmick.update({"깨어남_칸": 4, "속도_배": 0.5, "덮침_예고": 0.8, "영역_칸": 6})
            reasons.append("첫 거미 앞 영구 촛불·짧은 추격 영역·0.8초 예고로 빛 유인을 배운 뒤 후반 거미방에서 응용한다.")
        if number == 14:
            # 실제 플레이어는 도약 후 선반 왼끝에서 허리가 걸리고 발이 못 올라갔다. 기존 선반의 왼쪽만 1칸 넓힌다.
            add_terrain(data, ["유령", 16, 92, 1, 2])
            reasons.append("도약대 위 유령 선반 왼쪽을 1칸 보강해 착지 오차가 생겨도 모서리에 매달리지 않고 발이 올라간다.")
        if number == 16:
            reasons.append("썩은 마루는 단일판 → 연속판 → 높이 변화 → 점멸 빛과 연속판으로 발전한다. 추격 몹을 섞지 않는다.")
        for door in data.get("옆방문", []):
            target = int(door["연결"][0].split("_")[1])
            door["표제"] = NAMES[target]
        memos = [m for m in data.get("메모", []) if not m.startswith(NOTE)]
        data["메모"] = memos + [f"{NOTE} {reason}" for reason in reasons]
        original = json.loads(path.read_text(encoding="utf-8"))
        write_members(path, {k: v for k, v in data.items() if k not in original or original[k] != v})
        # 안내 표제만 변경한다. 문 이동·연결·입력·키 진행은 기존 에디터 저장값을 보존한다.
        scene = STAGES / (path.stem + ".tscn")
        scene_text = scene.read_text(encoding="utf-8")
        for door in data.get("옆방문", []):
            pattern = rf'(\[node name="{re.escape(door["이름"])}"[^\n]*\n[^\[]*?"표제" = ")[^"]*(")'
            scene_text = re.sub(pattern, lambda m: m[1] + door["표제"] + m[2], scene_text)
        if scene_text != scene.read_text(encoding="utf-8"):
            save(scene, scene_text.encode("utf-8"))
    import 추가기믹
    추가기믹.적용()


if __name__ == "__main__":
    apply()
