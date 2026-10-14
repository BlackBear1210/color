# -*- coding: utf-8 -*-
"""
F5 연결 지도 — "F5 를 누르면 어떤 파일들이 줄줄이 불려 오나" 를 글로 뽑는다.

왜 만들었나 (2026-10-13 · Claude)
  graphify 그래프는 함수 호출까지 다 들어 있어서 너무 크고, HTML 은 브라우저가 멈춘다.
  도형님이 원한 건 "어떤 파일이 어떤 파일을 쓰나" 한 단계 — 코드·씬·음악·그림 전부.
  그래서 엔진을 켜지 않고 **파일 글자만 읽어서** 연결을 따라간다.

어떻게 연결을 찾나 (엔진이 실제로 쓰는 경로 표기 그대로)
  1. project.godot  : run/main_scene(= F5 시작 씬) · 아이콘 · 플러그인
  2. .tscn / .tres  : [ext_resource ... path="res://..." uid="uid://..."]
  3. .gd            : 글 안의 "res://..." · "uid://..." (preload/load/change_scene 전부)
                      + class_name 으로 이름만 불러 쓰는 스크립트(preload 없이 쓰는 경우)
                      + "res://폴더/" 처럼 폴더만 적고 이름을 이어 붙이는 경우
                        → 그 폴더 바로 아래 파일을 **전부** 잇는다(동적 · "폴더 전체")
                      + "…/saw_r%d.png" 같은 형식 문자열 → 맞는 파일 전부
  4. .gdshader      : #include "res://..."
  5. .json/.cfg     : 표 안의 "res://..."
  6. 짝 규칙        : xxx_black ↔ xxx_white · …/black/… ↔ …/white/…(지형.gd 가 짝을 찾아 씀)
                      · xxx.png → xxx_n.png(노멀맵) · default_bus_layout.tres(엔진 기본)
  uid:// 는 .uid · .import · 씬 머리줄에서 진짜 경로로 바꾼다.

[2026-10-13 검토로 고친 것] 처음 판은 이름을 실행 중에 만드는 로드(잠긴문 문 그림 · 하수도 발소리
  step_*_%d.wav · 흑백 짝 그림 · 노멀맵)를 놓쳐서 실제로 쓰는 파일 153 개를 "안 씀" 으로 냈다.
  지울 파일을 고르는 지도이므로 지금은 **넉넉하게**(쓰는 쪽으로) 잇는다. 그래서 "F5 에서 닿음" 에는
  안 쓰는 것이 조금 섞일 수 있지만, "안 닿음" 은 정적·동적 로드를 다 확인한 결과다.
  검증 방법: Godot 의존 캐시(.godot/editor/filesystem_cache10)와 간선 비교 — 284 파일 중 어긋남 0
  (8 건은 캐시가 옛것) · 경로를 조립하는 load/exists/DirAccess 호출 전부 눈으로 확인 · class_name 누락 0.

한계
  - 주석 줄(# 로 시작)은 일부러 뺀다 — 옛 경로가 주석에 남아 있는 경우가 많아서.
  - 새로 경로를 조립하는 코드를 쓰면(폴더 상수 없이 다른 리소스 경로에서 바꿔 만들기 등) 다시 확인할 것.

안 닿는 파일 분류(6 절 · docs/연결지도_안닿는파일.txt)
  가 아무 데도 이름이 없음 · 나 문서에만 · 다 안 쓰는 옛 파일끼리만 · 라 검사(규칙 3)가 씀 · 마 다른 도구만 씀
  가·나·다·마 의 경계는 이름 검색이라 대략적이다. 확실한 선은 "F5 로 안 닿음" 과 "라(검사)" 다.

쓰는 법
  python -X utf8 tools/연결지도.py              → docs/연결지도_F5.md · 연결지도_안닿는파일.txt 를 새로 쓴다(멱등)
  python -X utf8 tools/연결지도.py 월드.gd       → 그 파일이 쓰는 것 / 그 파일을 쓰는 곳 / F5 에서 가는 길
"""
import os
import re
import sys
from collections import defaultdict, deque

