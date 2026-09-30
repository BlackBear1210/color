# -*- coding: utf-8 -*-
"""하수도 효과음 합성 (음원 파일이 없어서 직접 만든다 · 씨앗 고정 = 멱등).

왜: 프로젝트에 음원이 하나도 없다(`음향.gd` 머리말 · 사운드 작업이 계속 밀림).
    도형님 지시(2026-09-30): 물에 닿는 소리 · 발소리 · 떨어지는 물소리.
    나중에 진짜 음원이 오면 같은 이름으로 덮어쓰면 코드는 그대로다.

만드는 것 (assets/audio/sewer/, 22050Hz · 16bit · 모노 WAV):
  step_stone_1..4.wav   돌바닥 발소리 — 짧은 저음 툭 + 모래 알갱이 긁힘 (0.12s)
  step_water_1..4.wav   얕은 물 발소리 — 찰박(짧은 물 튐 노이즈 + 방울 몇 개) (0.22s)
  splash_enter.wav      입수 — 풍덩(저음 둥 + 넓은 물 튐 + 방울 꼬리) (0.7s)
  stream_loop.wav       떨어지는 물 — 쏴아(필터 노이즈 + 느린 출렁임) · **이음매 없는 반복** (3.0s)

사용:  python tools/생성_하수도_효과음.py
"""
import os
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio", "sewer")
SR = 22050


def save(name, x):
    x = np.clip(x, -1, 1)
    data = (x * 32767 * 0.9).astype("<i2").tobytes()
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)


def lowpass(x, a):
    """한 극 저역 통과(a 가 작을수록 어둡다)."""
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += a * (v - acc)
        y[i] = acc
    return y


def env(n, attack, decay):
    t = np.arange(n) / SR
    return np.minimum(1.0, t / max(attack, 1e-4)) * np.exp(-t / decay)


def bubble(n, f0, f1, dur, start, r):
    """물방울 '뽁' — 위로 미끄러지는 사인(물속 공기 방울 소리)."""
    y = np.zeros(n)
    k = int(start * SR)
    m = min(n - k, int(dur * SR))
    if m <= 0:
        return y
    t = np.arange(m) / SR
    f = f0 + (f1 - f0) * (t / dur)
    ph = 2 * np.pi * np.cumsum(f) / SR
    y[k:k + m] = np.sin(ph) * np.exp(-t / (dur * 0.35)) * r
    return y


def step_stone(seed):
    r = np.random.default_rng(seed)
    n = int(0.12 * SR)
    t = np.arange(n) / SR
    thud = np.sin(2 * np.pi * r.uniform(85, 120) * t) * env(n, 0.002, 0.025)
    grit = lowpass(r.standard_normal(n), 0.35) * env(n, 0.001, 0.018) * 0.5
    return (thud * 0.8 + grit) * r.uniform(0.75, 1.0)


def step_water(seed):
    r = np.random.default_rng(seed)
    n = int(0.22 * SR)
    slosh = lowpass(r.standard_normal(n), 0.25) * env(n, 0.004, 0.05)
    hiss = (r.standard_normal(n) - lowpass(r.standard_normal(n), 0.5)) * env(n, 0.002, 0.03) * 0.25
    b = sum(bubble(n, r.uniform(700, 1100), r.uniform(1300, 2200), r.uniform(0.03, 0.06), r.uniform(0.02, 0.1), 0.25) for _ in range(2))
    return (slosh + hiss + b) * r.uniform(0.7, 0.95)


def splash():
    r = np.random.default_rng(77)
    n = int(0.7 * SR)
    t = np.arange(n) / SR
    boom = np.sin(2 * np.pi * (70 + 40 * np.exp(-t / 0.05)) * t) * env(n, 0.003, 0.08) * 0.7
    body = lowpass(r.standard_normal(n), 0.3) * env(n, 0.005, 0.12)
    spray = (r.standard_normal(n) - lowpass(r.standard_normal(n), 0.6)) * env(n, 0.01, 0.09) * 0.4
    b = sum(bubble(n, r.uniform(500, 900), r.uniform(1100, 2000), r.uniform(0.04, 0.09), r.uniform(0.05, 0.45), r.uniform(0.15, 0.3)) for _ in range(9))
    return boom + body + spray + b


def stream_loop():
    r = np.random.default_rng(5)
    dur = 3.0
    n = int(dur * SR)
    t = np.arange(n) / SR
    # 넓은 쏴아(분홍 비슷한 노이즈) + 굵은 물줄기 저역 + 느린 출렁임 — 주기 3s 에 맞춰 출렁임이 이어진다
    white = r.standard_normal(n + SR)
    pinkish = lowpass(white, 0.12)[SR:] * 2.2 + lowpass(white, 0.5)[SR:] * 0.35
    rumble = lowpass(r.standard_normal(n + SR), 0.02)[SR:] * 4.0
    wobble = 0.85 + 0.15 * np.sin(2 * np.pi * t / dur) * np.sin(2 * np.pi * 3 * t / dur)
    b = sum(bubble(n, r.uniform(600, 1000), r.uniform(1200, 1800), r.uniform(0.03, 0.06), r.uniform(0, dur - 0.1), 0.12) for _ in range(14))
    x = (pinkish + rumble) * wobble + b
    # 이음매: 끝 0.25s 를 처음과 겹쳐 섞는다(반복할 때 딸깍 없음)
    f = int(0.25 * SR)
    w = np.linspace(0, 1, f)
    x[:f] = x[:f] * w + x[-f:] * (1 - w)
    x = x[:-f]
    return x / np.max(np.abs(x)) * 0.8


def main():
    os.makedirs(OUT, exist_ok=True)
    for i in range(4):
        save("step_stone_%d.wav" % (i + 1), step_stone(10 + i))
        save("step_water_%d.wav" % (i + 1), step_water(20 + i))
    save("splash_enter.wav", splash())
    save("stream_loop.wav", stream_loop())
    print("->", OUT)


if __name__ == "__main__":
    main()
