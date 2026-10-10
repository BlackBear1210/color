# -*- coding: utf-8 -*-
"""쳅터1 검사기가 찾은 길(tools/_진단/경로/<이름>.json)을 칸 좌표로 찍는다 — 2026-10-10 Claude
사용: python tools/쳅터1/경로보기.py 쳅터1_03_방_서재 [길이름 일부]"""
import json
import os
import sys

저장소 = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
C = 32


def main():
    이름 = sys.argv[1]
    고름 = sys.argv[2] if len(sys.argv) > 2 else "시작→"
    d = json.load(open(os.path.join(저장소, "tools", "_진단", "경로", 이름 + ".json"), encoding="utf-8"))
    n, P, M = d["노드수"]
    구간 = d["구간"]

    def 노드(i):
        if i < n:
            cy, a, b = 구간[i]
            return f"바닥(행{cy} {a / C:.0f}~{b / C:.0f})"
        return f"도약대{i - n + 1}" if i < n + P else f"발판{i - n - P + 1}"

    for 길, 단계들 in d["경로"].items():
        if 고름 not in 길:
            continue
        print("──", 길)
        for s in 단계들:
            if s["종류"] != "비행":
                print(f"   {노드(s['from'])} → {노드(s['to'])} ({s['종류']})")
                continue
            x, y = s["출발"]
            색 = {2: "검", 3: "흰", None: "-"}.get(s.get("첫색"), "?")
            print(f"   {노드(s['from'])} @({x / C:.1f},{y / C:.0f}) → {노드(s['to'])}  첫색 {색} 전환 {len(s.get('전환') or [])}")


if __name__ == "__main__":
    main()
