extends SceneTree
## ============================================================================
## [2026-09-05 신규] 물 이펙트 원본 시트 → SpriteFrames(.tres) + 기준점(.json) 굽기
## ----------------------------------------------------------------------------
## 실행:
##   godot --headless --path . -s res://tools/생성_물감명중_프레임.gd
##
## ▣ 왜 도구로 굽나 (손으로 안 만드나)
##   인수인계 문서에는 "water_05 = 176×176 × 16프레임" 이라고 적혀 있었지만
##   실제 파일은 **5572×124** 였다. 사람이 옮겨 적은 숫자를 믿으면 프레임이
##   어긋난 채로 굴러간다. → 원본 픽셀에서 **매번 다시 재서** 굽는다.
##   (저장소 규약 5: 도구는 멱등. 기존 .tres 값에 더하지 않고 항상 새로 계산한다)
##
## ▣ 원본 시트에 대해 실측으로 알아낸 것 (2026-09-05)
##   · 가로로 이어붙인 한 줄 시트다. 세로 칸은 없다.
##   · **배경이 투명이 아니라 불투명한 검정**이다(알파가 전 픽셀 1.0).
##     → 프레임 유무도, 런타임 마스킹도 알파가 아니라 **밝기**로 판단해야 한다.
##       (런타임 쪽은 `shaders/물감_명중.gdshader` 가 같은 방식으로 뽑아낸다)
##   · 28 칸 균등 격자이고 뒤쪽 칸은 비어 있다. 칸수는 아래 `_칸수_찾기` 가 스스로 찾는다.
##
## ▣ 같이 굽는 기준점 JSON 이 왜 필요한가
##   물줄기가 "어디서 시작하는지"와 "그림의 바깥쪽이 어느 쪽인지"는 시트마다 다르다.
##   · water_05 : 바닥을 따라 오른쪽으로 퍼지는 가로 물결
##   · water_06 : 위로 솟는 물기둥
##   · water_07 : 위로 터지는 왕관
##   · water_08 : 사방으로 터지는 별
##   → **첫 프레임의 무게중심 = 명중 지점**을 재서 적어 둔다. 런타임은 이 점을
##     지형에 맞은 자리에 정확히 얹는다.
##
##   ⚠ "바깥방향"은 재려다 실패해서 **손으로 적은 값**이다(아래 `바깥방향표`).
##     처음엔 "첫 프레임 → 끝 프레임 무게중심 이동"으로 자동으로 뽑으려 했는데,
##     끝 프레임은 물방울이 **중력으로 떨어진 뒤**라 네 시트 모두 아래쪽(+y)이 나왔다.
##     즉 잰 것은 "그림이 자라는 방향"이 아니라 "물방울이 떨어진 방향"이었다.
##     원화 넷 다 **바닥에 맞은 그림**이라 그림 기준 바깥쪽은 전부 위(-y)다.
##     새 시트를 넣는데 방향이 다르면 아래 표에 한 줄만 더한다.
## ============================================================================

const 시트_폴더 := "res://assets/vfx/water_impact/"
const 시트들 := ["water_05", "water_06", "water_07", "water_08"]
const 프레임_저장 := 시트_폴더 + "물감_명중_프레임.tres"
const 기준_저장 := 시트_폴더 + "물감_명중_기준점.json"

## 밝기가 이 값을 넘으면 "물이 그려진 픽셀". 검정 배경(0.0)과 확실히 갈린다.
const 밝기_기준 := 0.06
## 재생 속도(FPS). 원본이 2프레임씩 거의 같은 그림이라 30 이면 체감 15프레임쯤이다.
const 초당_프레임 := 30.0
## 격자 후보 상한. 이보다 잘게 쪼개진 시트는 없다.
const 칸수_상한 := 40

## 원화가 "바깥"으로 삼은 로컬 방향. 네 시트 다 바닥에 맞은 그림이라 위(-y)다.
## 런타임은 이 방향이 실제 지형 법선을 향하도록 그림을 돌린다.
const 바깥방향표 := {
	"water_05": Vector2.UP,
	"water_06": Vector2.UP,
	"water_07": Vector2.UP,
	"water_08": Vector2.UP,
}


func _init() -> void: call_deferred("_go")


