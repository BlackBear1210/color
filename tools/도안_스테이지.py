# -*- coding: utf-8 -*-
"""하수도 스테이지 도안 — 맵 한 장에 구조 · 흐름(정답/헛걸음 경로) · 장애물을 그린다.

왜:
  [2026-10-01 Claude] 도형님: "일일이 맵을 돌아다니며 보기 힘들다. 한 장 안에 맵 전체 구조와 흐름, 장애물을 보고 싶다."
  `tools/맵그래프.py` 는 관계(무슨 물이 누굴 죽이나)를 보는 도구라 지형이 사각형이고 물이 파란색이다 — 도안으로는 안 읽힌다.
  이 도구는 같은 파서(맵그래프.stage_graph · parse_routes)를 빌려
  **실제 지형 폴리곤 모양 그대로** 검정/흰 지형을 칠하고, 그 위에 물·웅덩이·가시·유령 발판·레버·체크포인트와
  주행검사 공략표(`tools/하수도_주행검사.gd`)의 **정답 / 헛걸음 경로를 실제 좌표로** 그린다.
  엔진 없이 텍스트만 읽는다(에디터에서 저장한 지금 씬 그대로).

사용:
  python tools/도안_스테이지.py                  # 아래 `메모` 에 있는 스테이지 전부(2-1~2-9) + docs/도안/index.html
  python tools/도안_스테이지.py stage_2-5        # 하나만 → docs/도안/stage_2-5_도안.html
  ★[2026-10-01] 헛걸음 경로 · 단계 목록은 그리지 않는다(도형님). 방 사각형·설명은 `메모` 표에 손으로 적는다.
  2-10·2-11 은 아직 `메모` 에 없다(넣으면 된다).

⚠ 경로는 공략표 명령을 흉내 낸 그림이다. "가 x" 는 바닥을 따라 걷는 것으로, "뛰기" 는 포물선으로 그린다 — 실제 궤적과 조금 다르다.
"""
import html
import importlib.util
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
_sp = importlib.util.spec_from_file_location('맵그래프', ROOT / 'tools' / '맵그래프.py')
mg = importlib.util.module_from_spec(_sp)
_sp.loader.exec_module(mg)
OUT_DIR = ROOT / 'docs' / '도안'

