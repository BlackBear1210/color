extends Node
## ============================================================================
## [2026-10-09 Claude 신규] 스테이지 스냅 — 스테이지 한 장면을 '사진'으로 찍어 두었다가 클리어하면 보드 조각에 넣는다
## ----------------------------------------------------------------------------
## ▣ 도형님: "검정색 사진 대신 플레이어가 플레이하는 인게임 속 해당 스테이지의 한 부분을 랜덤하게 찍어서 넣는 거야."
## ★[2026-10-15 프레임 방어 · 도형님 선택 "출구 암전 중에 찍기"] 사진 = **출구에 도착한 장면**으로 바꿨다.
##   예전에는 들어온 뒤 무작위 시각(6~40 초)에 화면을 그래픽 칩에서 읽어 왔는데, 읽는 데만 약 17 ms(이 PC · OpenGL)라
##   그 프레임이 24 ms → 60 FPS 아래로 떨어졌다(같은 자리에 작은 화면을 따로 그려 읽어도 12~16 ms — 읽기 자체가 멈춘다).
##   → 클리어하는 순간 **세계만** 작은 보조 화면(480×270 · HUD·화면 효과 없음)에 한 번 그려 두고,
##     실제 읽기는 다음 스테이지로 넘어가며 **화면이 까만 동안**(화면준비.암전_중) 한다 → 멈춤이 안 보인다.
## ▣ 하는 일
##   1) 들어오면 `게임진행.방문_기록` — 숨은 스테이지는 이걸로 '입구를 찾았다' 가 된다(보드에 점선 실이 나타난다).
##   2) 스테이지가 클리어되면(월드 `클리어됨` 신호) 그 순간 화면의 가운데(70%×74% — 예전과 같은 구도)를 보조 화면에 그린다.
##   3) 화면이 까매지면 `미뤄둔_사진_저장()` 이 읽어 user://스냅/<스테이지>.png 로 저장한다(클리어한 판의 사진만 보드에 들어간다).
## ▣ 헤드리스(시험)·저장 금지 실행에서는 찍지 않는다.
## ============================================================================

const 폴더 := "user://스냅/"
const 크기 := Vector2i(480, 270)
## 화면 가운데 몇 % 를 찍나 — 예전과 같은 구도(왼위 물감 HUD · 위 가운데 시계가 있던 가장자리를 뺀 자리)
const 자르기_시작 := Vector2(0.15, 0.18)
const 자르기_크기 := Vector2(0.70, 0.74)

var _씬이름 := ""

## 클리어 순간 그려 두고 아직 안 읽은 사진들 — [{"화면": SubViewport, "이름": String, "그린프레임": int}]
## 보조 화면은 트리 루트에 붙어 있어 스테이지가 바뀌어도 남는다(읽고 나면 지운다).
static var _미뤄둔: Array = []


func _ready() -> void:
	var 씬 := get_parent()
	_씬이름 = 씬.scene_file_path.get_file().get_basename()
	게임진행.방문_기록(씬.scene_file_path)
	if 씬.has_signal("클리어됨"):
		씬.connect("클리어됨", _출구에서_그려두기)


## 클리어 순간 — 지금 카메라가 보는 세계를 작은 보조 화면에 한 번 그려 둔다(읽기는 나중 · 그리기는 1~2 ms).
func _출구에서_그려두기() -> void:
	# 저장을 금지한 검증 실행·헤드리스(화면 없음)에서는 찍지 않는다
	if not 게임진행.기록해도_되나() or DisplayServer.get_name() == "headless":
		return
	var 뿌리 := get_tree().root
	var 화면크기 := Vector2(뿌리.size)
	var 자름 := Rect2(화면크기 * 자르기_시작, 화면크기 * 자르기_크기)
	var 배율 := Vector2(크기) / 자름.size
	var 보조 := SubViewport.new()
	보조.size = 크기
	보조.world_2d = 뿌리.world_2d                    # 같은 세계를 그린다(HUD·전환 판 같은 CanvasLayer 는 안 들어간다)
	보조.render_target_update_mode = SubViewport.UPDATE_ONCE
	보조.name = "스냅_보조화면"
	뿌리.add_child(보조)
	# ⚠ 트리에 넣은 뒤에 변환을 준다 — 먼저 주면 엔진이 "canvas_map" 오류를 낸다(10-15 실험)
	보조.canvas_transform = Transform2D(0.0, 배율, 0.0, -자름.position * 배율) * 뿌리.get_canvas_transform()
	_미뤄둔.append({"화면": 보조, "이름": _씬이름, "그린프레임": Engine.get_frames_drawn()})


## 화면이 까만 동안 부른다(화면준비.암전_중). 미뤄 둔 사진을 읽어 저장하고 보조 화면을 지운다.
static func 미뤄둔_사진_저장(_트리: SceneTree) -> void:
	while not _미뤄둔.is_empty():
		var 일: Dictionary = _미뤄둔.pop_front()
		var 보조 := 일["화면"] as SubViewport
		if not is_instance_valid(보조):
			continue
		# 아직 한 번도 안 그려졌으면(클리어와 같은 프레임에 넘어온 경우) 한 번 그려질 때까지 기다린다
		if Engine.get_frames_drawn() <= int(일["그린프레임"]) + 1:
			await RenderingServer.frame_post_draw
		var 그림 := 보조.get_texture().get_image() if 보조.get_texture() else null
		보조.queue_free()
		if 그림 == null or 그림.is_empty():
			continue
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(폴더))
		그림.save_png(폴더 + String(일["이름"]) + ".png")
