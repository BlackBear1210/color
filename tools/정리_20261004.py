# -*- coding: utf-8 -*-
"""
프로젝트 정리 — 2026-10-04 Claude 작성 · **도형님이 직접 실행**(자동 실행이 권한 검사에서 막혔다)

왜 필요한가
  GitHub Desktop 변경 255건 중 상당수가 (1) 폴더 이동(scenes/집 → scenes/쳅터1)에 끌려
  **다른 작업자 씬(하수도 world_2_클로드 등)의 경로가 바뀐 것**, (2) 에디터 재저장 잡음,
  (3) 미추적 산출물(artifacts 597MB · 이미지 1,092장 = 에디터가 전부 import)이다.
  그대로 푸시하면 다른 작업자가 올릴 하수도 씬과 충돌한다.

하는 일 (전부 되돌릴 수 있다 — 지우지 않고 저장소 밖 백업 폴더로 **옮긴다**)
  ① 잡음 되돌리기   다른 작업자 파일의 에디터 재저장·경로 변경을 마지막 커밋 상태로 (git restore)
                     → 되돌리기 전 diff 는 백업 폴더에 patch 로 남긴다
  ② 공용 키트 원위치 scenes/쳅터1/스마트월드_장애물 · 스마트 매쉬 assets → scenes/집/ (커밋된 원래 자리)
                     → 하수도 씬들이 이 경로를 쓴다. 쳅터1 쪽 참조는 경로만 고쳐 준다
  ③ 안 쓰는 파일 옮기기  docs 옛 작업기록·백업·스크린샷 · artifacts/reports/research_notes ·
                     옛 생성기 산출물(scenes/쳅터1/생성) · .bak 씬 · 초안_방5종 · __pycache__
     ★타일셋·장애물·지형 템플릿·옛 스테이지 씬·배경 그림은 **건드리지 않는다**(언젠가 쓸 수 있는 것)

사용 (저장소 폴더에서)
  python tools/정리_20261004.py                    # 미리보기만(아무것도 안 바뀜)
  python tools/정리_20261004.py --실행              # 실제로 정리
  python tools/정리_20261004.py --실행 --하수도기록_남김   # 다른 작업자 하수도 작업기록은 docs 에 남긴다
  python tools/정리_20261004.py --되돌리기           # ③에서 옮긴 파일을 전부 제자리로
백업: C:/Users/김도형/Documents/GRAY_백업/정리_20261004/  (목록.json 에 원래 경로)
"""
import json
import os
import re
import shutil
import subprocess
import sys

저장소 = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
백업 = os.path.join(os.path.expanduser("~"), "Documents", "GRAY_백업", "정리_20261004")
목록파일 = os.path.join(백업, "목록.json")

# ── ① 다른 작업자 파일(에디터 재저장·경로 잡음) ──
잡음 = [
    "scenes/world_2_클로드/",
    "scenes/world_2/",
    "scenes/world_1/",
    "scenes/테스트/",
    "assets/textures/smartshape/sewer_masonry_v02/",
]

# ── ② 공용 키트 ──
키트 = ["스마트월드_장애물", "스마트 매쉬 assets"]

