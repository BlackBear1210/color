# -*- coding: utf-8 -*-
"""
생성된 쳅터1 씬(.tscn)·프리셋(.tres) 정적 검사 — 2026-10-04 Claude (엔진 미실행)

  · ExtResource/SubResource 참조가 모두 선언돼 있나
  · res:// 경로 파일이 디스크에 있나
  · parent 경로가 앞에서 만든 노드를 가리키나 · 같은 부모 아래 이름 중복이 없나
  · 문 연결: 다음_씬 파일이 있고, 그 씬에 다음_연결 이름의 노드가 있나 (양방향)
사용: python tools/쳅터1/씬검사.py
"""
import os
import re
import sys

저장소 = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
씬폴더 = os.path.join(저장소, "scenes", "쳅터1", "스테이지")
프리셋폴더 = os.path.join(저장소, "assets", "background", "쳅터1", "프리셋")


def res_경로(p):
    return os.path.join(저장소, *p[len("res://"):].split("/"))


def 검사_파일(경로):
    글 = open(경로, encoding="utf-8").read()
    오류 = []
    ext = dict(re.findall(r'\[ext_resource [^\]]*path="([^"]+)" id="([^"]+)"\]', 글))
    ext_ids = {v: k for k, v in ext.items()}
    for p in ext:
        if not os.path.exists(res_경로(p)):
            오류.append(f"없는 파일: {p}")
    sub_ids = set(re.findall(r'\[sub_resource type="[^"]+" id="([^"]+)"\]', 글))
    for i in re.findall(r'ExtResource\("([^"]+)"\)', 글):
        if i not in ext_ids:
            오류.append(f"선언 안 된 ExtResource {i}")
    for i in re.findall(r'SubResource\("([^"]+)"\)', 글):
        if i not in sub_ids:
            오류.append(f"선언 안 된 SubResource {i}")
    노드 = {}
    뿌리 = None
    for m in re.finditer(r'\[node name="([^"]+)"(?: type="[^"]+")?(?: parent="([^"]+)")?', 글):
        이름, 부모 = m.group(1), m.group(2)
        if 부모 is None:
            뿌리 = 이름
            노드["."] = set()
            continue
        if 부모 not in 노드:
            오류.append(f"부모 없음: {이름} ← {부모}")
            continue
        if 이름 in 노드[부모]:
            오류.append(f"이름 중복: {부모}/{이름}")
        노드[부모].add(이름)
        경로 = 이름 if 부모 == "." else f"{부모}/{이름}"
        노드[경로] = set()
    return 오류, 글, 노드, 뿌리


def main():
    합 = 0
    문들 = {}
    for f in sorted(os.listdir(프리셋폴더)):
        if f.endswith(".tres"):
            오류, *_ = 검사_파일(os.path.join(프리셋폴더, f))
            for o in 오류:
                print(f"  × {f}: {o}")
            합 += len(오류)
    씬들 = {}
    for f in sorted(os.listdir(씬폴더)):
        if not f.endswith(".tscn"):
            continue
        오류, 글, 노드, 뿌리 = 검사_파일(os.path.join(씬폴더, f))
        씬들[f[:-5]] = 노드
        for m in re.finditer(r'\[node name="([^"]+)" type="Node2D" parent="연결"\]\n(?:[^\[]*?)"다음_씬" = "([^"]*)"\n"다음_연결" = "([^"]*)"', 글):
            문들[(f[:-5], m.group(1))] = (m.group(2), m.group(3))
        print(f"{'○' if not 오류 else '×'} {f}: 노드 {sum(len(v) for v in 노드.values())}개 · 지형 {len(노드.get('지형', []))} · 연결 {sorted(노드.get('연결', []))}")
        for o in 오류:
            print("    ×", o)
        합 += len(오류)
    for (씬, 문), (다음, 다음문) in sorted(문들.items()):
        if not 다음:
            print(f"  · {씬}/{문}: 닫힌 길목")
            continue
        목표 = os.path.basename(다음)[:-5]
        # 다른 챕터의 기본 시작점 진입은 쳅터1 연결구 목록에 없어도 실제 파일이 있으면 유효하다.
        if not 다음문 and 다음.startswith("res://") and os.path.isfile(os.path.join(저장소, 다음[6:])):
            continue
        if 목표 not in 씬들:
            print(f"  × {씬}/{문} → {다음} 파일 없음")
            합 += 1
        elif 다음문 not in 씬들[목표].get("연결", set()):
            print(f"  × {씬}/{문} → {목표} 에 '{다음문}' 연결 없음")
            합 += 1
        elif 문들.get((목표, 다음문), ("", ""))[0].endswith(f"/{씬}.tscn") is False:
            print(f"  · {씬}/{문} → {목표}/{다음문} (되돌아오는 길이 이 문으로 오지 않음)")
    print("오류 합계:", 합)
    return 1 if 합 else 0


if __name__ == "__main__":
    sys.exit(main())
