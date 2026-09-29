"""[2026-09-30 Claude] 씬에 저장된 SS2D 클릭 사각형 흔적을 찾고(기본) 지운다(--적용).

왜:
  SmartShape2D 는 **에디터에서만** 지형마다 투명 ColorRect(클릭 영역, meta __ss2d_click_rect__)를
  내부 자식으로 만든다. 지형이 편집 가능한 인스턴스([editable path=...])로 들어간 씬을 에디터가 저장하면
  그 ColorRect 가 "인스턴스 안 노드의 덮어쓰기" 로 파일에 남는다:
      [node name="@ColorRect@19684" parent="지형/G_천장" index="0"]
      modulate = Color(1, 1, 1, 0) ... metadata/__ss2d_click_rect__ = true
  게임에서는 그 노드가 만들어지지 않으므로 Godot 가 로드 때마다
  "was modified from inside an instance, but it has vanished" 경고를 하나씩 낸다 — 디버그 실행에서 하나당 ~110ms.
  실측(2026-09-30): stage_2-9 는 27 개 → instantiate 3,095ms, 지우면 10ms. 통로로 넘어갈 때 3 초 멈춤이었다.

무엇을 지우나:
  헤더에 type=/instance= 가 없고(= 덮어쓰기), 이름이 @ColorRect@숫자 이고, 본문에
  metadata/__ss2d_click_rect__ = true 가 있는 블록만. 템플릿 씬의 실제 노드(type="ColorRect")는 건드리지 않는다
  (SS2D 가 로드 때 스스로 지우고 경고도 없다).

쓰는 법:
  python tools/정리_SS2D_클릭사각형_흔적.py            # 보고만(바꾸지 않음). 흔적이 있으면 종료코드 1 → 검사로도 쓴다
  python tools/정리_SS2D_클릭사각형_흔적.py --적용     # 지운다(멱등: 다시 돌리면 0 개)
  python tools/정리_SS2D_클릭사각형_흔적.py 경로.tscn  # 특정 파일만
⚠ 해당 씬이 에디터에 열려 있으면 먼저 닫거나, 적용 뒤 에디터에서 "다시 불러오기" 할 것.
   열린 채 에디터가 저장하면 흔적이 다시 써진다. 보관 폴더(`보관`)는 게임이 안 읽으므로 기본 제외.
"""
import re
import sys
from pathlib import Path

뿌리 = Path(__file__).resolve().parent.parent
헤더 = re.compile(r'^\[node name="@ColorRect@\d+"(?P<rest>[^\]]*)\]')


def 블록들(글: str) -> list[str]:
    # 줄바꿈(CRLF/LF)을 그대로 보존하려고 "[" 로 시작하는 줄 앞에서만 자른다.
    return re.split(r'(?m)^(?=\[)', 글)


def 흔적인가(블록: str) -> bool:
    m = 헤더.match(블록)
    if not m:
        return False
    rest = m.group("rest")
    if "type=" in rest or "instance=" in rest:
        return False
    return "metadata/__ss2d_click_rect__ = true" in 블록


def 처리(경로: Path, 적용: bool) -> int:
    with open(경로, encoding="utf-8", newline="") as f:
        글 = f.read()
    조각 = 블록들(글)
    남길것 = [b for b in 조각 if not 흔적인가(b)]
    개수 = len(조각) - len(남길것)
    if 개수 and 적용:
        with open(경로, "w", encoding="utf-8", newline="") as f:
            f.write("".join(남길것))
    return 개수


def main() -> int:
    인자 = [a for a in sys.argv[1:] if not a.startswith("--")]
    적용 = "--적용" in sys.argv
    if 인자:
        대상 = [Path(a) for a in 인자]
    else:
        대상 = [p for p in (뿌리 / "scenes").rglob("*.tscn") if "보관" not in p.parts]
    합계 = 0
    for p in sorted(대상):
        n = 처리(p, 적용)
        if n:
            합계 += n
            print(f"{'지움' if 적용 else '발견'} {n:3d}  {p.relative_to(뿌리) if p.is_absolute() else p}")
    if 합계 == 0:
        print("SS2D 클릭 사각형 흔적 없음 ✔")
        return 0
    if 적용:
        print(f"총 {합계} 개 지웠다. 열려 있던 씬은 에디터에서 다시 불러올 것.")
        return 0
    print(f"총 {합계} 개 — 로드 때마다 하나당 ~110ms 경고. `--적용` 으로 지운다.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
