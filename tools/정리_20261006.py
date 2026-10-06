# -*- coding: utf-8 -*-
"""
2026-10-06 정리 — 프로젝트 가볍게 (도형님: "내가 올린 파일들을 전부 도형 작업 내용으로 묶어서 정리…
프로젝트 파일의 무게를 줄이고 가볍게 만들어 보자")

게임이 쓰지 않는 검토·백업 자료를 **저장소 밖** 백업으로 옮긴다. 지우지 않는다 → 언제든 되돌린다.
  python tools/정리_20261006.py            # 무엇을 옮길지 보기만
  python tools/정리_20261006.py --실행     # 옮기기 (백업/목록.json 에 기록)
  python tools/정리_20261006.py --되돌리기 # 목록.json 대로 제자리로

옮기는 것(게임 그림·씬·스크립트는 하나도 없다):
  tools/쳅터1/목재_v05_검토/   v05 기둥판 전후 비교 JPG — v06(평행 사선)으로 대체됨
  tools/쳅터1/목재_v06_검토/   Codex v06 수정 전 백업·diff·정적검사
  tools/쳅터1/목재_v07_검토/   10-06 맞물림 부분 적용 전 씬 백업(되돌릴 때 여기서 꺼낸다)
  tools/_진단/                 로컬 엔진 촬영·진단(원래 git 밖, 도구로 다시 만든다)
  docs/작업기록_2026-10-05_Codex_목재평행마감.md — docs/작업기록_도형_쳅터1_2026-10-04_06.md §7-3 으로 합쳤다
남기는 것: tools/쳅터1/목재_v04_검토/비교_*.jpg — 명암 안(§5) 선택이 아직 대기 중이라 도형님이 볼 자료.
"""
import json
import os
import shutil
import sys

저장소 = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
백업 = os.path.join(os.path.expanduser("~"), "Documents", "GRAY_백업", "정리_20261006")
목록파일 = os.path.join(백업, "목록.json")

대상 = [
    "tools/쳅터1/목재_v05_검토",
    "tools/쳅터1/목재_v06_검토",
    "tools/쳅터1/목재_v07_검토",
    "tools/_진단",
    "docs/작업기록_2026-10-05_Codex_목재평행마감.md",
]


def 크기(p):
    if os.path.isfile(p):
        return os.path.getsize(p)
    합 = 0
    for 뿌리, _d, 파일들 in os.walk(p):
        for f in 파일들:
            try:
                합 += os.path.getsize(os.path.join(뿌리, f))
            except OSError:
                pass
    return 합


def main():
    if "--되돌리기" in sys.argv:
        기록 = json.load(open(목록파일, encoding="utf-8"))
        for rel in 기록["옮김"]:
            src, dst = os.path.join(백업, rel), os.path.join(저장소, rel)
            if os.path.exists(src):
                os.makedirs(os.path.dirname(dst), exist_ok=True)
                shutil.move(src, dst)
                print("되돌림", rel)
        return
    실행 = "--실행" in sys.argv
    목록 = [r for r in 대상 if os.path.exists(os.path.join(저장소, r))]
    합 = 0
    for rel in 목록:
        b = 크기(os.path.join(저장소, rel))
        합 += b
        print(f"{b / 1e6:8.1f}MB  {rel}")
    print(f"합계 {합 / 1e6:.1f}MB → {백업}")
    if not 실행:
        print("(보기만 — 옮기려면 --실행)")
        return
    os.makedirs(백업, exist_ok=True)
    옮김 = []
    for rel in 목록:
        src, dst = os.path.join(저장소, rel), os.path.join(백업, rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.move(src, dst)
        옮김.append(rel)
    이전 = json.load(open(목록파일, encoding="utf-8"))["옮김"] if os.path.exists(목록파일) else []
    json.dump({"옮김": sorted(set(이전 + 옮김)), "설명": __doc__}, open(목록파일, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("옮김", len(옮김))


if __name__ == "__main__":
    main()
