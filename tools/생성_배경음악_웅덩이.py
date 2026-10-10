"""제공된 MP3를 게임용 Vorbis로 변환한다. 원본에서 재계산해 멱등성을 지킨다."""
import argparse
from pathlib import Path

import numpy as np
import soundfile as sf

MUSIC = {
    "로비": "로비 배경음악.mp3",
    "챕터1_집": "쳅터_1Dim_Corridors_2026-10-10T050826.mp3",
    "챕터2_하수도": "쳅터_2.mp3",
}


def generate(source: Path, root: Path) -> None:
    output = root / "assets/audio/bgm"
    output.mkdir(parents=True, exist_ok=True)
    for name, filename in MUSIC.items():
        # 긴 곡은 float32로 읽어 변환 중 메모리가 불필요하게 두 배로 커지지 않게 한다.
        audio, rate = sf.read(source / filename, always_2d=True, dtype="float32")
        if not np.isfinite(audio).all() or not np.any(audio):
            raise ValueError(f"유효하지 않은 음악: {filename}")
        # 끝 1초와 첫 1초를 겹쳐 시작·끝의 파형 단절을 줄인다. 전체 음악 흐름은 보존한다.
        count = min(rate, len(audio) // 4)
        weight = np.linspace(0, 1, count, dtype=np.float32)[:, None]
        seam = audio[-count:] * (1 - weight) + audio[:count] * weight
        loop = np.concatenate([seam, audio[count:-count]])
        # 곡별 원래 음량을 유지하고 클리핑 우려가 있는 경우에만 낮춘다.
        peak = float(np.max(np.abs(loop)))
        loop *= min(1.0, 0.95 / max(peak, 1e-8))
        target = output / f"{name}.ogg"
        # libsndfile의 긴 Vorbis 일괄 쓰기 대신 작은 블록으로 인코딩해 버퍼를 제한한다.
        with sf.SoundFile(target, mode="w", samplerate=rate, channels=loop.shape[1],
                          format="OGG", subtype="VORBIS") as stream:
            for offset in range(0, len(loop), 16384):
                stream.write(loop[offset:offset + 16384])
        print(f"{name}: {len(loop)/rate:.3f}초")
        del audio, loop, seam

    # 원본에는 여러 찰박 소리가 들어 있어 첫 한 걸음의 타격만 골라 반복 중첩을 피한다.
    audio, rate = sf.read(source / "물웅덩이 밟는 소리.mp3", always_2d=True)
    clip = audio[int(0.26 * rate):int(0.50 * rate)].mean(axis=1)
    peak = float(np.max(np.abs(clip)))
    if peak < 1e-7:
        raise ValueError("웅덩이 구간이 무음입니다")
    active = np.flatnonzero(np.abs(clip) > peak * 0.02)
    clip = clip[max(0, active[0] - int(rate * 0.005)):].copy()
    clip *= 0.8 / float(np.max(np.abs(clip)))
    fade_in, fade_out = int(rate * 0.003), int(rate * 0.025)
    clip[:fade_in] *= np.linspace(0, 1, fade_in)
    clip[-fade_out:] *= np.linspace(1, 0, fade_out)
    target = root / "assets/audio/sfx/웅덩이_찰박.ogg"
    target.parent.mkdir(parents=True, exist_ok=True)
    sf.write(target, clip, rate, format="OGG", subtype="VORBIS")
    print(f"웅덩이_찰박: {len(clip)/rate:.3f}초")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=Path.home() / "Downloads")
    args = parser.parse_args()
    generate(args.source, Path(__file__).resolve().parents[1])
