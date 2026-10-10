"""사용자가 제공한 Opus 5종을 무음 제거 후 게임용 Vorbis로 변환한다.

원본에서 매번 계산하므로 재실행해도 음량과 길이가 누적 변경되지 않는다.
사용법: python tools/생성_페인트_몬스터_효과음.py [--source 원본폴더]
필요 패키지: numpy, soundfile
"""
import argparse
from pathlib import Path

import numpy as np
import soundfile as sf

SOURCES = {
    "플레이어_페인트발사": "A single shot from a small handheld paint gun in a.opus",
    "플레이어_페인트명중": "Tight wet slap of thick paint hitting a wall, with.opus",
    "몬스터_걷기": "One isolated footstep of a small heavy creature wa.opus",
    "몬스터_페인트발사": "A single short burst of thick, sticky paint from a.opus",
    "몬스터_페인트명중": "A single blob of thick, sticky paint hitting a har.opus",
}
# 원본에 여러 걸음·타격이 들어 있으므로 가장 또렷한 한 동작만 사용한다.
# 끝의 여유는 잔향을 보존하며, 무음 제거·음량 계산은 이 구간 안에서 다시 한다.
WINDOWS = {"몬스터_걷기": (0.35, 0.95), "몬스터_페인트명중": (1.30, 1.85)}


def convert(source: Path, output: Path) -> None:
    output.mkdir(parents=True, exist_ok=True)
    for name, filename in SOURCES.items():
        audio, rate = sf.read(source / filename, always_2d=True)
        if name in WINDOWS:
            begin, finish = WINDOWS[name]
            audio = audio[int(begin * rate):int(finish * rate)]
        # 2D 소리는 위치에서 좌우 배분하므로 원본을 모노로 정리한다.
        audio = audio.mean(axis=1)
        peak = float(np.max(np.abs(audio)))
        if peak < 1e-7:
            raise ValueError(f"무음 원본: {filename}")
        active = np.flatnonzero(np.abs(audio) > peak * 0.02)
        start = max(0, int(active[0]) - int(rate * 0.005))
        end = min(len(audio), int(active[-1]) + 1 + int(rate * 0.08))
        clip = audio[start:end].copy()
        # 최대치만 맞추고 실제 게임별 음량은 공통 재생기 호출에서 조절한다.
        clip *= 0.8 / float(np.max(np.abs(clip)))
        fade_in = min(len(clip), max(1, int(rate * 0.003)))
        fade_out = min(len(clip), max(1, int(rate * 0.025)))
        clip[:fade_in] *= np.linspace(0, 1, fade_in)
        clip[-fade_out:] *= np.linspace(1, 0, fade_out)
        target = output / f"{name}.ogg"
        sf.write(target, clip, rate, format="OGG", subtype="VORBIS")
        info = sf.info(target)
        assert info.subtype == "VORBIS" and info.channels == 1
        print(f"{name}: {len(audio)/rate:.3f}s -> {info.duration:.3f}s (앞 무음 {start/rate:.3f}s 제거)")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=Path.home() / "Downloads")
    args = parser.parse_args()
    convert(args.source, Path(__file__).resolve().parents[1] / "assets/audio/sfx")
