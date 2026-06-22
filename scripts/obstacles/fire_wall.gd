extends Area2D
## ▼ 2026-06-22 신규(stage_3 특별 스테이지): 추격하는 '불의 장벽'.
##
## ◆ 컨셉
##   - 스테이지가 시작되면 화면 왼쪽에서 오른쪽으로 '서서히' 전진하는 거대한 불의 벽.
##   - 벽에 닿으면 색과 무관하게 즉시 사망 → 플레이어는 계속 오른쪽으로 달려 도망쳐야 한다.
##   - 세로로 화면 전체를 덮으므로 점프로 넘어갈 수 없다(피할 길은 '앞으로 전진'뿐).
##
## ◆ 설계
##   - Area2D(layer 없음, mask=1)로 플레이어(layer1)만 감지 → 닿으면 die().
##   - add_to_group("obstacle") → 색총 PaintMark 가 생기지 않음.
##   - start_delay 동안은 제자리(플레이어가 출발할 시간) → 이후 advance_speed 로 전진.
##   - 물리 콜백 내 직접 die() 금지 → call_deferred 사용.
##
## ▼ 2026-06-22 보강(디자인 완성도):
##   ① 사망 리셋: 플레이어가 죽으면 불벽도 시작 위치로 되돌린다.
##      (안 하면 죽고 리스폰돼도 불은 이미 앞에 있어 '죽자마자 또 죽는' 무한루프가 됨 — 추격물 필수.)
##   ② 위급 연출: 불이 플레이어에게 가까워지면 화면 가장자리에 붉은 비네트를 점점 강하게 + 맥동.
##      (셀레스트/소닉 탈출 구간처럼 '쫓기는 긴장감'을 주는 장르 표준 피드백.)

## 초당 전진 속도(px). 플레이어 이동속도(390)보다 충분히 느려야 도망이 가능.
@export var advance_speed: float = 175.0
## 시작 후 멈춰 있는 시간(초). 플레이어가 먼저 달려나갈 여유.
@export var start_delay: float = 1.2
## 전진을 멈출 한계 x(이 값 이상 가지 않음). 0 이하면 무제한.
@export var stop_at_x: float = 0.0
## 이 거리(px) 안으로 불이 다가오면 위급 붉은 비네트가 보이기 시작.
@export var danger_range: float = 760.0
## ▼ 추격 게이지(하단 바)용: 출발 x ~ 목표(포탈) x. goal_x<=0 이면 게이지 숨김.
@export var track_start_x: float = 0.0
@export var goal_x: float = 0.0

var _elapsed: float = 0.0
var _initial_x: float = 0.0          # 사망 리셋용 시작 x
var _player: Node2D = null

# 위급 연출용(코드로 생성하는 전체화면 비네트)
var _danger_rect: ColorRect = null
var _danger_mat: ShaderMaterial = null

# 추격 게이지(하단 바)
var _gauge_track: ColorRect = null
var _gauge_fill: ColorRect = null
var _gauge_fire: ColorRect = null

const DANGER_SHADER_CODE := """
shader_type canvas_item;
uniform float intensity = 0.0;
void fragment() {
	float d = distance(UV, vec2(0.5));
	float edge = smoothstep(0.30, 0.85, d);
	COLOR = vec4(0.95, 0.08, 0.0, edge * intensity);
}
"""


func _ready() -> void:
	add_to_group("obstacle")     # 색총 PaintMark 차단
	collision_layer = 0
	collision_mask  = 1          # 플레이어(layer1)만 감지
	monitoring      = true
	monitorable     = false
	body_entered.connect(_on_body_entered)

	_initial_x = global_position.x
	_setup_danger_overlay()

	# ▼ 플레이어 연결은 한 프레임 뒤로 미룬다.
	#   이유: FireWall 이 Player 보다 먼저 _ready 되면 player 가 아직 "player" 그룹에 없어
	#         조회/시그널 연결이 빈손이 된다 → deferred 로 모든 _ready 완료 후 연결.
	call_deferred("_connect_player")


func _connect_player() -> void:
	_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player and _player.has_signal("died") and not _player.died.is_connected(_on_player_died):
		_player.died.connect(_on_player_died)


