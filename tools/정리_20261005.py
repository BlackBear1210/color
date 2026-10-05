# -*- coding: utf-8 -*-
"""
2026-10-05 정리 — 프로젝트 가볍게 (도형님: "프로젝트 파일의 무게를 줄이고 가볍게 만들어 보자")

게임이 쓰지 않는 검토·백업 자료를 **저장소 밖** 백업으로 옮긴다. 지우지 않는다 → 언제든 되돌린다.
  python tools/정리_20261005.py            # 무엇을 옮길지 보기만
  python tools/정리_20261005.py --실행     # 옮기기 (백업/목록.json 에 기록)
  python tools/정리_20261005.py --되돌리기 # 목록.json 대로 제자리로

옮기는 것(게임 그림·씬·스크립트는 하나도 없다):
  tools/쳅터1/아트_v01_원본/   아스트라 생성 원본·완성본(적용본은 assets 에 있다)·이전 임시 그림·검토판
  tools/쳅터1/아트_v02_검토/   Codex 아트 v02 백업·검사 결과
  tools/쳅터1/목재_v03_검토/   Codex 목재 v03 캡처·로그
  tools/쳅터1/목재_v04_검토/*_안?.png · 비교_*.png   명암 안 원본 캡처(비교판은 JPG 로 남긴다)
  tools/_shots/ · tools/_진단/  로컬 캡처·진단(원래 git 밖, 도구로 다시 만든다)
  docs 작업기록 5개 · 깃_푸시_가이드 — docs/작업기록_도형_쳅터1_2026-10-04_05.md 로 통합했다
"""
import json
import os
import shutil
import sys

저장소 = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
백업 = os.path.join(os.path.expanduser("~"), "Documents", "GRAY_백업", "정리_20261005")
목록파일 = os.path.join(백업, "목록.json")

대상 = [
    "tools/쳅터1/아트_v01_원본",
    "tools/쳅터1/아트_v02_검토",
    "tools/쳅터1/목재_v03_검토",
    "tools/_shots",
    "tools/_진단",
    "docs/작업기록_2026-10-04_Claude_쳅터1_재구성_전경전환_정리.md",
    "docs/작업기록_2026-10-05_Claude_쳅터1_아트적용_기믹_시뮬.md",
    "docs/작업기록_2026-10-05_Codex_목재64px_투영방향_명암.md",
    "docs/작업기록_2026-10-05_Codex_목재상판분리_단면_천장경량화.md",
    "docs/작업기록_2026-10-05_Codex_목재입체_어두운배경_레이어시차.md",
    "docs/깃_푸시_가이드_2026-10-04.md",
]


def 목재_v04_원본():
    폴더 = os.path.join(저장소, "tools", "쳅터1", "목재_v04_검토")
    if not os.path.isdir(폴더):
        return []
    return [f"tools/쳅터1/목재_v04_검토/{f}" for f in sorted(os.listdir(폴더)) if f.endswith(".png")]


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


def 비교판_jpg():
    """비교판 PNG(장당 1~2MB)는 도형님이 보고 고를 자료라 JPG(장당 수백 KB)로 남긴다."""
    from PIL import Image
    폴더 = os.path.join(저장소, "tools", "쳅터1", "목재_v04_검토")
    for f in sorted(os.listdir(폴더)):
        if f.startswith("비교_") and f.endswith(".png"):
            Image.open(os.path.join(폴더, f)).convert("RGB").save(os.path.join(폴더, f[:-4] + ".jpg"), quality=86, optimize=True)


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
    if 실행:
        비교판_jpg()
    목록 = [r for r in 대상 + 목재_v04_원본() if os.path.exists(os.path.join(저장소, r))]
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
