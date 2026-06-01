# 색상 반전 2D 플랫포머 (Color Inversion Platformer)

> Godot 4.6.1 / Forward Plus / Jolt Physics  
> 작성일: 2026-05-27

---

## 게임 소개

플레이어가 **검정(BLACK)** 과 **흰색(WHITE)** 두 색상을 자유롭게 토글하며,  
같은 색 지형은 안전하게 밟고, 반대 색 지형은 통과해 사망하는 색상 반전 메커니즘 기반 2D 플랫포머.

페인트 총으로 지형 표면 일부를 칠해 **죽음의 함정을 안전지대로 바꾸는 전략**이 핵심.

### 핵심 색상 규칙

| 플레이어 색 | BLACK 지형 | WHITE 지형 | GRAY 지형 |
|------------|----------|----------|---------|
| BLACK | ✅ 안전 (밟힘) | ❌ 사망 (통과 후 판정) | ⚠️ 미끄러짐 |
| WHITE | ❌ 사망 (통과 후 판정) | ✅ 안전 (밟힘) | ⚠️ 미끄러짐 |

### 조작

| 입력 | 동작 |
|------|------|
| A / D / ← / → | 좌우 이동 |
| Space | 점프 |
| Up | 색 토글 (BLACK ↔ WHITE) |
| 마우스 좌클릭 | 페인트 총 발사 (반대색 페인트) |

---

## 프로젝트 빠른 시작

### 실행
1. Godot 4.6.1로 `project.godot` 열기
2. **F5** 실행 (자동으로 `stage_1` 로드)

### DEBUG 모드 변경
`scripts/main.gd` 의 `DEBUG_STAGE` 상수로 시작 스테이지 변경:
```gdscript
const DEBUG_STAGE: int = 1   # 1~N: 해당 스테이지 직진입 / 0: MainMenu부터
```

---

## 프로젝트 구조

```
프로젝트ver-2/
├── main.tscn                        ← 진입점
├── project.godot
│
├── autoload/
│   └── SceneManager.gd              ← 씬 전환 전담
│
├── scripts/
│   ├── main.gd                      ← 진입점 스크립트
│   ├── stage.gd                     ← 스테이지 공통 로직
│   ├── player.gd                    ← 플레이어
│   ├── platform.gd                  ← 발판
│   ├── bullet.gd                    ← 총알
│   ├── paint_mark.gd                ← 페인트 얼룩
│   ├── color_defs.gd                ← 색 상수 전역
│   └── obstacles/                   ← 장애물 스크립트 (신규)
│
├── scenes/
│   ├── player/Player.tscn
│   ├── platforms/Platform.tscn
│   ├── obstacles/                   ← 장애물 씬
│   ├── effects/PaintMark.tscn
│   ├── bullet/Bullet.tscn
│   ├── ui/                          ← MainMenu, StageSelect
│   └── world_1/stage_N/             ← 스테이지 씬
│
├── assets/
│   ├── textures/
│   │   ├── player/
│   │   ├── platforms/
│   │   ├── obstacles/
│   │   ├── effects/
│   │   └── ui/
│   ├── audio/
│   └── fonts/
│
├── README.md                        ← 이 파일
├── 프로젝트_개발정리.md              ← 개발 흐름/시스템 상세
├── 가이드라인_장애물제작규칙.md       ← 새 장애물 만들 때
├── 가이드라인_투명블럭.md            ← 투명 블럭(Ghost) 설계
└── 가이드라인_기존장애물_이식.md      ← 외부 장애물 이식 시
```

---

## 핵심 시스템 요약

### 1. 물리 레이어

| 레이어 | 이름 | 비트값 | 역할 |
|--------|------|--------|------|
| 1 | player | 1 | 플레이어 본체 |
| 2 | platform_black | 2 | 검정 지형 |
| 3 | platform_white | 4 | 흰색 지형 |
| 4 | platform_gray | 8 | 회색 지형 |
| 5 | bullet | 16 | 총알 |
| 6 | paint_detector | 32 | PaintMark JudgmentZone |
| 7 | kill_zone | 64 | DeathDetector |
| 8 | ghost_interact | 128 | 투명 블럭 (예정) |
| 9 | obstacle_body | 256 | 장애물 본체 (예정) |

### 2. 그룹 (Group)

| 그룹명 | 용도 |
|--------|------|
| `player` | 플레이어 식별 (장애물이 `is_in_group("player")`로 검사) |
| `paint_bodies` | 총알이 닿으면 `update_color()` 호출됨 |
| `paint_marks` | 사망 판정 1순위 (페인트 우선) |
| `death_zones` | 사망 판정 2순위 (지형 색) |
| `obstacle` | 총알이 닿으면 PaintMark 생성 안 함 (총알만 소멸) |

### 3. 사망 판정 흐름

```
매 프레임 _physics_process()
  └── ColorSensor (Area2D)가 겹친 영역 스캔
      ├── paint_marks 그룹 (페인트 얼룩) → 1순위
      │     └── paint_color == player_color ? 안전 : die()
      └── death_zones 그룹 (지형 색) → 2순위
            └── color_state != player_color ? die() : 안전
```