# 스테이지별 설계 메모. 방 = (글자, 제목, [x0, y0, x1, y1] 월드 사각형, 설명).
#   ★방 사각형은 손으로 적는다 — 지형 이름 규칙이 스테이지마다 달라(2-4 T·S, 2-8 층 L1~L3) 이름으로는 못 나눈다.
#   출처: 각 빌더 머리말(tools/build_하수도_2-N.gd) · 작업 문서(scenes/world_2_클로드/작업/) · 재제작 작업기록.
# 경로이름 = 공략표 이름표 → 도안에 쓸 이름. 「헛걸음」 은 그리지 않는다(도형님 2026-10-01). 탑·위층·아래층 같은 실제 갈래는 그린다.
# _경로없음 = 공략표가 지금 씬과 안 맞을 때 — 경로 대신 방 순서 화살표를 그린다.
메모 = {
    'stage_2-1': {
        '_요약': '★[2026-10-03 v3] 도형님 uvtt 도면(한 칸 32px). 튜토리얼 물 세 줄기(검·흰·회) → 원형 밸브(흰 물_3 ↔ 흰 물_2) → '
                 '격자 4장 → 윗길(가시 홈 · CP1 · 경사로 · 막다른 길) → 수직 통로 낙하 중 흰색 → 흰 웅덩이 → 검·흰·검·흰 공중 발판. 정답 발수 0.',
        '_출처': 'tools/build_하수도_2-1.gd 머리말 · docs/작업기록_2026-10-03_Claude_2-1_uvtt도면_재제작.md',
        '방': [
            ('A', '물 세 줄기 · 격자', [0, 0, 1872, 1984],
             '바닥 768. 검정 물은 걸어서 · 흰 물과 회색 물은 흰 바닥 토막(1104~1440) 위에서 흰 몸으로 지난다(뛰며 흰색 → 뛰며 검정). '
             '격자 G0(검·추가) → G1(검) → G2(흰) → G3(검) 으로 윗길에 오른다.'),
            ('B', '밸브 방 · 윗길', [1872, 0, 4288, 784],
             '밸브 방(바닥 768)의 원형 밸브가 윗길을 막는 흰 물_3 을 끄고 흰 물_2 를 켠다(다시 돌리면 반대). '
             '윗길(바닥 416 · 천장 128) → 가시 홈 → CP1 → 25° 경사로 → 수직 통로(3584~3712). 건너편은 막다른 길.'),
            ('C', '흰 웅덩이', [3312, 784, 4432, 1984],
             '수직 통로로 떨어지며 흰색으로 바꿔 흰 웅덩이(홈 바닥도 흰 지형)에 내린다 → 뛰며 검정으로 큰 방 바닥 → CP2.'),
            ('D', '검·흰 공중 발판', [4432, 784, 6880, 1984],
             '가시 구덩이 위 P1(검) · P2(흰) · P3(검) · P4(흰) — 칸마다 공중에서 색 전환 → 끝 바닥(검) → 출구(2-2).'),
        ],
    },
    'stage_2-2': {
        '_요약': '★[2026-10-03 v3] 도형님 uvtt 도면 map_153x83(한 칸 32px). 밸브로 흰 물막을 끄고 유령 발판을 검정으로 칠해 가시 구덩이를 건넌다 → '
                 '흰 물_2 를 공중에서 두 번 건너 격자 방 → 경사 통로 → 도약대 → 윗길 번갈이 물(3 초) → 수갱 낙하 중 흰색 → 흰 웅덩이 → 출구. '
                 '격자 방 오른쪽 흰 물_3 을 짧은 점프로 뚫는 지름길이 있다(도형님 확인 필요). 정답 발수 4.',
        '_출처': 'tools/build_하수도_2-2.gd 머리말 · docs/작업기록_2026-10-03_Claude_2-2_uvtt도면_재제작.md',
        '경로이름': {'정답': '정답(윗길 고리)', '지름길': '지름길(물_3)'},
        '방': [
            ('A', '시작 방 · 밸브', [0, 1072, 1904, 1984],
             '바닥 턱 위 검정 격자 3 장(G9 → G10 → G8)으로 왼쪽 선반에 올라 원형 밸브를 돌린다 → 구덩이를 덮은 흰 물_1 이 꺼진다.'),
            ('B', '가시 구덩이 · CP1', [1904, 1216, 2672, 1984],
             '흰 유령 발판 2 장. 물_1 이 켜져 있으면 검정 총알이 막힌다 → 끈 뒤 검정으로 칠해(2 발) 건넌다 → CP1. 앞에 흰 물_2(64 폭).'),
            ('C', '격자 방', [2656, 624, 3200, 1600],
             '물_2 를 뛰며 흰색 → 지나서 검정으로 착지. 검정 격자를 왼쪽 위(G20 → G17 → G15 → G14)로 올라 다시 물_2 를 건너 통로로. '
             '오른쪽 위(G18 → G22 → G23)에서 흰 물_3 을 짧은 점프로 뚫으면 CP3 지름길.'),
            ('D', '경사 통로 · 도약대', [768, 496, 2592, 1104],
             '천장 낮은 통로(128)를 왼쪽 위로 → 왼쪽 기둥 바닥의 도약대 ① 로 섬 선반(496)에 → 도약대 ③ 으로 윗길(384) · CP2.'),
            ('E', '번갈이 물', [1136, 128, 3616, 496],
             '천장까지 닿는 물 두 쌍(흰4↔검1 · 검2↔흰5)이 3 초마다 바뀐다 — 두 쌍은 늘 반대색. 검정일 때 걸어서 지나 사이에서 기다린다.'),
            ('F', '수갱 · 흰 웅덩이 · 출구', [3200, 128, 5360, 1100],
             '윗길 끝에서 떨어지며 흰색 → 흰 물_6 과 흰 웅덩이(금 간 흰 바닥) → 뛰며 검정 → 끝 통로 → 출구(2-3).'),
        ],
    },
    'stage_2-3': {
        '_요약': '★[2026-10-03 v3] 도형님 uvtt 도면 map_215x63(한 칸 32px). 갱도 바닥 밸브_1 로 흰 물_1 을 끄고 호퍼_1 을 걸어 건넌다 → '
                 '낙사 존 위 호퍼 4 개(흰·검·흰·검 물 속)를 공중 색 전환으로 → CP1 · 밸브_2(둘 다 → 흰만 → 검만 순환)로 호퍼_6 → '
                 '윗방 격자 → 밸브_3 으로 흰 물_8·9 끄기 → 투명발판 3·4 → 섬 윗길 → 도착. 틈으로 떨어지면 아래층(CP2 · 안 죽음)으로도 도착 = 두 갈래. 정답 발수 2.',
        '_출처': 'tools/build_하수도_2-3.gd 머리말 · docs/작업기록_2026-10-03_Claude_2-3_uvtt도면_재제작.md',
        '경로이름': {'정답': '정답(섬 윗길)', '아래길': '아래길(CP2)'},
        '방': [
            ('A', '시작 · 격자 갱도 · 호퍼_1', [224, 416, 1888, 1100],
             '시작 바닥 → 검정 격자 6 장 갱도. 흰 물_1 이 호퍼_1 로 떨어지고 출구로 흰 물_2 가 나온다(호퍼는 밟을 수 있다). '
             '갱도 바닥 밸브_1 로 물_1 을 끄면 물_2 도 끊긴다 → 격자로 올라 기둥 → 호퍼_1 을 걸어 건넌다.'),
            ('B', '낙사 존 · 호퍼 리듬', [1888, 368, 3008, 1400],
             '천장에서 흰3 · 검1 · 흰5 · 검3 이 호퍼 2~5 로 떨어진다. 호퍼 위는 물 속이라 공중에서 흰 → 검 → 흰 → 검. 바닥은 가시.'),
            ('C', 'CP1 · 밸브_2 · 호퍼_6', [3008, 368, 3712, 1440],
             '밸브_2 = 세 상태(둘 다 → 흰만 → 검만). 둘 다면 호퍼_6 위에 설 자리가 없다. 두 번 돌려 검정 몸으로(또는 한 번 · 흰 몸으로) 건넌다. 출구 색 = 들어온 색.'),
            ('D', '윗방 · 밸브_3', [3712, 128, 5424, 720],
             '벽 가시(세로) 옆 투명발판 1·2 · 검정 격자 3 → 막대 위 밸브_3 이 흰 물_8 을 끈다 → 호퍼_7 이 멈춰 흰 물_9 도 끊긴다.'),
            ('E', '섬 윗길 / 아래층 · 도착', [4512, 400, 7376, 1040],
             '투명발판 3·4 를 칠해(2 발) 섬으로 → 물_9 자리를 지나 도착. 틈으로 떨어지면 섬 아래 통로(128) → CP2 → 계단 → 도착(두 갈래).'),
        ],
    },
    'stage_2-4': {
        '_요약': '★[2026-10-07 v3] 도형님 uvtt 도면 2-4_403x107(한 칸 32px · 12,896×3,424). 물탱크 3 개 = 호퍼의 두 번째 입력: '
                 '검정으로 칠하면 흰 물이 회색이 된다(A·B) · C 는 고정 공급이 없어 칠한 색 그대로 물이 나온다. '
                 '발판_1 이 B 를 덮은 지형을 들이민다 · 검·흰 격자 번갈아 오르기 · 호퍼_4 흰 물은 공중 색 전환(벨브는 그 너머) · '
                 '움직이는 발판 · 낙사 존 위 부서지는 발판. 정답 발수 5.',
        '_출처': 'tools/build_하수도_2-4.gd 머리말 · docs/작업기록_2026-10-07_Claude_2-4_uvtt도면_재제작.md',
        '방': [
            ('A', '시작 복도 · 물탱크 A · 흰물 수갱', [224, 560, 3040, 1440],
             '가시 구덩이 둘을 넘어 바닥 구덩이의 물탱크 A 를 검정으로(1 발) → 호퍼_1 이 흰물_1 + 검정 = 회색 → 흰물_2 수갱의 검정 격자 5 장으로 오른다.'),
            ('B', '발판_1 · 물탱크 B · 호퍼 2', [3040, 560, 5040, 1650],
             '발판_1 을 밟으면 덮개가 오른쪽으로 들어간다 → 구덩이로 내려가 물탱크 B 를 검정으로(2 발) → 흰색물_4 회색 → '
             '바닥 한가운데서 뛰어 호퍼_2 밑 착지 발판으로(가장자리에서 뛰면 호퍼 밑면에 머리를 박는다). 밑은 가시 막다른 구덩이.'),
            ('C', '격자 사다리 · 물탱크 C', [5040, 200, 6944, 1100],
             '검정 격자 7 장을 지그재그로 올라 받침 위 물탱크 C 를 칠한다(2 발 · 고정 공급 없음 = 칠한 색 그대로 물_1). 받침 왼끝으로 내려와 수갱으로.'),
            ('D', '수갱 · CP2 · 가시 수갱', [6240, 1056, 7520, 3360],
             '1,248 떨어져 물웅덩이 홈에 선다 → CP2 → 징검발판으로 가시 수갱을 건넌다.'),
            ('E', '검·흰 격자 · 호퍼 4 · 벨브', [7520, 1050, 10048, 2300],
             '세로 톱 옆 격자 4 장(검·흰·검·흰)을 오를 때마다 공중 색 전환 → 호퍼_4 의 흰물_5 를 공중에서 흰색으로 지나 검정으로 → '
             '움직이는 발판을 아래 끝에서 타고 위 끝에서 벨브 선반으로 → 벨브로 흰물_5 를 끈다(돌아올 때 편하다). 왼쪽 선반 길은 내려오는 길.'),
            ('F', '낙사 존 · 부서지는 발판 · 도착', [10000, 1400, 12336, 2400],
             '부서지는 발판 2 → 4 로 건너뛴다(3 은 흰물_7 이 적신다 · 공중에서 흰색으로 지나 검정으로) → 도착 방 → 출구(2-5).'),
        ],
    },
    'stage_2-5': {
        '_요약': '레버로 물길을 잠그거나 돌린다. 펌프실에서 위/아래 두 갈래. 끝은 유령 두 장을 반대색으로 칠해 건너는 종합.',
        '_출처': 'scenes/world_2_클로드/작업/stage_2-5_작업.md · docs/작업기록_2026-09-05_Codex_하수도_2-5_제어레버.md(이후 레버 수가 바뀜 — 지금 씬 기준)',
        '방': [
            ('A', '첫 밸브', [128, 0, 2288, 1696],
             '시작하자마자 레버 L1 이 앞길의 흰 물 F1 을 잠근다 — 조작 결과를 가까이서 본다. 계단을 올라 펌프실로.'),
            ('B', '펌프실 — 위냐 아래냐', [2288, 0, 4600, 1696],
             '직선 레버 L2 가 흰 길막(A)과 위쪽 검정 배수(B) 중 하나를 흘린다. 아래로: B 로 돌리고 아래 검정 바닥 → 오른쪽 계단 → 상부 밸브실. '
             '위로: 그대로 두고 틈 두 곳에서 공중 색 전환 → 상부. 어느 쪽이든 레버 L3 이 두 번째 흰 길막 F3 을 끈다.'),
            ('C', '반대색으로 건넌다', [4600, 0, 6688, 1696],
             '레버 L4 로 흰 물 F4 를 끈다 → 호퍼 H4(색 규칙 밖) 위에서 흰색으로 흰 유령, 검정으로 검정 유령을 칠한다 → 두 장을 뛰어 건너며 흰색으로. '
             '빠지면 E 로 회수하고 아래 계단으로 복귀.'),
            ('D', '흰 출구', [6688, 0, 8800, 1696], '흰 바닥 복도 → 출구(2-6). 색 판단이 끝까지 남는다.'),
        ],
    },
    'stage_2-6': {
        '_요약': '2 층(아래 = 양동이 운반로 / 위 = 복귀로). 방마다 양동이 쓰임이 다르다: 굳혀서 딛기 · 구덩이 메우기 · 물 실어 나르기. 총은 안 쓴다(발수 0).',
        '_출처': 'tools/build_하수도_2-6.gd 머리말 · docs/작업기록_2026-09-21_Claude_2-6_무거운것_재제작.md',
        '방': [
            ('A', '받으면 굳는다', [0, 1984, 2496, 2600],
             '빈 검정 양동이를 문턱 앞 검정 물줄기 W1 까지 밀면 물을 받아 그 자리에서 굳는다 → 양동이를 딛고 문턱(224 — 바닥에서는 못 오름)을 넘는다.'),
            ('B', '구덩이를 메운다', [2496, 1984, 4736, 2600],
             '가시 슬롯에서 흰색으로. 흰 양동이를 가시 구덩이(352 폭 — 뛰어 못 넘음)에 떨어뜨리면 왼벽 관의 흰 물이 채워 굳힌다 → 양동이가 다리. 슬롯에서 검정으로.'),
            ('C', '실어 나른다', [4736, 1984, 7600, 2600],
             '회전톱을 지나 검정 양동이를 W3 에서 채워 배출구까지 민 뒤 E → 관을 타고 굴뚝 꼭대기 호퍼 H3 로 검정 물 → 고정 흰 물과 섞여 회색 → 격자 사다리를 오른다.'),
            ('D', '위층 — 색으로 닫는다', [4864, 1216, 9216, 1860],
             '왼쪽은 복귀로(막다른 곳 · 구멍으로 C 시작점에 떨어짐). 오른쪽: 구멍을 뛰어 → 슬롯에서 흰색 → 흰 구간 → 슬롯에서 검정 → 출구(2-7).'),
        ],
    },
    'stage_2-7': {
        '_요약': '버튼 다섯 개를 한 정비실(2 층)에 묶었다. 규칙이 다 다르다: 누르는 동안만 / 한 번 유지 / 물 찬 양동이만 / 둘이 동시에 / 땅을 끌어오기. '
                 '마지막은 흰 구간으로 색 게임을 되살린다. 발수 0.',
        '_출처': 'tools/build_하수도_2-7.gd 머리말 · docs/작업기록_2026-09-22_Claude_2-7_눌러두어라_재제작.md',
        '방': [
            ('A', '도입 — 유지와 순간', [0, 1984, 2688, 2600],
             '버튼 1(사람 · 한 번 누르면 유지) → 문 1. 버튼 2(박스 · 누르는 동안만) → 박스를 올려 두어야 문 2 가 열려 있다. 끝의 격자 굴뚝으로 위층에.'),
            ('B', '정비길 — 끊긴 다리', [2496, 1216, 5200, 1830],
             '위층을 걸어가면 가운데 틈(4000~5200)에 다리가 없다. 떨어지면 아래층 C.'),
            ('C', '다리를 만든다', [3392, 1984, 5904, 2600],
             '양동이를 검정 물에서 채워 양동이 전용 버튼 3 에 올려 두면 위층 틈에 다리가 밀려 나온다. 왼끝 굴뚝으로 위층에 되돌아가 다리를 건넌다. 오른끝은 막다른 곳(CP).'),
            ('D', '동시 · 끌어오기 · 흰 끝', [5200, 1216, 9216, 2048],
             '박스 2 를 버튼 4b 에, 사람이 버튼 4a 에 — 둘 다 눌려야 문 4. 박스 3 을 버튼 5 에 두면 움직이는 땅이 틈을 메운다. 가시 슬롯에서 흰색으로 → 흰 바닥 → 출구(2-8).'),
        ],
    },
    'stage_2-8': {
        '_요약': '3 층 「갈래」 — 갈래점에서 세 층 중 하나를 고르고 끝 방에서 합류. 층마다 앞 판들의 장치를 2~3 개씩 조합한 챕터 종합. 발수: 가운데 길 6 · 위/아래 길 2.',
        '_출처': 'tools/build_하수도_2-8.gd 머리말 · docs/작업기록_2026-09-22_Claude_2-8_갈래_재제작.md',
        '경로이름': {'정답': '가운데 길(L2)', '위층': '위층 길(L3)', '아래층': '아래층 길(L1)'},
        '방': [
            ('A', '입구 · 갈래점', [0, 1472, 2200, 2112],
             '입구는 가운데 층 왼쪽. 승강기(1600~1856)를 타면 위층 L3, 구멍(2000~2192)으로 떨어지면 아래층 L1, 그냥 걸으면 L2. 어느 길로 가도 끝 방에서 만난다.'),
            ('B', 'L3 — 물 위 격자 · 톱 · 검정 커튼', [1600, 704, 9616, 1300],
             '흰 웅덩이 위 검정 격자 4 → 세로 회전톱 2 → 슬롯(흰) → 흰 구간: 원형 레버로 검정 물 커튼을 끈다 · 선반 3 장을 오르면 막다른 곳(CP) '
             '→ 슬롯(검정) → 가시 구덩이 위 선반 → 구멍으로 끝 방.'),
            ('C', 'L2 — 유령 · 저장고 · 발판 · 양동이', [2200, 1472, 9216, 2140],
             '가시 구덩이 위 유령(2 발) → 저장고(2 발)로 천장 호퍼 흰 물을 회색으로 → 흰 웅덩이 위를 움직이는 발판으로 → 슬롯(흰) '
             '→ 흰 양동이를 흰 물에서 채워 버튼에 두면 흰 문이 열린다 → 슬롯(검정) → 끝 방.'),
            ('D', 'L1 — 물길', [1216, 2304, 9408, 2980],
             '흰 웅덩이 위 검정 격자 → 검정 웅덩이(그냥 걷는다) + 세로 톱 → 직선 레버로 흰 커튼을 옆 구덩이로 돌린다 '
             '→ 검정 양동이를 채워 배출구에서 E → 굴뚝 호퍼가 회색 → 격자 사다리로 끝 방.'),
            ('E', '끝 방 — 종합', [9408, 1472, 11520, 2140],
             '흰 웅덩이 위 격자 + 유령(2 발) → 박스를 버튼에 → 문 → 출구.'),
        ],
    },
    'stage_2-9': {
        '_요약': '방 연결형 배수실(Codex 2026-09-23 재구축). 방향이 → ↑ ← ↓ → ↑ ← ↑ → 로 엇갈리며 오른쪽 위 출구로 간다. '
                 '주철 호퍼 1 · 밸브 1 · 압력 버튼 2 · 승강 발판 1 · 왕복 톱 2.',
        '_출처': 'scenes/world_2_클로드/작업/stage_2-9_작업.md',
        '_경로없음': '주행검사 공략표의 2-9 경로는 폐기된 옛 3 층 판용이라(좌표가 지금 맵 밖) 그리지 않았다 — 흐름은 방 순서 화살표로 표시.',
        '방': [
            ('A', '입구', [448, 3776, 2432, 4480],
             '발높이 4096. 검정 → 흰 징검 → 검정(틈 160). 떨어지면 회색 물받이 → 복귀 격자 2 개로 재도전.'),
            ('B', '상승 갱도', [2176, 3200, 2432, 4100],
             '원웨이 격자 7 개를 좌우 교대로 밟아 3968 → 3200 으로 오른다.'),
            ('C', '호퍼실', [512, 2688, 2432, 3296],
             '오른쪽 → 왼쪽. 검정·흰 공급이 주철 호퍼로 → 회색 출력. 밸브로 흰 공급을 끊으면 출력이 검정이 된다. 왼쪽 버튼이 아래 E 의 진입 수문을 연다.'),
            ('D', '배수로', [512, 3296, 2432, 3712],
             'C 왼쪽에서 512 내려와 발높이 3712. 호퍼 출력 물 아래를 오른쪽으로 지나 기계실로.'),
            ('E', '기계실', [2560, 3200, 4608, 4480],
             '왕복 톱을 보고 → 유지 버튼 → 연결 발판이 256 올라온다 → 5 초 주기 승강 발판으로 768 상승. 실패하면 물받이와 복귀 격자.'),
            ('F', '상부 통로', [2560, 2624, 4416, 3040],
             '왼쪽으로 진행(3968 → 3008) · 두 번째 왕복 톱 · 엇갈린 원웨이 격자 6 개로 위층에.'),
            ('G', '출구', [2688, 1536, 6400, 2624],
             '발높이 2048/1968. 흰 착지 발판 · 검정 높은 발판 · 얇은 흰 물 통과 → 오른쪽 출구(지금은 로비로). 떨어지면 회색 수조 → 복귀 격자.'),
        ],
    },
}

