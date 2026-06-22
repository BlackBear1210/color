extends Node
## ▼ 2026-06-22 신규: 오디오 매니저 (Autoload).
##   - 효과음(SFX) 재생 풀 + 배경음(BGM) 1개 + Master/BGM/SFX 버스 음량 관리.
##   - 음량 설정은 user://audio.json 에 저장(설정 화면에서 조절).
##   - SFX 는 res://assets/audio/sfx/<이름>.res (tools/build_sfx.gd 로 생성. 더 좋은 음원으로 교체 가능).
##   ※ BGM 음원 파일이 들어오면 play_bgm("res://assets/audio/bgm/xxx.ogg") 로 재생하면 됨.

const SFX_DIR := "res://assets/audio/sfx/"
const SFX_NAMES := ["jump", "land", "shoot", "switch", "death", "portal", "click"]
const SETTINGS_PATH := "user://audio.json"
const SFX_POOL := 8

var master_vol: float = 1.0   # 0.0 ~ 1.0
var bgm_vol: float    = 0.7
var sfx_vol: float    = 0.9

var _sfx: Dictionary = {}                         # 이름 -> AudioStream
var _pool: Array[AudioStreamPlayer] = []
var _pool_i: int = 0
var _bgm: AudioStreamPlayer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()

	# SFX 로드
	for nm in SFX_NAMES:
		var path: String = SFX_DIR + str(nm) + ".res"
		if ResourceLoader.exists(path):
			_sfx[nm] = load(path)

	# SFX 재생 풀
	for i in SFX_POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)

	# BGM 플레이어
	_bgm = AudioStreamPlayer.new()
	_bgm.bus = "BGM"
	add_child(_bgm)

	_load_settings()
	_apply_volumes()

## Master 외에 BGM/SFX 버스를 보장(없으면 생성).
func _ensure_buses() -> void:
	for nm in ["BGM", "SFX"]:
		if AudioServer.get_bus_index(nm) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, nm)
			AudioServer.set_bus_send(idx, "Master")

# ── 재생 ──────────────────────────────────────────────────────────
func play_sfx(name: String, pitch: float = 1.0) -> void:
	var s = _sfx.get(name)
	if s == null:
		return
	var p := _pool[_pool_i]
	_pool_i = (_pool_i + 1) % _pool.size()
	p.stream = s
	p.pitch_scale = pitch
	p.play()

func play_bgm(path: String, loop: bool = true) -> void:
	if not ResourceLoader.exists(path):
		return
	var s := load(path)
	if s is AudioStream:
		_bgm.stream = s
		_bgm.play()

func stop_bgm() -> void:
	if _bgm:
		_bgm.stop()

# ── 음량 ──────────────────────────────────────────────────────────
func set_master(v: float) -> void:
	master_vol = clampf(v, 0.0, 1.0); _apply_volumes(); _save_settings()
func set_bgm(v: float) -> void:
	bgm_vol = clampf(v, 0.0, 1.0); _apply_volumes(); _save_settings()
func set_sfx(v: float) -> void:
	sfx_vol = clampf(v, 0.0, 1.0); _apply_volumes(); _save_settings()

func _apply_volumes() -> void:
	_set_bus_db("Master", master_vol)
	_set_bus_db("BGM", bgm_vol)
	_set_bus_db("SFX", sfx_vol)

func _set_bus_db(bus: String, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx == -1:
		return
	# 0 이면 음소거, 그 외엔 선형→dB 변환
	AudioServer.set_bus_mute(idx, v <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)))

# ── 저장 / 불러오기 ──────────────────────────────────────────────
func _save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"master": master_vol, "bgm": bgm_vol, "sfx": sfx_vol}))
		f.close()

func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) == TYPE_DICTIONARY:
		master_vol = float(data.get("master", master_vol))
		bgm_vol = float(data.get("bgm", bgm_vol))
		sfx_vol = float(data.get("sfx", sfx_vol))
