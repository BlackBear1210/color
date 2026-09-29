# -*- coding: utf-8 -*-
"""짧은 호퍼 공급 물을 천장 밑면까지 늘린다 (씬 텍스트만 고친다 · 기본은 미리보기).

왜 (2026-09-29 도형님 결정):
  작은 호퍼 위 공급 물(호퍼_유입)이 48×60 처럼 짧아 위 끝이 허공에서 잘리고, 호퍼 위에 올려놓은
  "흰 컵" 처럼 보였다. 물이 떨어져 들어오는 줄기로 보이게 **위쪽 출처까지** 늘린다.
  이 물들 위에는 배관 끝이 없고 바로 천장이다(tools/진단_공급물_출처.gd 실측) → 2-9 공급 물처럼 천장 밑면에서 떨어진다.
  배관 끝 그림을 붙이는 방법은 쓰지 않는다(도형님: 물이 짧은 채로 붙을 수 있어서).

규칙:
  - 아래 끝(호퍼 입구)은 그대로 둔다: 새 크기.y = (옛 position.y + 옛 크기.y) − 천장 y.
  - 천장 y 는 진단 도구가 잰 값(아래 표). 표에 없는 물은 건드리지 않는다.
  - 멱등: 다시 돌려도 position.y = 천장, 크기.y = 아래끝 − 천장 으로 같은 값이 나온다.
  - ⚠ 판정 영역이 위로 길어진다 → 해당 스테이지 주행검사로 확인한다.

사용:
  python tools/apply_공급물_천장까지.py            # 미리보기(파일 안 바꿈)
  python tools/apply_공급물_천장까지.py --적용
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
D = os.path.join(ROOT, "scenes", "world_2_클로드")

# 스테이지 → {물 이름: 천장 밑면 y}  (2026-09-29 진단_공급물_출처.gd 실측)
표 = {
    "stage_2-3.tscn": {"B_H2_공급_검": 1408, "B_H3_공급_흰": 1408, "B_H4_공급_검": 1408, "B_H4_공급_흰": 1408},
    "stage_2-4.tscn": {"S1_고정공급": 2240, "S1_저장고공급": 2240, "S2_고정공급": 1472, "S2_저장고공급": 1472,
                       "S3a_고정공급": 896, "S3a_저장고공급": 896, "S3b_고정공급": 640, "S3b_저장고공급": 640,
                       "H4_고정공급": 640, "H4_저장고공급": 640},
    "stage_2-6.tscn": {"H3_고정공급": 1216, "H3_배출공급": 1216},
    "stage_2-8.tscn": {"HB_고정공급": 1472, "HB_저장고공급": 1472, "H1_고정공급": 1472, "H1_배출공급": 1472},
}

# 씬이 CRLF 로 저장돼 있어 줄 끝 \r 을 허용한다($ 앞의 \r 때문에 한 번 못 찾았다)
POS = re.compile(r'^("?position"?) = Vector2\(([-\d.]+), ([-\d.]+)\)(?=\r?$)', re.M)
SIZE = re.compile(r'^("?크기"?) = Vector2\(([-\d.]+), ([-\d.]+)\)(?=\r?$)', re.M)


def fmt(v):
    return str(int(v)) if float(v).is_integer() else str(v)


def main():
    apply = "--적용" in sys.argv
    for 파일, 물들 in 표.items():
        path = os.path.join(D, 파일)
        text = open(path, encoding="utf-8", newline="").read()
        blocks = re.split(r'(?=^\[)', text, flags=re.M)  # CRLF 여도 줄 머리 [ 로 나뉜다
        changed = 0
        for i, b in enumerate(blocks):
            m = re.match(r'\[node name="([^"]+)"', b)
            if not m or m.group(1) not in 물들:
                continue
            ceil = float(물들[m.group(1)])
            pm, sm = POS.search(b), SIZE.search(b)
            if not pm or not sm:
                print("  !", 파일, m.group(1), "position/크기 줄을 못 찾음 — 건너뜀")
                continue
            x, y = float(pm.group(2)), float(pm.group(3))
            w, h = float(sm.group(2)), float(sm.group(3))
            bottom = y + h
            new_h = bottom - ceil
            if new_h <= h - 0.5:
                print("  ·", 파일, m.group(1), "이미 천장보다 길거나 같음 — 건너뜀")
                continue
            print("  %s %-16s y %s→%s · 높이 %s→%s (아래끝 %s 유지)" % (파일, m.group(1), fmt(y), fmt(ceil), fmt(h), fmt(new_h), fmt(bottom)))
            b = b[:pm.start()] + '%s = Vector2(%s, %s)' % (pm.group(1), pm.group(2), fmt(ceil)) + b[pm.end():]
            sm = SIZE.search(b)
            b = b[:sm.start()] + '%s = Vector2(%s, %s)' % (sm.group(1), sm.group(2), fmt(new_h)) + b[sm.end():]
            blocks[i] = b
            changed += 1
        if apply and changed:
            open(path, "w", encoding="utf-8", newline="").write("".join(blocks))
    print("적용함" if apply else "미리보기만 (--적용 으로 씀)")


if __name__ == "__main__":
    main()