물색 = {'검정': '#050506', '흰색': '#f4f6f8', '회색': '#7d8288'}
죽는몸 = {'검정': '흰 몸 사망', '흰색': '검정 몸 사망', '회색': '누구나 안전'}
경로색 = ['#ff9d2e', '#4fd1ff', '#9be15d']          # 정답 · 갈래 1 · 갈래 2


def esc(s):
    return html.escape(str(s), quote=True)


def 안에있나(pt, poly):
    x, y = pt
    inside = False
    for i in range(len(poly)):
        (x1, y1), (x2, y2) = poly[i], poly[(i + 1) % len(poly)]
        if (y1 > y) != (y2 > y) and x < (x2 - x1) * (y - y1) / (y2 - y1 + 1e-9) + x1:
            inside = not inside
    return inside


class 바닥:
    """세로 광선으로 윗면을 찾는다 — 걷는 경로를 바닥에 붙이는 데 쓴다.
    ⚠ 수평 변만 찾으면 안 된다: 2-1 은 Codex 의 자연발판(울퉁불퉁한 윗면)이라 수평 변이 거의 없다."""

    def __init__(self, 지형들):
        # 유령도 넣는다 — 공략이 칠한 뒤에 그 위를 걷는다(2-1 G3). 칠하지 않은 유령 위로는 공략이 애초에 안 걷는다.
        self.폴리 = [t['poly'] for t in 지형들]
        self.색 = [t.get('color', '') for t in 지형들]

    def 벽인가(self, x, y):
        """그 점이 지형 속인가(유령·장치 제외 — 칠한 유령이나 격자는 몸을 막지 않는 것으로 친다)."""
        return any(안에있나((x, y), p) for p, c in zip(self.폴리, self.색) if c not in ('유령', '장치'))

    def 아래(self, x, y_위):
        """x 에서 y_위 보다 아래(같거나 큰) 가장 가까운 '위에서 들어가는' 면."""
        best = None
        for p in self.폴리:
            for i in range(len(p)):
                (x1, y1), (x2, y2) = p[i], p[(i + 1) % len(p)]
                if (x1 <= x < x2) or (x2 <= x < x1):
                    y = y1 + (y2 - y1) * (x - x1) / (x2 - x1)
                    if y >= y_위 and (best is None or y < best) and 안에있나((x, y + 3), p) and not 안에있나((x, y - 3), p):
                        best = y
        return best


