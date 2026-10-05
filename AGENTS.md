# GRAY (color) — 세션 시작 브리핑

> 이 파일은 **Codex 가 세션을 열 때 자동으로 읽는다.** 짧게 유지할 것.
> 자세한 것은 전부 `docs/` 에 있고, 여기는 **어디를 봐야 하는지**만 적는다.
> 최종 갱신: 2026-08-18 · 도형


> ★[2026-10-05] **쳅터1(집) = 14 스테이지** (`scenes/쳅터1/스테이지/`, 원본 도안 `scenes/쳅터1/도안/*.json` → `python tools/쳅터1/만들기.py`) · 스테이지 사이 = **연결구**(`scripts/쳅터1/연결구.gd` · `전경전환.gd`) · 기믹(창문빛·도약대·움직이는발판) · 색 전환 시뮬 + 엔진 경로 재생 · 목재 2.5D(`목재_상판메시.gd` 판자 맞춤 · `wood_deck.gdshaderinc` 명암 안).
>   **10-04~05 작업 전부 = `docs/작업기록_도형_쳅터1_2026-10-04_05.md` 한 장**(따로 있던 작업기록 5개·푸시 가이드는 여기로 통합) · 규칙 `docs/쳅터1_스테이지_제작규격.md` · 팀 공유 `docs/프롬프트_팀공유_쳅터1_총괄_2026-10-04.md`.
>   ⚠ 검토·백업 자료는 저장소 밖 `Documents/GRAY_백업/정리_20261004/`·`정리_20261005/` 에 있다(되돌리기 `tools/정리_2026100x.py --되돌리기`).

---

## 지금 상태 (60초)

- **2D 흑백 다크판타지 퍼즐 플랫포머.** 플레이어는 검정/흰색 중 하나. 물감총으로 지형을 칠한다.
  ★핵심 규칙: 몸에 닿은 지형이 **내 색과 다르면 즉사**.
  ★[2026-08-30 변경] **안 칠한 지형은 무색이 아니라 검정**이다 — 화면이 검정이니까.
    흰색 플레이어는 안 칠한 바닥에서 죽는다. 회색(물·웅덩이·호퍼)만 안전. 지형에 회색은 없다.
    규칙 전문: `docs/색판정_규칙_2026-08-30.md` · 코드: `scripts/스마트월드/색규칙.gd`
  ★[2026-09-14] 하수도 기준값: 점프 20칸(320) · 카메라 줌 1.0 · 치명 낙하 1500 — 씬에 명시. `tools/하수도_빌더_공통.gd`
  ★[2026-08-18] **빛도 이 규칙 안에 들어왔다.** 굳은 빛은 밟을 수 있고, 색이 다르면 죽는다.
