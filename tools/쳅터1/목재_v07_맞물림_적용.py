# -*- coding: utf-8 -*-
"""[2026-10-06 Claude] 목재 v07 — 하수도식 흑백 맞물림을 **씬 지형 노드만** 부분 적용한다.

왜 따로 있나
  쳅터1 씬은 Codex 목재 v03(목재_v03_적용.py)이 부분 갱신해서 첫 줄 표식이 바뀌었다 → 만들기.py 는
  '에디터에서 손댄 씬' 으로 보고 멈춘다(--강제 는 기믹·배경 수동 편집까지 덮어쓴다).
  그래서 v03 과 같은 방식으로 **지형 노드(구조·흰판)의 점과 새 속성 '내부_무늬' 만** 바꾸고 나머지 노드는 그대로 둔다.

무엇이 바뀌나 (도안._목재_맞물림 참고)
  · 흰판: 예전엔 안쪽 줄을 깎아 엇갈렸다 → 이제 설계한 사각형 그대로(밟는 윗면·판정 불변).
  · 구조: 흰 판 아래·옆 '묻힌' 칸에 반대색 무늬 줄(내부_무늬) — 구조는 칠하기 금지라 물감이 닿지 않는다.
  · 같은 이름 노드만 바꾼다. 이름 집합이 다르면(덩어리 수가 달라짐) 그 씬은 건너뛰고 알린다.

실행
  python tools/쳅터1/목재_v07_맞물림_적용.py            # 바꿀 것만 보여 준다(쓰지 않음)
  python tools/쳅터1/목재_v07_맞물림_적용.py --쓰기     # 적용 (원본은 tools/쳅터1/목재_v07_검토/이전/ 에 백업)
"""
import re
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import 도안
import 만들기
from 아트_v02_적용 import blocks, world_points, same

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).parent / "목재_v07_검토"


def 노드표(text):
    표 = {}
    for m in blocks(text, "node"):
        첫줄 = m.group().splitlines()[0]
        if 'parent="지형"' in 첫줄 and "_points = SubResource" in m.group():
            표[re.search(r'name="([^"]+)"', 첫줄).group(1)] = m
    return 표


def 점_블록(text, pa):
    """PA_xx 와 그 점(P_xx_n) sub_resource 블록들."""
    pre = "P_" + pa[3:] + "_"
    return [m for m in blocks(text, "sub_resource")
            if re.search(r'id="([^"]+)"', m.group().splitlines()[0]).group(1) in (pa,)
            or re.search(r'id="([^"]+)"', m.group().splitlines()[0]).group(1).startswith(pre)]


def main():
    쓰기 = "--쓰기" in sys.argv
    for path in sorted((ROOT / "scenes/쳅터1/도안").glob("*.json")):
        dn = 도안.도안(str(path))
        if not dn.d.get("목재_맞물림", False):
            continue
        scene = ROOT / "scenes/쳅터1/스테이지" / f"{dn.이름}.tscn"
        old = scene.read_text(encoding="utf-8")
        new = 만들기.씬_글(dn)
        옛노드, 새노드 = 노드표(old), 노드표(new)
        if set(옛노드) != set(새노드):
            print(f"  ✗ {dn.이름}: 지형 이름이 다르다 — 건너뜀 (옛 {len(옛노드)} / 새 {len(새노드)})")
            continue
        바꿈 = []
        for 이름 in 옛노드:
            if not (이름.startswith("구조") or 이름.startswith("흰판")):
                continue
            a, b = 옛노드[이름].group(), 새노드[이름].group()
            _pa, 옛점 = world_points(old, a)
            _pb, 새점 = world_points(new, b)
            옛무늬 = re.search(r'^"내부_무늬" = .*$', a, re.M)
            새무늬 = re.search(r'^"내부_무늬" = .*$', b, re.M)
            점바뀜 = not same(옛점, 새점)
            무늬바뀜 = (옛무늬.group() if 옛무늬 else "") != (새무늬.group() if 새무늬 else "")
            if 점바뀜 or 무늬바뀜:
                바꿈.append((이름, 점바뀜, 새무늬.group() if 새무늬 else ""))
        print(f"  {dn.이름}: " + (", ".join(f"{n}({'점' if c else ''}{'+무늬' if m else ''})" for n, c, m in 바꿈) or "변경 없음"))
        if not 쓰기 or not 바꿈:
            continue
        백업 = OUT / "이전" / scene.relative_to(ROOT)
        if not 백업.exists():
            백업.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(scene, 백업)
        text = old
        for 이름, 점바뀜, 무늬줄 in 바꿈:
            옛 = 노드표(text)[이름]
            블록 = 옛.group()
            # 에디터가 저장한 unique_id · shape_material · _meshes 는 그대로 두고 필요한 줄만 바꾼다.
            블록 = re.sub(r'^"내부_무늬" = .*\n', "", 블록, flags=re.M)
            if 무늬줄:
                끝빈줄 = "\n" if 블록.endswith("\n\n") else ""
                블록 = 블록.rstrip("\n") + "\n" + 무늬줄 + "\n" + 끝빈줄
            if 점바뀜:
                새 = 새노드[이름].group()
                블록 = re.sub(r"^position = .*$", re.search(r"^position = .*$", 새, re.M).group(), 블록, count=1, flags=re.M)
                pa = re.search(r'_points = SubResource\("([^"]+)"\)', 블록).group(1)
                pa_new = re.search(r'_points = SubResource\("([^"]+)"\)', 새).group(1)
                블록 = 블록.replace(f'_points = SubResource("{pa}")', f'_points = SubResource("{pa_new}")')
            text = text[:옛.start()] + 블록 + text[옛.end():]
            if 점바뀜:
                for m in reversed(점_블록(text, pa)):
                    text = text[:m.start()] + text[m.end():]
                새점블록 = "".join(m.group() for m in 점_블록(new, pa_new))
                at = text.index("[node ")
                text = text[:at] + 새점블록 + text[at:]
        count = len(re.findall(r"^\[(?:ext_resource|sub_resource) ", text, re.M)) + 1
        text = re.sub(r"load_steps=\d+", f"load_steps={count}", text, count=1)
        text = re.sub(r"\n{3,}", "\n\n", text)
        scene.write_text(text, encoding="utf-8", newline="\n")
        print("    → 씀")


if __name__ == "__main__":
    main()
