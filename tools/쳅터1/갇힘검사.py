# -*- coding: utf-8 -*-
"""
쳅터1 갇힘(소프트락) 검사 — 2026-10-10 Claude

검사.py 는 "시작에서 출구까지 가나" 와 "밟을 것 같은 바닥에 닿나" 를 본다. 그런데 **닿을 수는 있지만
거기서 나갈 수 없는 바닥**(빠지면 죽지도 못하고 갇히는 구덩이)은 못 잡는다. 2026-10-10 03 서재 왼쪽 아래
구덩이(6~39)가 그랬다 — 부활이 '입구에서' 로 바뀌며 죽지 않는 갇힘은 게임을 다시 켜야 하는 버그가 됐다.

시작에서 닿는 바닥 구간마다 "여기서 출구(길목) 하나에라도 닿나" 를 편한 손 기준으로 본다.

사용
  python tools/쳅터1/갇힘검사.py                    # 도안 전부
  python tools/쳅터1/갇힘검사.py 쳅터1_03_방_서재   # 하나만
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import 도안 as 도안모듈  # noqa: E402
import 검사  # noqa: E402


def 갇힘(dn):
    m = 검사.지도(dn, True)
    구간 = 검사.구간들(m)
    gr = 검사.그래프(m, 구간)
    # 갇힘은 "어떻게든 나갈 수 있나" 다 → 가장 너그러운 손(점프 100% · 색 틈 8프레임)으로 본다.
    #   (편한 손으로 보면 빠듯한 탈출구까지 갇힘으로 잡힌다 — 그건 검사.py 의 '못 닿는 바닥' 몫)
    m.최소틈 = 검사.색전환_최소_프레임
    m.점프배율 = 1.0
    sx, sy = dn.d["시작"]
    시작 = gr.도달([검사.찾기(구간, sx * 검사.C + 검사.C / 2, sy * 검사.C)])
    출구 = {검사.찾기(구간, *검사.문_나감점(dn, 문)) for 문 in dn.문} - {None}
    out = []
    for i, (cy, a, b) in enumerate(구간):
        if i not in 시작 or i in 출구:
            continue
        if not (출구 & set(gr.도달([i]))):
            out.append(f"바닥 행 {cy} 칸 {a / 검사.C:.0f}~{b / 검사.C:.0f}")
    return out


def main():
    이름들 = [a for a in sys.argv[1:] if not a.startswith("--")]
    합 = 0
    for dn in 도안모듈.모두_읽기(검사.도안폴더):
        if 이름들 and dn.이름 not in 이름들:
            continue
        r = 갇힘(dn)
        합 += len(r)
        print(f"{dn.이름}: " + ("갇힘 없음" if not r else f"갇힘 {len(r)}"))
        for s in r:
            print("    ×", s, "— 여기 오면 출구로 못 간다")
    print("갇힘 합계:", 합)
    return 1 if 합 else 0


if __name__ == "__main__":
    sys.exit(main())
