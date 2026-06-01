World_1
    ├── stage_1 (Node2D)  ← 모든 것의 부모
        ├── Background (ParallaxBackground)  ← 배경 레이어 3개 
        │   ├── ParallaxLayer_Far    (Layer1: 원경)
        │   ├── ParallaxLayer_Mid    (Layer2: 중경)
        │   └── ParallaxLayer_Near   (Layer3: 전경)
        │
        ├── MapVisual (Node2D)  ← 보이는 맵 그림 전체
        │   ├── TerrainSprite (Sprite2D)         ← 지형 전체 일러스트 이미지
        │   ├── PaintOverlay  (Node2D)           ← 페인트 효과 스프라이트들이 쌓이는 곳
        │   └── Details (Node2D)                 ← 크랙, 구멍, 장식 스프라이트들
        │
        ├── MapPhysics (Node2D)  ← 보이지 않는 물리/판정 전담
        │   ├── Platform_001 (StaticBody2D)      ← 검정 발판
        │   │   ├── CollisionPolygon2D           ← 충돌 영역 (손으로 직접 그림)
        │   │   └── PaintDetector (Area2D)       ← 페인트 총알이 닿는지 감지
        │   │       └── CollisionShape2D
        │   ├── Platform_002 (StaticBody2D)      ← 흰색 발판
        │   │   ├── CollisionPolygon2D
        │   │   └── PaintDetector (Area2D)
        │   ├── Slope_001 (StaticBody2D)         ← 회색 경사로
        │   │   ├── CollisionPolygon2D
        │   │   └── SurfaceStrip (Area2D)        ← 잔디 띠 판정 전용
        │   └── KillZone (Area2D)               ← 낭떠러지/죽음 영역
        │
        ├── Obstacles (Node2D)  ← 장애물 전담
        │   ├── CircularSaw_001
        │   ├── Spikes_001
        │   └── FallingObject_001
        │
        └── Player (CharacterBody2D)  ← 플레이어
            ├── CollisionShape2D
            ├── GunPivot (Node2D)               ← 총구 회전
            │   └── Bullet (씬 인스턴스)
            └── ColorStateManager (스크립트)    ← 현재 색 상태 관리



├── Background (ParallaxBackground)  ← 배경 레이어 3개 
        │   ├── ParallaxLayer_Far    (Layer1: 원경)
        │   ├── ParallaxLayer_Mid    (Layer2: 중경)
        │   └── ParallaxLayer_Near   (Layer3: 전경)