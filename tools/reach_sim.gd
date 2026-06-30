extends SceneTree
## ▼ 2026-06-30 임시 — 지형 도달성(플레이) 검증 시뮬. 플레이어와 동일 물리 프록시가
##   오른쪽으로 달리며 갭에서 자동 점프 → 간격/고도차가 실제 점프로 통과되는지 검증.
##   (장애물·색 로직 무시, 지형 기하만. SIM_OK 면 통과 보장.) 확인 후 삭제.
const SPEED := 390.0
const JUMP := -600.0
# user args: [stage_path, portal_x, kill_y, start_x, start_y]  (없으면 stage_3 기본)
var STAGE := "res://scenes/world_1/stage_3/stage_3.tscn"
var PORTAL_X := 4520.0
var KILL_Y := 780.0
var START := Vector2(60, 300)
var body: CharacterBody2D
var f := 0
var maxx := -9999.0

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() >= 5:
		STAGE = a[0]; PORTAL_X = float(a[1]); KILL_Y = float(a[2]); START = Vector2(float(a[3]), float(a[4]))
	var ps: PackedScene = load(STAGE)
	var st := ps.instantiate()
	get_root().add_child(st)
	body = CharacterBody2D.new()
	body.scale = Vector2(0.3, 0.3)
	body.collision_layer = 0
	body.collision_mask = 6   # 검정(2)+흰(4) 지형 모두 밟는다고 가정(색 무시, 기하 검증)
	body.floor_snap_length = 32.0
	body.floor_max_angle = 0.8029
	body.safe_margin = 2.0
	var col := CollisionShape2D.new()
	var cap := CapsuleShape2D.new()
	cap.radius = 32.0; cap.height = 142.0
	col.shape = cap; col.position = Vector2(-12, 108)
	body.add_child(col)
	st.add_child(body)
	body.global_position = START

func _physics_process(d: float) -> bool:
	f += 1
	if not body.is_on_floor():
		body.velocity.y += (1200.0 if body.velocity.y < 0.0 else 2880.0) * d
	body.velocity.x = SPEED
	if body.is_on_floor() and (_gap_ahead() or body.is_on_wall()):
		body.velocity.y = JUMP
	body.move_and_slide()
	maxx = maxf(maxx, body.global_position.x)
	if body.global_position.y > KILL_Y:
		print("SIM_FAIL 낙사 x=%d (여기 간격 점검)" % int(body.global_position.x)); quit(); return true
	if body.global_position.x >= PORTAL_X:
		print("SIM_OK 포탈도달 x=%d frame=%d" % [int(body.global_position.x), f]); quit(); return true
	if f > 1200:
		print("SIM_TIMEOUT 최대도달 x=%d (막힘 지점)" % int(maxx)); quit(); return true
	return false

# 발 앞쪽 아래로 레이 → 바닥 없으면 갭(점프)
func _gap_ahead() -> bool:
	var ss := body.get_world_2d().direct_space_state
	var feet := body.global_position + Vector2(0, 54)
	var from := feet + Vector2(48, -6)
	var to := from + Vector2(0, 130)
	var q := PhysicsRayQueryParameters2D.create(from, to, 6)
	q.collide_with_areas = false
	return ss.intersect_ray(q).is_empty()
