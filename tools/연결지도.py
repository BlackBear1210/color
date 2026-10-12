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
                        → 그 폴더 파일 중 스크립트 글에 이름이 나오는 것만 잇는다(동적)
  4. .gdshader      : #include "res://..."
  5. .json/.cfg     : 표 안의 "res://..."
  uid:// 는 .uid · .import · 씬 머리줄에서 진짜 경로로 바꾼다.

한계
  - 실행 중에 글자를 조립해서 만드는 경로("stage_" + str(n))는 이름이 글에 안 나오면 못 잡는다.
  - 주석 줄(# 로 시작)은 일부러 뺀다 — 옛 경로가 주석에 남아 있는 경우가 많아서.

쓰는 법
  python -X utf8 tools/연결지도.py              → docs/연결지도_F5.md 를 새로 쓴다(멱등)
  python -X utf8 tools/연결지도.py 월드.gd       → 그 파일이 쓰는 것 / 그 파일을 쓰는 곳 / F5 에서 가는 길
"""
import os
import re
import sys
from collections import defaultdict, deque

루트 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
결과_경로 = os.path.join(루트, "docs", "연결지도_F5.md")

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
                    for 후보 in 폴더_안.get(p, []):
                        이름 = os.path.splitext(후보.rsplit("/", 1)[1])[0]
                        if len(이름) >= 2 and 이름 in 글:
                            잇기(후보, "폴더+이름")
                    continue
                if "%" in p:
                    접두 = p.split("%")[0]
                    for 후보 in 파일들:
                        if 후보.startswith(접두) and 후보.endswith(p.rsplit("%s", 1)[-1]):
                            잇기(후보, "폴더+이름")
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

    # 4-6 안 닿는 파일 폴더별
    w("## 6. F5 로 안 닿는 파일 — 폴더별 개수")
    w("")
    w("지워도 된다는 뜻이 **아니다**. 도구가 쓰는 파일, 에디터에서만 여는 시험 씬, 동적으로 불리는 파일이 섞여 있다.")
    w("")
    폴더수 = defaultdict(int)
    for r in 파일들:
        if r in 닿음 or 종류(r) == "기타" or r.startswith(("res://docs/", "res://addons/", "res://tools/")):
            continue
        폴더수[r.rsplit("/", 1)[0]] += 1
    w("| 폴더 | 개수 |")
    w("|---|---:|")
    for 폴더, n in sorted(폴더수.items(), key=lambda x: -x[1])[:60]:
        w(f"| `{짧게(폴더)}/` | {n} |")
    w("")

    with open(결과_경로, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(줄) + "\n")


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
    닿음 = 따라가기(쓰는것, "res://project.godot")
    if len(sys.argv) > 1:
        한_파일_보기(쓰는것, 파일들, 닿음, 출발, sys.argv[1])
        return
    문서_쓰기(파일들, 쓰는것, 출발, 닿음)
    print(f"F5 에서 닿는 파일 {len(닿음) - 1} 개 / 전체 {len(파일들)} 개")
    print(f"→ {os.path.relpath(결과_경로, 루트)}")


if __name__ == "__main__":
    main()