루트 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
결과_경로 = os.path.join(루트, "docs", "연결지도_F5.md")
목록_경로 = os.path.join(루트, "docs", "연결지도_안닿는파일.txt")
# CLAUDE.md 규칙 3 의 검사 목록 — 원문 docs/다음작업_프롬프트.md §1 은 10-04 정리 때 저장소 밖으로 나갔다
# (git a082c01^ 에 남아 있음). 거기 적힌 것 중 지금 tools/ 에 남아 있는 것만 실제로 쓰인다.
검사_목록 = {
    "check_스마트월드", "test_SS2D_중복연결", "test_color_death", "test_lobby_flow", "test_paint_system",
    "test_stages", "test_낙하사망", "test_빛창문", "test_사망판정", "test_지형규칙", "test_차오르는물",
    "test_챕터전환", "test_카메라공간", "test_카메라연출", "test_통로전환", "test_페인트v4", "레벨검사",
}

# 엔진 내부 캐시·백업은 진짜 게임 파일이 아니다
# docs/ 는 검토용 사본(씬·코드 통째 복사본)이 있어 같은 uid 가 두 벌이 된다 → 진짜 파일과 섞여서 뺀다
빼는_폴더 = {".godot", ".git", ".agents", ".claude", "graphify-out", "tmp", "node_modules", "docs"}
# addons 안은 펼치면 수백 줄이 된다 — 이어진 것만 보이고 안쪽은 펼치지 않는다
안_펼침_접두 = ("res://addons/",)

종류표 = {
    ".gd": "코드", ".tscn": "씬", ".scn": "씬", ".tres": "리소스", ".res": "리소스",
    ".gdshader": "셰이더", ".gdshaderinc": "셰이더",
    ".png": "그림", ".jpg": "그림", ".jpeg": "그림", ".webp": "그림", ".svg": "그림", ".ico": "그림",
    ".ogg": "소리", ".wav": "소리", ".mp3": "소리",
    ".ttf": "글꼴", ".otf": "글꼴", ".fnt": "글꼴",
    ".json": "데이터", ".cfg": "데이터", ".txt": "데이터", ".csv": "데이터",
    ".glb": "3D", ".gltf": "3D", ".obj": "3D",
}
읽는_확장자 = {".gd", ".tscn", ".tres", ".gdshader", ".gdshaderinc", ".json", ".cfg"}

RES = re.compile(r'"(res://[^"\n]+)"')
UID = re.compile(r'"(uid://[a-z0-9]+)"')
CLASS = re.compile(r'^class_name\s+([^\s#]+)', re.M)


def res(절대):
    return "res://" + os.path.relpath(절대, 루트).replace("\\", "/")


def 절대(r):
    return os.path.join(루트, r[len("res://"):].replace("/", os.sep))


def 종류(r):
    return 종류표.get(os.path.splitext(r)[1].lower(), "기타")


def 읽기(r):
    try:
        with open(절대(r), encoding="utf-8", errors="replace") as f:
            return f.read()
    except OSError:
        return ""


def 주석_뺀_글(글, 확장자):
    if 확장자 in (".gd",):
        return "\n".join(l for l in 글.splitlines() if not l.lstrip().startswith("#"))
    if 확장자 in (".gdshader", ".gdshaderinc"):
        return "\n".join(l for l in 글.splitlines() if not l.lstrip().startswith("//"))
    return 글


# ── 1. 파일 목록 + uid 표 ─────────────────────────────────────────────
def 훑기():
    파일들 = set()
    uid표 = {}

    def uid_넣기(u, r):
        # 같은 uid 가 두 파일에 있으면(사본) 보관·백업 쪽은 뒤로 미룬다
        if u in uid표 and not any(k in uid표[u] for k in ("보관", "백업", "backup")):
            return
        uid표[u] = r

    for 폴더, 하위, 이름들 in os.walk(루트):
        하위[:] = [d for d in 하위 if d not in 빼는_폴더 and not d.startswith("백업")]
        for n in 이름들:
            p = os.path.join(폴더, n)
            r = res(p)
            확장자 = os.path.splitext(n)[1].lower()
            if 확장자 == ".uid":
                m = re.search(r"uid://[a-z0-9]+", 읽기(r))
                if m:
                    uid_넣기(m.group(0), r[:-4])
            elif 확장자 == ".import":
                m = re.search(r'uid="(uid://[a-z0-9]+)"', 읽기(r))
                if m:
                    uid_넣기(m.group(1), r[:-7])
            else:
                파일들.add(r)
                if 확장자 in (".tscn", ".tres"):
                    with open(p, encoding="utf-8", errors="replace") as f:
                        머리 = f.readline()
                    m = re.search(r'uid="(uid://[a-z0-9]+)"', 머리)
                    if m:
                        uid_넣기(m.group(1), r)
    return 파일들, uid표


