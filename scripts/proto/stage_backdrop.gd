extends RefCounted
## ============================================================================
## [2026-07-25 도형 · 신규] 스테이지 배경 빌더 (Stage Backdrop)
## ----------------------------------------------------------------------------
## ▣ 목표 — "바인(VINE)처럼 이어지지만 변한다"
##   스테이지마다 배경을 따로 만들면 넘어갈 때 뚝 끊긴다. 그래서 배경을
##   **한 스테이지 안에서 왼쪽→오른쪽으로 서서히 다음 바이옴으로 변하게** 만든다.
##     스테이지 1 : 자연 ────────→ 자연·물가 경계
##     스테이지 2 : 물가 ────────→ 물가
##     스테이지 3 : 물가 ────────→ 판자촌
##     스테이지 4 : 판자촌 ──────→ 도심
##     스테이지 5 : 도심 ────────→ 고층 (위로 상승)
##   각 스테이지의 **끝 바이옴 = 다음 스테이지의 시작 바이옴**이라, 통로를 지나
##   다음 스테이지로 나오면 하늘색과 실루엣이 그대로 이어진다.
##
## ▣ 어떻게 변하게 하나 (2가지를 동시에)
##   1. **하늘**: 네 귀퉁이 색(좌상/좌하/우상/우하)을 월드 좌표로 보간하는 셰이더.
##      좌측 = 시작 바이옴 팔레트 / 우측 = 끝 바이옴 팔레트 → 걸어갈수록 하늘이 변한다.
##   2. **실루엣**: 시작 바이옴 프롭은 왼쪽에 많고 오른쪽에서 사라지게(알파 감소),
##      끝 바이옴 프롭은 그 반대로. 가운데 구간에서 두 풍경이 겹친다 = 자연스러운 교차.
##
## ▣ 레이어 구성 (레인월드의 "깊이 레이어"를 Godot 패럴랙스로 옮긴 것)
##   z=-40 하늘          scroll 0.05
##   z=-30 원경 실루엣   scroll 0.20   (가장 밝고 흐림 = 공기원근)
##   z=-20 중경          scroll 0.42
##   z=-12 근경          scroll 0.68
##   z=-8  ★뒷벽        scroll 1.00   (지형 뒤를 채우는 어두운 벽 — "파낸 공간" 느낌)
##   z= 0  지형(발판)                  ← PaintPlatform
##   z=+12 전경 실루엣   scroll 1.18   (플레이어 앞을 스쳐 지나감 = 깊이감)
##
## ▣ 왜 뒷벽이 중요한가
##   지금까지 발판이 "허공에 뜬 막대기"로 보인 가장 큰 이유는 **뒤가 비어 있어서**다.
##   레인월드/리틀나이트메어의 지형이 묵직해 보이는 건 방이 항상 "덩어리에서 파낸 공간"
##   이기 때문이다. 어두운 뒷벽 한 장이면 같은 발판도 완전히 다르게 읽힌다.
##
## ▣ 사용법 (생성기에서)
##   StageBackdrop.구성(root, root, 범위, "자연", "물가", 자료)
##   → 노드를 전부 만들어 root 에 붙이고 owner 를 지정한다(씬 저장용).
## ============================================================================
class_name StageBackdrop

## ⚠ class_name 대신 **경로 preload** 로 잡는다 — 새 스크립트의 전역 클래스 이름은
##   에디터가 한 번 훑어야 등록돼서, 그 전에 헤드리스 검사를 돌리면 통째로 죽는다.
const 조명표준 := preload("res://scripts/스마트월드/조명표준.gd")

const PROPS := "res://assets/textures/props/"
const FLICKER := "res://scripts/proto/light_flicker.gd"