func _go() -> void:
	var 프레임집 := SpriteFrames.new()
	# SpriteFrames 는 만들면 "default" 애니메이션이 하나 들어 있다. 안 지우면 찌꺼기로 남는다.
	프레임집.remove_animation("default")
	var 기준표 := {}

	for 이름 in 시트들:
		var 경로: String = 시트_폴더 + String(이름) + ".png"
		var 원본 := load(경로) as Texture2D
		if 원본 == null:
			push_error("시트를 못 읽었다: %s" % 경로); quit(1); return
		var img := Image.load_from_file(ProjectSettings.globalize_path(경로))
		var w := img.get_width()
		var h := img.get_height()

		var 칸수 := _칸수_찾기(img)
		if 칸수 <= 0:
			push_error("%s : 균등 격자를 못 찾았다" % 이름); quit(1); return
		var 칸폭 := w / 칸수

		# 칸마다 내용이 있는지 + 무게중심
		var 중심들 := {}
		for i in 칸수:
			var c = _칸_무게중심(img, i * 칸폭, 칸폭, h)
			if c != null:
				중심들[i] = c
		var 칸번호: Array = 중심들.keys()
		칸번호.sort()
		if 칸번호.is_empty():
			push_error("%s : 내용이 있는 칸이 없다" % 이름); quit(1); return
		var 첫: int = 칸번호[0]
		var 끝: int = 칸번호[칸번호.size() - 1]

		# ── SpriteFrames 애니메이션 한 줄 ──
		프레임집.add_animation(이름)
		프레임집.set_animation_speed(이름, 초당_프레임)
		프레임집.set_animation_loop(이름, false)   # 명중 연출은 한 번만 튄다
		for i in range(첫, 끝 + 1):
			var 조각 := AtlasTexture.new()
			조각.atlas = 원본
			조각.region = Rect2(i * 칸폭, 0, 칸폭, h)
			# filter_clip 을 켜야 옆 칸 픽셀이 가장자리로 새어 나오지 않는다.
			조각.filter_clip = true
			프레임집.add_frame(이름, 조각)

		var 시작중심: Vector2 = 중심들[첫]
		var 바깥: Vector2 = 바깥방향표.get(이름, Vector2.UP)

		기준표[이름] = {
			"칸폭": 칸폭, "높이": h,
			"프레임수": 끝 - 첫 + 1,
			"첫칸": 첫, "끝칸": 끝,
			"기준점": [시작중심.x, 시작중심.y],      # 칸 안 좌표 = 명중 지점이 놓일 자리
			"바깥방향": [바깥.x, 바깥.y],            # 그림 기준 "표면 바깥" 로컬 방향
		}
		print("  %s  %dx%d  격자 %d칸×%dpx  프레임 %d~%d (%d장)  기준점=(%.1f, %.1f)  바깥=%s" % [
			이름, w, h, 칸수, 칸폭, 첫, 끝, 끝 - 첫 + 1,
			시작중심.x, 시작중심.y, 바깥])

	var 결과 := ResourceSaver.save(프레임집, 프레임_저장)
	if 결과 != OK:
		push_error("SpriteFrames 저장 실패: %d" % 결과); quit(1); return
	var f := FileAccess.open(기준_저장, FileAccess.WRITE)
	f.store_string(JSON.stringify(기준표, "\t"))
	f.close()
	print("저장 완료 → %s / %s" % [프레임_저장, 기준_저장])
	quit()


## 시트를 몇 칸으로 나눠야 "덩어리 하나가 칸 하나 안에" 들어가는지 찾는다.
## 나누어떨어지는 칸수 중 **가장 잘게 쪼개지는 것**이 정답이다
## (더 잘게 쪼개면 덩어리가 칸 경계를 넘어가므로 자동으로 걸러진다).
func _칸수_찾기(img: Image) -> int:
	var w := img.get_width()
	var h := img.get_height()
	var 참: Array[bool] = []
	참.resize(w)
	for x in w:
		var 있음 := false
		for y in h:
			var c := img.get_pixel(x, y)
			if maxf(c.r, maxf(c.g, c.b)) > 밝기_기준:
				있음 = true; break
		참[x] = 있음
	var 덩어리: Array = []
	var 시작 := -1
	for x in w:
		if 참[x] and 시작 < 0: 시작 = x
		elif not 참[x] and 시작 >= 0:
			덩어리.append([시작, x - 1]); 시작 = -1
	if 시작 >= 0: 덩어리.append([시작, w - 1])

	var 최고 := -1
	for 칸수 in range(2, 칸수_상한 + 1):
		if w % 칸수 != 0: continue
		var 칸폭 := w / 칸수
		var 맞음 := true
		for d in 덩어리:
			if int(d[0]) / 칸폭 != int(d[1]) / 칸폭:
				맞음 = false; break
		if 맞음: 최고 = 칸수
	return 최고


## 한 칸 안에서 밝은 픽셀의 무게중심. 내용이 없으면 null.
func _칸_무게중심(img: Image, x0: int, 칸폭: int, h: int):
	var 개수 := 0
	var 합 := Vector2.ZERO
	for x in range(x0, x0 + 칸폭):
		for y in h:
			var c := img.get_pixel(x, y)
			var l := maxf(c.r, maxf(c.g, c.b))
			if l > 밝기_기준:
				개수 += 1
				합 += Vector2(x - x0, y)
	if 개수 == 0:
		return null
	return 합 / float(개수)
