"""선택한 #1 발걸음을 원본에서 다시 읽어 짧고 부드러운 게임용 음원으로 변환한다."""
from pathlib import Path
import argparse
import numpy as np
import soundfile as sf


def generate(source: Path, target: Path) -> None:
    audio, rate = sf.read(source, always_2d=True)
    audio = audio.mean(axis=1)
    peak = float(np.max(np.abs(audio)))
    if peak < 1e-7:
        raise ValueError("발걸음 원본이 무음입니다")
    active = np.flatnonzero(np.abs(audio) > peak * 0.02)
    start = max(0, int(active[0]) - int(rate * 0.005))
    end = min(len(audio), int(active[-1]) + int(rate * 0.05) + 1)
    clip = audio[start:end].copy()
    # 큰 타격을 피하려고 이전 발걸음의 최대치 0.6보다 낮은 0.5로 맞춘다.
    clip *= 0.5 / float(np.max(np.abs(clip)))
    fade_in, fade_out = int(rate * 0.003), int(rate * 0.025)
    clip[:fade_in] *= np.linspace(0, 1, fade_in)
    clip[-fade_out:] *= np.linspace(1, 0, fade_out)
    target.parent.mkdir(parents=True, exist_ok=True)
    sf.write(target, clip, rate, format="OGG", subtype="VORBIS")
    print(f"#1 선택: 앞 무음 {start/rate:.3f}초 제거, 길이 {len(clip)/rate:.3f}초")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=Path.home() / "Downloads/One_isolated,_gentle_#1-1791611523481.mp3")
    args = parser.parse_args()
    generate(args.source, Path(__file__).resolve().parents[1] / "assets/audio/sfx/걷기_부드러운.ogg")
