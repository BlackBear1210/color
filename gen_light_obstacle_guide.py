from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import mm
from reportlab.lib import colors
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle,
    HRFlowable, Preformatted
)
from reportlab.lib.enums import TA_LEFT, TA_CENTER
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
import os

# ── 한글 폰트 등록 ────────────────────────────────────────────────
font_candidates = [
    "C:/Windows/Fonts/malgun.ttf",
    "C:/Windows/Fonts/NanumGothic.ttf",
]
for path in font_candidates:
    if os.path.exists(path):
        pdfmetrics.registerFont(TTFont("Korean", path))
        FONT = "Korean"
        break
else:
    FONT = "Helvetica"

# ── 스타일 ─────────────────────────────────────────────────────────
BASE = getSampleStyleSheet()

def S(name, parent="Normal", **kw):
    kw.setdefault("fontName", FONT)
    return ParagraphStyle(name, parent=BASE[parent], **kw)

title_style    = S("Title2",   "Title",   fontSize=20, spaceAfter=6, textColor=colors.HexColor("#1a1a2e"))
h1_style       = S("H1",       "Heading1", fontSize=14, spaceBefore=14, spaceAfter=4, textColor=colors.HexColor("#16213e"))
h2_style       = S("H2",       "Heading2", fontSize=11, spaceBefore=10, spaceAfter=3, textColor=colors.HexColor("#0f3460"))
body_style     = S("Body",     fontSize=9,  spaceAfter=4, leading=15)
caption_style  = S("Caption",  fontSize=8,  textColor=colors.gray, spaceAfter=6)
code_style     = ParagraphStyle(
    "Code", fontName="Courier", fontSize=8,
    backColor=colors.HexColor("#f4f4f4"), leftIndent=8,
    borderPad=6, leading=13, spaceAfter=6
)
bullet_style   = S("Bullet",   fontSize=9, leftIndent=12, spaceAfter=3, leading=14)
warn_style     = S("Warn",     fontSize=9, textColor=colors.HexColor("#b5451b"), spaceAfter=4)

def hr(): return HRFlowable(width="100%", thickness=0.5, color=colors.HexColor("#cccccc"), spaceAfter=6)
def sp(h=4): return Spacer(1, h*mm)
def p(text, style=body_style): return Paragraph(text, style)
def b(text): return Paragraph(f"• {text}", bullet_style)
def code(text): return Preformatted(text, code_style)

# ── 표 스타일 헬퍼 ─────────────────────────────────────────────────
def make_table(data, col_widths):
    t = Table(data, colWidths=col_widths)
    t.setStyle(TableStyle([
        ("BACKGROUND",  (0,0), (-1,0),  colors.HexColor("#16213e")),
        ("TEXTCOLOR",   (0,0), (-1,0),  colors.white),
        ("FONTNAME",    (0,0), (-1,-1), FONT),
        ("FONTSIZE",    (0,0), (-1,0),  9),
        ("FONTSIZE",    (0,1), (-1,-1), 8),
        ("ROWBACKGROUNDS",(0,1),(-1,-1),[colors.white, colors.HexColor("#f0f4ff")]),
        ("GRID",        (0,0), (-1,-1), 0.4, colors.HexColor("#cccccc")),
        ("TOPPADDING",  (0,0), (-1,-1), 5),
        ("BOTTOMPADDING",(0,0),(-1,-1), 5),
        ("LEFTPADDING", (0,0), (-1,-1), 7),
        ("ALIGN",       (0,0), (-1,-1), "LEFT"),
        ("VALIGN",      (0,0), (-1,-1), "MIDDLE"),
    ]))
    return t

# ── 문서 빌드 ──────────────────────────────────────────────────────
out_path = "light_obstacle_guide.pdf"
doc = SimpleDocTemplate(
    out_path, pagesize=A4,
    leftMargin=20*mm, rightMargin=20*mm,
    topMargin=22*mm, bottomMargin=22*mm
)

story = []

# 제목
story.append(p("가로등 장애물 구현 가이드라인", title_style))
story.append(p("Godot 4 · 프로그래머용", caption_style))
story.append(hr())
story.append(sp(2))

