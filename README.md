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

- [Godot Engine 4](https://godotengine.org/)

---

## 폴더 구조
color/
├── main/ # 메인 씬
├── player/ # 플레이어 (CharacterBody2D)
│ ├── player.tscn
│ ├── player.gd
│ ├── bullet.tscn
│ └── gun_pivot.gd
├── platform/ # 색상 플랫폼 (StaticBody2D)
│ ├── color_platform.tscn
│ └── color_platform.gd
├── area/ # 스테이지 맵
│ ├── stage1/
│ │ ├── stage1-1/
│ │ ├── stage1-2/
│ │ └── ...
│ ├── stage2/
│ │ ├── stage2-1/
│ │ └── ...
│ └── stage3/
│ └── ...
├── obstacle/ # 장애물
│ ├── obstacle_gear/ # 이동형 톱니바퀴
│ │ ├── gear_obstacle.tscn
│ │ └── gear_obstacle.gd
│ ├── obstacle_blockspawner/ # 낙하 블록
│ │ ├── BlockSpawner.tscn
│ │ ├── block_spawner.gd
│ │ ├── FallingBlock.tscn
│ │ └── falling_block.gd
│ └── obstacle_[새 장애물 이름]/ # 새 장애물 추가 시
│ └── ...
├── background/ # 패럴렉스 배경
├── camera/ # 카메라
├── ui/ # UI
└── Tilesheet/ # 타일 이미지 리소스

---
## 폴더 관리 규칙
> **새로운 요소를 추가할 때는 반드시 전용 폴더를 먼저 생성한다.**  
> 이유: 파일이 늘어날수록 폴더 단위 관리가 훨씬 효율적이기 때문
### 맵 추가 시
area/
└── stage[번호]/ # 스테이지 단위 폴더 생성
├── stage[번호]-1/ # 세부 구간 폴더 생성
├── stage[번호]-2/
└── ...

예시: 스테이지 2의 3번째 구간 → `area/stage2/stage2-3/`
### 장애물 추가 시
obstacle/
└── obstacle_[장애물 이름]/ # 장애물 종류별 폴더 생성
├── [이름].tscn
└── [이름].gd

예시: 가시 장애물 추가 → `obstacle/obstacle_spike/`
### 그 외 모든 요소
새로운 종류의 요소(UI, 아이템, 이펙트 등)를 추가할 때도 동일하게  
**최상위 카테고리 폴더 → 세부 폴더** 순서로 생성 후 작업한다.
---
## Collision 구조 (Layer / Mask)
| 오브젝트 | Layer | Mask | 설명 |
|----------|-------|------|------|
| Player | 1 | 2, 3 | 플랫폼·장애물과 충돌 |
| Color Platform | 2 | - | 플레이어가 올라서는 지형 |
| Gear Obstacle | 2 | - | 이동형 톱니바퀴 장애물 |
| Falling Block | 2 | - | 낙하 블록 |
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
| `black_tiles` | 검은색 Color Platform |
| `white_tiles` | 흰색 Color Platform |
| `camera` | Camera2D |
---
## 팀원 & 역할
| 이름 | 역할 |
|------|------|
| 김동현 | 총괄 및 프로그래밍 |
| 안성진 | 프로그래밍 |
| 김도형 | 기획 및 디자인 |
| 유강훈 | 디자인 총괄 |
| 박미소 | 디자인 |