# ── ③ docs 에 남길 것(살아 있는 규칙·가이드·기획·하수도 참고) ──
docs_남김 = {
    "게임_기획서_세계관_디자인_도형.md", "기획서_규칙_플로우차트.md", "색판정_규칙_2026-08-30.md",
    "경계_색구역_시스템.md", "경계_시스템_가이드.md", "플레이어_경계걸침_규칙.md", "점프_튜닝_시스템.md",
    "장애물_카탈로그.md", "장애물_아이디어_정리.md", "SmartShape2D_도입_가이드.md",
    "SS2D_고해상도_타일셋_마스터템플릿.md", "SS2D_배관_유체_맵제작_가이드_2026-09-01.md", "원본_소스_제작규칙.md",
    "카메라_공간전환_가이드.md", "레벨디자인_가이드.md", "로비_에셋_배경_기획_도형.md",
    "사용법_동굴맵생성기_v2_2026-09-21.md", "사용법_복도계단_생성기_2026-09-23.md", "사용법_스테이지_생성기_2026-09-20.md",
    # 하수도(다른 작업자) 참고 문서 — 작업기록이 아니라 지금도 쓰는 자료
    "맵분석_2026-09-07_Claude_하수도_2-1_2-7.md", "맵분석_2026-09-13_아스트라_world2_2-1부터2-7_개편방향.md",
    "맵분석_2026-09-22_Claude_2-9_2-11_플레이어관점.md", "하수도_쇠사슬_지지대_사용안내.md", "하수도_흑백벽돌_모듈_사용법.md",
    "스테이지1_플랫폼과배경_공통제작가이드_팀원전달.md", "레벨디자인_하수도챕터_2026-08-20.md",
    "스테이지2_하수도_제작계획_2026-08-22.md", "스테이지2_하수도_제작계획_2026-08-22.pdf",
    "설계도_하수도_2-10.svg", "설계도_하수도_2-10.svg.import", "설계도_하수도_2-11.png", "설계도_하수도_2-11.png.import",
    "설계도_하수도_2-1_2-3.html", "Claude_인수인계_2026-09-29_물디자인_ver2.md",
    "장치외관_일괄교체_2026-09-22.json", "호퍼유입_정렬_2026-09-22.json",          # 도구가 읽는다
    "아트기준_스테이지2_v01", "stage29_rework_layout.html", "stage29_rooms_layout.png",
    "stage29_rooms_layout.png.import", "stage29_rooms_manifest.json",
    # 2026-10-04 새 문서
    "작업기록_2026-10-04_Claude_쳅터1_재구성_전경전환_정리.md", "쳅터1_스테이지_제작규격.md",
    "프롬프트_아스트라_쳅터1_방배경레이어_v01_2026-10-04.md",
}
# 하수도 작업기록 판별(파일 이름 낱말) — --하수도기록_남김 일 때만 쓴다
하수도_낱말 = ["하수도", "2-", "2_9", "2_1", "stage2", "world2", "물", "호퍼", "벽등", "낙수", "웅덩이", "유체", "배관",
          "ver2", "주철", "격자", "압력", "지지", "쇠사슬", "FBWG", "레버", "양동이", "저장고", "버튼", "분사기", "등번짐",
          "맵문서", "마감", "맞물림", "선반", "공중", "테두리", "성진", "동현", "5단계", "6단계", "화면효과", "프레임드랍",
          "가시_톱", "장치", "아스트라_하수도", "흑백벽돌", "흑백무늬", "물너비", "오퍼스", "Opus", "필수퍼즐", "stage"]

옮길_폴더 = ["artifacts", "reports", "research_notes", "scenes/쳅터1/생성", "scenes/쳅터1/초안_방5종"]
옮길_파일 = ["scenes/쳅터1/스테이지_2_복도.bak.tscn", "scenes/쳅터1/스테이지_2_복도계단.bak.tscn"]


def git(*args, 출력=True):
    r = subprocess.run(["git", "-c", "core.quotepath=false", *args], cwd=저장소, capture_output=True, text=True, encoding="utf-8")
    if 출력 and r.returncode != 0:
        print("  git 오류:", r.stderr.strip())
    return r


def 옮길_것들(하수도남김):
    out = []
    for f in sorted(os.listdir(os.path.join(저장소, "docs"))):
        if f in docs_남김:
            continue
        if 하수도남김 and f.startswith("작업기록_") and any(k in f for k in 하수도_낱말):
            continue
        if 하수도남김 and f in ("visual_review", "performance", "맵검토_stage25_2026-09-21.png", "맵검토_stage25_2026-09-21.png.import",
                             "스크린샷_2-1_2-2_재제작_2026-09-14", "스크린샷_하수도_지지구조_2026-09-14",
                             "스크린샷_하수도_지지구조_정식아트_2026-09-14", "이슈_CORNER-SIDE-ROTATION-01.md"):
            continue
        out.append("docs/" + f)
    for p in 옮길_폴더 + 옮길_파일:
        if os.path.exists(os.path.join(저장소, p)):
            out.append(p)
    for root, dirs, _files in os.walk(os.path.join(저장소, "tools")):
        for d in dirs:
            if d == "__pycache__":
                out.append(os.path.relpath(os.path.join(root, d), 저장소).replace("\\", "/"))
    return out