# ── 1. 개요 ────────────────────────────────────────────────────────
story.append(p("1. 개요", h1_style))
story.append(p(
    "오브젝트에서 부채꼴 모양의 빛이 나옵니다. 빛의 색상은 흰색 또는 검은색이며, "
    "플레이어와 같은 색일 때만 통과 가능합니다. 다른 색이면 사망 처리됩니다. "
    "색이 전환되는 동안(흰↔검)은 어떤 색의 플레이어도 안전합니다."))
story.append(sp())

# ── 2. 기존 코드 연동 방식 ─────────────────────────────────────────
story.append(p("2. 기존 코드 연동 방식", h1_style))
story.append(p(
    "player.gd 는 수정하지 않습니다. "
    "기존 <b>_check_color_death()</b> 함수가 아래 조건으로 사망 판정합니다."))
story.append(sp(1))
story.append(code(
    "  Area2D 가 'death_zones' 그룹에 속해 있고\n"
    "  부모 노드의 color_state != player_color  →  사망"
))
story.append(p(
    "색 전환 중일 때는 <b>_area.remove_from_group(\"death_zones\")</b> 으로 판정 영역을 "
    "일시 제거하면, player.gd 수정 없이 안전 구간을 구현할 수 있습니다. "
    "전환이 끝나면 다시 <b>add_to_group(\"death_zones\")</b> 으로 복구합니다."))
story.append(sp())

# ── 3. 씬 구조 ─────────────────────────────────────────────────────
story.append(p("3. 씬 구조  (LightObstacle.tscn)", h1_style))
story.append(code(
    "  LightObstacle   (Node2D)            ← light_obstacle.gd 부착\n"
    "  ├── LampSprite   (Sprite2D)         ← 가로등 오브젝트 이미지\n"
    "  ├── LightVisual  (Sprite2D)         ← 부채꼴 빛 이미지 (반투명)\n"
    "  └── DetectionArea (Area2D)          ← 사망 판정 영역\n"
    "      └── CollisionPolygon2D          ← 코드에서 부채꼴로 자동 생성"
))
story.append(p("⚠ DetectionArea 설정: Monitoring = ON,  Monitorable = OFF", warn_style))
story.append(sp())

# ── 4. 스크립트 ────────────────────────────────────────────────────
story.append(p("4. 스크립트  (light_obstacle.gd)", h1_style))
story.append(code(
    "extends Node2D\n"
    "\n"
    "# ── 인스펙터 ──────────────────────────────────────────────────\n"
    "@export_enum(\"BLACK:0\", \"WHITE:1\")\n"
    "var start_color: int      = ColorDefs.BLACK\n"
    "\n"
    "@export var hold_time: float       = 2.0    # 한 색이 유지되는 시간(초)\n"
    "@export var transition_time: float = 0.5    # 색 전환에 걸리는 시간(초)\n"
    "@export var light_radius: float    = 200.0  # 부채꼴 반지름(px)\n"
    "@export var light_angle: float     = 90.0   # 부채꼴 각도(도)\n"
    "\n"
    "# ── player.gd 가 읽는 값 ───────────────────────────────────────\n"
    "var color_state: int = ColorDefs.BLACK\n"
    "\n"
    "# ── 내부 ──────────────────────────────────────────────────────\n"
    "var _is_transitioning: bool = false\n"
    "var _timer: float = 0.0\n"
    "\n"
    "@onready var _area:    Area2D             = $DetectionArea\n"
    "@onready var _polygon: CollisionPolygon2D = $DetectionArea/CollisionPolygon2D\n"
    "@onready var _visual:  Sprite2D           = $LightVisual\n"
    "\n"
    "func _ready() -> void:\n"
    "    color_state = start_color\n"
    "    _timer      = hold_time\n"
    "    _area.add_to_group(\"death_zones\")\n"
    "    _build_fan_polygon()\n"
    "    _update_visual()\n"
    "\n"
    "func _process(delta: float) -> void:\n"
    "    _timer -= delta\n"
    "    if _timer <= 0.0:\n"
    "        if _is_transitioning:\n"
    "            _end_transition()\n"
    "        else:\n"
    "            _start_transition()\n"
    "\n"
    "# 전환 시작: death_zones 에서 제거 → 플레이어 안전\n"
    "func _start_transition() -> void:\n"
    "    _is_transitioning = true\n"
    "    _timer = transition_time\n"
    "    _area.remove_from_group(\"death_zones\")\n"
    "    # TODO: 시각 전환 연출 (트윈, 깜빡임 등)\n"
    "\n"
    "# 전환 완료: 색 교체 후 death_zones 복구\n"
    "func _end_transition() -> void:\n"
    "    _is_transitioning = false\n"
    "    color_state = ColorDefs.WHITE if color_state == ColorDefs.BLACK \\\n"
    "                                  else ColorDefs.BLACK\n"
    "    _timer = hold_time\n"
    "    _area.add_to_group(\"death_zones\")\n"
    "    _update_visual()\n"
    "\n"
    "# 부채꼴 충돌체 자동 생성\n"
    "# 노드 회전값으로 방향 조절 가능 (에디터에서 LightObstacle 회전)\n"
    "func _build_fan_polygon() -> void:\n"
    "    var points := PackedVector2Array()\n"
    "    points.append(Vector2.ZERO)  # 부채꼴 꼭짓점(중심)\n"
    "\n"
    "    var half_rad := deg_to_rad(light_angle * 0.5)\n"
    "    var steps    := 16  # 높을수록 곡선이 부드러움\n"
    "\n"
    "    for i in steps + 1:\n"
    "        var angle := -half_rad + (half_rad * 2.0 / steps) * i\n"
    "        points.append(Vector2(cos(angle), sin(angle)) * light_radius)\n"
    "\n"
    "    _polygon.polygon = points\n"
    "\n"
    "# 비주얼 색상 업데이트\n"
    "func _update_visual() -> void:\n"
    "    if _visual:\n"
    "        _visual.modulate = Color.BLACK if color_state == ColorDefs.BLACK \\\n"
    "                                       else Color.WHITE"
))
story.append(sp())