### 4. 총알 충돌 흐름

```
bullet body_entered
  ├── body가 "paint_bodies" 그룹? → update_color() 호출 (색 교체)
  ├── body가 "obstacle" 그룹?    → 아무것도 안 함 (총알만 소멸)
  └── 그 외 (일반 지형)           → PaintMark 새로 생성
  → 어떤 경우든 총알은 _safe_free() 로 소멸
```

---

## 역할별 작업 가이드

### 🎨 맵 디자이너

#### 작업 흐름
1. 디자인 툴(Photoshop/Procreate 등)에서 맵 일러스트 제작
2. PNG 파일로 납품 (투명 배경)
3. 프로그래머가 Godot에 배치 + 충돌 영역 트레이싱

#### 납품 시 분리할 레이어 (PNG 별도 파일)
- **TerrainSprite**: 지형 베이스 이미지
- **PaintOverlay**: 페인트가 올라갈 영역 (투명)
- **Details**: 배경 장식, 소품

#### 색상 디자인 주의사항
- BLACK / WHITE / GRAY 지형이 **시각적으로 명확히 구분**돼야 함
- 페인트 얼룩이 잘 보여야 하므로 **너무 복잡한 패턴 지양**
- 회색 지형은 검정/흰색과 충분한 명도 차이

#### 충돌 영역 명세 필수 제공
- 색상별 구역 표시 (별도 레이어 or 오버레이)
- 어디가 BLACK / WHITE / GRAY 지형인지 명확히

#### 기준 해상도
- 플레이어 크기: 32×64 px
- 점프 도달 높이: 약 200px 이하 권장
- 일반 발판 두께는 플레이어 키 대비 적절히

---

### 💻 프로그래머

#### 코드 수정 최소화 원칙

> **기존 시스템(player.gd, bullet.gd, platform.gd)을 수정해야 하는 일은 거의 없어야 함.**  
> 새 장애물/요소는 **기존 시스템에 맞춰 만들고**, 기존 코드는 건드리지 않는 것이 원칙.

#### 새 장애물 만들 때
**👉 `가이드라인_장애물제작규칙.md` 참조**

핵심:
- 장애물 스크립트는 `scripts/obstacles/`에 작성
- 장애물 씬은 `scenes/obstacles/`에 저장
- 사망 판정은 **KillArea (Area2D)** 자식 노드로 처리 (ColorSensor 시스템과 분리)
- `add_to_group("obstacle")` 잊지 말 것 (총알 PaintMark 생성 차단)

#### 색 상수 사용
```gdscript
# ✅ 항상 ColorDefs 사용
var color_state: int = ColorDefs.BLACK

# ❌ 로컬 const 금지
const BLACK = 0
```

#### 물리 콜백 안에서 금지 사항
```gdscript
# ❌ 절대 금지 — physics flush 오류
func _on_body_entered(body):
    body.die()              # ← 직접 호출
    add_child(something)    # ← 직접 add_child
    queue_free()

# ✅ 반드시 call_deferred 사용
func _on_body_entered(body):
    body.call_deferred("die")
    call_deferred("add_child", something)
    call_deferred("queue_free")
```

#### 인스턴스 추가 순서
```gdscript
# ✅ 올바른 순서
var obj = SCENE.instantiate()
obj.some_property = value     # ← _ready() 전에 설정
get_tree().current_scene.add_child(obj)
obj.global_position = pos     # ← add_child 후 위치 설정

# ❌ 잘못된 순서
var obj = SCENE.instantiate()
get_tree().current_scene.add_child(obj)
obj.some_property = value     # ← _ready() 이미 실행됨, 적용 안 될 수 있음
```

---

### 🎯 스테이지 제작자

#### 새 스테이지 만들기
1. `scenes/world_1/stage_N/stage_N.tscn` 폴더/파일 생성
2. `stage_1.tscn`을 복사해 시작 (기본 구조 동일)
3. `autoload/SceneManager.gd`의 `STAGES` 딕셔너리에 경로 등록:
   ```gdscript
   const STAGES = {
       1: "res://scenes/world_1/stage_1/stage_1.tscn",
       2: "res://scenes/world_1/stage_2/stage_2.tscn",   # ← 추가
       ...
   }
   ```

#### 스테이지 기본 구조
```
stage_N (Node2D) ← stage.gd
├── MapVisual (Node2D)
│   ├── TerrainSprite (Sprite2D)
│   ├── PaintOverlay (Node2D)
│   └── Details (Node2D)
├── MapPhysics (Node2D)
│   ├── Platform_xxx (Platform 인스턴스들)
│   ├── (Obstacle 인스턴스들)
│   └── KillZone (Area2D) ← 추락 사망 영역
└── Player (Player 인스턴스)
```