- 엔진: **Godot 4.6.3-stable** · 브랜치 **dev_4** · 지형은 SmartShape2D(SS2D).
  ⚠ 콘솔 exe 는 **한글 경로에서 본체를 못 찾는다** → `C:\Users\Public\godot46\` 에 복사해 쓴다.
- 게임 켜기: F5 → 로비 → **시작** (= 집 · 거실)
- 스테이지 **7개**가 **통로로** 이어진다 (포탈 없음):
  `거실(5) → 굴뚝(6) → 지붕(7) → 숲의 초입(1) → 뒤틀린 나무들(2) → 늪으로(3) → 폐수로(4)`
  ⚠ 번호는 파일 이름표일 뿐이고 **진행 순서는 표의 줄 순서**다.
- ★순서·챕터·배경색·BGM 톤은 전부 `scripts/스마트월드/챕터.gd` 의 **표 하나**에 있다.
  씬 파일에는 순서 정보가 없다.

## 무엇부터 읽나

| 상황 | 문서 |
|---|---|
| **작업을 시작한다** | `docs/다음작업_프롬프트.md` ★ 여기부터. 검사 명령·할 일·지뢰밭이 전부 있다 |
| 카메라를 만진다 | `docs/카메라_공간전환_가이드.md` |
| 새 스테이지를 만든다 | `docs/레벨디자인_4스테이지_2026-08-17_도형.md` + `docs/레벨디자인_가이드.md` |
| **최근에 뭘 했나** | `docs/작업기록_2026-08-18_도형_빛기둥_창문커튼_집3분할.md` ★ |
| **지금 뭐가 꼬여 있나** | `docs/프로젝트_점검_2026-08-18_도형_병합_오류_꼬임.md` ★ |
| 파일이 어디 있나 | `docs/파일_분류_인덱스.md` |

## 반드시 지킬 규칙 (이 저장소의 규약)

1. 코드를 고치면 **왜 그렇게 했는지 한글 주석**을 반드시 붙인다.
2. 작업이 끝나면 `docs/작업기록_<날짜>_<이름>_<요약>.md` 를 남긴다.
3. 손대기 전과 후에 **검사 13개**를 돌려 하나도 안 깨졌는지 확인한다
   (명령은 `docs/다음작업_프롬프트.md` §1 에 복붙용으로 있다).
   ★ **사용자 안전 예외 (2026-08-31): 사용자에게 Godot 실행을 명시적으로 요청받기 전에는
   Godot 편집기·콘솔·`--headless` 검사·빌드 도구를 절대 실행하지 않는다. 이 PC에서는
   Godot 충돌 시 오류 대화상자가 반복 표시된다. 엔진 검사는 "미실행"으로 보고하고,
   파일·코드의 정적 확인만 한다.**
4. 씬을 통째로 다시 만드는 도구(`tools/build_*.gd`)는 **평소에 돌리지 않는다.**
   에디터에서 손본 값이 전부 날아간다.
5. 도구는 **멱등**이어야 한다. "기존 값 + 여유" 같은 누적 금지 — 항상 내용물에서 다시 계산.
6. 읽어온 씬의 노드에 **owner 를 다시 박지 않는다.** 새로 만든 노드에만 준다
   (어기면 다음 로드 때 노드가 두 벌이 되어 씬 교체 시 세그폴트).
7. 셰이더(.gdshader) 안에는 **한글을 쓸 수 없다.** 조용히 셰이더가 안 나온다.
8. `git pull` 먼저, 충돌은 **파일 단위**로 해결. 커밋 전 `git status` 로
   **내가 안 지운 파일이 D 로 잡혀 있는지** 확인 (2026-08-07 에 남의 작업 55개가 사라진 적 있다).

> ⚠ 지뢰밭 전체 목록(전부 실제로 한 번씩 터진 것)은 `docs/다음작업_프롬프트.md` §5 에 있다.
> **새 작업 전에 그것부터 읽을 것.**

## 자주 고치는 곳

| 하고 싶은 것 | 파일 |
|---|---|
| 스테이지 순서·챕터·배경색·BGM | `scripts/스마트월드/챕터.gd` ★ |
| 카메라 추적·줌·리밋 | `scripts/proto/proto_camera.gd` |
| 굴뚝/갱도에서 화면 조이기 | `scripts/proto/카메라_공간.gd` |
| 스테이지 전환 연출 | `scripts/스마트월드/장면전환.gd` |
| 사망 판정 | `scripts/스마트월드/월드.gd` 의 `_사망_판정()` |
| **빛(지붕 구멍·창문)의 색·굳음 규칙** | `scripts/스마트월드/빛기둥.gd` |
| **창문/커튼 규칙** | `scripts/스마트월드/창문커튼.gd` |
| **집 안 배경(거실·굴뚝·지붕·하수도)** | `scripts/스마트월드/실내배경.gd` |
| **집 3장의 레벨 배치** | `tools/build_원본_집.gd` |
| 지형 점 생성 규칙 | `scripts/스마트월드/지형규칙.gd` |
| 공중에 뜬 지형 찾기·고치기 | `tools/지형_다듬기.gd` |

## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

When the user types `/graphify`, use the installed graphify skill or instructions before doing anything else.

Rules:
- For codebase questions, first run `graphify query "<question>"` when graphify-out/graph.json exists. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- Dirty graphify-out/ files are expected after hooks or incremental updates; dirty graph files are not a reason to skip graphify. Only skip graphify if the task is about stale or incorrect graph output, or the user explicitly says not to use it.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).


## 시각 작업 완료 기준 (2026-09-28 사용자 요청)
- 시안 적용은 코드 연결/정적 검사만으로 완료라고 보고하지 않는다.
- 실제 게임의 같은 스테이지·카메라 줌·해상도에서 수정 전후 PNG를 확보하고 직접 열어 본다.
- 배경/지형 분리, 벽돌 크기, 벽등 형태와 빛 범위, 물색 구분, HUD, 반복 이음새를 시안과 비교한다.
- 입수 효과는 정지 화면만으로 판정하지 않고 진입/물 안 이동/재진입/리스폰 및 소멸을 확인한다.
- 실행은 위 Godot 명시적 허용 규칙을 따른다. 허용 없이는 "수정 완료·시각 검증 대기"로 보고하며 시안과 같다고 단정하지 않는다.
- 결과 보고에는 실제 엔진 캡처 경로와 남은 차이를 적는다. 생성형 시안은 검증 이미지로 대체 사용하지 않는다.