# ── 2. 파일마다 "이 파일이 쓰는 것" ─────────────────────────────────
def 연결_찾기(파일들, uid표):
    클래스표 = {}
    for r in 파일들:
        if r.endswith(".gd"):
            m = CLASS.search(읽기(r))
            if m:
                클래스표[m.group(1)] = r
    클래스_정규 = None
    if 클래스표:
        # 긴 이름부터 — "챕터" 가 "챕터1_보드표" 안에서 잘못 잡히지 않게 경계도 건다
        이름들 = sorted(클래스표, key=len, reverse=True)
        클래스_정규 = re.compile(r"(?<![\w])(" + "|".join(map(re.escape, 이름들)) + r")(?![\w])")

    폴더_안 = defaultdict(list)
    for r in 파일들:
        폴더_안[r.rsplit("/", 1)[0] + "/"].append(r)

    쓰는것 = defaultdict(dict)   # r -> {대상: 방식}
    for r in 파일들:
        확장자 = os.path.splitext(r)[1].lower()
        if 확장자 not in 읽는_확장자 and not r.endswith("project.godot"):
            continue
        글 = 주석_뺀_글(읽기(r), 확장자)

        def 잇기(대상, 방식):
            if 대상 and 대상 != r and 대상 in 파일들:
                쓰는것[r].setdefault(대상, 방식)

        for 줄 in 글.splitlines():
            if 'path="res://' not in 줄:
                for u in UID.findall(줄):
                    잇기(uid표.get(u), "uid")
            for p in RES.findall(줄):
                p = p.split("::")[0]
                if p.endswith("/"):
                    # 폴더만 적은 줄: begins_with 같은 "여기 씬인가?" 검사는 불러오는 게 아니다
                    if "begins_with" in 줄 or "contains" in 줄:
                        continue
                    # [2026-10-13 검토] 이름이 글에 그대로 나오는 것만 잇던 것을 고쳤다.
                    #   폴더 + 재 + "_문_닫힘.png"(잠긴문) · 경로 + "step_stone_%d.wav"(하수도_물소리)
                    #   · DirAccess.get_files_at(폴더)(게임진행)처럼 이름을 실행 중에 만드는 곳을 놓쳤다.
                    #   지울 파일을 고르는 지도라서 "모자라게" 보다 "넉넉하게" 잇는 쪽이 안전하다 →
                    #   폴더 바로 아래 파일을 전부 잇고, 이름이 글에 안 나오는 것은 "폴더 전체" 로 표시해 둔다.
                    for 후보 in 폴더_안.get(p, []):
                        이름 = os.path.splitext(후보.rsplit("/", 1)[1])[0]
                        잇기(후보, "폴더+이름" if len(이름) >= 2 and 이름 in 글 else "폴더 전체")
                    continue
                if "%" in p:
                    # "…/saw_r%d.png" · "…/%s/fill.tres" — 형식 자리를 아무 글자로 보고 맞춘다
                    틀 = re.compile(re.sub(r"%(?:0?\d+)?[sd]", "[^/]+", re.escape(p).replace(r"\%", "%")) + "$")
                    for 후보 in 파일들:
                        if 틀.match(후보):
                            잇기(후보, "형식 문자열")
                    continue
                if p in 파일들:
                    잇기(p, "경로")
                elif p.endswith(".cfg") and "addons" in p:
                    잇기(p, "경로")
        if 확장자 == ".gd" and 클래스_정규:
            # 한글 class_name(월드·장식·챕터…)은 보통 낱말과 겹친다 → 글자열·줄끝 주석을 지우고,
            # 코드에서 클래스를 쓰는 모양(월드.xxx · : 월드 · as 월드 · extends 월드 …)만 센다
            코드만 = re.sub(r'"[^"\n]*"', '""', 글)
            코드만 = re.sub(r"#.*", "", 코드만)
            for m in 클래스_정규.finditer(코드만):
                앞 = 코드만[max(0, m.start() - 12):m.start()]
                뒤 = 코드만[m.end():m.end() + 1]
                if 뒤 == "." or re.search(r"(:|->|\bas|\bis|\bextends|\[)\s*$", 앞):
                    잇기(클래스표[m.group(1)], "class_name")

    # ── 실행 중에 "짝" 으로 불려 오는 파일 ──
    # [2026-10-13 검토] 아래 둘은 경로가 어느 글에도 안 적혀 있는데 실제로 읽힌다.
    #   1) 흑백 짝: 지형.gd `_짝_찾기` 가 xxx_black.png ↔ xxx_white.png, …/black/… ↔ …/white/…
    #      를 바꿔 끼운다(하수도_벽돌지형.gd 도 /black/ ↔ /white/). 한쪽만 쓰여 있어도 다른 쪽이 필요하다.
    #   2) 노멀 짝: lobby.gd · 하수도_주철배관.gd 가 xxx.png 옆의 xxx_n.png 를 찾아 붙인다.
    for r in 파일들:
        if 종류(r) not in ("그림", "리소스"):
            continue
        폴더, 파일 = r.rsplit("/", 1)
        이름, 확장 = os.path.splitext(파일)
        짝들 = []
        조각 = 이름.split("_")
        for i, t in enumerate(조각):
            if t in ("black", "white"):
                반대 = 조각[:]
                반대[i] = "white" if t == "black" else "black"
                짝들.append(f"{폴더}/{'_'.join(반대)}{확장}")
        if "/black/" in r + "/" or "/white/" in r + "/":
            짝들.append(r.replace("/black/", "/\0/").replace("/white/", "/black/").replace("/\0/", "/white/"))
        짝들.append(f"{폴더}/{이름}_n{확장}")
        for 짝 in 짝들:
            if 짝 != r and 짝 in 파일들:
                쓰는것[r].setdefault(짝, "흑백·노멀 짝")
    return 쓰는것


