# -*- coding: utf-8 -*-
"""
전후비교 — 코드 정리(리팩터링) 전후로 게임이 **완전히 같게** 도는지 한 명령으로 확인한다. (2026-10-14 · Claude)

왜 만들었나
  도형님: "원래 의도로 구현한 기능은 그대로 두고, 디자인이 변하거나 되던 것이 안 되면 안 된다."
  → 코드를 고치기 전에 지금 상태를 "기준" 으로 찍어 두고, 고칠 때마다 같은 검사를 돌려 기준과 다른 점만 보여 준다.
  10-13 파일 정리 때 손으로 한 검사(작업기록_2026-10-13_Claude_안쓰는파일_정리.md §4)를 도구로 굳힌 것이다.

무엇을 비교하나 (단계 이름 = --단계 에 쓰는 이름)
  연결  tools/연결지도.py 로 F5 에서 닿는 파일 목록 — 줄거나 늘면 알린다
  로드  모든 씬·리소스·스크립트·셰이더 load() + 컴파일 (전수로드.gd · 헤드리스)
  화면  F5 에서 닿는 씬을 하나씩 띄워 90 프레임 뒤 화면을 찍고 오류를 모은다 (화면촬영.gd · 창이 뜬다)
        → 픽셀 비교 · 다른 곳은 빨갛게 칠한 차이 그림을 남긴다
  검사  CLAUDE.md 규칙 3 의 검사 + 시험_* (FAIL 줄 내용이 기준과 같은가)
  경로  쳅터1 진짜 입력 재생(tools/쳅터1/검사.py → 시험_경로재생.gd) 의 합계 줄

쓰는 법
  python -X utf8 tools/전후비교/전후비교.py 기준             # 지금 상태를 기준으로 저장 (고치기 전에 한 번)
  python -X utf8 tools/전후비교/전후비교.py 비교             # 다시 돌려 기준과 비교 → 보고서
  python -X utf8 tools/전후비교/전후비교.py 비교 --빠르게     # 느린 것(경로 재생 · 부서지는발판 시험) 빼고
  python -X utf8 tools/전후비교/전후비교.py 비교 --단계=로드,화면
  python -X utf8 tools/전후비교/전후비교.py 비교만           # 이미 찍어 둔 "지금" 을 기준과 다시 비교만
  결과: tools/_진단/전후비교/{기준,지금}/ · 보고서 tools/_진단/전후비교/보고서.md (git 밖 · .gdignore)

판정
  "다름 없음" 이어야 통과(종료 코드 0). 다르면 1.
  ⚠ 엔진 종료 때 나는 누수 경고(resources still in use at exit 등)는 엔진 캐시 상태에 따라 오락가락해서 비교에서 뺀다
    (10-13 에 파일을 되돌린 상태로 다시 돌려 확인함).
  ⚠ 화면은 픽셀 차이가 `화면_허용`(기본 0 픽셀 — 기준 두 번 찍어 흔들림을 재 보고 정한다) 넘으면 "다름".
"""
import json
import os
import re
import shutil
import subprocess
import sys
import time

저장소 = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
엔진 = r"C:\Users\Public\godot46\Godot_v4.6.3-stable_win64_console.exe"   # 한글 경로에선 콘솔 exe 가 본체를 못 찾는다(CLAUDE.md)
결과_뿌리 = os.path.join(저장소, "tools", "_진단", "전후비교")
단계_전부 = ["연결", "로드", "화면", "검사", "경로", "프레임"]