func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= start_delay and not (stop_at_x > 0.0 and global_position.x >= stop_at_x):
		global_position.x += advance_speed * delta

	_update_danger()


## 플레이어 사망 → 불벽도 시작 위치/타이머로 리셋(무한사망 루프 방지)
func _on_player_died() -> void:
	global_position.x = _initial_x
	_elapsed = 0.0
	if _danger_mat:
		_danger_mat.set_shader_parameter("intensity", 0.0)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		body.call_deferred("die")


# ── 위급 붉은 비네트 ──────────────────────────────────────────────────────
func _setup_danger_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 60                       # 월드 위, HUD 아래쯤
	add_child(layer)
	_danger_rect = ColorRect.new()
	_danger_rect.anchor_right = 1.0
	_danger_rect.anchor_bottom = 1.0
	_danger_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = DANGER_SHADER_CODE
	_danger_mat = ShaderMaterial.new()
	_danger_mat.shader = sh
	_danger_mat.set_shader_parameter("intensity", 0.0)
	_danger_rect.material = _danger_mat
	layer.add_child(_danger_rect)

	# ── 추격 게이지(하단 중앙 바): 트랙 + 플레이어 진행 채움 + 불 위치 마커 ──
	if goal_x > track_start_x:
		_gauge_track = ColorRect.new()
		_gauge_track.color = Color(0, 0, 0, 0.45)
		_gauge_track.anchor_left = 0.2
		_gauge_track.anchor_right = 0.8
		_gauge_track.anchor_top = 1.0
		_gauge_track.anchor_bottom = 1.0
		_gauge_track.offset_top = -40.0
		_gauge_track.offset_bottom = -24.0
		_gauge_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(_gauge_track)
		# 플레이어 진행 채움(왼→현재)
		_gauge_fill = ColorRect.new()
		_gauge_fill.color = Color(0.3, 0.85, 0.5, 0.85)
		_gauge_fill.anchor_bottom = 1.0
		_gauge_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_gauge_track.add_child(_gauge_fill)
		# 불 위치 마커(빨강 세로선)
		_gauge_fire = ColorRect.new()
		_gauge_fire.color = Color(0.95, 0.15, 0.0, 0.95)
		_gauge_fire.anchor_bottom = 1.0
		_gauge_fire.custom_minimum_size = Vector2(5, 0)
		_gauge_fire.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_gauge_track.add_child(_gauge_fire)


func _update_danger() -> void:
	if _danger_mat == null:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	var target := 0.0
	if _player:
		# 불 front(원점) ~ 플레이어 사이 거리. 가까울수록 1 에 수렴.
		var dist: float = _player.global_position.x - global_position.x
		if dist > 0.0 and dist < danger_range:
			target = 1.0 - dist / danger_range
	# 가까울수록 더 빠르게 맥동(쫓기는 느낌)
	var pulse := 0.78 + 0.22 * sin(Time.get_ticks_msec() / 1000.0 * (4.0 + 6.0 * target) * TAU)
	var cur: float = _danger_mat.get_shader_parameter("intensity")
	var want := clampf(target * 0.6, 0.0, 0.6) * pulse
	# 부드럽게 수렴
	_danger_mat.set_shader_parameter("intensity", lerpf(cur, want, 0.15))

	_update_gauge()


## 하단 추격 게이지 갱신(플레이어 진행도 + 불 위치).
func _update_gauge() -> void:
	if _gauge_track == null:
		return
	var span: float = goal_x - track_start_x
	if span <= 0.0:
		return
	var w: float = _gauge_track.size.x
	var pf := 0.0
	if _player:
		pf = clampf((_player.global_position.x - track_start_x) / span, 0.0, 1.0)
	var ff := clampf((global_position.x - track_start_x) / span, 0.0, 1.0)
	if _gauge_fill:
		_gauge_fill.offset_left = 0.0
		_gauge_fill.offset_right = w * pf   # 왼쪽부터 pf 비율만큼 채움
	if _gauge_fire:
		_gauge_fire.offset_left = w * ff
		_gauge_fire.offset_right = w * ff + 5.0