# ============================================================================
# 바이옴 팔레트
# ----------------------------------------------------------------------------
# 명도 규칙(레벨디자인_가이드 §5): 배경은 15~40% 또는 60~85%.
# **45~55% 는 회색(죽은 지형) 전용이라 배경이 절대 침범하면 안 된다.**
# 그래서 하늘은 전부 0.09~0.40 대역에 둔다.
# 색조는 무채색에 아주 미세한 편차만 준다(흑백 게임이므로) — 자연=따뜻, 물=차가움.
# ============================================================================
const 바이옴 := {
	"자연": {
		"하늘_위": Color(0.36, 0.36, 0.34),
		"하늘_아래": Color(0.15, 0.15, 0.14),
		"원경": ["tree_pine.svg", "tree_pine.svg", "tree_broad.svg"],
		"중경": ["tree_broad.svg", "tree_pine.svg", "rock_boulder.svg"],
		"근경": ["bush.svg", "grass_tuft.svg", "rock_boulder.svg"],
		"전경": ["bush.svg", "rock_boulder.svg"],
		"등불": "구슬",          # 반딧불 = 발광 구슬
		"바닥장식": ["grass_tuft.svg", "bush.svg"],
		"매달림": "hang_moss.svg",
	},
	"물가": {
		"하늘_위": Color(0.31, 0.32, 0.34),
		"하늘_아래": Color(0.11, 0.12, 0.13),
		"원경": ["tree_broad.svg", "dock_post.svg", "tree_pine.svg"],
		"중경": ["dock_post.svg", "reed.svg", "rock_boulder.svg"],
		"근경": ["reed.svg", "water_plant.svg", "reed.svg"],
		"전경": ["reed.svg", "water_plant.svg"],
		"등불": "구슬",
		"바닥장식": ["reed.svg", "water_plant.svg", "grass_tuft.svg"],
		"매달림": "hang_moss.svg",
		"물": true,               # 바닥에 수면 반사 스트립을 깐다
	},
	"판자촌": {
		"하늘_위": Color(0.27, 0.27, 0.28),
		"하늘_아래": Color(0.09, 0.09, 0.10),
		"원경": ["shanty.svg", "highrise.svg", "shanty.svg"],
		"중경": ["shanty.svg", "water_tank.svg", "wire_pole.svg"],
		"근경": ["pipe_cluster.svg", "water_tank.svg", "wire_pole.svg"],
		"전경": ["pipe_cluster.svg", "reed.svg"],
		"등불": "가로등",
		"바닥장식": ["pipe_cluster.svg", "grass_tuft.svg"],
		"매달림": "hang_moss.svg",
	},
	"도심": {
		"하늘_위": Color(0.24, 0.24, 0.26),
		"하늘_아래": Color(0.08, 0.08, 0.09),
		"원경": ["highrise.svg", "highrise.svg", "crane.svg"],
		"중경": ["highrise.svg", "water_tank.svg", "shanty.svg"],
		"근경": ["wire_pole.svg", "pipe_cluster.svg", "water_tank.svg"],
		"전경": ["pipe_cluster.svg", "reed.svg"],
		"등불": "가로등",
		"바닥장식": ["pipe_cluster.svg"],
		"매달림": "hang_moss.svg",
	},
	"고층": {
		"하늘_위": Color(0.40, 0.40, 0.42),   # 위로 갈수록 새벽빛 — "높이 왔다"는 신호
		"하늘_아래": Color(0.09, 0.09, 0.11),
		"원경": ["highrise.svg", "antenna.svg", "highrise.svg"],
		"중경": ["highrise.svg", "crane.svg", "antenna.svg"],
		"근경": ["antenna.svg", "water_tank.svg", "wire_pole.svg"],
		"전경": ["pipe_cluster.svg", "water_tank.svg"],
		"등불": "가로등",
		"바닥장식": ["pipe_cluster.svg"],
		"매달림": "hang_moss.svg",
	},
}

