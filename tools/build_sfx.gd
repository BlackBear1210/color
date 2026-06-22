extends SceneTree
## ▼ 2026-06-22 신규: 합성 효과음(SFX) 생성기 (1회 실행용).
##   실행: Godot --headless --path . -s res://tools/build_sfx.gd
##   결과: res://assets/audio/sfx/ 에 jump/shoot/switch/land/death/portal/click .res 저장.
##   ※ 음원 에셋이 없어 코드로 짧은 합성음을 만든다. 나중에 더 좋은 .wav 로 교체 가능
##     (AudioManager 가 같은 파일명으로 로드하므로 파일만 바꾸면 됨).

const OUT := "res://assets/audio/sfx/"
const RATE := 22050

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var ok := 0
	ok += _save("jump",   _make(0.22, func(t, d): return _env(t, 9.0)  * sin(TAU * (430.0 + 360.0 * t / d) * t)))
	ok += _save("land",   _make(0.16, func(t, d): return _env(t, 16.0) * sin(TAU * 130.0 * t) + 0.2 * _env(t, 30.0) * _noise()))
	ok += _save("shoot",  _make(0.12, func(t, d): return _env(t, 26.0) * (signf(sin(TAU * 240.0 * t)) * 0.5 + 0.5 * _noise())))
	ok += _save("switch", _make(0.20, func(t, d): return _env(t, 11.0) * sin(TAU * (520.0 if t < d * 0.5 else 820.0) * t)))
	ok += _save("death",  _make(0.55, func(t, d): return _env(t, 4.5)  * _saw((600.0 - 470.0 * t / d) * t)))
	ok += _save("portal", _make(0.55, func(t, d): return _env(t, 3.5)  * (sin(TAU * 523.0 * t) + sin(TAU * 659.0 * t) + sin(TAU * 784.0 * t)) / 3.0))
	ok += _save("click",  _make(0.06, func(t, d): return _env(t, 40.0) * sin(TAU * 880.0 * t)))
	print("SFX_DONE %d/7" % ok)
	quit(0 if ok == 7 else 1)

# ── 합성 헬퍼 ──────────────────────────────────────────────────────
func _env(t: float, k: float) -> float:        # 지수 감쇠 엔벨로프
	return exp(-t * k)

func _noise() -> float:
	return randf() * 2.0 - 1.0

func _saw(x: float) -> float:                  # 톱니파(-1..1)
	return 2.0 * (x - floor(x + 0.5))

func _make(dur: float, fn: Callable) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var v: float = clampf(fn.call(t, dur), -1.0, 1.0)
		bytes.encode_s16(i * 2, int(v * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w

func _save(nm: String, w: AudioStreamWAV) -> int:
	var err := ResourceSaver.save(w, OUT + nm + ".res")
	if err == OK:
		print("  저장: ", OUT + nm + ".res")
		return 1
	print("  실패(", err, "): ", nm)
	return 0
