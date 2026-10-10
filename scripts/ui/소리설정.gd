extends RefCounted
## [2026-10-10 Codex] 같은 소리 행을 재사용해 로비와 일시정지에서 범위·저장 방식이 달라지지 않게 한다.
const 설정 := preload("res://scripts/스마트월드/게임설정.gd")

static func 만들기(부모: VBoxContainer, 글꼴: Font = null) -> void:
	설정.소리_준비()
	var 값 := 설정.소리_불러오기()
	for 키 in 설정.소리_항목:
		var 묶음 := VBoxContainer.new()
		묶음.name = "소리_" + 키
		묶음.add_theme_constant_override("separation", 2)
		부모.add_child(묶음)
		var 글 := Label.new()
		글.text = "%s  %d%%" % [설정.소리_항목[키], roundi(float(값[키]) * 100)]
		글.add_theme_font_size_override("font_size", 22)
		if 글꼴:
			글.add_theme_font_override("font", 글꼴)
		묶음.add_child(글)
		var 슬라이더 := HSlider.new()
		슬라이더.name = "볼륨"
		슬라이더.min_value = 0.0
		슬라이더.max_value = 1.0
		슬라이더.step = 0.01
		슬라이더.value = 값[키]
		슬라이더.custom_minimum_size.y = 36
		슬라이더.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		묶음.add_child(슬라이더)
		슬라이더.value_changed.connect(_바뀜.bind(키, 글))

static func _바뀜(값: float, 키: String, 글: Label) -> void:
	글.text = "%s  %d%%" % [설정.소리_항목[키], roundi(값 * 100)]
	if 설정.소리_저장(키, 값) != OK:
		글.text += " · 저장 실패"
