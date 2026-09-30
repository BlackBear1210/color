extends RefCounted
## Python 프로토타입과 같은 splitmix64. 부호 있는 int64의 오버플로에
## 의존하지 않도록 16비트 네 자리로 계산한다. 장식 추첨은 지형을 바꾸지 않는다.
const 증가 = [0x7c15, 0x7f4a, 0x79b9, 0x9e37]
const 스트림상수 = [0xed03, 0xd192, 0x4a32, 0xd1b5]
var 상태: Array = []

func _init(씨앗: int, 이름: String):
	var 번호: int = {"지형": 1, "출구": 2, "관문": 3, "장식": 4}[이름]
	상태 = 더하기(곱하기(자리(씨앗), 증가), 곱하기(자리(번호), 스트림상수))
	for i in 4:
		다음()

static func 자리(n: int) -> Array:
	return [n & 65535, (n >> 16) & 65535, (n >> 32) & 65535, (n >> 48) & 65535]

static func 더하기(a: Array, b: Array) -> Array:
	var out = []
	var carry: int = 0
	for i in 4:
		carry += a[i] + b[i]
		out.append(carry & 65535)
		carry >>= 16
	return out

static func 곱하기(a: Array, b: Array) -> Array:
	var out = []
	var carry: int = 0
	for i in 4:
		for j in range(i + 1):
			carry += a[j] * b[i - j]
		out.append(carry & 65535)
		carry >>= 16
	return out

static func 섞기(a: Array, bits: int) -> Array:
	var shifted = [0, 0, 0, 0]
	for bit in range(64 - bits):
		var src: int = bit + bits
		if (a[src / 16] & (1 << (src % 16))) != 0:
			shifted[bit / 16] |= 1 << (bit % 16)
	for i in 4:
		shifted[i] ^= a[i]
	return shifted

func 다음() -> Array:
	상태 = 더하기(상태, 증가)
	var z = 곱하기(섞기(상태, 30), [0xe5b9, 0x1ce4, 0x476d, 0xbf58])
	z = 곱하기(섞기(z, 27), [0x11eb, 0x1331, 0x49bb, 0x94d0])
	return 섞기(z, 31)

func 정수(a: int, b: int) -> int:
	if b <= a:
		return a
	var z = 다음()
	var n: int = z[0] | (z[1] << 16) | (z[2] << 32) | ((z[3] & 32767) << 48)
	return a + (n >> 1) % (b - a + 1)

func 확률(퍼센트: int) -> bool:
	return 정수(0, 99) < 퍼센트

func 하나(목록: Array):
	return 목록[정수(0, 목록.size() - 1)]

## ★포팅 자가검사 — 파이썬 프로토타입(`tools/프로토타입/탐색방_프로토.py`)과 같은 수열인가.
##   그 프로토타입이 씨앗 1~10 을 검증한 근거이므로, **같은 난수라야 그 검증이 여기에도 유효**하다.
##   false 가 나오면 포팅이 깨진 것이고, 그 상태로 만든 맵은 검증과 무관하다.
static func 자가검사() -> bool:
	var 기대_지형 := [49, 1, 38, 38, 33, 45, 2, 26]      # 씨앗 1 · 스트림 "지형"
	var 기대_출구 := [60, 19, 59, 72, 43, 96, 76, 19]    # 씨앗 7 · 스트림 "출구"
	var 스크립트 = load("res://tools/생성기/난수.gd")
	var a = 스크립트.new(1, "지형")
	var b = 스크립트.new(7, "출구")
	for i in 8:
		if a.정수(0, 99) != 기대_지형[i]:
			push_error("난수 자가검사 실패(지형 %d 번째)" % i)
			return false
		if b.정수(0, 99) != 기대_출구[i]:
			push_error("난수 자가검사 실패(출구 %d 번째)" % i)
			return false
	return true