## 레이어별 설정: [이름, 가로 패럴랙스 계수, z, 밝기(공기원근), 프롭 개수, 크기 배율, 지면비율]
##
## ⚠[2026-07-25 수정] 두 가지를 고쳤다 (첫 스크린샷에서 나무가 화면 **아래쪽**에 깔림).
##   ① 지면선을 "패딩 포함 사각형"이 아니라 **지형 실제 범위** 기준으로 잡는다.
##      지면비율 = 지형 높이에 대한 비율. 음수일수록 위(=지평선 쪽)에 걸린다.
##   ② **세로 패럴랙스를 끈다**(y 계수 1.0). Parallax2D 는 계수가 1 보다 작으면
##      카메라가 움직인 만큼 레이어를 되밀어서, 세로로 긴 스테이지에서 프롭이
##      엉뚱한 높이로 떠버린다. 가로만 시차를 주는 게 2D 플랫포머의 안전한 정석.
const 레이어 := [
	["원경", 0.20, -30, 0.58, 14, 1.20, -0.55],
	["중경", 0.42, -20, 0.36, 12, 1.00, -0.32],
	["근경", 0.68, -12, 0.22, 10, 0.80, -0.10],
	["전경", 1.15,  12, 0.15, 4, 1.55,  0.62],
]

# ============================================================================
# 메인 진입점
# ============================================================================
## parent/owner = 노드를 붙일 곳과 씬 저장 owner (보통 둘 다 스테이지 루트)
## 범위 = 지형이 차지하는 월드 사각형
## 시작/끝 = 바이옴 이름. 스테이지를 가로지르며 시작 → 끝으로 변한다.
static func 구성(parent: Node, owner: Node, 범위: Rect2,
		시작: String, 끝: String, 씨앗: int = 20260725) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 씨앗

	var a: Dictionary = 바이옴.get(시작, 바이옴["자연"])
	var b: Dictionary = 바이옴.get(끝, a)

	# 화면 밖까지 넉넉히 덮는다 (카메라가 리밋 끝까지 갔을 때 빈 공간이 안 보이게)
	var 여백 := Vector2(1400, 900)
	var 사각 := Rect2(범위.position - 여백, 범위.size + 여백 * 2.0)

	_하늘(parent, owner, 사각, a, b)
	_뒷벽(parent, owner, Rect2(범위.position - Vector2(1300, 460),
		범위.size + Vector2(2600, 1000)))
	for L in 레이어:
		_프롭_레이어(parent, owner, 사각, 범위, a, b, L, rng)
	_안개(parent, owner, 사각)

# ============================================================================
# 1) 하늘 — 네 귀퉁이 색을 월드 좌표로 보간 (걸어갈수록 색이 변한다)
# ============================================================================
static func _하늘(parent: Node, owner: Node, 사각: Rect2,
		a: Dictionary, b: Dictionary) -> void:
	var par := Parallax2D.new()
	par.name = "배경_하늘"
	par.scroll_scale = Vector2(0.05, 0.05)     # 거의 안 움직임 = 아주 먼 하늘
	par.z_index = -40

	var poly := Polygon2D.new()
	poly.name = "Sky"
	poly.polygon = PackedVector2Array([
		사각.position, Vector2(사각.end.x, 사각.position.y),
		사각.end, Vector2(사각.position.x, 사각.end.y)])

	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
// 폴리곤이 월드 좌표로 찍혀 있으므로 VERTEX = 월드 좌표
varying vec2 wpos;
uniform vec4 rect = vec4(0.0, 0.0, 1.0, 1.0);   // x, y, w, h (월드)
uniform vec3 c_tl : source_color = vec3(0.36);  // 좌상 = 시작 바이옴 하늘 위
uniform vec3 c_bl : source_color = vec3(0.15);  // 좌하 = 시작 바이옴 하늘 아래
uniform vec3 c_tr : source_color = vec3(0.24);  // 우상 = 끝 바이옴
uniform vec3 c_br : source_color = vec3(0.08);
void vertex() { wpos = VERTEX; }
float hash(vec2 p){ return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453); }
void fragment() {
	float tx = clamp((wpos.x - rect.x) / max(rect.z, 1.0), 0.0, 1.0);
	float ty = clamp((wpos.y - rect.y) / max(rect.w, 1.0), 0.0, 1.0);
	// 세로는 위→아래, 가로는 시작 바이옴→끝 바이옴. smoothstep 으로 전환 구간을 완만하게.
	float tb = smoothstep(0.12, 0.88, tx);
	vec3 top = mix(c_tl, c_tr, tb);
	vec3 bot = mix(c_bl, c_br, tb);
	vec3 col = mix(top, bot, pow(ty, 0.85));
	// 아주 미세한 그레인 — 평평한 그라데이션의 밴딩(줄무늬)을 깬다
	col += (hash(floor(wpos * 0.5)) - 0.5) * 0.012;
	COLOR = vec4(col, 1.0);
}"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("rect",
		Vector4(사각.position.x, 사각.position.y, 사각.size.x, 사각.size.y))
	mat.set_shader_parameter("c_tl", a["하늘_위"])
	mat.set_shader_parameter("c_bl", a["하늘_아래"])
	mat.set_shader_parameter("c_tr", b["하늘_위"])
	mat.set_shader_parameter("c_br", b["하늘_아래"])
	poly.material = mat

	par.add_child(poly)
	parent.add_child(par)
	par.owner = owner
	poly.owner = owner