# ── 3. F5 에서 따라가기 ───────────────────────────────────────────────
def 시작점():
    글 = 읽기("res://project.godot")
    m = re.search(r'run/main_scene="([^"]+)"', 글)
    return m.group(1) if m else None


def 따라가기(쓰는것, 출발):
    부모 = {출발: None}
    q = deque([출발])
    while q:
        r = q.popleft()
        if r.startswith(안_펼침_접두):
            continue
        for 대상 in sorted(쓰는것.get(r, {})):
            if 대상 not in 부모:
                부모[대상] = r
                q.append(대상)
    return 부모


def 짧게(r):
    return r[len("res://"):]


# ── 4. 글로 쓰기 ──────────────────────────────────────────────────────
def 문서_쓰기(파일들, 쓰는것, 출발, 닿음):
    줄 = []
    w = 줄.append
    w("# F5 연결 지도")
    w("")
    w("> `python -X utf8 tools/연결지도.py` 가 만든다(손으로 고치지 말 것). "
      "파일 하나만 보려면 `python -X utf8 tools/연결지도.py <파일이름>`.")
    w("> 엔진을 켜지 않고 파일 글자만 읽어서 찾은 연결이다 — 실행 중에 글자를 조립해 만드는 경로는 빠질 수 있다.")
    w("")
    w(f"**F5 시작 씬** = `{짧게(출발)}` (project.godot `run/main_scene`)")
    w("")

    # 4-1 숫자
    w("## 1. 한눈에 — 종류별 개수")
    w("")
    w("| 종류 | F5 에서 닿음 | 프로젝트 전체 | 안 닿음 |")
    w("|---|---:|---:|---:|")
    전체 = defaultdict(int)
    닿은 = defaultdict(int)
    for r in 파일들:
        if r.startswith(안_펼침_접두) or r.startswith("res://docs/"):
            continue
        k = 종류(r)
        if k == "기타":
            continue
        전체[k] += 1
        if r in 닿음:
            닿은[k] += 1
    for k in ["씬", "코드", "리소스", "셰이더", "그림", "소리", "글꼴", "데이터", "3D"]:
        if 전체[k]:
            w(f"| {k} | {닿은[k]} | {전체[k]} | {전체[k] - 닿은[k]} |")
    w("")
    w("_docs/ · addons/ 안쪽은 세지 않았다. '안 닿음' 은 도구(tools/)·시험 씬·옛 파일·동적 경로로 못 잡은 것이 섞여 있다._")
    w("")

    # 4-2 씬 흐름
    # 처음엔 "씬 → 그 씬 코드가 (줄줄이) 부르는 씬" 을 나무로 그렸는데, 게임진행.gd 처럼
    # 모든 씬이 같이 쓰는 코드를 거치면 모든 씬이 모든 씬으로 이어져 나무가 폭발했다.
    # 그래서 둘로 나눈다: (가) 씬이 씬을 품는 것(인스턴스) · (나) 화면을 넘기는 코드.
    def 묶어_적기(목록):
        # 같은 폴더에 4 개 이상이면 "폴더/ (N개: a, b, …)" 로 접는다 — 스테이지 목록이 길어서
        폴더별 = defaultdict(list)
        for x in 목록:
            폴더별[x.rsplit("/", 1)[0]].append(x.rsplit("/", 1)[1])
        조각 = []
        for 폴더, 이름들 in sorted(폴더별.items()):
            if len(이름들) >= 4:
                조각.append(f"`{짧게(폴더)}/` {len(이름들)}개 ({', '.join(sorted(이름들))})")
            else:
                조각 += [f"`{짧게(폴더)}/{n}`" for n in sorted(이름들)]
        return " · ".join(조각)

    w("## 2. 씬 흐름")
    w("")
    w("### 2-가. 씬을 부르는 코드 — 어느 코드가 어느 씬으로 넘기거나 만들어 넣나")
    w("")
    w("| 코드 | 붙어 있는 씬 | 부르는 씬 (화면 넘김 · 새로 만들어 넣기) |")
    w("|---|---|---|")
    붙은씬 = defaultdict(list)
    for 씬 in 닿음:
        if 씬.endswith(".tscn"):
            for 대상 in 쓰는것.get(씬, {}):
                if 대상.endswith(".gd"):
                    붙은씬[대상].append(씬)
    for r in sorted(x for x in 닿음 if x.endswith(".gd")):
        자기씬 = set(붙은씬[r])
        목표 = [x for x in 쓰는것.get(r, {}) if x.endswith(".tscn") and x not in 자기씬]
        if not 목표:
            continue
        붙음 = 묶어_적기(붙은씬[r]) if 붙은씬[r] else "— (다른 코드가 불러 씀)"
        w(f"| `{짧게(r)}` | {붙음} | {묶어_적기(목표)} |")
    w("")
    w("### 2-나. 씬 조립 — 씬 안에 통째로 들어 있는 씬(인스턴스)")
    w("")
    w("| 씬 | 안에 든 씬 |")
    w("|---|---|")
    for 씬 in sorted(x for x in 닿음 if x.endswith(".tscn")):
        글 = 읽기(씬)
        안 = sorted({p for p in re.findall(r'\[ext_resource[^\]]*path="(res://[^"]+\.tscn)"', 글) if p in 파일들})
        if 안:
            w(f"| `{짧게(씬)}` | {묶어_적기(안)} |")
    w("")

    # 4-3 씬마다 직접 쓰는 것
    w("## 3. 씬마다 — 직접 쓰는 코드·그림·소리")
    w("")
    w("F5 에서 닿는 씬 하나하나가 **직접** 가져다 쓰는 파일. (코드가 또 부르는 것은 4 절)")
    w("")
    for 씬 in sorted(r for r in 닿음 if r.endswith(".tscn")):
        묶음 = defaultdict(list)
        for 대상 in sorted(쓰는것.get(씬, {})):
            묶음[종류(대상)].append(짧게(대상))
        w(f"<details><summary><code>{짧게(씬)}</code> — {sum(len(v) for v in 묶음.values())} 개</summary>")
        w("")
        for k in ["씬", "코드", "리소스", "셰이더", "그림", "소리", "글꼴", "데이터", "기타"]:
            if 묶음[k]:
                w(f"- **{k}**: " + " · ".join(f"`{x}`" for x in 묶음[k]))
        w("")
        w("</details>")
        w("")

    # 4-4 코드마다
    w("## 4. 코드마다 — 무엇을 부르나 / 누가 부르나")
    w("")
    쓰이는곳 = defaultdict(set)
    for a, 대상들 in 쓰는것.items():
        for b in 대상들:
            쓰이는곳[b].add(a)
    w("| 코드 | 부르는 것 (코드·씬·그림·소리…) | 이 코드를 쓰는 곳 수 |")
    w("|---|---|---:|")
    for r in sorted(x for x in 닿음 if x.endswith(".gd")):
        대상들 = sorted(쓰는것.get(r, {}))
        글 = " · ".join(f"`{짧게(x).rsplit('/', 1)[-1]}`" for x in 대상들[:12])
        if len(대상들) > 12:
            글 += f" 외 {len(대상들) - 12}"
        w(f"| `{짧게(r)}` | {글 or '—'} | {len(쓰이는곳[r])} |")
    w("")

    # 4-5 소리·음악
    w("## 5. 소리·음악은 어디서 울리나")
    w("")
    for r in sorted(x for x in 닿음 if 종류(x) == "소리"):
        누가 = sorted(짧게(x) for x in 쓰이는곳[r])
        w(f"- `{짧게(r)}` ← " + " · ".join(f"`{x}`" for x in 누가))
    w("")

    # 4-6 안 닿는 파일 — 지울 후보를 고르려고 다섯 칸으로 나눈다
    # [2026-10-13] 도형님 목적 = 필요 없는 파일 정리. "F5 로 안 닿는다" 만으로는 시험 씬·도구 입력이
    #   섞여서 고를 수가 없다 → 누가 이름이라도 부르는지로 나눈다. 전체 목록은 옆 txt 에.
    분류 = 안닿는_분류(파일들, 쓰는것, 닿음)
    설명 = {
        "가": "아무 데도 안 나옴 — 게임·도구·문서 어디에도 파일 이름이 없다. **지울 1순위**",
        "나": "문서(.md)에만 이름이 나옴 — 게임·도구는 안 쓴다. 기록용이면 지워도 게임엔 영향 없음",
        "다": "안 쓰는 옛 파일끼리만 이어짐 — 옛 씬·옛 코드가 부르는 것. 부르는 쪽과 같이 지울지 판단",
        "라": "검사(CLAUDE.md 규칙 3 의 검사 도구)가 불러 씀 — 지우면 검사가 깨진다. 남기거나 검사를 먼저 고칠 것",
        "마": "다른 도구(촬영·진단·빌더·시험_*·이미지 굽는 파이썬)만 씀 — 게임엔 영향 없음. 그 도구와 같이 정리",
    }
    w("## 6. F5 로 안 닿는 파일 — 지울 후보 분류")
    w("")
    w(f"전체 목록(파일 하나하나): `{os.path.relpath(목록_경로, 루트).replace(os.sep, '/')}`")
    w("")
    w("| 칸 | 뜻 | 개수 |")
    w("|---|---|---:|")
    for k in "가나다라마":
        w(f"| {k} | {설명[k]} | {len(분류[k])} |")
    w("")
    w("⚠ 지우기 전에: `.import`·`.uid` 짝 파일도 같이 지운다 · `addons/` 는 플러그인 통째라 건드리지 않는다 · "
      "지운 뒤 에디터를 한 번 열어 깨진 의존(빨간 경고)이 없는지 보고 검사 13개를 돌린다.")
    w("")
    for k in "가나다라마":
        폴더수 = defaultdict(int)
        for r in 분류[k]:
            폴더수[r.rsplit("/", 1)[0]] += 1
        w(f"<details><summary>{k}. {설명[k].split(' — ')[0]} — 폴더별 (위 25)</summary>")
        w("")
        w("| 폴더 | 개수 |")
        w("|---|---:|")
        for 폴더, n in sorted(폴더수.items(), key=lambda x: -x[1])[:25]:
            w(f"| `{짧게(폴더)}/` | {n} |")
        w("")
        w("</details>")
        w("")

    안전_쓰기(결과_경로, "\n".join(줄) + "\n")
    목록 = ["# F5 로 안 닿는 게임 파일 — tools/연결지도.py 가 만든다(손으로 고치지 말 것)",
            "# 칸: 가=아무데도 안 나옴 · 나=문서에만 · 다=옛 파일끼리만 · 라=시험·도구가 불러 씀 · 마=도구 글에 이름만", ""]
    for k in "가나다라마":
        목록.append(f"## {k}. {설명[k]}  ({len(분류[k])}개)")
        목록 += [f"{k}\t{종류(r)}\t{짧게(r)}" for r in sorted(분류[k])]
        목록.append("")
    안전_쓰기(목록_경로, "\n".join(목록) + "\n")


