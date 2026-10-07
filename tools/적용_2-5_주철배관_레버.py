"""[2026-09-30 Claude] 2-5 밸브·레버 연결 정리 — 도형님 결정 그대로.

  · 레버는 관 없이 **호퍼/물 가까운 지형 위에 단독**으로 둔다(연결은 자리로 읽힌다).
  · 첫 밸브(L1, 도형님 스크린샷 자리)는 **레버로 교체** — 직선 레버에 갈래_A 만 주면 켜기/끄기 스위치가 된다
    (제어레버._켜기 는 빈 경로를 조용히 건너뛴다). 주행검사가 이름으로 찾으므로 노드 이름은 그대로 둔다.
  · 원형 밸브(L3·L4)는 새 주철 배관(`하수도_주철배관.gd`)에 **포트로 연결** — 관이 바퀴 뒤를 지나 바닥까지 내려간다
    (바닥이 밸브 중심 +64 = 축 끝 +32 보다 32 낮다 → `배관_아래_연장 = 32`, 실측).
  · 예전 Line2D 안내선 5 개는 지운다(레버 쪽 3 개는 관 자체가 없어지고, 밸브 쪽 2 개는 주철 배관으로 바뀐다).

멱등: 이미 적용됐으면(`cast_pipe` ext_resource 가 있으면) 아무것도 안 한다. 기본은 조사만, `--적용` 이면 쓴다.
"""
import pathlib
import re
import sys

P = pathlib.Path(__file__).resolve().parent.parent / "scenes" / "world_2_클로드" / "stage_2-5.tscn"
raw = P.read_bytes()
crlf = b"\r\n" in raw
s = raw.decode("utf-8").replace("\r\n", "\n")
if 'id="cast_pipe"' in s:
    print("이미 적용됨")
    sys.exit(0)

# 1) 배관 스크립트 ext_resource
last = list(re.finditer(r"^\[ext_resource[^\n]*\]$", s, re.M))[-1]
s = s[:last.end()] + '\n[ext_resource type="Script" path="res://scripts/스마트월드/하수도_주철배관.gd" id="cast_pipe"]' + s[last.end():]

# 2) L1 원형 밸브 → 직선 레버(켜기/끄기)
old_l1 = '''[node name="L1_원형_첫밸브" parent="장치" instance=ExtResource("9_lever")]
position = Vector2(864, 1056)
"대상_유체" = NodePath("../F1_첫길막_흰물")
editor_description = "첫 조작은 눈앞의 물을 멈추는 한 가지 결과만 보여 준다."'''
new_l1 = '''[node name="L1_원형_첫밸브" parent="장치" instance=ExtResource("9_lever")]
position = Vector2(864, 1056)
"종류" = 1
"갈래_A" = NodePath("../F1_첫길막_흰물")
editor_description = "첫 조작은 눈앞의 물을 멈추는 한 가지 결과만 보여 준다. 2026-09-30: 원형 밸브 → 관 없는 단독 레버(갈래_A 만 = 켜기/끄기). 주행검사가 이름으로 찾아서 이름은 그대로."'''
assert old_l1 in s, "L1 블록이 예상과 다르다"
s = s.replace(old_l1, new_l1, 1)

# 3) 원형 밸브 L3·L4 — 관이 바닥까지
for name in ("L3_원형_양자택일", "L4_원형_반대색건너"):
    m = re.search(r'(\[node name="%s" parent="장치" instance=ExtResource\("9_lever"\)\]\nposition = [^\n]*\n)' % name, s)
    assert m, name
    s = s[:m.end()] + '"배관_아래_연장" = 32.0\n' + s[m.end():]

# 4) Line2D 안내선 → 주철 배관 2 개
m = re.search(r'\[node name="배관_안내" type="Node2D" parent="\."\]\nz_index = -1\n.*?(?=\n\[node name="입구통로")', s, re.S)
assert m, "배관_안내 블록"
s = s[:m.start()] + '''[node name="배관_안내" type="Node2D" parent="."]
z_index = -1
editor_description = "2026-09-30: 원형 밸브만 주철 배관으로 물과 잇는다(포트 자동 연결). 레버는 관 없이 물 가까이 단독."

[node name="상부출구연결" type="Node2D" parent="배관_안내"]
script = ExtResource("cast_pipe")
"점들" = PackedVector2Array(3312, 624, 3312, 192, 4400, 192, 4400, 352)
"시작_장치" = NodePath("../../장치/L3_원형_양자택일")
"끝_장치" = NodePath("../../장치/F3_두번째길막")

[node name="사격수문" type="Node2D" parent="배관_안내"]
script = ExtResource("cast_pipe")
"점들" = PackedVector2Array(5232, 1000, 5232, 512, 5992, 512, 5992, 576)
"시작_장치" = NodePath("../../장치/L4_원형_반대색건너")
"끝_장치" = NodePath("../../장치/F4_레버앞_흰물")
''' + s[m.end():]

print("L1 → 레버 · L3/L4 배관_아래_연장 32 · 안내선 5 → 주철 배관 2")
if "--적용" in sys.argv:
    P.write_bytes((s.replace("\n", "\r\n") if crlf else s).encode("utf-8"))
    print("→ 저장")
