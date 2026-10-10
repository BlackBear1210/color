"""사용자가 선택한 붓 효과음 원본을 로비용 PCM WAV로 변환한다."""
from pathlib import Path
import argparse

import numpy as np
import soundfile as sf


def convert(source: Path, target: Path) -> None:
    audio, rate = sf.read(source, always_2d=True)
    if not np.isfinite(audio).all() or not np.any(audio):
        raise ValueError("선택 음원에 유효한 소리가 없습니다")
    # 선택한 붓 소리의 길이·음정·스테레오 질감을 보존하고 클리핑 여유만 확보한다.
    audio *= min(1.0, 0.60 / float(np.max(np.abs(audio))))
    # 압축 원본의 경계가 0이 아니므로 시작·끝에 짧은 페이드를 넣어 클릭 잡음을 막는다.
    start = min(len(audio), round(rate * 0.003))
    end = min(len(audio), round(rate * 0.025))
    audio[:start] *= np.linspace(0, 1, start)[:, None]
    audio[-end:] *= np.linspace(1, 0, end)[:, None]
    target.parent.mkdir(parents=True, exist_ok=True)
    sf.write(target, audio, rate, format="WAV", subtype="PCM_16")
    print(f"붓 선택음: {len(audio)/rate:.3f}초 · {rate}Hz · {audio.shape[1]}채널")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=Path.home() / "Downloads/A_single_short_paint_#1-1791612454641.mp3")
    args = parser.parse_args()
    convert(args.source, Path(__file__).resolve().parents[1] / "assets/audio/sfx/로비_붓선택.wav")