def 크기(p):
    a = os.path.join(저장소, p)
    if os.path.isfile(a):
        return os.path.getsize(a)
    return sum(os.path.getsize(os.path.join(r, f)) for r, _d, fs in os.walk(a) for f in fs)


def 되돌리기():
    if not os.path.exists(목록파일):
        print("목록.json 이 없다 — 되돌릴 것이 없다")
        return 1
    목록 = json.load(open(목록파일, encoding="utf-8"))
    for p in 목록["옮김"]:
        src = os.path.join(백업, p)
        dst = os.path.join(저장소, p)
        if os.path.exists(src) and not os.path.exists(dst):
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.move(src, dst)
            print("  되돌림:", p)
    print("완료. ①잡음 되돌리기는 백업의 잡음_되돌리기전.patch 로 `git apply` 하면 원래대로.")
    return 0


def main():
    if "--되돌리기" in sys.argv:
        return 되돌리기()
    실행 = "--실행" in sys.argv
    하수도남김 = "--하수도기록_남김" in sys.argv
    print(("■ 실행" if 실행 else "■ 미리보기(아무것도 안 바뀜 — 실제로 하려면 --실행)") + f" · 백업: {백업}")

    # ① 잡음
    바뀐 = [l[3:].strip().strip('"') for l in git("status", "--porcelain", "--", *잡음).stdout.splitlines() if l.startswith(" M")]
    print(f"\n① 다른 작업자 파일 잡음 되돌리기: {len(바뀐)}개")
    for p in 바뀐:
        print("   ", p)
    # ② 키트
    print("\n② 공용 키트 원위치(scenes/쳅터1 → scenes/집):")
    for k in 키트:
        print(f"    {k}: {'옮김 필요' if os.path.isdir(os.path.join(저장소, 'scenes', '쳅터1', k)) else '이미 제자리'}")
    # ③ 옮기기
    목록 = 옮길_것들(하수도남김)
    합 = sum(크기(p) for p in 목록)
    print(f"\n③ 백업으로 옮길 것: {len(목록)}개 · {합 / 1048576:.0f} MB" + (" (하수도 작업기록은 남김)" if 하수도남김 else ""))
    for p in 목록:
        print("   ", p)

    if not 실행:
        print("\n미리보기 끝. 문제없으면: python tools/정리_20261004.py --실행")
        return 0

    os.makedirs(백업, exist_ok=True)
    # ①
    if 바뀐:
        patch = git("diff", "--", *잡음).stdout
        open(os.path.join(백업, "잡음_되돌리기전.patch"), "w", encoding="utf-8", newline="\n").write(patch)
        git("restore", "--", *잡음)
    # ②
    for k in 키트:
        src = os.path.join(저장소, "scenes", "쳅터1", k)
        dst = os.path.join(저장소, "scenes", "집", k)
        if os.path.isdir(src) and not os.path.exists(dst):
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.move(src, dst)
    고친 = 0
    for root, dirs, files in os.walk(저장소):
        if ".git" in root or ".godot" in root:
            continue
        for f in files:
            if not f.endswith((".tscn", ".tres", ".gd", ".py")) or f == "정리_20261004.py":
                continue
            p = os.path.join(root, f)
            try:
                t = open(p, encoding="utf-8").read()
            except (UnicodeDecodeError, OSError):
                continue
            t2 = t
            for k in 키트:
                t2 = t2.replace(f"res://scenes/쳅터1/{k}/", f"res://scenes/집/{k}/")
            if t2 != t:
                open(p, "w", encoding="utf-8", newline="").write(t2)
                고친 += 1
    print(f"\n② 키트 원위치 완료 · 경로 고친 파일 {고친}개")
    # ③
    옮김 = []
    for p in 목록:
        src = os.path.join(저장소, p)
        dst = os.path.join(백업, p)
        if not os.path.exists(src):
            continue
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        if os.path.exists(dst):
            shutil.rmtree(dst) if os.path.isdir(dst) else os.remove(dst)
        shutil.move(src, dst)
        옮김.append(p)
    json.dump({"옮김": 옮김, "하수도기록_남김": 하수도남김}, open(목록파일, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(f"③ 옮김 {len(옮김)}개 → {백업}")
    print("\n남은 변경:", len(git("status", "--porcelain").stdout.splitlines()), "건 (GitHub Desktop 에서 확인)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