def 밟는것들(G):
    """걷는 경로가 붙을 면 — 지형 + 밟을 수 있는 장치의 윗면 사각형.
    장치를 빼면 격자 사다리(2-2 갱도 · 2-4 굴뚝) 위를 걷는 구간이 아래층까지 떨어지는 가짜 낙하로 그려진다."""
    out = [n for n in G['nodes'] if n['kind'] == '지형']
    for n in G['nodes']:
        if n['kind'] in ('격자', '호퍼', '저장고', '발판', '양동이', '박스', '버튼'):
            x0, x1, y0 = n['x'] - n['w'] / 2, n['x'] + n['w'] / 2, n['y']
            out.append({'color': '장치', 'poly': [[x0, y0], [x1, y0], [x1, y0 + max(n['h'], 8)], [x0, y0 + max(n['h'], 8)]]})
    return out


def 경로_그리기(steps, 시작, 바닥면, by_name):
    """공략표 → (선분 목록, 표식 목록). 선분 = [('walk'|'jump'|'shot', 점들)], 표식 = (번호, x, y, 종류, 글)."""
    x, y = 시작
    색 = '검정'
    선 = []
    표식 = []

    def 걷기(x_to, y_끝=None):
        nonlocal x, y
        pts = [(x, y)]
        step = 16 if x_to >= x else -16
        cx = x
        cy = y
        while (x_to - cx) * step > 0:
            nx_ = cx + step if abs(x_to - cx) > 16 else x_to
            if 바닥면.벽인가(nx_, cy - 140):
                break                          # 몸 높이(머리 쪽)에 벽 — 공략이 벽 앞까지 "가" 하는 자리. 뚫고 지나가 아래로 떨어지지 않게 멈춘다
            cx = nx_
            ny = 바닥면.아래(cx, cy - 130)      # 턱은 130 까지 오른다 · 없으면 그대로(허공 = 떨어지는 중)
            if ny is not None and ny - cy <= 1500:
                cy = ny
            pts.append((cx, cy))
        if y_끝 is not None:
            pts.append((x_to, y_끝))
            cy = y_끝
        x, y = x_to, cy
        선.append(('walk', pts))

    for i, s in enumerate(steps, 1):
        cmd = s[0]
        try:
            if cmd == '가':
                걷기(float(s[1]))
                표식.append((i, x, y, 'walk', f'걷기 → x {float(s[1]):.0f}'))
            elif cmd == '걸어':
                걷기(float(s[1]), float(s[2]))
                표식.append((i, x, y, 'walk', f'걸어 내려감 → ({float(s[1]):.0f}, {float(s[2]):.0f})'))
            elif cmd in ('뛰기', '뛰기색', '뛰기정', '뛰기정색', '뛰기두색', '뛰기정경계색', '튕겨'):
                # ★[2026-10-03] 뛰기정(짧은 점프 · 2-1) · 뛰기두색(공중 두 번 전환 · 2-2) · 튕겨(도약대 · 2-2)도 포물선으로.
                #   예전엔 '뛰기'·'뛰기색' 만 알아 2-1 격자 구간 경로가 끊겨 그려졌다.
                if cmd == '튕겨':
                    t = by_name.get(s[1])
                    x0 = t['x'] if t else x
                    x1, y1 = float(s[2]), float(s[3])
                else:
                    x0, x1, y1 = float(s[1]), float(s[2]), float(s[3])
                if abs(x0 - x) > 1:
                    걷기(x0)
                꼭대기 = min(y, y1) - (60 if cmd == '튕겨' else 150)
                조절 = 2 * 꼭대기 - (y + y1) / 2          # 2 차 베지어의 조절점 — 곡선 가운데가 꼭대기에 닿게
                pts = []
                for k in range(21):
                    t = k / 20
                    bx = x0 + (x1 - x0) * t
                    by = (1 - t) ** 2 * y + 2 * (1 - t) * t * 조절 + t ** 2 * y1
                    pts.append((bx, by))
                선.append(('jump', pts))
                if cmd in ('뛰기색', '뛰기정색'):
                    색 = s[4]
                    mx, my = pts[10]
                    표식.append((i, mx, my, 'swap', f'뛰는 중 {색}으로 전환 → 착지 ({x1:.0f}, {y1:.0f})'))
                elif cmd == '뛰기두색':
                    mx, my = pts[10]
                    표식.append((i, mx, my, 'swap', f'뜨자마자 {s[4]} → x {float(s[5]):.0f} 지나 {s[6]} → 착지 ({x1:.0f}, {y1:.0f})'))
                elif cmd == '뛰기정경계색':
                    # ★[2026-10-03] 2-3 호퍼 리듬 — 앞 물을 벗어난 뒤(경계x) 한 번 바꾼다.
                    mx, my = pts[10]
                    표식.append((i, mx, my, 'swap', f'x {float(s[4]):.0f} 지나 {s[5]}으로 전환 → 착지 ({x1:.0f}, {y1:.0f})'))
                elif cmd == '튕겨':
                    표식.append((i, x0, y, 'jump', f'{s[1]} 로 튕겨 → ({x1:.0f}, {y1:.0f})'))
                else:
                    표식.append((i, x1, y1, 'jump', f'뛰기 {x0:.0f} → ({x1:.0f}, {y1:.0f})'))
                x, y = x1, y1
            elif cmd == '떨어져색':
                걷기(float(s[1]), float(s[2]))
                표식.append((i, x, y, 'swap', f'떨어지며 {s[3]}으로 전환 → ({float(s[1]):.0f}, {float(s[2]):.0f})'))
            elif cmd == '켜짐기다림':
                표식.append((i, x, y, 'check', f'{s[1]} 이 켜질 때까지 기다림'))
            elif cmd == '칠':
                t = by_name.get(s[1])
                if t:
                    tx = t['x']
                    ty = (t['bbox'][1] + t['bbox'][3]) / 2 if 'bbox' in t else t['y']
                    선.append(('shot', [(x, y - 60), (tx, ty)]))
                    표식.append((i, tx, ty, 'shot', f'{s[1]} 를 {s[2]}으로 칠함'))
            elif cmd == '레버':
                t = by_name.get(s[1])
                if t:
                    걷기(t['x'])
                    표식.append((i, x, y, 'lever', f'{s[1]} 당김'))
            elif cmd == '색':
                색 = s[1]
                표식.append((i, x, y, 'swap', f'{색}으로 전환'))
            elif cmd == '밀기':
                t = by_name.get(s[1])
                if t:
                    걷기(float(s[2]))
                    표식.append((i, x, y, 'push', f'{s[1]} 밀기 → x {float(s[2]):.0f}'))
            elif cmd == '확인':
                표식.append((i, x, y, 'check', f'{s[1]} 상태 확인'))
        except (ValueError, IndexError):
            continue
    return 선, 표식