# ============================================================================
# 2) ★뒷벽 — 지형 뒤를 채우는 어두운 암반. "허공의 막대기"를 "파낸 공간"으로 바꾼다
# ============================================================================
static func _뒷벽(parent: Node, owner: Node, 사각: Rect2) -> void:
	var poly := Polygon2D.new()
	poly.name = "배경_뒷벽"
	poly.z_index = -8
	poly.polygon = PackedVector2Array([
		사각.position, Vector2(사각.end.x, 사각.position.y),
		사각.end, Vector2(사각.position.x, 사각.end.y)])

	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
varying vec2 wpos;
uniform vec4 rect = vec4(0.0, 0.0, 1.0, 1.0);
void vertex() { wpos = VERTEX; }
float hash(vec2 p){ p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float vnoise(vec2 p){
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1,0)), f.x),
	           mix(hash(i + vec2(0,1)), hash(i + vec2(1,1)), f.x), f.y);
}
void fragment() {
	// 큰 덩어리 + 잔 알갱이 = 거칠게 파낸 암반 질감
	float n = vnoise(wpos * 0.0035) * 0.62 + vnoise(wpos * 0.017) * 0.26 + vnoise(wpos * 0.09) * 0.12;
	// 위에서 아래로 어두워짐 (빛은 위에서 들어온다)
	float tx = clamp((wpos.x - rect.x) / max(rect.z, 1.0), 0.0, 1.0);
	float ty = clamp((wpos.y - rect.y) / max(rect.w, 1.0), 0.0, 1.0);
	float v = 0.115 + n * 0.075 - ty * 0.045;
	// ★[2026-07-25] 가장자리를 알파로 흐리게 — 안 그러면 뒷벽 끝에 직선 이음매가 보인다
	//   (첫 스크린샷에서 화면 중간에 가로로 딱 떨어지는 경계선이 생겼다)
	float edge = smoothstep(0.0, 0.10, tx) * smoothstep(1.0, 0.90, tx)
	           * smoothstep(0.0, 0.09, ty) * smoothstep(1.0, 0.88, ty);
	COLOR = vec4(vec3(v), edge);
}"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("rect",
		Vector4(사각.position.x, 사각.position.y, 사각.size.x, 사각.size.y))
	poly.material = mat
	parent.add_child(poly)
	poly.owner = owner