def 안전_쓰기(경로, 글):
    # 앱의 파일 창이 결과 문서를 열어 두면 Windows 가 open(…, "w") 에 Errno 22 를 낸다(10-13 두 번 겪음).
    # 옆에 임시 파일로 쓰고 바꿔 끼우며, 잠깐 잠긴 경우를 위해 몇 번 다시 해 본다.
    import time
    임시 = 경로 + ".tmp"
    with open(임시, "w", encoding="utf-8", newline="\n") as f:
        f.write(글)
    for _ in range(10):
        try:
            os.replace(임시, 경로)
            return
        except OSError:
            time.sleep(0.3)
    raise OSError(f"{경로} 를 바꿔 쓸 수 없다(다른 프로그램이 열고 있나?) — 새 내용은 {임시} 에 있다")


def 안닿는_분류(파일들, 쓰는것, 닿음):
    """F5 로 안 닿는 게임 파일(addons·docs·tools 밖)을 가/나/다/라 로 나눈다."""
    # 맨 위 폴더 파일(export_presets.cfg · icon.svg …)과 점 폴더(.codex 등 AI 도구 설정)는
    # 게임 리소스가 아니라 프로젝트 설정이다 → 지울 후보에서 뺀다(검토 때 "가" 로 잘못 나왔다)
    대상 = sorted(r for r in 파일들 if r not in 닿음 and 종류(r) != "기타"
                  and "/" in r[len("res://"):] and not r[len("res://"):].startswith(".")
                  and not r.startswith(("res://addons/", "res://docs/", "res://tools/")))

    # 라: CLAUDE.md 규칙 3 의 "검사" 가 연결로 닿는 것 — 지우면 검사가 깨진다
    # 마: 그 밖의 도구(촬영·진단·빌더·시험_*)가 닿거나 이름을 적은 것 — 도구와 같이 정리할 것
    # check_스마트월드.gd 처럼 "폴더 안 스크립트를 전부 컴파일해 본다" 는 검사는 폴더를 통째로 훑지만,
    # 파일 하나를 지운다고 깨지지 않는다 → 도구 자신이 건 "폴더 전체" 연결은 여기서 뺀다.
    도구용 = {k: ({t: w for t, w in v.items() if w != "폴더 전체"} if k.startswith("res://tools/") else v)
              for k, v in 쓰는것.items()}
    검사_닿음, 도구_닿음 = set(), set()
    for r in 파일들:
        if r.startswith("res://tools/") and r.endswith(".gd"):
            닿 = set(따라가기(도구용, r))
            (검사_닿음 if r.rsplit("/", 1)[1][:-3] in 검사_목록 else 도구_닿음).update(닿)
    # 이름 검색용 글 덩어리 — 파이썬 도구는 res:// 없이 상대 경로·이름으로 적으니 이름으로 찾는다
    def 덩어리(폴더들, 확장자들, 깊이_밖=False):
        조각 = []
        for 폴더 in 폴더들:
            for 위, 하위, 이름들 in os.walk(os.path.join(루트, 폴더)):
                하위[:] = [d for d in 하위 if d not in (".godot", ".git", "_진단")]
                for n in 이름들:
                    # 이 도구가 만든 결과(연결지도_*)는 모든 이름을 담고 있다 — 넣으면 전부 "문서에 나옴" 이 된다
                    if n.startswith("연결지도") or n == "연결지도.py":
                        continue
                    if os.path.splitext(n)[1].lower() in 확장자들:
                        try:
                            with open(os.path.join(위, n), encoding="utf-8", errors="ignore") as f:
                                조각.append(f.read())
                        except OSError:
                            pass
        return "\n".join(조각)
    도구글 = 덩어리(["tools"], {".gd", ".py", ".json", ".cfg", ".txt", ".tscn", ".cmd", ".ps1", ".mjs", ".js", ".sh"})
    문서글 = 덩어리(["docs", "scenes", "assets", "scripts"], {".md", ".txt"})
    for n in ("CLAUDE.md", "AGENTS.md"):
        문서글 += "\n" + 읽기("res://" + n)

    # 다: 안 닿는 게임 파일이 부르는 것
    옛것이_부름 = set()
    for r in 대상:
        옛것이_부름 |= set(쓰는것.get(r, {}))

    # 라 = 시험 씬·도구 코드가 실제로 불러 씀(그래프) / 마 = 도구 글에 이름만 나옴.
    # 마 는 대개 "이 그림을 굽는 파이썬 도구" 라서, 게임이 안 쓰면 지워도 도구로 다시 만들 수 있다.
    분류 = {k: [] for k in "가나다라마"}
    for r in 대상:
        이름 = r.rsplit("/", 1)[1]
        if r in 검사_닿음:
            분류["라"].append(r)
        # 파이썬 도구는 "scenes/쳅터1/도안/<이름>.png" 처럼 폴더만 적고 파일을 만들어 낸다(만들기.py 도면 PNG)
        # → 파일이 사는 폴더 경로가 도구 글에 있으면 "도구가 만들거나 읽는 파일" 로 본다
        elif r in 도구_닿음 or 이름 in 도구글 or (짧게(r).rsplit("/", 1)[0] + "/") in 도구글:
            분류["마"].append(r)
        elif r in 옛것이_부름:
            분류["다"].append(r)
        elif 이름 in 문서글:
            분류["나"].append(r)
        else:
            분류["가"].append(r)
    return 분류