# 규칙 3 검사 중 지금 tools/ 에 있는 것 + 최근 기능 시험. 시간 제한(초)은 원래부터 멈추는 것 때문에 둔다.
검사_목록 = [
    ("check_스마트월드", 300), ("test_SS2D_중복연결", 300), ("test_lobby_flow", 60), ("test_paint_system", 300),
    ("test_사망판정", 300), ("test_지형규칙", 300), ("test_차오르는물", 300), ("test_챕터전환", 600),
    ("test_페인트v4", 300), ("시험_열쇠", 600), ("시험_거미방", 600), ("시험_누름계단", 600), ("시험_연결전환", 600),
    ("시험_부서지는발판", 300),
]
느린_검사 = {"시험_부서지는발판"}
화면_허용 = 0          # 픽셀 수 — 흔들림 마스크가 없는 화면은 1 픽셀이라도 다르면 "다름"
화면_흔들림_허용 = 300  # 마스크가 있는(물이 출렁이는) 화면은 이만큼까지 "참고" 로만 적는다
                       # — 10-14 무변경 비교 두 번째에 물 가장자리 60·86 픽셀이 남았다
화면_색차 = 8          # 0~255 · 이보다 작은 차이는 압축·반올림 흔들림으로 본다
흔들림_표본 = 1        # 기준을 찍을 때 화면을 몇 번 더 찍어 흔들리는 픽셀을 모으나
마스크_넓힘 = 24       # 흔들림 마스크를 몇 픽셀 넓히나 — 실제 시계로 출렁이는 물은 찍을 때마다 다른 픽셀이 흔들려서 영역째 뺀다

# 엔진 종료 때 상태에 따라 나왔다 안 나왔다 하는 줄 — 비교에서 뺀다
종료_잡음 = ("still in use at exit", "ObjectDB instances leaked", "Pages in use exist at exit",
           "Unreferenced static string", "Unicode parsing error")


def 엔진_돌리기(인자, 로그, 제한):
    with open(로그, "w", encoding="utf-8", errors="replace") as f:
        try:
            p = subprocess.run([엔진, "--path", 저장소] + 인자, stdout=f, stderr=subprocess.STDOUT,
                               timeout=제한, cwd=저장소)
            return p.returncode
        except subprocess.TimeoutExpired:
            f.write("\n[전후비교] 시간 초과\n")
            return 124


def 오류줄(로그):
    """로그에서 오류·경고 줄만 뽑아 숫자·주소를 지운다(같은 오류가 숫자만 달라도 같게 본다)."""
    줄들 = set()
    if not os.path.exists(로그):
        return 줄들
    씬 = ""
    for 줄 in open(로그, encoding="utf-8", errors="replace"):
        if 줄.startswith("=== 씬 "):
            씬 = 줄.strip()[6:]
            continue
        if ("ERROR" in 줄 or "WARNING" in 줄 or "FAIL" in 줄) and not any(z in 줄 for z in 종료_잡음):
            정리 = re.sub(r"0x[0-9a-fA-F]+|\d+(\.\d+)?", "N", 줄.strip())
            줄들.add((씬 + " | " if 씬 else "") + 정리)
    return 줄들