# ============================================================================
# 3) 프롭 실루엣 레이어 — 시작 바이옴 → 끝 바이옴 교차 페이드
# ============================================================================
static func _프롭_레이어(parent: Node, owner: Node, 사각: Rect2, 범위: Rect2,
		a: Dictionary, b: Dictionary, 설정: Array,
		rng: RandomNumberGenerator) -> void:
	var 이름: String = 설정[0]
	var 스크롤: float = 설정[1]
	var z: int = 설정[2]
	var 밝기: float = 설정[3]
	var 개수: int = 설정[4]
	var 배율: float = 설정[5]
	var 지면비율: float = 설정[6]

	var par := Parallax2D.new()
	par.name = "배경_" + 이름
	# ★세로 시차 없음 (위 주석 ② 참조) — 가로로만 흐른다
	par.scroll_scale = Vector2(스크롤, 1.0)
	par.z_index = z
	parent.add_child(par)
	par.owner = owner

	var 목록_a: Array = a.get(이름, [])
	var 목록_b: Array = b.get(이름, [])
	if 목록_a.is_empty() and 목록_b.is_empty():
		return

	# 지면선: **지형 실제 바닥** 기준. 멀수록 위(지평선 쪽)에 걸린다.
	var 지면 := 범위.end.y + 범위.size.y * 지면비율

	# ⚠[2026-07-25 수정] 프롭을 "패딩 포함 사각형(좌우 +1400)" 전체에 흩뿌렸더니
	#   절반 이상이 지형 밖 허공에 놓여 **화면에 거의 안 보였다**(스크린샷에서 확인).
	#   → 지형 범위 + 좌우 900px 안에만 심는다. 밀도가 실제로 눈에 들어온다.
	var 좌 := 범위.position.x - 900.0
	var 폭 := 범위.size.x + 1800.0

	for i in 개수 * 2:
		# t = 0(왼쪽) ~ 1(오른쪽). 시작 바이옴은 왼쪽에, 끝 바이옴은 오른쪽에 많다.
		var t := (float(i) + rng.randf_range(0.15, 0.85)) / float(개수 * 2)
		var 끝쪽 := i % 2 == 1
		var 목록: Array = 목록_b if 끝쪽 else 목록_a
		if 목록.is_empty():
			continue
		# 교차 페이드: 시작 바이옴은 t 가 커질수록 사라지고, 끝 바이옴은 나타난다
		var 존재 := (1.0 - smoothstep(0.30, 0.85, t)) if not 끝쪽 else smoothstep(0.15, 0.70, t)
		if 존재 < 0.06:
			continue
		var 파일: String = 목록[rng.randi() % 목록.size()]
		var x := 좌 + 폭 * t
		var s := 배율 * rng.randf_range(0.8, 1.25)
		var y := 지면 + rng.randf_range(-30.0, 30.0) * 배율
		_프롭(par, owner, 파일, Vector2(x, y), 0, rng.randf() < 0.5, s,
			Color(밝기, 밝기, 밝기, minf(존재, 1.0)))

## 프롭 하나 배치 (pos = 아랫변이 닿을 지면 좌표)
static func _프롭(parent: Node, owner: Node, 파일: String, pos: Vector2,
		z: int, flip: bool, 배율: float, 틴트: Color) -> void:
	if not ResourceLoader.exists(PROPS + 파일):
		return
	var tex: Texture2D = load(PROPS + 파일)
	var spr := Sprite2D.new()
	spr.name = "P_%s_%d" % [파일.get_basename(), parent.get_child_count()]
	spr.texture = tex
	spr.centered = false
	spr.position = pos - Vector2(tex.get_width() * 배율 * 0.5, tex.get_height() * 배율)
	spr.scale = Vector2(배율, 배율)
	spr.flip_h = flip
	spr.z_index = z
	spr.modulate = 틴트
	parent.add_child(spr)
	spr.owner = owner