def 한_파일_보기(쓰는것, 파일들, 닿음, 출발, 찾는말):
    후보 = sorted(r for r in 파일들 if 찾는말 in r)
    if not 후보:
        print(f"'{찾는말}' 이 들어간 파일이 없다")
        return
    if len(후보) > 1:
        정확 = [r for r in 후보 if r.rsplit("/", 1)[-1] == 찾는말]
        if len(정확) == 1:
            후보 = 정확
        else:
            print("여러 개 찾았다 — 더 길게 적어 달라:")
            for r in 후보[:30]:
                print("  ", 짧게(r))
            return
    r = 후보[0]
    쓰이는곳 = sorted(a for a, 대상들 in 쓰는것.items() if r in 대상들)
    print(f"■ {짧게(r)}   ({종류(r)})")
    print()
    print("▶ 이 파일이 쓰는 것")
    for 대상, 방식 in sorted(쓰는것.get(r, {}).items()):
        print(f"   [{종류(대상)}] {짧게(대상)}" + ("" if 방식 == "경로" else f"   ({방식})"))
    if not 쓰는것.get(r):
        print("   —")
    print()
    print("◀ 이 파일을 쓰는 곳")
    for a in 쓰이는곳:
        print(f"   [{종류(a)}] {짧게(a)}")
    if not 쓰이는곳:
        print("   — (아무도 안 쓴다)")
    print()
    if r in 닿음:
        길 = []
        x = r
        while x:
            길.append(짧게(x))
            x = 닿음[x]
        print("F5 에서 가는 길:  " + "  →  ".join(reversed(길)))
    else:
        print("F5 에서 닿지 않는다")


def main():
    파일들, uid표 = 훑기()
    쓰는것 = 연결_찾기(파일들, uid표)
    출발 = 시작점()
    # project.godot 자체를 뿌리로: 시작 씬 + 아이콘 + 플러그인
    쓰는것["res://project.godot"] = {**쓰는것.get("res://project.godot", {})}
    if 출발:
        쓰는것["res://project.godot"][출발] = "main_scene"
    # 엔진이 이름으로 정해 두고 읽는 파일 — project.godot 에 안 적혀 있어도 쓰인다(오디오 버스 배치)
    if "res://default_bus_layout.tres" in 파일들:
        쓰는것["res://project.godot"]["res://default_bus_layout.tres"] = "엔진 기본"
    닿음 = 따라가기(쓰는것, "res://project.godot")
    if len(sys.argv) > 1:
        한_파일_보기(쓰는것, 파일들, 닿음, 출발, sys.argv[1])
        return
    문서_쓰기(파일들, 쓰는것, 출발, 닿음)
    print(f"F5 에서 닿는 파일 {len(닿음) - 1} 개 / 전체 {len(파일들)} 개")
    print(f"→ {os.path.relpath(결과_경로, 루트)}")


if __name__ == "__main__":
    main()
