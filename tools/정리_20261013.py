# -*- coding: utf-8 -*-
"""
2026-10-13 정리 — F5 로 안 닿는(게임이 안 쓰는) 파일을 저장소 밖 백업으로 옮긴다 (도형님 요청 · Claude)

지우지 않는다 → 언제든 되돌린다.
  python -X utf8 tools/정리_20261013.py            # 무엇을 옮길지 보기만
  python -X utf8 tools/정리_20261013.py --실행     # 옮기기 (백업/목록.json 에 기록)
  python -X utf8 tools/정리_20261013.py --되돌리기 # 목록.json 대로 제자리로

옮길 파일 목록은 옆 `정리_20261013_목록.txt` (188 개). 어떻게 골랐나:
  1) tools/연결지도.py 의 "F5 로 안 닿음" 중 가(이름 없음)·나(문서에만)·다(옛 파일끼리만) 칸
  2) 남는 파일이 하나라도 부르면 뺐다 — 연결 그래프 · 주석 포함 전체 경로 글자 · uid 글자 (고정점까지 반복)
     → 시험 씬(하수도_흑백벽돌_비교)·템플릿(WALL_STAIRS)·흑백 짝이 부르는 32 개가 여기서 빠졌다
  3) Godot 의존 캐시(.godot/editor/filesystem_cache10)에 "남는 파일 → 옮길 파일" 의존 0 확인
  4) 가이드 문서가 그림으로 보여 주는 21 개(fireboy 참고 13 · stage1_layers 목업 5 · 집 far/mid 3)는 남겼다
  5) 옮기기 전후로 엔진에서 모든 씬·리소스·스크립트를 load() 해 결과가 같은지 비교했다(작업기록 참고)
  몬스터 B 의 frames/ 낱장은 tools/prepare_monster_b_sprites.py 가 다시 만드는 중간 산출물이다(게임은 시트만 쓴다).

⚠ 목록에 .import / .uid 짝 파일은 적지 않는다 — 있으면 본 파일과 같이 옮긴다.
⚠ 파일이 다 빠져 빈 폴더는 지우고, 되돌릴 때 다시 만든다.
"""
import json
import os
import shutil
import sys

저장소 = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
백업 = os.path.join(os.path.expanduser("~"), "Documents", "GRAY_백업", "정리_20261013")
목록파일 = os.path.join(백업, "목록.json")
대상파일 = os.path.join(저장소, "tools", "정리_20261013_목록.txt")


def 대상_읽기():
    with open(대상파일, encoding="utf-8") as f:
        return [줄.strip() for 줄 in f if 줄.strip() and not 줄.startswith("#")]


def 짝까지(rel):
    # 본 파일 + 엔진이 붙여 둔 .import(그림) / .uid(스크립트) 짝
    return [p for p in (rel, rel + ".import", rel + ".uid") if os.path.isfile(os.path.join(저장소, p))]


def main():
    if "--되돌리기" in sys.argv:
        with open(목록파일, encoding="utf-8") as f:
            기록 = json.load(f)
        for rel in 기록["옮김"]:
            src, dst = os.path.join(백업, rel), os.path.join(저장소, rel)
            if os.path.exists(src) and not os.path.exists(dst):
                os.makedirs(os.path.dirname(dst), exist_ok=True)
                shutil.move(src, dst)
                print("되돌림", rel)
        return

    옮길것, 없음 = [], []
    for rel in 대상_읽기():
        짝 = 짝까지(rel)
        if not 짝:
            없음.append(rel)
        옮길것 += 짝
    합 = sum(os.path.getsize(os.path.join(저장소, p)) for p in 옮길것)
    print(f"옮길 파일 {len(옮길것)} 개 (짝 포함) · {합 / 1024 / 1024:.1f} MB · 이미 없음 {len(없음)}")
    if "--실행" not in sys.argv:
        for p in 옮길것:
            print("  ", p)
        print("보기만 했다 — 옮기려면 --실행")
        return

    기록 = {"옮김": [], "지운_빈폴더": []}
    if os.path.exists(목록파일):
        with open(목록파일, encoding="utf-8") as f:
            기록 = json.load(f)
    for rel in 옮길것:
        src, dst = os.path.join(저장소, rel), os.path.join(백업, rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.move(src, dst)
        if rel not in 기록["옮김"]:
            기록["옮김"].append(rel)
    # 비어 버린 폴더 정리 — 깊은 곳부터. 저장소 맨 위 폴더(assets·scenes)는 절대 안 지운다
    폴더들 = sorted({os.path.dirname(rel) for rel in 옮길것}, key=lambda d: -d.count("/"))
    for d in 폴더들:
        while d and "/" in d:
            절대 = os.path.join(저장소, d)
            if os.path.isdir(절대) and not os.listdir(절대):
                os.rmdir(절대)
                # 되돌렸다가 다시 실행해도 기록이 두 벌로 쌓이지 않게(멱등)
                if d not in 기록["지운_빈폴더"]:
                    기록["지운_빈폴더"].append(d)
                d = d.rsplit("/", 1)[0]
            else:
                break
    os.makedirs(백업, exist_ok=True)
    with open(목록파일, "w", encoding="utf-8") as f:
        json.dump(기록, f, ensure_ascii=False, indent=1)
    print(f"옮김 {len(옮길것)} · 빈 폴더 지움 {len(기록['지운_빈폴더'])} → {백업}")


if __name__ == "__main__":
    main()