#### 발판 배치 시
- Platform 씬을 인스턴스화한 뒤 인스펙터에서 `color_state` (0/1/2) 변경
- 위치만 조정 → 색상은 인스펙터에서 → 점프 가능 거리 확인

---

### 🎮 사운드/UI 디자이너

#### 사운드 파일 배치
- BGM: `assets/audio/bgm/`
- 효과음: `assets/audio/sfx/`

#### UI 작업
- MainMenu, StageSelect는 `scenes/ui/`에 작성
- 메뉴 전환은 반드시 `SceneManager.go_to_main_menu()` / `SceneManager.go_to_stage_select()` 사용

---

## 절대 지켜야 할 규칙 ⚠️

### 1. ColorDefs 외에 색 상수 만들지 말 것
모든 색 비교는 `ColorDefs.BLACK / WHITE / GRAY` 사용.

### 2. 색 기반 레이어(2, 4, 8)를 장애물에 쓰지 말 것
플레이어 색에 따라 통과/막힘이 달라져 의도하지 않은 동작 발생.  
장애물은 항상 `layer_9 (obstacle_body)` 사용.

### 3. body_entered / area_entered 콜백 안에서
- `die()` / `queue_free()` / `add_child()` / `collision_layer 변경` 직접 호출 금지
- 반드시 `call_deferred` 사용

### 4. add_child 전에 프로퍼티 설정
`_ready()`가 add_child 시점에 호출되므로, 초기값은 그 전에 설정.

### 5. 폴더 규칙 준수
- 씬은 `scenes/카테고리/`, 스크립트는 `scripts/카테고리/`, 텍스처는 `assets/textures/카테고리/`
- 스테이지는 `scenes/world_N/stage_M/` 구조 유지

---

## 해결된 주요 버그 (재발 방지용)

| 버그 | 원인 | 해결 패턴 |
|------|------|---------|
| 총알 색 항상 흰색 | add_child 후 색 설정 | add_child 전에 설정 |
| Physics flush 오류 | body_entered 안에서 add_child | call_deferred 사용 |
| 반대색 발판에서 사망 안 됨 | PaintMark가 Area2D라 물리 충돌 부재 | StaticBody2D로 변경 |
| SceneManager remove_child 오류 | _ready() 안에서 change_scene | call_deferred 패턴 |
| stage_1.tscn 재생성 | .godot/editor/*.cfg 캐시 | 해당 cfg 수정 |
| Parser Error (타입 추론) | `:=` 추론 실패 | 명시적 타입 선언 |

---

## 외부 가이드라인 문서 안내

| 문서 | 언제 읽나 |
|------|---------|
| `프로젝트_개발정리.md` | 전체 시스템 동작 흐름, 노드 구조 상세 확인 |
| `가이드라인_장애물제작규칙.md` | 새 장애물 만들기 전 필수 |
| `가이드라인_투명블럭.md` | 투명 블럭(Ghost Platform) 구현 시 |
| `가이드라인_기존장애물_이식.md` | 외부 프로젝트의 톱니/낙하블록/부서지는 타일 이식 시 |

---

## TODO (현재 진행 중인 작업)

- [ ] 사망 모션 / 파티클 구현
- [ ] 리스폰 포인트 노드화
- [ ] 총알/PaintMark 텍스처 파일 교체
- [ ] MainMenu, StageSelect UI 구현
- [ ] 포탈 + 스테이지 클리어 시스템
- [ ] SceneManager STAGES 딕셔너리에 stage 2~30 경로 추가
- [ ] 투명 블럭 (Ghost Platform) 구현
- [ ] 기존 장애물 3종 (Gear, FallingBlock, BrokenTile) 이식
- [ ] 맵 일러스트 적용 + CollisionPolygon2D 트레이싱

---

## 개발자 노트

### 코드 수정을 최소화하는 설계 원칙

이 프로젝트는 **확장 우선, 수정 최소**를 원칙으로 함.

1. **그룹 기반 검사**: 새 노드 타입을 추가해도 `is_in_group()` 검사로 처리 → 기존 코드 수정 X
2. **레이어 분리**: 새 시스템은 새 레이어로 → 기존 충돌 규칙 보존
3. **자식 노드 추가 패턴**: 사망 판정은 KillArea(Area2D) 자식 노드로 → 부모 노드 타입 자유
4. **시그널 연결**: 외부에서 시그널 connect로 동작 확장 → 코드 수정 없이 기능 추가

### 새 기능 추가 우선순위

1. **기존 그룹/레이어 활용** → 0순위 (수정 0줄)
2. **새 그룹/레이어 추가** → 1순위 (project.godot만 수정)
3. **새 자식 노드 추가** → 2순위 (씬 트리만 수정)
4. **새 스크립트 추가** → 3순위 (기존 스크립트 수정 없이)
5. **기존 스크립트 수정** → 최후 수단 (다른 방법 다 검토 후)

---

*이 문서는 프로젝트의 첫 번째 진입점입니다. 작업 시작 전 반드시 읽고, 변경사항이 생기면 업데이트해주세요.*