# ============================================================================
# 4) 전경 안개 — 화면 아래쪽에 옅게 깔리는 대기감 (깊이 분리)
# ============================================================================
static func _안개(parent: Node, owner: Node, 사각: Rect2) -> void:
	var par := Parallax2D.new()
	par.name = "배경_안개"
	par.scroll_scale = Vector2(0.85, 0.85)
	par.z_index = -6
	var poly := Polygon2D.new()
	poly.name = "Fog"
	poly.polygon = PackedVector2Array([
		사각.position, Vector2(사각.end.x, 사각.position.y),
		사각.end, Vector2(사각.position.x, 사각.end.y)])
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
varying vec2 wpos;
uniform vec4 rect = vec4(0.0, 0.0, 1.0, 1.0);
void vertex() { wpos = VERTEX; }
float hash(vec2 p){ p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float vnoise(vec2 p){
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1,0)), f.x),
	           mix(hash(i + vec2(0,1)), hash(i + vec2(1,1)), f.x), f.y);
}
void fragment() {
	float ty = clamp((wpos.y - rect.y) / max(rect.w, 1.0), 0.0, 1.0);
	// 아주 느리게 흐르는 안개 띠
	float n = vnoise(vec2(wpos.x * 0.004 + TIME * 0.012, wpos.y * 0.010));
	float a = smoothstep(0.45, 0.95, ty) * (0.10 + n * 0.14);
	COLOR = vec4(vec3(0.62, 0.62, 0.65), a);
}"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("rect",
		Vector4(사각.position.x, 사각.position.y, 사각.size.x, 사각.size.y))
	poly.material = mat
	par.add_child(poly)
	parent.add_child(par)
	par.owner = owner
	poly.owner = owner

# ============================================================================
# 5) 광원 부품 — 생성기가 좌표를 주면 하나씩 심는다
# ============================================================================
## 라디얼 광원 (zone_visuals.gd 플레이어 광원과 같은 방식 = 외부 에셋 0)
static func 광원(parent: Node, owner: Node, 이름: String, pos: Vector2,
		반경: float, 세기: float, 색: Color, 깜빡임: bool) -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 256
	tex.height = 256
	var light := PointLight2D.new()
	light.name = 이름
	if 깜빡임 and ResourceLoader.exists(FLICKER):
		light.set_script(load(FLICKER))      # 촛불식 미세 깜빡임
	light.texture = tex
	light.texture_scale = 반경 * 2.0 / 256.0
	light.energy = 세기
	light.color = 색
	# ★[2026-09-05] 조명 표준 — height 128 · ADD.
	조명표준.적용(light)
	light.position = pos
	parent.add_child(light)
	light.owner = owner

## 가로등 = 기둥 일러스트 + 전구 광원 한 세트.
## base_x = 받침 중심, ground_y = 지면. 전구는 SVG 로컬 (44, 31).
## z=-1 : 기둥이 플레이어 "뒤"에 서야 등반 중 캐릭터를 가리지 않는다 (11차 검증 결과)
static func 가로등(parent: Node, owner: Node, 이름: String,
		base_x: float, ground_y: float, flip: bool = false) -> void:
	_프롭(parent, owner, "lamp_post.svg", Vector2(base_x, ground_y), -1, flip, 1.0,
		Color(0.30, 0.30, 0.30))
	var bulb_x := base_x + (-16.0 if flip else 16.0)
	광원(parent, owner, 이름, Vector2(bulb_x, ground_y - 149.0),
		300.0, 1.15, Color(1.0, 0.94, 0.78), true)

## 발광 구슬 / 반딧불 — 자연·물가 바이옴의 광원
static func 구슬(parent: Node, owner: Node, 이름: String, 중심: Vector2,
		반경: float = 170.0, 세기: float = 0.75) -> void:
	if ResourceLoader.exists(PROPS + "glow_orb.svg"):
		var spr := Sprite2D.new()
		spr.name = 이름 + "Sprite"
		spr.texture = load(PROPS + "glow_orb.svg")
		spr.position = 중심
		spr.z_index = 2
		parent.add_child(spr)
		spr.owner = owner
	광원(parent, owner, 이름 + "Light", 중심, 반경, 세기, Color(0.95, 0.97, 1.0), true)

