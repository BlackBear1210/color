# -*- coding: utf-8 -*-
"""
쳅터1 도안 글자 지도 — 2026-10-10 Claude (10-10 스크래치패드 도구를 저장소로)

도안 한 장을 글자 격자로 찍는다. 레벨을 고칠 때 그림(도면 PNG)보다 빨리 읽힌다 — 칸 좌표를 그대로 센다.

  #  구조(칠 못 함 · 2026-10-10 부터 검정 판정)   B 검정 판   W 흰 판   g 유령 판(칠해야 밟힘)   H 흰구조(달빛 깔개)
  ^  가시   *  색 고정 빛(흰=o · 검정=x 로 구별)   :  주기·점멸 빛(기다리면 지나감)
  J  도약대  =  움직이는 발판이 쓸고 가는 칸   p  부서지는 판   k  열쇠 조각   C  체크포인트   S  시작
  f  반딧불 멈춤 자리   s  그을음 둥지   L  레버   ~  닿는 바닥 줄(검사기 '편한 손' 기준)   !  못 닿는 바닥 줄

  위·왼쪽 테두리에 칸 번호(10 단위)를 단다.

사용
  python tools/쳅터1/글지도.py 쳅터1_02_복도_A            # 지도 + 검사
  python tools/쳅터1/글지도.py 쳅터1_02_복도_A --검사없이  # 지도만(빠름)
  python tools/쳅터1/글지도.py 쳅터1_02_복도_A --x 60 140  # 가로 범위만
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import 규격  # noqa: E402
import 도안 as 도안모듈  # noqa: E402
import 기믹 as 기믹모듈  # noqa: E402

C = 규격.칸
저장소 = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
도안폴더 = os.path.join(저장소, "scenes", "쳅터1", "도안")


def 지도글(dn, 검사결과=None, x범위=None):
    w, h = dn.w, dn.h
    판 = [[" "] * w for _ in range(h)]
    글자 = {0: " ", 1: "#", 2: "B", 3: "W", 4: "g", 5: "H"}
    for y in range(h):
        for x in range(w):
            판[y][x] = 글자.get(dn.g[y][x], "?")
    for gx, gy, gw in dn.d.get("가시", []):
        for x in range(gx, gx + gw):
            if 0 <= x < w and 0 <= gy - 1 < h and 판[gy - 1][x] == " ":
                판[gy - 1][x] = "^"
    gs = 기믹모듈.목록(dn)
    for g in gs:
        if isinstance(g, 기믹모듈.빛줄기):
            l, t, r, b = g.사각()
            for y in range(max(0, int(t // C)), min(h, int(b // C) + 1)):
                for x in range(max(0, int(l // C)), min(w, int(r // C) + 1)):
                    if 판[y][x] != " ":
                        continue
                    if g.닿음(x * C + 4, y * C + 4, x * C + C - 4, y * C + C - 4):
                        판[y][x] = ("o" if g.색 == "흰" else "x") if g.고정 else ":"
        elif isinstance(g, 기믹모듈.도약대):
            for x, y in g.칸들():
                판[y][x] = "J"
        elif isinstance(g, 기믹모듈.움직이는발판):
            for x, y in g.쓸고간_칸들():
                if 0 <= y < h and 0 <= x < w and 판[y][x] == " ":
                    판[y][x] = "="
        elif isinstance(g, 기믹모듈.부서지는판):
            for x, y in g.칸들():
                판[y][x] = "p"
        elif isinstance(g, 기믹모듈.열쇠조각):
            판[int(g.y)][int(g.x)] = "k"
        elif isinstance(g, 기믹모듈.반딧불몹):
            for x, y in g.멈춤:
                if 0 <= int(y) < h and 0 <= int(x) < w:
                    판[int(y)][int(x)] = "f"
        elif isinstance(g, 기믹모듈.그을음):
            판[g.바닥 - 1][g.x] = "s"
        elif isinstance(g, 기믹모듈.레버퍼즐):
            for x, y in g.레버 + [g.손잡이]:
                판[y - 1][x] = "L"
        elif isinstance(g, 기믹모듈.누름계단):
            for x, y in g.나온_칸들():
                if 판[y][x] == " ":
                    판[y][x] = "n"
    for cx, cy in dn.d.get("체크", []):
        if 0 <= cy - 1 < h:
            판[cy - 1][cx] = "C"
    sx, sy = dn.d["시작"]
    판[sy - 1][sx] = "S"
    if 검사결과 is not None:
        닿음 = 검사결과["도달구간"]
        for i, (cy, a, b) in enumerate(검사결과["구간"]):
            표 = "~" if i in 닿음 else "!"
            for x in range(int(a // C), int(b // C) + 1):
                if 0 <= x < w and 0 <= cy - 1 < h and 판[cy - 1][x] == " ":
                    판[cy - 1][x] = 표
    x0, x1 = (x범위 or (0, w))
    줄 = []
    줄.append("    " + "".join(str((x // 100) % 10) if x % 10 == 0 else " " for x in range(x0, x1)))
    줄.append("    " + "".join(str((x // 10) % 10) if x % 10 == 0 else "." if x % 5 == 0 else " " for x in range(x0, x1)))
    for y in range(h):
        줄.append(f"{y:3d} " + "".join(판[y][x0:x1]))
    return "\n".join(줄)


def main():
    인자 = sys.argv[1:]
    이름들 = [a for a in 인자 if not a.startswith("--") and not a.lstrip("-").isdigit()]
    x범위 = None
    if "--x" in 인자:
        i = 인자.index("--x")
        x범위 = (int(인자[i + 1]), int(인자[i + 2]))
        이름들 = [a for a in 이름들 if a not in (인자[i + 1], 인자[i + 2])]
    for dn in 도안모듈.모두_읽기(도안폴더):
        if 이름들 and dn.이름 not in 이름들:
            continue
        결과 = None
        if "--검사없이" not in 인자:
            import 검사 as 검사모듈
            결과 = 검사모듈.검사(dn, True, 출력=True)
        print(f"── {dn.이름} ({dn.w}×{dn.h})")
        print(지도글(dn, 결과, x범위))


if __name__ == "__main__":
    main()