def 보충(G, by_name, key):
    """`맵그래프.stage_graph` 가 놓치는 노드를 더한다(2026-10-01 · 2-9 에서 드러남).
    - 격자를 스크립트로 붙인 StaticBody2D(통과플랫폼.gd) — 2-9 의 격자 22 개
    - 주철 호퍼(호퍼_주철_직하/좌하/우하.tscn) — 이름에 '호퍼.tscn' 이 없어 빠졌다
    - 모양(_points)이 프리팹 안에만 있는 지형 인스턴스(공중발판 프리팹 · 2-9 E_연결발판)
    맵그래프.py 는 건드리지 않는다(관계 그래프 쪽 결과가 바뀌지 않게)."""
    import re
    path = mg.ROOT / f'scenes/world_2_클로드/{key}.tscn'
    ext, subs, nodes = mg.parse_scene(path)
    for n in nodes:
        if n['name'] in by_name or n['parent'] not in ('지형', '장치'):
            continue
        p = n['props']
        pos = mg.vec(re.search(r'\(([^)]+)\)', p['position'])[1]) if 'position' in p else [0.0, 0.0]
        inst = n['inst'] or ''
        스크립트 = ext.get((re.search(r'script = ExtResource\("([^"]+)"\)', n['block']) or [None, ''])[1], '') or ''
        item = None
        if n['type'] == 'StaticBody2D' and 스크립트.endswith('통과플랫폼.gd'):
            size = mg.vec(re.search(r'\(([^)]+)\)', p.get('크기', 'Vector2(128, 16)'))[1])
            item = {'id': n['name'], 'kind': '격자', 'x': pos[0], 'y': pos[1] - size[1] / 2, 'w': size[0], 'h': size[1],
                    'detail': f'통과플랫폼(격자) · {size[0]:.0f}×{size[1]:.0f}'}
        elif n['parent'] == '장치' and '호퍼' in inst:
            폭 = float(p.get('폭', '200')); 높이 = float(p.get('높이', '164'))
            item = {'id': n['name'], 'kind': '호퍼', 'x': pos[0], 'y': pos[1] - 높이, 'w': 폭, 'h': 높이 + 40,
                    'detail': f'주철 호퍼(밟을 수 있음 · 색 규칙 밖) · 폭 {폭:.0f}'}
        elif n['parent'] == '지형' and '지형' in inst and inst.startswith('res://'):
            ext2, subs2, nodes2 = mg.parse_scene(mg.ROOT / inst[len('res://'):])
            pts = mg.points_of(nodes2[0]['props'], subs2) if nodes2 else None
            if pts:
                poly = [[q[0] + pos[0], q[1] + pos[1]] for q in pts]
                bb = mg.bbox(pts, pos)
                color = '흰색' if '흰' in inst else '검정'
                item = {'id': n['name'], 'kind': '지형', 'color': color, 'ledge': True, 'role': '플랫폼', 'poly': poly, 'bbox': bb,
                        'x': (bb[0] + bb[2]) / 2, 'y': bb[1], 'detail': f'{color} · 프리팹 발판 · {bb[2]-bb[0]:.0f}×{bb[3]-bb[1]:.0f}'}
        if item:
            item['stage'] = key
            G['nodes'].append(item)
            by_name[item['id']] = item


def 방들(G, key):
    """메모의 방 사각형. 없으면 지형 이름 접두어로 x 띠를 만든다(옛 방식)."""
    if 메모.get(key, {}).get('방'):
        return [{'k': k, 'title': t, 'rect': r, 'text': d} for (k, t, r, d) in 메모[key]['방']]
    return [{'k': k, 'title': '', 'rect': [b[0], G['frame'][1], b[2], G['frame'][1] + G['frame'][3]], 'text': '(메모 없음)'}
            for k, b in 구역들(G).items()]


def 구역들(G):
    """지형 이름 접두어(A_·B2_·C_ …의 첫 글자)로 구역 x 범위를 만든다."""
    z = {}
    for n in G['nodes']:
        if n['kind'] != '지형' or n['id'].startswith('외곽'):
            continue
        k = n['id'][0]
        if not k.isalpha() or not k.isupper():
            continue
        if n['bbox'][2] - n['bbox'][0] > G['frame'][2] * 0.6:
            continue             # 판 전체를 가로지르는 바닥은 구역 경계를 흐린다
        b = z.setdefault(k, [1e9, 1e9, -1e9, -1e9])
        b[0] = min(b[0], n['bbox'][0]); b[1] = min(b[1], n['bbox'][1])
        b[2] = max(b[2], n['bbox'][2]); b[3] = max(b[3], n['bbox'][3])
    # 구역끼리 겹치면 가운데서 자른다(벽 두께가 두 구역에 걸친다)
    ks = sorted(z, key=lambda k: z[k][0])
    for a, b in zip(ks, ks[1:]):
        if z[a][2] > z[b][0]:
            m = (z[a][2] + z[b][0]) / 2
            z[a][2] = z[b][0] = m
    fx0, fx1 = G['frame'][0], G['frame'][0] + G['frame'][2]
    if ks:
        z[ks[0]][0] = max(fx0, z[ks[0]][0])
        z[ks[-1]][2] = min(fx1, z[ks[-1]][2])
    return {k: z[k] for k in ks}


