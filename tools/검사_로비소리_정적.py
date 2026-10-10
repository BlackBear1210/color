"""Godot·사용자 저장 파일을 건드리지 않고 챕터 선택과 소리 연결 계약 13개를 확인한다."""
from pathlib import Path
import argparse
import json
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = [
    "scripts/ui/타이틀.gd", "scripts/ui/소리설정.gd", "scripts/ui/퍼즐보드.gd",
    "scripts/진행/게임진행.gd", "scripts/진행/쳅터1_보드표.gd",
    "scripts/스마트월드/게임설정.gd", "scripts/스마트월드/일시정지_메뉴.gd",
    "scripts/스마트월드/음향.gd", "scripts/플레이어_효과음.gd",
    "scripts/페인트_효과음.gd", "scripts/스마트월드/하수도_물소리.gd",
    "scripts/쳅터1/전경전환.gd", "scenes/lobby/lobby.gd",
]


def read(path):
    return (ROOT / path).read_text(encoding="utf-8-sig")


def main():
    args = argparse.ArgumentParser()
    args.add_argument("--parser-path", type=Path, required=True)
    options = args.parse_args()
    sys.path.insert(0, str(options.parser_path.resolve()))
    from gdtoolkit.parser import parser

    results = []

    def check(name, ok, detail=""):
        results.append({"검사": name, "통과": bool(ok), "상세": detail})
        print(("PASS " if ok else "FAIL ") + name + (" · " + detail if detail else ""))

    board = json.loads(read("scenes/lobby/퍼즐보드_쳅터1.json"))
    house_ids = {c["id"] for c in board["조각"]}
    check("집 지도 씬·선행 ID 유지", len(house_ids) == len(board["조각"]) and all(
        (ROOT / "scenes/쳅터1/스테이지" / (c["씬"] + ".tscn")).exists()
        and all(a in house_ids for a in c.get("앞", [])) for c in board["조각"]))
    progress = read("scripts/진행/게임진행.gd")
    rows = re.findall(r'\["(2-\d+)", "(stage_2-\d+\.tscn)", Vector2\([^\n]+?\), \[([^\]]*)\]\]', progress)
    mapped = {r[1] for r in rows}
    scene_files = {p.name for p in (ROOT / "scenes/world_2_클로드").glob("stage_*.tscn")}
    # 이후 맵 수가 늘어도 검사 도구를 고칠 필요가 없도록 기존 표는 부분집합으로 확인한다.
    check("기존 하수도 씬 목록 포함", mapped <= scene_files and len(mapped) == len(rows) and bool(rows))
    reached = set()
    for _ in rows:
        for name, _, prev in rows:
            predecessors = re.findall(r'"(2-\d+)"', prev)
            if not predecessors or any(p in reached for p in predecessors):
                reached.add(name)
    check("하수도 모든 칸 해금 도달", reached == {r[0] for r in rows})
    title = read("scripts/ui/타이틀.gd")
    board_source = read("scripts/ui/퍼즐보드.gd")
    check("로비·집 지도 하수도 입구", '_항목("스테이지", _쳅터_선택)' in title
          and "_지도_열기.bind(1)" in title and "_지도_열기.bind(2)" in title
          and '_다음쳅터.disabled = not ResourceLoader.exists(게임진행.지도_씬, "PackedScene")' in board_source
          and "게임진행.선택_쳅터 = 2" in board_source and "disabled = not 열림2" not in board_source)
    check("새 맵 자동 발견·확장 스크롤", "DirAccess.get_files_at(하수도_폴더)" in progress
          and 'trim_suffix(".remap")' in progress and "추가.sort_custom" in progress
          and "하수도_칸들()" in read("scripts/진행/쳅터1_보드표.gd")
          and "ensure_control_visible" in read("scripts/ui/퍼즐보드.gd"))
    # 씬에 적힌 실제 목적지를 읽고, 옛 로비 종료만 새 규칙대로 연결해 전체 주행 경로를 추적한다.
    ordered = sorted(scene_files, key=lambda n: int(n[8:-5]))
    edges = {}
    for i, name in enumerate(ordered):
        destinations = re.findall(r'"다음_씬" = "(res://[^"]+)"', read("scenes/world_2_클로드/" + name))
        target = destinations[-1] if destinations else ""
        if target in ["res://scenes/lobby/lobby.tscn", "res://scenes/lobby/타이틀.tscn"]:
            target = "res://scenes/world_2_클로드/" + ordered[i + 1] if i + 1 < len(ordered) else "res://scenes/lobby/타이틀.tscn"
        edges[name] = target
    visited = set()
    current = "stage_2-1.tscn"
    while current in edges and current not in visited:
        visited.add(current)
        current = edges[current].split("/")[-1]
    check("실제 출구 처음→마지막→새 로비", visited == scene_files and current == "타이틀.tscn"
          and "씬경로(칸들[현재 + 1])" in progress, "정적 이동 모델, 실제 엔진 주행은 미실행")
    bus = read("default_bus_layout.tres")
    check("음악·효과음이 Master로 합쳐짐", 'bus/1/name = &"BGM"' in bus and 'bus/2/name = &"SFX"' in bus
          and 'bus/1/send = &"Master"' in bus and 'bus/2/send = &"Master"' in bus)
    # 프로젝트의 모든 재생기 생성 지점을 훑어 새 소리가 기본 Master에 남는 누락을 잡는다.
    unrouted = []
    for path in (ROOT / "scripts").rglob("*.gd"):
        source = path.read_text(encoding="utf-8-sig")
        for match in re.finditer(r'(\w+)\s*=\s*AudioStreamPlayer(?:2D|3D)?\.new\(\)', source):
            tail = source[match.end():]
            before_parent = re.split(r'\badd_child\(', tail, maxsplit=1)[0]
            if not re.search(r'\b' + match[1] + r'\.bus\s*=\s*"(?:BGM|SFX)"', before_parent):
                unrouted.append(str(path.relative_to(ROOT)))
    check("모든 음악·효과음 재생기 버스 지정", not unrouted, repr(unrouted))
    settings = read("scripts/스마트월드/게임설정.gd")
    check("세 볼륨 범위·0% 음소거·다시 켜기", all('"' + k + '":' in settings for k in ["master", "bgm", "sfx"])
          and "AudioServer.set_bus_mute(버스, 크기 <= 0.0)" in settings
          and 'cfg.set_value("audio", 키, clampf(값, 0.0, 1.0))' in settings)
    legacy = read("scenes/lobby/lobby.gd")
    save = legacy.split("func _save_settings()", 1)[1]
    check("기존 설정 보존·로비/인게임 공통 UI", "cfg.load(SETTINGS_PATH)" in save
          and "volume_slider.value" not in save and all("소리설정.gd" in read(p) for p in
          ["scripts/ui/타이틀.gd", "scripts/스마트월드/일시정지_메뉴.gd", "scenes/lobby/lobby.gd"]))
    snap = read("scripts/진행/스테이지_스냅.gd")
    check("사진은 실제 플레이 캡처·클리어 저장", "get_viewport().get_texture().get_image()" in snap
          and '씬.connect("클리어됨", _저장)' in snap and "res://scripts/진행/스테이지_스냅.gd" in read("scripts/스마트월드/월드.gd"))
    missing = []
    for p in SCRIPTS:
        source = "\n".join(line for line in read(p).splitlines() if not line.lstrip().startswith("#"))
        for resource in re.findall(r'(?:preload|load)\("(res://[^"]+)"\)', source):
            if not (ROOT / resource[6:]).exists():
                missing.append(resource)
    check("관련 리소스 경로 존재", not missing, repr(missing))
    errors = []
    for path in SCRIPTS:
        source = read(path)
        if path == "scenes/lobby/lobby.gd":
            # 예전 로비의 일반 따옴표 다중행 셰이더만 파서가 이해하는 삼중 따옴표로 메모리에서 바꾼다.
            # 디스크 원본은 수정하지 않는다. 이 검사로 Godot의 타입·셰이더 검증을 했다고 간주하지 않는다.
            source = re.sub(r'sh\.code = "\n(.*?)\n}"', lambda m: 'sh.code = """\n' + m[1] + '\n}"""', source, flags=re.S)
        try:
            parser.parse(source)
        except Exception as error:
            errors.append(path + ": " + str(error))
    deleted = subprocess.run(["git", "diff", "--name-only", "--diff-filter=D"], cwd=ROOT,
                             capture_output=True, text=True, check=True).stdout.strip()
    check("13개 스크립트 문법·삭제 없음", not errors and not deleted, repr(errors))
    report = {"범위": "정적 계약 13개. Godot 타입 검사·실행·실제 화면·청취 검증은 미실행.", "검사": results}
    out = ROOT / "docs/visual_review/로비소리_20261010"
    out.mkdir(parents=True, exist_ok=True)
    (out / "정적_검사.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return int(not all(r["통과"] for r in results))


if __name__ == "__main__":
    sys.exit(main())
