# -*- coding: utf-8 -*-
"""
쳅터1 도안의 "연결"(어느 스테이지 어느 길목으로 이어지나)만 씬의 연결구 노드에 옮겨 적기 — 2026-10-09 Claude

▣ 왜: 새 스테이지(16 썩은 마루 복도 · 17 응접실)를 사이에 끼우려면 이웃 스테이지(03·04·11·12)의 길목이 가리키는
  다음 씬을 바꿔야 한다. 그런데 그 씬들은 손으로 고친 흔적이 있어 생성기가 통째로 다시 쓰지 못한다(멈춤).
  → 이 도구는 `[node name="<길목>" … parent="연결"]` 블록의 "다음_씬" · "다음_연결" · "되돌아가기" 세 줄만 고친다.
  지형·배경·다른 노드는 건드리지 않는다. 멱등.

▣ 실행: python tools/쳅터1/연결_적용.py [스테이지 이름…]
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import 도안 as 도안모듈  # noqa: E402

저장소 = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
도안폴더 = os.path.join(저장소, "scenes", "쳅터1", "도안")
씬폴더 = os.path.join(저장소, "scenes", "쳅터1", "스테이지")


# 연결구.gd 의 기본값 — 에디터로 저장된 씬은 기본값 줄을 생략한다. 같은 값이면 줄을 새로 넣지 않는다(남의 씬을 덜 건드린다)
_기본값 = {"다음_씬": '""', "다음_연결": '"왼쪽"', "되돌아가기": "true"}


def _줄_바꾸기(블록, 키, 값):
    줄 = f'"{키}" = {값}'
    if re.search(rf'^"{키}" = .*$', 블록, re.M):
        return re.sub(rf'^"{키}" = .*$', 줄, 블록, count=1, flags=re.M)
    if _기본값.get(키) == 값:
        return 블록
    # 없으면 블록 끝(다음 빈 줄 앞)에 붙인다
    return 블록.rstrip("\n") + "\n" + 줄 + "\n\n"


def 적용(이름들=()):
    for 파일 in sorted(os.listdir(도안폴더)):
        if not 파일.endswith(".json"):
            continue
        dn = 도안모듈.도안(os.path.join(도안폴더, 파일))
        if 이름들 and dn.이름 not in 이름들:
            continue
        경로 = os.path.join(씬폴더, dn.이름 + ".tscn")
        if not os.path.exists(경로):
            continue
        옛 = open(경로, encoding="utf-8", newline="").read().replace(chr(13) + chr(10), chr(10))
        새 = 옛
        for 문 in dn.문:
            연결 = 문.get("연결") or []
            다음 = ""
            if 연결:
                다음 = 연결[0] if 연결[0].startswith("res://") else f"res://scenes/쳅터1/스테이지/{연결[0]}.tscn"
            m = re.search(rf'^\[node name="{re.escape(문["이름"])}" type="Node2D" parent="연결"[^\]\n]*\]\n(.*?)(?=^\[|\Z)', 새, re.M | re.S)
            if not m:
                print(f"  ⚠ {dn.이름}: 연결구 '{문['이름']}' 노드 없음")
                continue
            블록 = m.group(0)
            b2 = _줄_바꾸기(블록, "다음_씬", f'"{다음}"')
            b2 = _줄_바꾸기(b2, "다음_연결", f'"{연결[1] if 연결 else ""}"')
            b2 = _줄_바꾸기(b2, "되돌아가기", "true" if 문.get("되돌아가기", True) and 연결 else "false")
            새 = 새[:m.start()] + b2 + 새[m.end():]
        if 새 != 옛:
            with open(경로, "w", encoding="utf-8", newline="\n") as f:
                f.write(새)
            print(f"  연결 → {dn.이름}")


if __name__ == "__main__":
    적용(tuple(a for a in sys.argv[1:] if not a.startswith("--")))