# ── 단계별 실행 ───────────────────────────────────────────────────────
def 연결_단계(폴더):
    sys.path.insert(0, os.path.join(저장소, "tools"))
    import importlib.util
    spec = importlib.util.spec_from_file_location("연결지도", os.path.join(저장소, "tools", "연결지도.py"))
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    파일들, uid표 = m.훑기()
    쓰는것 = m.연결_찾기(파일들, uid표)
    출발 = m.시작점()
    # 연결지도.py main() 과 똑같이 — project.godot 자신이 적은 연결(아이콘·플러그인)에 시작 씬을 더한다
    쓰는것["res://project.godot"] = {**쓰는것.get("res://project.godot", {}), 출발: "main_scene"}
    if "res://default_bus_layout.tres" in 파일들:
        쓰는것["res://project.godot"]["res://default_bus_layout.tres"] = "엔진 기본"
    닿음 = sorted(r for r in m.따라가기(쓰는것, "res://project.godot") if r != "res://project.godot")
    with open(os.path.join(폴더, "닿음.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(닿음) + "\n")
    씬 = [r for r in 닿음 if r.endswith(".tscn") and not r.startswith("res://addons/")]
    with open(os.path.join(폴더, "씬목록.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(씬) + "\n")
    print(f"  연결: F5 에서 닿는 파일 {len(닿음)} · 씬 {len(씬)}")


def 로드_단계(폴더):
    # 엔진이 도중에 죽으면 json 이 안 생긴다 — 옛 json 이 남아 "같음" 으로 보이지 않게 먼저 지운다
    if os.path.exists(os.path.join(폴더, "로드.json")):
        os.remove(os.path.join(폴더, "로드.json"))
    code = 엔진_돌리기(["--headless", "-s", "res://tools/전후비교/전수로드.gd", "--",
                      "--out=" + os.path.join(폴더, "로드.json")], os.path.join(폴더, "로드.log"), 1200)
    print(f"  로드: 끝 (종료 {code})")


def 화면_단계(폴더, 그림폴더=None):
    씬목록 = os.path.join(폴더, "씬목록.txt")
    if not os.path.exists(씬목록):
        연결_단계(폴더)
    그림폴더 = 그림폴더 or os.path.join(폴더, "화면")
    shutil.rmtree(그림폴더, ignore_errors=True)
    # 얼굴 방향·총 조준이 실제 커서를 읽어서 촬영 중에는 커서를 창 안 한 점에 묶는다(화면촬영.gd 머리말)
    print("  화면: 촬영 중(약 4 분)에는 마우스가 게임 창 안에 묶입니다 — 끝나면 풀립니다")
    code = 엔진_돌리기(["--fixed-fps", "60", "--resolution", "1920x1080", "--audio-driver", "Dummy",
                      "--rendering-method", "gl_compatibility",
                      "-s", "res://tools/전후비교/화면촬영.gd", "--",
                      "--list=" + 씬목록, "--out=" + 그림폴더], 그림폴더 + ".log", 1800)
    print(f"  화면: 끝 (종료 {code})")


def 흔들림_마스크(폴더, 횟수=흔들림_표본):
    """기준 화면을 몇 번 더 찍어 '코드를 안 고쳐도 매번 달라지는 픽셀' 을 모은다.
    물줄기·자연발판·양동이 출렁임은 실제 시계(Time.get_ticks_msec)로 움직여서 프레임을 고정해도 매번 다르다
    (흰물_디자인.gd · 하수도_자연발판.gd 등 — 게임 원래 동작이라 0 단계에서는 안 고친다).
    → 그 픽셀만 빼고(조금 넓혀서) 나머지는 1 픽셀이라도 다르면 잡는다."""
    from PIL import Image, ImageChops, ImageFilter
    마스크폴더 = os.path.join(폴더, "화면_마스크")
    shutil.rmtree(마스크폴더, ignore_errors=True)
    os.makedirs(마스크폴더)
    기준그림 = os.path.join(폴더, "화면")
    for k in range(1, 횟수 + 1):
        표본 = os.path.join(폴더, f"_표본{k}")
        print(f"  흔들림 표본 {k}/{횟수}")
        화면_단계(폴더, 표본)
        for n in os.listdir(기준그림):
            if not n.endswith(".png") or not os.path.exists(os.path.join(표본, n)):
                continue
            A = Image.open(os.path.join(기준그림, n)).convert("RGB")
            B = Image.open(os.path.join(표본, n)).convert("RGB")
            if A.size != B.size:
                continue
            차 = ImageChops.difference(A, B).convert("L").point(lambda v: 255 if v > 화면_색차 else 0)
            if 차.getbbox() is None:
                continue
            mp = os.path.join(마스크폴더, n)
            if os.path.exists(mp):
                차 = ImageChops.lighter(차, Image.open(mp).convert("L"))
            차.save(mp)
    # 표본 사이에 안 잡힌 이웃 픽셀도 흔들릴 수 있다 → 마스크를 조금 넓힌다
    # (큰 MaxFilter 한 번은 PIL 에서 아주 느리다 → 9 칸짜리를 여러 번 = 4 픽셀씩 넓힘)
    표 = []
    for n in sorted(os.listdir(마스크폴더)):
        mp = os.path.join(마스크폴더, n)
        m = Image.open(mp).convert("L")
        for _ in range((마스크_넓힘 + 3) // 4):
            m = m.filter(ImageFilter.MaxFilter(9))
        m.save(mp)
        덮음 = sum(m.histogram()[1:]) / (m.size[0] * m.size[1]) * 100   # 0 이 아닌 픽셀 수(getdata 는 Pillow 14 에서 없어진다)
        표.append(f"{n}: 화면의 {덮음:.1f}% 를 흔들림으로 뺌")
    # 표본 그림은 마스크를 만든 뒤에는 필요 없다 — 격자 촬영 때문에 한 벌이 100MB 를 넘는다
    for k in range(1, 횟수 + 1):
        shutil.rmtree(os.path.join(폴더, f"_표본{k}"), ignore_errors=True)
    with open(os.path.join(폴더, "화면_마스크.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(표) + "\n")
    print(f"  흔들림 마스크: {len(표)} 장")
    for x in 표:
        print("    " + x)


def 검사_단계(폴더, 빠르게):
    for n in os.listdir(폴더):
        if n.startswith("검사_") or n == "검사.json":
            os.remove(os.path.join(폴더, n))
    요약 = {}
    for 이름, 제한 in 검사_목록:
        if 빠르게 and 이름 in 느린_검사:
            continue
        if not os.path.exists(os.path.join(저장소, "tools", 이름 + ".gd")):
            continue
        로그 = os.path.join(폴더, "검사_" + 이름 + ".log")
        code = 엔진_돌리기(["--headless", "-s", f"res://tools/{이름}.gd"], 로그, 제한)
        요약[이름] = code
        print(f"  검사: {이름} (종료 {code})")
    with open(os.path.join(폴더, "검사.json"), "w", encoding="utf-8") as f:
        json.dump(요약, f, ensure_ascii=False, indent=1)


def 프레임_단계(폴더):
    """[2026-10-15] 쳅터1·하수도 스테이지 전부를 측정_하수도_프레임.gd 로 잰다(창 모드 · 실제 게임처럼 VSync 끔 · 플레이어 멈춤).
    기준과 비교하지 않고 문턱으로 본다 — 60 FPS 아래(16.7 ms 초과) 프레임이 생기면 보고서에 적는다.
    호퍼 입구가 화면 밖에서도 매 프레임 다시 그려 2-3 p99 가 16 ms 에 붙어 있던 것(작업기록 2026-10-15)을 다시 놓치지 않으려고."""
    씬목록 = os.path.join(폴더, "씬목록.txt")
    if not os.path.exists(씬목록):
        연결_단계(폴더)
    스테이지 = [l.strip() for l in open(씬목록, encoding="utf-8")
              if "/scenes/쳅터1/스테이지/" in l or "/scenes/world_2_클로드/stage_" in l]
    code = 엔진_돌리기(["--resolution", "1920x1080", "--audio-driver", "Dummy", "--rendering-method", "gl_compatibility",
                      "-s", "res://tools/측정_하수도_프레임.gd", "--"] + 스테이지 + ["--칸=120"],
                     os.path.join(폴더, "프레임.log"), 3000)
    줄 = 프레임_읽기(os.path.join(폴더, "프레임.log"))
    print(f"  프레임: 스테이지 {len(줄)} · 16.7ms 초과 {sum(r['넘음'] for r in 줄.values())} / {sum(r['n'] for r in 줄.values())} (종료 {code})")


def 프레임_읽기(로그):
    결과 = {}
    if not os.path.exists(로그):
        return 결과
    for l in open(로그, encoding="utf-8", errors="replace"):
        m = re.match(r"^(\S+)\s+로드.*중앙\s+([\d.]+)\s+p95\s+([\d.]+)\s+p99\s+([\d.]+)\s+최대\s+([\d.]+) ms\s+16.7초과 (\d+)/(\d+)\s+18초과 (\d+)", l)
        if m:
            결과[m.group(1)] = {"p99": float(m.group(4)), "최대": float(m.group(5)), "넘음": int(m.group(6)),
                               "n": int(m.group(7)), "놓침": int(m.group(8))}
    return 결과


# [2026-10-15] 스테이지마다 따로 본다 — 전체 비율로 보면 한 스테이지의 23/960 이 다른 스테이지 수천 프레임에 묻혔다.
#   한 스테이지에서 18 ms 넘은 프레임이 이 수 이하면 PC 상태 흔들림으로 보고 "참고" 로만 적는다(그보다 많으면 실패).
프레임_참고_허용 = 1


def 경로_단계(폴더):
    # 시험_경로재생 은 tools/쳅터1/검사.py 가 남긴 경로(tools/_진단/경로)를 읽는다 — 먼저 만든다
    subprocess.run([sys.executable, "-X", "utf8", os.path.join(저장소, "tools", "쳅터1", "검사.py")],
                   cwd=저장소, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    로그 = os.path.join(폴더, "경로재생.log")
    엔진_돌리기(["--headless", "-s", "res://tools/시험_경로재생.gd"], 로그, 1800)
    합계 = [l.strip() for l in open(로그, encoding="utf-8", errors="replace") if "합계" in l]
    print("  경로: " + (합계[-1] if 합계 else "합계 줄 없음"))


# ── 비교 ──────────────────────────────────────────────────────────────
def 비교(기준, 지금, 단계=단계_전부):
    다름 = []
    줄 = ["# 전후비교 보고서", "", f"- 기준: `{기준}`", f"- 지금: `{지금}`", f"- 시각: {time.strftime('%Y-%m-%d %H:%M')}", ""]

    def 칸(제목, 항목들, 최대=40):
        줄.append(f"## {제목}")
        줄.append("")
        if not 항목들:
            줄.append("같음 ✔")
        else:
            다름.append(제목)
            for x in sorted(항목들)[:최대]:
                줄.append(f"- {x}")
            if len(항목들) > 최대:
                줄.append(f"- … 외 {len(항목들) - 최대}")
        줄.append("")

    def 읽기(폴더, 이름):
        p = os.path.join(폴더, 이름)
        return open(p, encoding="utf-8").read().split() if os.path.exists(p) else None

    a, b = 읽기(기준, "닿음.txt"), 읽기(지금, "닿음.txt")
    if "연결" in 단계 and a is not None and b is not None:
        칸("연결 — F5 에서 닿는 파일", [f"빠짐 {x}" for x in set(a) - set(b)] + [f"새로 닿음 {x}" for x in set(b) - set(a)])

    pa, pb = os.path.join(기준, "로드.json"), os.path.join(지금, "로드.json")
    if "로드" in 단계 and os.path.exists(pa):
        if not os.path.exists(pb):
            칸("로드 — 실행 실패", ["로드.json 이 안 생겼다 — 엔진이 도중에 죽었나? 지금/로드.log 끝을 볼 것"])
    if "로드" in 단계 and os.path.exists(pa) and os.path.exists(pb):
        ja, jb = json.load(open(pa, encoding="utf-8")), json.load(open(pb, encoding="utf-8"))
        칸("로드 — 전에 되던 것이 안 됨", [f"{k}" for k in jb if ja.get(k) and not jb[k]]
           + [f"없어짐 {k}" for k in ja if k not in jb])
        칸("로드 — 오류 줄", [f"새 오류 {x}" for x in 오류줄(os.path.join(지금, "로드.log")) - 오류줄(os.path.join(기준, "로드.log"))])

    if "화면" in 단계 and os.path.exists(os.path.join(지금, "화면.log")):
        칸("화면 — 씬 실행 중 오류 줄", [f"새 오류 {x}" for x in 오류줄(os.path.join(지금, "화면.log")) - 오류줄(os.path.join(기준, "화면.log"))])
        실패, 참고 = 화면_비교(기준, 지금)
        칸("화면 — 픽셀", 실패)
        if 참고:
            줄.append("### 참고 — 물이 출렁이는 화면의 작은 차이(실패로 안 셈)")
            줄.append("")
            줄.extend(f"- {x}" for x in 참고)
            줄.append("")

    ja_p, jb_p = os.path.join(기준, "검사.json"), os.path.join(지금, "검사.json")
    if "검사" in 단계 and os.path.exists(jb_p):
        jb = json.load(open(jb_p, encoding="utf-8"))
        항목 = []
        for 이름 in jb:
            la, lb = os.path.join(기준, "검사_" + 이름 + ".log"), os.path.join(지금, "검사_" + 이름 + ".log")
            if not os.path.exists(la):
                항목.append(f"{이름}: 기준에 없음")
                continue
            새, 없어진 = 오류줄(lb) - 오류줄(la), 오류줄(la) - 오류줄(lb)
            for x in sorted(새):
                항목.append(f"{이름}: 새 {x}")
            for x in sorted(없어진):
                항목.append(f"{이름}: 없어짐(좋아졌을 수 있음) {x}")
        칸("검사 — FAIL·오류 줄", 항목)

    la, lb = os.path.join(기준, "경로재생.log"), os.path.join(지금, "경로재생.log")
    if "경로" in 단계 and os.path.exists(lb) and os.path.exists(la):
        합 = lambda p: [l.strip() for l in open(p, encoding="utf-8", errors="replace") if "합계" in l][-1:]
        칸("경로 재생 합계", [] if 합(la) == 합(lb) else [f"기준 {합(la)} → 지금 {합(lb)}"])

    pf = os.path.join(지금, "프레임.log")
    if "프레임" in 단계 and os.path.exists(pf):
        r = 프레임_읽기(pf)
        총 = sum(x["n"] for x in r.values()) or 1
        줄글 = lambda k, x: f"{k}: 16.7ms 초과 {x['넘음']}/{x['n']} · 18ms 초과 {x['놓침']} · p99 {x['p99']} · 최대 {x['최대']}"
        떨어짐 = [줄글(k, x) for k, x in sorted(r.items()) if x["놓침"] > 프레임_참고_허용]
        드묾 = [줄글(k, x) for k, x in sorted(r.items()) if x["넘음"] > 0 and x["놓침"] <= 프레임_참고_허용]
        if not r:
            칸("프레임 — 60 FPS", ["측정 결과가 없다 — 지금/프레임.log 를 볼 것"])
        else:
            칸("프레임 — 60 FPS 아래로 떨어짐" if 떨어짐 else "프레임 — 60 FPS", 떨어짐)
            줄.append(f"스테이지 {len(r)} · 프레임 {총} · 16.7ms 초과 {sum(x['넘음'] for x in r.values())} · p99 최고 {max(x['p99'] for x in r.values())} ms")
            줄.append("")
            if 드묾:
                줄.append(f"### 참고 — 드물게 넘은 프레임(스테이지마다 18ms 초과 {프레임_참고_허용} 개 이하 · PC 상태 흔들림일 수 있음)")
                줄.append("")
                줄.extend(f"- {x}" for x in 드묾)
                줄.append("")

    줄.insert(5, "**결과: " + ("다름 없음 ✔" if not 다름 else "다름 — " + " · ".join(다름)) + "**")
    with open(os.path.join(결과_뿌리, "보고서.md"), "w", encoding="utf-8") as f:
        f.write("\n".join(줄) + "\n")
    print("\n".join(줄[5:6]))
    print(f"→ {os.path.relpath(os.path.join(결과_뿌리, '보고서.md'), 저장소)}")
    return not 다름


def 화면_비교(기준, 지금):
    """돌려줌: (실패 항목, 참고 항목)"""
    from PIL import Image, ImageChops
    항목, 참고 = [], []
    ga, gb = os.path.join(기준, "화면"), os.path.join(지금, "화면")
    차이폴더 = os.path.join(지금, "화면_차이")
    shutil.rmtree(차이폴더, ignore_errors=True)
    ra = json.load(open(os.path.join(ga, "결과.json"), encoding="utf-8")) if os.path.exists(os.path.join(ga, "결과.json")) else {}
    rb = json.load(open(os.path.join(gb, "결과.json"), encoding="utf-8")) if os.path.exists(os.path.join(gb, "결과.json")) else {}
    for k in sorted(set(ra) | set(rb)):
        if ra.get(k) != rb.get(k):
            항목.append(f"{k}: 실행 결과 {ra.get(k)} → {rb.get(k)}")
    for n in sorted(os.listdir(ga)) if os.path.isdir(ga) else []:
        if not n.endswith(".png"):
            continue
        pb = os.path.join(gb, n)
        if not os.path.exists(pb):
            항목.append(f"{n}: 지금 그림 없음")
            continue
        A, B = Image.open(os.path.join(ga, n)).convert("RGB"), Image.open(pb).convert("RGB")
        if A.size != B.size:
            항목.append(f"{n}: 크기 다름 {A.size} → {B.size}")
            continue
        차 = ImageChops.difference(A, B).convert("L").point(lambda v: 255 if v > 화면_색차 else 0)
        mp = os.path.join(기준, "화면_마스크", n)
        흔들림 = os.path.exists(mp)
        if 흔들림:
            # 기준을 여러 번 찍을 때도 흔들리던 픽셀은 뺀다
            차 = ImageChops.subtract(차, Image.open(mp).convert("L"))
        수 = sum(차.histogram()[1:])          # 0 이 아닌 픽셀 수 — getdata 순회와 같은 값(Pillow 14 대비 · 더 빠름)
        if 수 > 화면_허용:
            os.makedirs(차이폴더, exist_ok=True)
            표시 = B.copy()
            표시.paste((255, 0, 0), mask=차)
            표시.save(os.path.join(차이폴더, n))
            글 = f"{n}: {수} 픽셀 다름 ({수 / (A.size[0] * A.size[1]) * 100:.3f}%) → 지금/화면_차이/{n}"
            (참고 if 흔들림 and 수 <= 화면_흔들림_허용 else 항목).append(글)
    return 항목, 참고


def main():
    인자 = sys.argv[1:]
    if not 인자 or 인자[0] not in ("기준", "비교", "비교만"):
        print(__doc__)
        return 2
    os.makedirs(결과_뿌리, exist_ok=True)
    # 이 폴더의 그림을 엔진이 가져오지(import) 않게 — 10-09 에 시험 캡처 231MB 를 에디터가 가져오던 일이 있었다
    open(os.path.join(결과_뿌리, ".gdignore"), "a").close()
    기준 = os.path.join(결과_뿌리, "기준")
    지금 = os.path.join(결과_뿌리, "지금")
    if 인자[0] == "비교만":
        return 0 if 비교(기준, 지금) else 1

    폴더 = 기준 if 인자[0] == "기준" else 지금
    단계 = 단계_전부
    for a in 인자[1:]:
        if a.startswith("--단계="):
            단계 = a.split("=", 1)[1].split(",")
    빠르게 = "--빠르게" in 인자
    if 빠르게 and "경로" in 단계:
        단계 = [s for s in 단계 if s != "경로"]
    # 전부 돌릴 때만 폴더를 통째로 비운다. 일부 단계만 돌릴 때는 그 단계가 자기 결과만 지우고 다시 쓰며,
    # 비교도 이번에 돌린 단계만 한다(안 돌린 단계의 옛 결과로 "같음" 이 나오지 않게).
    if 단계 == 단계_전부:
        shutil.rmtree(폴더, ignore_errors=True)
    os.makedirs(폴더, exist_ok=True)
    시작 = time.time()
    for s in 단계:
        print(f"[{s}]")
        {"연결": lambda: 연결_단계(폴더), "로드": lambda: 로드_단계(폴더), "화면": lambda: 화면_단계(폴더),
         "검사": lambda: 검사_단계(폴더, 빠르게), "경로": lambda: 경로_단계(폴더), "프레임": lambda: 프레임_단계(폴더)}[s]()
    if 인자[0] == "기준" and "화면" in 단계:
        print("[흔들림]")
        흔들림_마스크(폴더)
    print(f"걸린 시간 {int(time.time() - 시작)} 초")
    if 인자[0] == "비교":
        return 0 if 비교(기준, 지금, 단계) else 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