## 수면 — 빛이 비치는 물. 물 바이옴 바닥에 깐다.
## streak_x 아래가 가장 밝게 빛나고(반사 스트릭), 잔물결 반짝임이 흐른다.
static func 수면(parent: Node, owner: Node, 이름: String,
		x0: float, x1: float, y0: float, y1: float, streak_x: float) -> void:
	var poly := Polygon2D.new()
	poly.name = 이름
	poly.polygon = PackedVector2Array([
		Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])
	poly.z_index = 3
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
varying vec2 wpos;
uniform float streak_x = 0.0;
void vertex() { wpos = VERTEX; }
void fragment() {
	// 잔물결: 주기가 다른 사인파 2개의 곱 — 불규칙해 보이는 흐름
	float shimmer = sin(wpos.x * 0.16 + TIME * 2.1) * sin(wpos.x * 0.055 - TIME * 1.4);
	// 광원 바로 아래가 가장 밝은 가우시안 반사 스트릭
	float streak = exp(-pow((wpos.x - streak_x) / 90.0, 2.0));
	float a = 0.10 + 0.30 * streak + max(shimmer, 0.0) * (0.05 + 0.24 * streak);
	vec3 col = mix(vec3(0.78, 0.80, 0.84), vec3(1.0, 0.95, 0.80), streak);
	COLOR = vec4(col, a);
}"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("streak_x", streak_x)
	poly.material = mat
	parent.add_child(poly)
	poly.owner = owner

# ============================================================================
# 6) ★발판 장식 — "막대기"를 "덩어리"로 만드는 마지막 한 겹
# ============================================================================
## 플랫폼 하나에 윗면 풀/파이프 + 아랫면 늘어진 이끼를 자동으로 붙인다.
## 색칠 셰이더와 분리된 별도 스프라이트라 **칠해져도 장식은 그대로 남는다**
## (지형이 색을 바꿔도 실루엣의 디테일은 유지 = 레인월드식 읽기).
static func 발판_장식(parent: Node, owner: Node, 중심: Vector2, 크기: Vector2,
		바이옴이름: String, rng: RandomNumberGenerator) -> void:
	var b: Dictionary = 바이옴.get(바이옴이름, 바이옴["자연"])
	var 윗면 := 중심.y - 크기.y * 0.5
	var 아랫면 := 중심.y + 크기.y * 0.5
	var 좌 := 중심.x - 크기.x * 0.5
	var 우 := 중심.x + 크기.x * 0.5

	# ── 윗면 장식: 폭 1칸당 약 0.4개 ──
	var 바닥목록: Array = b.get("바닥장식", [])
	if not 바닥목록.is_empty():
		var n := maxi(int(크기.x / 80.0), 1)
		for i in n:
			if rng.randf() > 0.62:
				continue
			var 파일: String = 바닥목록[rng.randi() % 바닥목록.size()]
			var x := 좌 + 크기.x * (float(i) + rng.randf_range(0.15, 0.85)) / float(n)
			# z=-2 : 발판 그림 뒤에 살짝 걸쳐 "발판에서 자라난" 느낌
			_프롭(parent, owner, 파일, Vector2(x, 윗면 + 3.0), -2,
				rng.randf() < 0.5, rng.randf_range(0.5, 0.85),
				Color(0.22, 0.22, 0.22))

	# ── 아랫면: 늘어진 이끼/덩굴 ──
	# ⚠[2026-07-25] 처음엔 폭 96px 이상 전부에 달았더니 **바닥(60칸짜리)에도 주렁주렁**
	#   매달려 허공에 낙서한 것처럼 보였다(스크린샷). → 바닥/거대 선반은 제외하고,
	#   "공중에 떠 있는 발판"(폭 20칸 미만)에만 단다.
	var 매달림: String = b.get("매달림", "")
	if 매달림 != "" and 크기.x >= 96.0 and 크기.x <= 640.0 and rng.randf() < 0.7:
		var mx := 좌 + 크기.x * rng.randf_range(0.15, 0.7)
		var tex_ok := ResourceLoader.exists(PROPS + 매달림)
		if tex_ok:
			var tex: Texture2D = load(PROPS + 매달림)
			var spr := Sprite2D.new()
			spr.name = "Hang_%d" % parent.get_child_count()
			spr.texture = tex
			spr.centered = false
			var s := rng.randf_range(0.55, 0.95)
			spr.scale = Vector2(s, s)
			spr.position = Vector2(mx, 아랫면 - 4.0)
			spr.z_index = -3
			spr.modulate = Color(0.18, 0.18, 0.18)
			parent.add_child(spr)
			spr.owner = owner
