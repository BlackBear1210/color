"""로비 확인용 짧은 타격·유리 울림을 합성한다. 외부 음원·라이브러리 없이 재생성 가능."""
from pathlib import Path
import math
import random
import struct
import wave

ROOT = Path(__file__).resolve().parents[1]
RATE = 48000
DURATION = 0.48


def generate() -> Path:
    # 고정 시드·고정 파형으로 매번 원본부터 만들므로 실행 횟수에 따라 소리가 변하지 않는다.
    rng = random.Random(1010)
    values = []
    low_noise = 0.0
    for index in range(round(RATE * DURATION)):
        t = index / RATE
        low_noise += 0.19 * (rng.uniform(-1, 1) - low_noise)
        # 낮고 둥근 접촉음 위에 작은 유리 공명을 얹어 어두운 로비에서도 확인이 또렷하게 들린다.
        tap = 0.58 * math.sin(math.tau * (170 * t + 1.9 * (1 - math.exp(-t / 0.014)))) * math.exp(-t / 0.028)
        tap += 0.24 * low_noise * math.exp(-t / 0.012)
        ring = 0.0
        for frequency, weight, decay in [(660, 0.19, 0.09), (990, 0.09, 0.065), (1584, 0.022, 0.045)]:
            ring += weight * math.sin(math.tau * frequency * t) * math.exp(-t / decay)
        # 앞뒤 페이드로 클릭 잡음을 줄이고 긴 잔향이 다음 버튼 입력을 가리지 않게 한다.
        attack = min(1.0, t / 0.0025)
        release = min(1.0, (DURATION - t) / 0.06)
        values.append((tap + ring) * attack * release)
    scale = 0.62 / max(abs(value) for value in values)
    data = b"".join(struct.pack("<h", round(value * scale * 32767)) for value in values)
    output = ROOT / "assets/audio/sfx/로비_확인.wav"
    output.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(output), "wb") as stream:
        stream.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        stream.writeframes(data)
    print(f"로비 확인음: {DURATION:.2f}초 · {RATE}Hz · 모노 PCM")
    return output


if __name__ == "__main__":
    generate()