def svg_도안(G, by_name, routes):
    fx, fy, fw, fh = G['frame']
    M = 260
    vb = f'{fx - M} {fy - M - 260} {fw + 2 * M} {fh + 2 * M + 260}'
    o = [f'<svg id="map" viewBox="{vb}" xmlns="http://www.w3.org/2000/svg">']
    o.append('''<defs>
<pattern id="ghost" width="40" height="40" patternUnits="userSpaceOnUse" patternTransform="rotate(45)"><rect width="40" height="40" fill="rgba(180,140,255,.18)"/><line x1="0" y1="0" x2="0" y2="40" stroke="rgba(190,150,255,.55)" stroke-width="10"/></pattern>
<clipPath id="frame"><rect x="%s" y="%s" width="%s" height="%s"/></clipPath>
<marker id="ahbig" viewBox="0 0 10 10" refX="6" refY="5" markerWidth="4" markerHeight="4" orient="auto"><path d="M0,0 L10,5 L0,10 z" fill="#ffd166"/></marker>
<marker id="ah" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="5" markerHeight="5" orient="auto"><path d="M0,0 L10,5 L0,10 z" fill="context-stroke"/></marker>
</defs>''' % (fx, fy, fw, fh))
    # 공기(배경) + 격자
    o.append(f'<rect x="{fx}" y="{fy}" width="{fw}" height="{fh}" fill="var(--air)"/>')
    o.append('<g class="grid">')
    for gx in range(int(fx), int(fx + fw) + 1, 512):
        o.append(f'<line x1="{gx}" y1="{fy}" x2="{gx}" y2="{fy + fh}"/><text x="{gx + 12}" y="{fy + fh + 90}">{gx}</text>')
    for gy in range(int(fy), int(fy + fh) + 1, 512):
        o.append(f'<line x1="{fx}" y1="{gy}" x2="{fx + fw}" y2="{gy}"/><text x="{fx - 20}" y="{gy + 28}" text-anchor="end">{gy}</text>')
    o.append('</g>')
    # 방 — 사각형 테두리 + 왼위 이름표(방 A · 제목). 층 구조 맵은 방이 위아래로 쌓인다.
    zs = 방들(G, G['id'])
    o.append('<g class="zones">')
    for z in zs:
        x0, y0, x1, y1 = z['rect']
        o.append(f'<rect x="{x0 + 10}" y="{y0 + 10}" width="{x1 - x0 - 20}" height="{y1 - y0 - 20}" rx="24" class="room"/>')
    o.append('</g>')
    # 지형
    o.append('<g clip-path="url(#frame)">')
    칠색 = {}
    for rk, steps in routes.items():
        for s in steps:
            if s and s[0] == '칠' and len(s) > 2:
                칠색[s[1]] = s[2]
    for n in G['nodes']:
        if n['kind'] != '지형' or n['id'].startswith('외곽'):
            continue
        pts = ' '.join(f'{p[0]:.0f},{p[1]:.0f}' for p in n['poly'])
        cls = {'검정': 'tb', '흰색': 'tw', '회색': 'tg', '유령': 'tghost', '무색': 'tghost'}.get(n['color'], 'tb')
        tip = f"{n['id']} — {n['detail']}"
        o.append(f'<polygon points="{pts}" class="{cls}"><title>{esc(tip)}</title></polygon>')
    o.append('</g>')
    # 유령 발판 이름표
    o.append('<g class="labels">')
    for n in G['nodes']:
        if n['kind'] == '지형' and n['color'] == '유령':
            c = 칠색.get(n['id'])
            글 = n['id'].split('_')[1] if '_' in n['id'] else n['id']
            뒤 = f" · {c} {n.get('필요횟수', 1)}발" if c else ' · 함정(칠해도 지워짐)'
            o.append(f'<text x="{n["x"]}" y="{n["bbox"][1] - 22}" text-anchor="middle" class="lbl ghost">유령 {esc(글)}{esc(뒤)}</text>')
    o.append('</g>')
    # 물 · 웅덩이
    o.append('<g class="water">')
    for n in G['nodes']:
        if n['kind'] == '유체':
            x0 = n['x'] - n['w'] / 2
            cls = 'wf' if n['on'] else 'wf off'
            o.append(f'<rect x="{x0}" y="{n["y"]}" width="{n["w"]}" height="{n["h"]}" class="{cls}" fill="{물색[n["color"]]}"><title>{esc(n["id"] + " — " + n["detail"])}</title></rect>')
            o.append(f'<path d="M{n["x"] - n["w"]} {n["y"] + n["h"]} q{n["w"] / 2} -30 {n["w"]} 0 q{n["w"] / 2} 30 {n["w"]} 0" class="splash"/>')
            글 = f'{n["color"]} 물 · {죽는몸[n["color"]]}' + ('' if n['on'] else ' · 처음엔 꺼짐')
            cls = f'lbl water {"haz" if n["color"] != "회색" else ""}'
            if n['h'] >= 300:
                # 긴 물줄기는 이름표를 물줄기 옆에 세로로 세운다 — 가로로 두면 옆 물줄기 이름표와 겹친다(2-1 W1·W2 는 384 간격)
                tx, ty = n['x'] + n['w'] / 2 + 16, n['y'] + 30
                o.append(f'<text x="{tx}" y="{ty}" transform="rotate(90 {tx} {ty})" class="{cls}">{esc(n["id"].split("_")[0])} {esc(글)}</text>')
            else:
                o.append(f'<text x="{n["x"] + n["w"] / 2 + 18}" y="{n["y"] + 70}" class="{cls}">{esc(n["id"].split("_")[0])} {esc(글)}</text>')
        elif n['kind'] == '웅덩이':
            x0 = n['x'] - n['w'] / 2
            o.append(f'<rect x="{x0}" y="{n["y"]}" width="{n["w"]}" height="{n["h"]}" class="wf pool" fill="{물색[n["color"]]}"><title>{esc(n["id"] + " — " + n["detail"])}</title></rect>')
            o.append(f'<text x="{n["x"]}" y="{n["y"] - 20}" text-anchor="middle" class="lbl water {"haz" if n["color"] != "회색" else ""}">{esc(n["color"])} 웅덩이 · {esc(죽는몸[n["color"]])}</text>')
    o.append('</g>')
    # 가시 · 톱 · 호퍼 · 격자 · 기타 장치
    o.append('<g class="devices">')
    for n in G['nodes']:
        k = n['kind']
        if k == '가시':
            칸 = int(n['w'] // 32)
            x0 = n['x'] - n['w'] / 2
            base = n['y'] + 11
            d = ''.join(f'M{x0 + 32 * i} {base} l16 -26 l16 26 z ' for i in range(칸))
            o.append(f'<path d="{d}" class="spike"><title>{esc(n["id"] + " — " + n["detail"])}</title></path>')
            o.append(f'<text x="{n["x"]}" y="{base + 70}" text-anchor="middle" class="lbl haz">가시</text>')
        elif k == '회전톱':
            o.append(f'<circle cx="{n["x"]}" cy="{n["y"]}" r="36" class="spike"><title>{esc(n["detail"])}</title></circle>')
        elif k in ('호퍼', '격자', '저장고', '양동이', '박스', '버튼', '발판'):
            o.append(f'<rect x="{n["x"] - n["w"] / 2}" y="{n["y"]}" width="{n["w"]}" height="{n["h"]}" class="dev {k}"><title>{esc(n["id"] + " — " + n["detail"])}</title></rect>'
                     f'<text x="{n["x"]}" y="{n["y"] - 16}" text-anchor="middle" class="lbl">{esc(k)}</text>')
        elif k == '레버':
            o.append(f'<g class="lever"><line x1="{n["x"]}" y1="{n["y"]}" x2="{n["x"] + 30}" y2="{n["y"] - 90}"/><circle cx="{n["x"] + 30}" cy="{n["y"] - 90}" r="20"/>'
                     f'<title>{esc(n["id"] + " — " + n["detail"])}</title></g>'
                     f'<text x="{n["x"]}" y="{n["y"] - 130}" text-anchor="middle" class="lbl leverl">{esc(n["id"].replace("_", " "))}</text>')
            for t in n.get('targets', []):
                if t in by_name:
                    tn = by_name[t]
                    o.append(f'<path d="M{n["x"] + 30} {n["y"] - 90} Q{(n["x"] + tn["x"]) / 2} {min(n["y"], tn["y"]) - 250} {tn["x"]} {tn["y"] + 40}" class="leverlink" marker-end="url(#ah)"/>')
        elif k == '체크포인트':
            o.append(f'<g class="cp"><line x1="{n["x"]}" y1="{n["y"]}" x2="{n["x"]}" y2="{n["y"] - 120}"/><path d="M{n["x"]} {n["y"] - 120} l60 20 l-60 20 z"/><title>{esc(n["id"])}</title></g>')
        elif k == '통로':
            if n.get('next'):
                o.append(f'<g class="exit"><path d="M{n["x"] - 60} {n["y"] - 70} h90 v-40 l80 70 l-80 70 v-40 h-90 z"/></g>'
                         f'<text x="{n["x"]}" y="{n["y"] - 150}" text-anchor="middle" class="lbl big">출구 → {esc(n["next"])}</text>')
        elif k == '플레이어':
            o.append(f'<circle cx="{n["x"]}" cy="{n["y"] - 60}" r="44" class="start"/><text x="{n["x"]}" y="{n["y"] - 150}" text-anchor="middle" class="lbl big">시작</text>')
    o.append('</g>')
    # 규모 기준 — 화면 한 장(줌 1.0) · 점프
    sx, sy = fx + 260, fy + 230
    o.append(f'<g class="scale"><rect x="{sx}" y="{sy}" width="1920" height="1080"/><text x="{sx + 20}" y="{sy + 70}">화면 한 장 1920×1080 (줌 1.0)</text></g>')
    # 경로 — 공략표에서 「헛걸음」 은 빼고(도형님 2026-10-01), 정답 + 실제 갈래(2-2 탑 · 2-8 위층/아래층)만 그린다.
    바닥면 = 바닥(밟는것들(G))
    시작 = next(((n['x'], n['y']) for n in G['nodes'] if n['kind'] == '플레이어'), tuple(G.get('start', [0, 0])))
    이름표 = 메모.get(G['id'], {}).get('경로이름', {})
    경로정보 = []
    쓸것 = [] if 메모.get(G['id'], {}).get('_경로없음') else [k for k in routes if '헛걸음' not in k]
    # 정답을 맨 마지막에 그려 맨 위에 오게 한다 — 갈래 경로는 앞부분이 정답과 겹쳐서, 먼저 그리면 정답이 가려진다
    정답표식 = []
    if G['id'] in 쓸것:
        _, 정답표식 = 경로_그리기(routes[G['id']], 시작, 바닥면, by_name)
    순서 = sorted(쓸것, key=lambda k: (k == G['id'], k))
    갈래번호 = 1
    for rk in 순서:
        steps = routes[rk]
        원이름 = rk.replace(G['id'], '').strip() or '정답'
        label = 이름표.get(원이름, 원이름)
        곁길 = rk != G['id']
        색 = 경로색[0] if not 곁길 else 경로색[min(갈래번호, len(경로색) - 1)]
        if 곁길:
            갈래번호 += 1
        선, 표식 = 경로_그리기(steps, 시작, 바닥면, by_name)
        gid = f'route-{len(경로정보)}'
        o.append(f'<g id="{gid}" class="route{" side" if 곁길 else ""}" style="--rc:{색}">')
        for kind, pts in 선:
            d = 'M' + ' L'.join(f'{p[0]:.0f} {p[1] - 40:.0f}' for p in pts)
            o.append(f'<path d="{d}" class="r{kind}"/>')
        for (i, x, y, kind, 글) in 표식:
            if kind in ('walk', 'check'):
                continue
            if 곁길 and any(k2 == kind and abs(x2 - x) < 80 and abs(y2 - y) < 80 for (_, x2, y2, k2, _) in 정답표식):
                continue          # 정답과 같은 자리의 같은 동작 — 표식을 겹쳐 찍지 않는다(갈라지는 구간만)
            아이콘 = {'swap': '', 'shot': '●', 'lever': 'E', 'push': '⇢', 'jump': ''}.get(kind, '')
            o.append(f'<g class="step s{kind}"><circle cx="{x:.0f}" cy="{y - 40:.0f}" r="{34 if kind == "jump" else 46}"/>'
                     f'<text x="{x:.0f}" y="{y - 24:.0f}" text-anchor="middle">{아이콘}</text><title>{esc(글)}</title></g>')
        o.append('</g>')
        경로정보.append({'id': gid, 'label': label, 'color': 색,
                        'shots': sum(1 for s in steps if s and s[0] == '칠'),
                        'swaps': sum(1 for s in steps if s and s[0] in ('색', '뛰기색', '뛰기정색', '떨어져색', '뛰기정경계색'))
                                 + 2 * sum(1 for s in steps if s and s[0] == '뛰기두색')})
    # 공략이 없으면 방 순서 화살표로 흐름을 보인다(2-9)
    if not 경로정보 and len(zs) > 1:
        o.append('<g class="order">')
        중심 = [((z['rect'][0] + z['rect'][2]) / 2, (z['rect'][1] + z['rect'][3]) / 2) for z in zs]
        for (ax, ay), (bx, by) in zip(중심, 중심[1:]):
            mx, my = (ax + bx) / 2, (ay + by) / 2
            nx, ny = -(by - ay), (bx - ax)
            L = max((nx * nx + ny * ny) ** 0.5, 1)
            cx, cy = mx + nx / L * 180, my + ny / L * 180
            o.append(f'<path d="M{ax:.0f} {ay:.0f} Q{cx:.0f} {cy:.0f} {bx:.0f} {by:.0f}" marker-end="url(#ahbig)"/>')
        o.append('</g>')
    # 방 이름표 — 맨 위에(지형·경로에 안 가리게)
    o.append('<g class="roomlabels">')
    for z in zs:
        x0, y0 = z['rect'][0], z['rect'][1]
        # 폭이 좁은 방(2-9 B 상승 갱도 256)은 제목이 옆 방 이름표를 덮는다 — 지도엔 글자 원만, 제목은 아래 카드에
        제목 = f' · {z["title"]}' if z['title'] and z['rect'][2] - z['rect'][0] >= 700 else ''
        o.append(f'<g class="roomchip"><circle cx="{x0 + 90}" cy="{y0 + 90}" r="58"/><text x="{x0 + 90}" y="{y0 + 118}" text-anchor="middle" class="rk">{esc(z["k"])}</text>'
                 f'<text x="{x0 + 166}" y="{y0 + 112}" class="rt">{esc(제목[3:] if 제목 else "")}</text></g>')
    o.append('</g>')
    o.append('</svg>')
    return '\n'.join(o), 경로정보, zs


PAGE = r'''<!doctype html>
<html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>__TITLE__ 도안</title>
<style>
:root{--bg:#16181c;--panel:#1f2228;--fg:#e9e9e6;--dim:#9aa0a8;--air:#3a3f47;--line:#2c3037;--haz:#ff5d5d;--acc:#ff9d2e}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--fg);font:14px/1.55 "Malgun Gothic","Apple SD Gothic Neo",system-ui,sans-serif}
header{padding:18px 20px 6px}h1{margin:0;font-size:22px}header p{margin:6px 0 0;color:var(--dim);max-width:1100px}
.bar{display:flex;flex-wrap:wrap;gap:6px 14px;align-items:center;padding:8px 20px;position:sticky;top:0;background:var(--bg);z-index:2;border-bottom:1px solid var(--line)}
.bar label{color:var(--dim);cursor:pointer;user-select:none}.bar button{background:var(--panel);color:var(--fg);border:1px solid #3a3f47;border-radius:6px;padding:3px 10px;cursor:pointer}
.stats{margin-left:auto;color:var(--dim);font-size:13px}
#wrap{overflow:auto;padding:10px 16px}#map{width:100%;display:block;background:#101215;border-radius:8px}
.grid line{stroke:#ffffff10;stroke-width:4}.grid text{fill:#6c727b;font-size:56px}
.room{fill:#ffd16608;stroke:#ffd16666;stroke-width:8;stroke-dasharray:46 26}
.roomchip circle{fill:#ffd166;stroke:#101215;stroke-width:8}.roomchip .rk{fill:#101215;font-size:84px;font-weight:800}
.roomchip .rt{fill:#ffe3a3;font-size:66px;font-weight:700;paint-order:stroke;stroke:#101215;stroke-width:16px;stroke-linejoin:round}
.order path{fill:none;stroke:#ffd166;stroke-width:22;opacity:.8;stroke-linecap:round}
.tb{fill:#08090a;stroke:#5b6068;stroke-width:5}.tw{fill:#eeeeea;stroke:#9aa0a8;stroke-width:5}.tg{fill:#8a8f96}
.tghost{fill:url(#ghost);stroke:#b48cff;stroke-width:6;stroke-dasharray:22 14}
.wf{stroke:#3fa7ff;stroke-width:8;opacity:.95}.wf.off{fill:transparent!important;stroke-dasharray:24 18;opacity:.8}.wf.pool{stroke-width:10}
.splash{fill:none;stroke:#3fa7ff;stroke-width:6}
.lbl{fill:#dfe3e8;font-size:58px;paint-order:stroke;stroke:#101215;stroke-width:14px;stroke-linejoin:round}
.lbl.haz{fill:#ff8a8a}.lbl.water{fill:#8cc8ff}.lbl.water.haz{fill:#ffb0b0}.lbl.ghost{fill:#d2b8ff}.lbl.big{font-size:72px;font-weight:700}.lbl.leverl{fill:#ff8ad8;font-weight:700}
.spike{fill:#ff4d4d;stroke:#5a0000;stroke-width:3}
.lever line{stroke:#ff8ad8;stroke-width:12}.lever circle{fill:#ff8ad8}.leverlink{fill:none;stroke:#ff8ad8;stroke-width:8;stroke-dasharray:30 20}
.cp line{stroke:#ffd84d;stroke-width:8}.cp path{fill:#ffd84d}
.exit path{fill:#5ad1ff}.start{fill:#6ee7a0;stroke:#0b3;stroke-width:6}
.dev{fill:#ffb347;stroke:#7a4a00;stroke-width:4}
.scale rect{fill:none;stroke:#ffffff30;stroke-width:6;stroke-dasharray:18 14}.scale text{fill:#ffffff55;font-size:52px}
.route path{fill:none;stroke:var(--rc);stroke-linecap:round;stroke-linejoin:round}
.route .rwalk{stroke-width:14;opacity:.9}.route.side path{stroke-width:9!important;opacity:.75}.route.side .step circle{r:38px}.route .rjump{stroke-width:12;stroke-dasharray:28 16;opacity:.95}.route .rshot{stroke-width:7;stroke-dasharray:6 18;opacity:.9}
.step circle{fill:#101215;stroke:var(--rc);stroke-width:8}.step text{fill:#fff;font-size:48px;font-weight:700}
.step.sswap circle{fill:url(#swapfill);stroke-width:10}.step.sshot circle{stroke-dasharray:10 8}.step.slever circle{stroke:#ff8ad8}
.step:hover circle,.step.hl circle{stroke:#fff;stroke-width:14}
.hidden{display:none}
main{display:grid;grid-template-columns:repeat(auto-fit,minmax(320px,1fr));gap:14px;padding:6px 16px 24px}
.card{background:var(--panel);border-radius:10px;padding:12px 14px}.card h2{margin:0 0 6px;font-size:16px}.card p{margin:0;color:#c9cdd2}
.card h2 .rk{display:inline-block;width:24px;height:24px;border-radius:50%;background:#ffd166;color:#101215;text-align:center;line-height:24px;font-weight:800;margin-right:6px}
nav{display:flex;gap:10px;flex-wrap:wrap;padding:0 20px 8px;font-size:13px}nav a{color:#9ec5ff;text-decoration:none}nav a.on{color:var(--fg);font-weight:700;text-decoration:underline}
.legend{display:flex;flex-wrap:wrap;gap:6px 16px;color:var(--dim);font-size:13px}.legend i{display:inline-block;width:18px;height:12px;vertical-align:-1px;margin-right:5px;border-radius:2px}
.src{color:#6c727b;font-size:12px;margin-top:8px}
@media (max-width:700px){header,.bar{padding-left:16px;padding-right:16px}#wrap{padding:8px}}
</style></head><body>
<header><h1>__TITLE__ — 도안</h1><p>__SUMMARY__</p></header>
<nav>__NAV__</nav>
<div class="bar">
__ROUTE_TOGGLES__
<label><input type="checkbox" id="t-labels" checked> 이름표</label>
<label><input type="checkbox" id="t-grid" checked> 좌표 격자</label>
<button data-z="1">맞춤</button><button data-z="1.8">1.8×</button><button data-z="3">3×</button>
<span class="stats">__STATS__</span>
</div>
<div id="wrap">__SVG__</div>
<main>
<section class="card"><h2>범례</h2><div class="legend">
<span><i style="background:#08090a;border:1px solid #5b6068"></i>검정 지형</span><span><i style="background:#eeeeea"></i>흰 지형</span>
<span><i style="background:repeating-linear-gradient(45deg,#b48cff55 0 4px,transparent 4px 8px);border:1px dashed #b48cff"></i>유령 발판(칠해야 밟힘)</span>
<span><i style="background:#050506;border:2px solid #3fa7ff"></i>검정 물</span><span><i style="background:#f4f6f8;border:2px solid #3fa7ff"></i>흰 물</span><span><i style="background:#7d8288;border:2px solid #3fa7ff"></i>회색 물(안전)</span><span><i style="border:2px dashed #3fa7ff"></i>꺼진 물</span>
<span><i style="background:#ff4d4d"></i>가시(색 무관 즉사)</span><span><i style="background:#ff8ad8"></i>레버 → 바꾸는 물</span><span><i style="background:#ffd84d"></i>체크포인트</span>
<span><i style="background:#ffb347"></i>호퍼·격자·저장고·양동이·박스·버튼·발판</span><span><i style="background:#ff9d2e"></i>정답 경로</span><span><i style="background:#4fd1ff"></i>다른 갈래</span><span><i style="background:#ffd166"></i>방 · 방 순서</span>
</div><p class="src">경로: 실선 = 걷기 · 점선 = 점프 · 잔 점선 = 페인트 발사. 흑백 원 = 색 전환 · ● 원 = 칠함 · E 원 = 레버 · ⇢ 원 = 밀기. 지형·물·표식에 마우스를 올리면 이름과 값이 나온다. 좌표 = 월드 px (y 는 아래로 커진다). 경로는 공략표를 그림으로 옮긴 것이라 실제 궤적과 조금 다르다.</p></section>
__ZONES__
</main>
<script>
document.querySelectorAll('.bar input[data-r]').forEach(c=>c.addEventListener('change',()=>document.getElementById(c.dataset.r).classList.toggle('hidden',!c.checked)));
document.getElementById('t-labels').addEventListener('change',e=>document.querySelectorAll('.labels,.lbl,.roomlabels').forEach(n=>n.classList.toggle('hidden',!e.target.checked)));
document.getElementById('t-grid').addEventListener('change',e=>document.querySelector('.grid').classList.toggle('hidden',!e.target.checked));
document.querySelectorAll('.bar button').forEach(b=>b.addEventListener('click',()=>{document.getElementById('map').style.width=(100*parseFloat(b.dataset.z))+'%';}));
</script>
</body></html>'''


def 만들기(key, 전체):
    G, by_name = mg.stage_graph(key)
    보충(G, by_name, key)
    모든경로 = mg.parse_routes()
    routes = {k: v for k, v in 모든경로.items() if k == key or k.startswith(key + ' ')}
    svg, 경로정보, zs = svg_도안(G, by_name, routes)
    # 흑백 반반 원(색 전환 표식)
    svg = svg.replace('</defs>', '<linearGradient id="swapfill" x1="0" x2="1"><stop offset=".5" stop-color="#08090a"/><stop offset=".5" stop-color="#eeeeea"/></linearGradient></defs>', 1)
    m = 메모.get(key, {})
    kinds = {}
    for n in G['nodes']:
        kinds[n['kind']] = kinds.get(n['kind'], 0) + 1
    fx, fy, fw, fh = G['frame']
    항목 = [('물', '유체'), ('웅덩이', '웅덩이'), ('가시', '가시'), ('톱', '회전톱'), ('호퍼', '호퍼'), ('저장고', '저장고'), ('격자', '격자'),
            ('레버', '레버'), ('버튼', '버튼'), ('양동이', '양동이'), ('박스', '박스'), ('움직이는 발판', '발판'), ('CP', '체크포인트')]
    유령수 = sum(1 for n in G['nodes'] if n['kind'] == '지형' and n['color'] == '유령')
    stats = f'{fw:.0f}×{fh:.0f} · ' + ' · '.join(f'{a} {kinds[b]}' for a, b in 항목 if kinds.get(b)) + (f' · 유령 {유령수}' if 유령수 else '')
    toggles = ''
    if 경로정보:
        toggles = '<span>경로:</span>' + ''.join(
            f'<label style="color:{r["color"]}"><input type="checkbox" data-r="{r["id"]}" checked> {esc(r["label"])} '
            f'<small style="color:var(--dim)">(칠하기 {r["shots"]}회 · 색 전환 {r["swaps"]}회)</small></label>' for r in 경로정보)
    elif m.get('_경로없음'):
        toggles = '<span style="color:#ffd166">흐름 = 방 순서 화살표</span>'
    zones = ''.join(f'<section class="card"><h2><span class="rk">{esc(z["k"])}</span>방 {esc(z["k"])}'
                    f'{" · " + esc(z["title"]) if z["title"] else ""}</h2><p>{esc(z["text"])}</p></section>' for z in zs)
    if m.get('_경로없음'):
        zones += f'<section class="card"><h2>⚠ 경로</h2><p>{esc(m["_경로없음"])}</p></section>'
    nav = '<a href="index.html">← 목록</a>' + ''.join(
        f'<a href="{k}_도안.html" class="{"on" if k == key else ""}">{esc(k.replace("stage_", ""))}</a>' for k in 전체)
    요약 = esc(m.get('_요약', '')) + (f' <span class="src">출처: {esc(m["_출처"])}</span>' if m.get('_출처') else '')
    page = (PAGE.replace('__TITLE__', esc(G['title'])).replace('__SUMMARY__', 요약).replace('__STATS__', esc(stats))
            .replace('__ROUTE_TOGGLES__', toggles).replace('__SVG__', svg).replace('__ZONES__', zones).replace('__NAV__', nav))
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    out = OUT_DIR / f'{key}_도안.html'
    out.write_text(page, encoding='utf-8')
    print('→', out)


def 목록(항목들):
    """docs/도안/index.html — 스테이지 도안 목록(카드를 누르면 그 도안)."""
    카드 = ''.join(f'<a class="c" href="{k}_도안.html"><b>{esc(t)}</b><span>{esc(요약)}</span></a>' for k, t, 요약 in 항목들)
    css = ('body{margin:0;background:#16181c;color:#e9e9e6;font:14px/1.55 "Malgun Gothic",system-ui,sans-serif;padding:20px 16px}'
           'h1{font-size:22px;margin:0 0 4px}p{color:#9aa0a8;margin:0 0 16px}'
           '.g{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:12px}'
           '.c{display:block;background:#1f2228;border-radius:10px;padding:12px 14px;color:inherit;text-decoration:none;border:1px solid #2c3037}'
           '.c:hover{border-color:#ffd166}.c b{display:block;font-size:16px;margin-bottom:4px}.c span{color:#c9cdd2}')
    page = ('<!doctype html><html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'
            f'<title>하수도 도안 목록</title><style>{css}</style></head><body><h1>하수도(2 챕터) 도안</h1>'
            '<p>python tools/도안_스테이지.py 가 씬과 공략표를 읽어 만든다. 씬을 고치면 다시 돌릴 것.</p>'
            f'<div class="g">{카드}</div></body></html>')
    (OUT_DIR / 'index.html').write_text(page, encoding='utf-8')
    print('→', OUT_DIR / 'index.html')


if __name__ == '__main__':
    전체 = list(메모)
    keys = sys.argv[1:] or 전체
    for k in keys:
        만들기(k, 전체)
    # 목록은 도안 파일이 있는 스테이지 전부로(일부만 다시 만들어도 목록이 줄지 않게)
    목록([(k, mg.stage_graph(k)[0]['title'], 메모[k]['_요약']) for k in 전체 if (OUT_DIR / f'{k}_도안.html').exists()])