# ── 5. 인스펙터 항목 ───────────────────────────────────────────────
story.append(p("5. 인스펙터 설정 항목", h1_style))
insp_data = [
    ["항목", "설명", "기본값"],
    ["Start Color",      "시작 색 (BLACK / WHITE)",        "BLACK"],
    ["Hold Time",        "한 색이 유지되는 시간 (초)",      "2.0"],
    ["Transition Time",  "색 전환에 걸리는 시간 (초)",      "0.5"],
    ["Light Radius",     "부채꼴 반지름 (px)",              "200.0"],
    ["Light Angle",      "부채꼴 각도 (도)",                "90.0"],
]
insp_rows = []
for row in insp_data:
    insp_rows.append([Paragraph(c, ParagraphStyle("tc", fontName=FONT, fontSize=8, leading=12)) for c in row])
story.append(make_table(insp_rows, [50*mm, 90*mm, 30*mm]))
story.append(sp())

# ── 6. 방향 조절 ───────────────────────────────────────────────────
story.append(p("6. 방향 조절", h1_style))
story.append(p(
    "부채꼴은 항상 <b>+X 방향(오른쪽)</b> 기준으로 생성됩니다. "
    "에디터에서 LightObstacle 노드를 <b>회전</b>시키면 빛의 방향을 자유롭게 설정할 수 있습니다."))
story.append(sp())

# ── 7. 주의사항 ────────────────────────────────────────────────────
story.append(p("7. 주의사항", h1_style))
story.append(b("player.gd 는 수정하지 않습니다. 기존 death_zones 그룹 시스템을 그대로 활용합니다."))
story.append(b("DetectionArea 의 Monitoring 은 반드시 ON 으로 설정해야 합니다."))
story.append(b("LightVisual 이미지는 부채꼴 모양의 반투명 스프라이트를 사용하세요."))
story.append(b("시각적 전환 연출(_start_transition 내 TODO)은 별도로 구현이 필요합니다."))
story.append(b("light_radius / light_angle 변경 시 _build_fan_polygon() 은 _ready() 에서만 호출됩니다. 런타임 중 변경이 필요하면 직접 재호출하세요."))

story.append(sp(4))
story.append(hr())
story.append(p("light_obstacle_guide  ·  Godot 4", caption_style))

doc.build(story)
print(f"생성 완료: {out_path}")
