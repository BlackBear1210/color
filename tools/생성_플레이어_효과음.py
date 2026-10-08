# [2026-10-05 Claude] 플레이어 효과음 굽기 — ElevenLabs 원본(.opus) → 무음 자른 .ogg
#
# 왜 필요한가
#   · Godot 4.6 은 Opus 를 못 읽는다(Ogg Vorbis · MP3 · WAV 만). → Vorbis 로 다시 굽는다.
#   · ElevenLabs 원본은 앞에 0.5~1.3 초 무음이 붙어 있다. 그대로 쓰면 키를 누르고 한참 뒤에 소리가 난다.
#   · 걷기 원본엔 발소리가 두 번 들어 있다 → 걷기_1 · 걷기_2 로 나눠 번갈아 울린다.
#   · 걷기 원본은 최대 음량이 0.06 이라 거의 안 들린다 → 목표 최대음량으로 맞춘다.
# 멱등 — 항상 원본에서 다시 계산한다(돌릴 때마다 더 잘리지 않는다).
# 쓰는 법: pip install soundfile  →  python tools/생성_플레이어_효과음.py
#   원본 위치(D)는 도형님 다운로드 폴더. 원본을 다른 데 두면 D 만 고칠 것.
import soundfile as sf, numpy as np, os
D = r"C:\Users\아버지\Downloads"
O = r"C:\Users\아버지\Desktop\게임프로젝트_2\color-dev_4\assets\audio\sfx"
# (원본, 이름, 구간 시작~끝 초(대략 범위), 목표 최대음량)
표 = [
 ("single soft footstep on stone floor, light boot, c.opus", "걷기_1", 0.0, 0.66, 0.6),
 ("single soft footstep on stone floor, light boot, c.opus", "걷기_2", 1.5, 2.25, 0.6),
 ("quick light jump takeoff, soft cloth whoosh and a.opus", "점프", 0, 9, 0.8),
 ("soft landing on stone floor, light thud with a tin.opus", "착지", 0, 9, 0.8),
 ("heavy landing on stone floor, deeper thud with clo.opus", "착지_높은곳", 0, 9, 0.9),
 ("a body bursts into thick black ink, wet splatter,.opus", "죽음_잉크터짐", 0, 9, 0.9),
]
for src, name, a, b, 목표 in 표:
    d, sr = sf.read(os.path.join(D, src))
    d = d[int(a*sr):int(b*sr)]
    m = np.abs(d).max(axis=1)
    pk = m.max()
    i = np.where(m > pk*0.02)[0]
    s = max(0, i[0] - int(0.005*sr))            # 앞: 소리 시작 5ms 전
    e = min(len(d), i[-1] + int(0.08*sr))        # 뒤: 꼬리 80ms 여유
    x = d[s:e] * (목표/pk)
    f_in, f_out = int(0.003*sr), int(0.04*sr)    # 딸깍 소리 방지 페이드
    x[:f_in] *= np.linspace(0,1,f_in)[:,None]
    x[-f_out:] *= np.linspace(1,0,f_out)[:,None]
    sf.write(os.path.join(O, name+".ogg"), x, sr, format="OGG", subtype="VORBIS")
    print(f"{name}.ogg  {len(x)/sr*1000:.0f}ms")
old = os.path.join(O, "걷기.ogg")
if os.path.exists(old): os.remove(old)
