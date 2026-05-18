# Color (가제)

> 2D 횡스크롤 플랫포머 게임 — 지형, 장애물, 색상 전환이 핵심인 게임

---

## 게임 소개

흑(Black)과 백(White), 두 가지 색상을 전환하며 장애물을 피해 골인 지점에 도달하는 2D 횡스크롤 플랫포머 게임입니다.  
색상에 따라 통과할 수 있는 지형과 닿으면 죽는 장애물이 달라지며, 페인트 총으로 환경에 상호작용할 수 있습니다.

---

## 플레이 방법

| 입력 | 동작 |
|------|------|
| 방향키 / WASD | 이동 |
| Space | 색상 전환 (흑 ↔ 백) |
| 마우스 좌클릭 | 페인트 총 발사 |

- **목표**: 장애물을 피해 골인 지점에 도달

---

## 스크린샷

> 추후 추가 예정

---

## 사용 기술

- [Godot Engine 4.6.1](https://godotengine.org/)

---

## 폴더 구조

```
color/
├── main/                       # 메인 씬
├── player/                     # 플레이어 (CharacterBody2D)
│   ├── player.tscn
│   ├── player.gd
│   ├── bullet.tscn
│   └── gun_pivot.gd
├── map_dohyoung/               # 맵 (TileMapLayer 기반)
│   ├── color 타일셋/            # 타일 이미지 리소스
│   └── world_1/
│       └── stage_1.tscn
├── obstacle/                   # 장애물
│   ├── obstacle_gear/          # 이동형 톱니바퀴
│   │   ├── gear_obstacle.tscn
│   │   └── gear_obstacle.gd
│   └── blockspawner/           # 낙하 블록
│       ├── BlockSpawner.tscn
│       ├── FallingBlock.tscn
│       └── ...
├── background/                 # 패럴렉스 배경 (무한 스크롤)
│   ├── parallax_background.tscn
│   └── parallax_background.gd
├── camera/                     # 데드존 카메라
│   ├── camera_2d.tscn
│   └── camera_2d.gd
├── ui/                         # UI 씬 및 스크립트
│   ├── main_lobby.gd
│   ├── world_select.gd
│   └── stage_select.gd
├── area/                       # (구) 테스트 맵
├── platform/                   # 색상 플랫폼
├── game_manager.gd             # 오토로드 싱글톤
└── Tilesheet/                  # 타일 이미지 리소스
```

---

## 폴더 관리 규칙

> **새로운 요소를 추가할 때는 반드시 전용 폴더를 먼저 생성한다.**  
> 이유: 파일이 늘어날수록 폴더 단위 관리가 훨씬 효율적이기 때문

### 맵 추가 시
```
map_dohyoung/
└── world_[번호]/
	├── stage_1.tscn
	├── stage_2.tscn
	└── ...
```
예시: 월드 2의 스테이지 3 → `map_dohyoung/world_2/stage_3.tscn`

### 장애물 추가 시
```
obstacle/
└── obstacle_[장애물 이름]/
	├── [이름].tscn
	└── [이름].gd
```
예시: 가시 장애물 추가 → `obstacle/obstacle_spike/`

### 그 외 모든 요소
새로운 종류의 요소(UI, 아이템, 이펙트 등)를 추가할 때도 동일하게  
**최상위 카테고리 폴더 → 세부 폴더** 순서로 생성 후 작업한다.

---

## Collision 구조 (Layer / Mask)

### Layer / Mask 표

| 오브젝트 | 노드 타입 | Layer | Mask | 설명 |
|----------|-----------|-------|------|------|
| Player | CharacterBody2D | 1 | 2, 3 | 플랫폼·장애물과 충돌 |
| White TileMapLayer | TileMapLayer | 2 | 1 | 흰색 지형 |
| Black TileMapLayer | TileMapLayer | 3 | 1 | 검은색 지형 |
| Broken TileMapLayer | TileMapLayer | 2, 3 | 4 | 부서지는 타일 |
| Gear Obstacle | AnimatableBody2D | 2 | - | 이동형 톱니바퀴 장애물 |
| Falling Block | RigidBody2D | 2 | - | 낙하 블록 |

### 사망 판정 방식

- **색상 플랫폼**: 플레이어 색상과 다른 색 타일을 밟으면 사망  
  → `get_slide_collision()` + 그룹(`black_tiles` / `white_tiles`) 판별
- **이동 장애물 (Gear)**: 닿으면 즉시 사망  
  → `get_slide_collision()` + 그룹(`obstacle`) 판별
- **낙하 블록**: 닿으면 즉시 사망  
  → `RigidBody2D.body_entered` 시그널 + 그룹(`player`) 판별

### 그룹 목록

| 그룹명 | 적용 노드 |
|--------|----------|
| `player` | Player |
| `obstacle` | Gear Obstacle |
| `falling_blocks` | Falling Block |
| `black_tiles` | Black TileMapLayer |
| `white_tiles` | White TileMapLayer |
| `camera` | Camera2D |

---

## 게임 흐름

```
[main_lobby.tscn]
	  ↓ 시작 버튼
[world_select.tscn]
	  ↓ 월드 선택
[stage_select.tscn]
	  ↓ 스테이지 선택
[map/world_N/stage_N.tscn]
```

GameManager(오토로드 싱글톤)가 선택한 월드/스테이지 번호를 전역 보관하며 씬 전환을 처리한다.  
새 스테이지 추가 시 `game_manager.gd`의 `STAGE_DATA`에 경로만 추가하면 된다.

---

## 팀원 & 역할

| 이름 | 역할 |
|------|------|
| 김동현 | 총괄 및 프로그래밍 |
| 안성진 | 프로그래밍 |
| 김도형 | 기획 및 맵 디자인 |
| 유강훈 | 디자인 총괄 |
| 박미소 | 디자인 |

---

---

# 작업 지시서

## ⏰ 기한: 5월 19일(화) 오전 13시까지

---

## 박미소 — 캐릭터 & 지형 디자인

### 공통 규격

| 항목 | 내용 |
|------|------|
| 파일 형식 | PNG (투명 배경) |
| 타일 기본 크기 | 16 x 16 px |
| 색상 버전 | 흑(Black) / 백(White) 필수 제작 |
| 네이밍 규칙 | `동작명_색상_프레임번호.png` (예: `run_black_01.png`) |

---

### 모션 디자인

#### 1. 이동 모션 (좌우)
- 프레임 수: 최소 4프레임 이상
- 흑 / 백 버전 각각 제작
- 좌우 방향은 코드에서 flip 처리 예정 → **오른쪽 방향 기준**으로만 제작

#### 2. 점프 모션
- 3단계 구분: **도약 / 공중 / 착지**
- 흑 / 백 버전 각각 제작

#### 3. 죽는 모션
- 프레임 수: 최소 4프레임 이상
- 흑 / 백 버전 각각 제작
- 마지막 프레임에서 멈추는 형태로 제작

#### 4. 총 쏘는 모션
- 이동 중 사격 가능
- 흑 / 백 버전 각각 제작
- **총구 위치 좌표 별도 명시 필수** (코드에서 총알 발사 위치로 사용)

---

### 지형 디자인

> 타일셋은 **아틀라스 소스** 형식으로 제작 (타일들을 하나의 PNG에 격자 배열)  
> 타일 1칸 크기: **16 x 16 px**  
> 흑 / 백 / 회색(중립) 총 3가지 버전 제작

#### 1. 경사 지형
- 경사 각도: 45도 기준
- 완만한 경사 (2칸 너비 1칸 높이) / 급경사 (1칸 너비 1칸 높이) 두 종류
- **Collision 폴리곤은 개발팀에서 설정** → 디자이너는 비주얼만 제작

#### 2. 점프대
- 일반 바닥과 구별되는 디자인으로 제작
- 눌리는 느낌의 **압축 버전** 1프레임 추가 (애니메이션용)
- 흑 / 백 / 회색 3가지 버전

#### 3. 낙하 가시 장애물

특정 지점을 플레이어가 지나면 천장에서 가시가 **순서대로 하나씩** 내려오는 장애물

**가시 본체 규격**

| 항목 | 내용 |
|------|------|
| 크기 | 가로 32~48px / 세로 64~96px |
| 형태 | 아래가 뾰족한 삼각형 또는 고드름 형태 |
| 색상 버전 | 흑 / 백 / 회색(중립) 3가지 |
| 천장 연결부 | 위쪽 끝은 천장에 붙어있는 형태 (추후 바닥에서 올라오는 버전도 예정) |

**애니메이션 프레임 (가시 1개 기준)**

| 프레임 | 상태 | 설명 |
|--------|------|------|
| 01 | 대기 | 천장에 완전히 숨겨진 상태 |
| 02 | 내려오는 중 | 절반쯤 내려온 상태 |
| 03 | 완전 돌출 | 완전히 내려온 상태 (접촉 시 사망) |

> 가시가 순서대로 내려오는 연출은 **코드에서 타이머로 처리** → 디자이너는 가시 1개 단위로만 제작  
> 가시 개수는 코드에서 조절 예정이므로 1개 단위로만 납품  
> **가시 끝 뾰족한 부분의 정확한 픽셀 위치 명시 필수** (Collision 기준점으로 사용)

---

### 납품 형식

```
캐릭터/
├── black/
│   ├── run_black_01.png ~ run_black_04.png
│   ├── jump_black_01.png ~ ...
│   ├── die_black_01.png ~ ...
│   └── shoot_black_01.png ~ ...
└── white/
	└── (동일 구조)

타일셋/
├── tileset_black.png
├── tileset_white.png
└── tileset_gray.png

장애물/
└── spike_drop/
	├── spike_idle.png
	├── spike_mid.png
	└── spike_down.png
```

---

## 안성진 — 프로그래밍: 게임 흐름 시스템

### 구현 범위

| 항목 | 내용 |
|------|------|
| 화면 전환 흐름 | 로비 → 월드 선택 → 스테이지 선택 → 게임 실행 |
| 선택 데이터 저장 | 선택한 월드/스테이지 번호 전역 보관 |
| 스테이지 로딩 | 선택한 스테이지 씬 파일 로드 및 전환 |

### 생성 파일

```
res://game_manager.gd        ← 오토로드 싱글톤 (작성 완료)
res://ui/main_lobby.gd       ← 메인 로비 스크립트 (작성 완료)
res://ui/world_select.gd     ← 월드 선택 스크립트 (작성 완료)
res://ui/stage_select.gd     ← 스테이지 선택 스크립트 (작성 완료)
```

> 스크립트는 작성 완료. 아래 에디터 세팅만 진행하면 됨.

### 에디터 세팅 (필수)

**① GameManager 오토로드 등록**
- `프로젝트 → 프로젝트 설정 → 오토로드`
- 파일: `res://game_manager.gd`
- 이름: `GameManager`

**② main_lobby.tscn 노드 구조**
```
Control  [스크립트: main_lobby.gd]
└── Button "시작"
	 └── pressed 시그널 → _on_start_button_pressed()
```

**③ world_select.tscn 노드 구조**
```
Control  [스크립트: world_select.gd]
└── VBoxContainer
	 ├── Label          [이름: TitleLabel]
	 ├── VBoxContainer  [이름: ButtonContainer]  ← 버튼 코드로 자동 생성
	 └── Button "뒤로"
		  └── pressed 시그널 → _on_back_button_pressed()
```

**④ stage_select.tscn 노드 구조**
```
Control  [스크립트: stage_select.gd]
└── VBoxContainer
	 ├── Label          [이름: TitleLabel]
	 ├── VBoxContainer  [이름: ButtonContainer]  ← 버튼 코드로 자동 생성
	 └── Button "뒤로"
		  └── pressed 시그널 → _on_back_button_pressed()
```

### 스테이지 데이터 구조

`game_manager.gd` 내 `STAGE_DATA` 딕셔너리에서 관리  
새 스테이지 추가 시 **`STAGE_DATA`에만 경로 추가**, 다른 코드 수정 불필요

```gdscript
STAGE_DATA = {
	1: {
		"name": "World 1",
		1: "res://map/world_1/stage_1.tscn",
		2: "res://map/world_1/stage_2.tscn",  # 도형이가 제작 후 주석 해제
	},
	2: {
		"name": "World 2",                     # 도형이가 제작 후 추가
		1: "res://map/world_2/stage_1.tscn",
	},
}
```

### 향후 주의사항
- UI 디자인 완성 후 각 `.tscn` 파일만 교체하면 로직 재작성 없이 적용 가능
- 현재 UI는 임시(버튼만 존재), 디자인 작업 후 씬 파일 교체 예정

---

## 김도형 — 맵 디자인: Godot 설정 유의사항

새 맵 씬(`.tscn`)을 만들 때 **TileMapLayer 노드 2개를 반드시 아래 설정대로 맞춰야 한다.**  
하나라도 빠지면 플레이어가 바닥을 뚫고 떨어지거나 색깔 판정이 작동하지 않는다.

### 1. Collision Layer / Mask 설정

`FloorLayer_black` 또는 `FloorLayer_white` 노드 선택  
→ 인스펙터 오른쪽 → **TileSet 클릭** → **Physics Layers** 섹션

| | Collision Layer | Collision Mask |
|---|---|---|
| **FloorLayer_black** | **3번** 체크 | **1번** 체크 |
| **FloorLayer_white** | **2번** 체크 | **1번** 체크 |

> ⚠️ 다른 번호가 체크되어 있으면 반드시 해제하고 위 번호만 체크

### 2. 그룹 설정

`FloorLayer_black` 노드 선택  
→ 오른쪽 패널 상단 **"그룹" 탭** 클릭  
→ 텍스트 입력창에 `black_tiles` 입력 후 추가 버튼

`FloorLayer_white` 노드 선택  
→ 오른쪽 패널 상단 **"그룹" 탭** 클릭  
→ 텍스트 입력창에 `white_tiles` 입력 후 추가 버튼

> ⚠️ 그룹 이름 오타 주의 (`black_tiles`, `white_tiles` 정확히 입력)  
> ⚠️ **씬 그룹**에 추가할 것. 전역 그룹에 추가하지 말 것.

### 3. 저장 전 최종 체크리스트

- [ ] FloorLayer_black → Collision Layer **3번**, Mask **1번**
- [ ] FloorLayer_white → Collision Layer **2번**, Mask **1번**
- [ ] FloorLayer_black → 그룹 `black_tiles` 등록됨
- [ ] FloorLayer_white → 그룹 `white_tiles` 등록됨


처음 시작할 때 (최초 1회)
1. 프로젝트 받기 (master 기준)

git clone https://github.com/BlackBear1210/color.git

2. dev 브랜치 만들고 이동

git checkout -b dev
git push -u origin dev
이후 작업할 때마다
작업 전 — 최신 내용 받기

git pull origin dev
작업 후 — 올리기

git add .
git commit -m "작업 내용 설명"
git push origin dev
dev 브랜치가 이미 있을 때 (두 번째 팀원 또는 재접속 시)
git clone https://github.com/BlackBear1210/color.git
git checkout dev
이렇게 하면 dev 브랜치로 바로 이동됩니다.

현재 어느 브랜치인지 확인
git branch
* dev 라고 표시되면 현재 dev에 있는 거에요.


