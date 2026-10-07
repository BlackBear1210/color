"""[2026-09-30 Claude] 팀원 전달 분위기 가이드의 그림을 만든다(멱등 — 매번 원본에서 다시 만든다).

원본:
  - 게임 캡처: tools/촬영_가이드장면.gd 가 user://가이드장면/ 에 저장한 것
      A_2-9_호퍼구간.png · A_2-9_호퍼구간_앞지형끔.png · B_2-9_넓게.png
  - 이미 있는 비교 자료: docs/visual_review/...
결과: docs/팀원전달_분위기가이드_이미지/*.png
명도 숫자는 캡처에서 **직접 잰 평균**(0~255 회색값)을 그림에 적는다 — 손으로 적지 않는다.

  python tools/만들기_분위기가이드_이미지.py
"""
import os
import shutil
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

뿌리 = Path(__file__).resolve().parent.parent
출력 = 뿌리 / "docs" / "팀원전달_분위기가이드_이미지"
캡처 = Path(os.environ["APPDATA"]) / "Godot" / "app_userdata" / "dev_4" / "가이드장면"
검토 = 뿌리 / "docs" / "visual_review"
글꼴 = "C:/Windows/Fonts/malgunbd.ttf"
빨강 = (235, 60, 60)
노랑 = (255, 214, 64)


def 폰트(크기: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(글꼴, 크기)


def 명도(im: Image.Image, 상자) -> int:
    h = im.convert("L").crop(상자).histogram()
    n = sum(h)
    return round(sum(i * v for i, v in enumerate(h)) / n)


def 이름표(d: ImageDraw.ImageDraw, xy, 글, 크기=24, 색=노랑):
    f = 폰트(크기)
    x, y = xy
    l, t, r, b = d.textbbox((x, y), 글, font=f)
    d.rectangle((l - 6, t - 4, r + 6, b + 4), fill=(0, 0, 0))
    d.text((x, y), 글, font=f, fill=색)


def 제목띠(im: Image.Image, 글: str, 크기=30) -> Image.Image:
    띠 = 크기 + 24
    o = Image.new("RGB", (im.width, im.height + 띠), (12, 12, 12))
    o.paste(im.convert("RGB"), (0, 띠))
    ImageDraw.Draw(o).text((16, 10), 글, font=폰트(크기), fill=(240, 240, 240))
    return o


def 세로로(이미지들, 간격=8, 색=(60, 60, 60)) -> Image.Image:
    w = max(i.width for i in 이미지들)
    o = Image.new("RGB", (w, sum(i.height for i in 이미지들) + 간격 * (len(이미지들) - 1)), 색)
    y = 0
    for i in 이미지들:
        o.paste(i, (0, y))
        y += i.height + 간격
    return o


def 가로로(이미지들, 간격=8, 색=(60, 60, 60)) -> Image.Image:
    h = max(i.height for i in 이미지들)
    o = Image.new("RGB", (sum(i.width for i in 이미지들) + 간격 * (len(이미지들) - 1), h), 색)
    x = 0
    for i in 이미지들:
        o.paste(i, (x, 0))
        x += i.width + 간격
    return o


def main():
    출력.mkdir(parents=True, exist_ok=True)
    A = Image.open(캡처 / "A_2-9_호퍼구간.png").convert("RGB")
    A끔 = Image.open(캡처 / "A_2-9_호퍼구간_앞지형끔.png").convert("RGB")
    B = Image.open(캡처 / "B_2-9_넓게.png").convert("RGB")

    # 01 목표 시안(ver.2 아래 칸만)
    시안 = Image.open(검토 / "ver2_stage29_baseline" / "approved_ver2_reference.png").convert("RGB")
    아래 = 시안.crop((0, 시안.height // 2 + 2, 시안.width, 시안.height))
    제목띠(아래, "01 · 목표 시안(ver.2) — 이 화면의 분위기가 기준").save(출력 / "01_목표시안_ver2.png")

    # 02 지금 게임 화면
    제목띠(B, "02 · 지금 게임 화면(stage_2-9 · HUD 없음 · 비네트/입자 켜짐)").save(출력 / "02_게임화면_2-9.png")

    # 03 명도 계층 — 실측 숫자를 그림에 적는다
    그림 = A.copy()
    d = ImageDraw.Draw(그림)
    구역 = [
        ("배경 벽(빛 밖)", (1300, 560, 1450, 640), (1300, 650)),
        ("등 옆 40px", (1020, 300, 1050, 340), (1060, 250)),
        ("등 옆 80px", (1060, 300, 1090, 340), (1060, 350)),
        ("앞 지형 몸통", (150, 421, 550, 490), (150, 500)),
        ("앞 지형 윗면 한 줄", (150, 394, 550, 403), (150, 350)),
        ("검정 물", (710, 100, 750, 300), (560, 60)),
        ("흰 물", (840, 100, 880, 300), (900, 60)),
        ("호퍼 주철", (700, 440, 880, 520), (560, 560)),
    ]
    for 이름, 상자, 글자리 in 구역:
        d.rectangle(상자, outline=빨강, width=3)
        이름표(d, 글자리, f"{이름} {명도(A, 상자)}")
    제목띠(그림, "03 · 명도 계층(0~255 실측 평균) — 앞 지형 몸통 < 배경 벽 < 윗면 한 줄 · 빛은 작고 진하게").save(출력 / "03_명도계층_실측.png")

    # 04 앞 지형 깊이 끔/켬(같은 자리)
    위 = A끔.crop((0, 300, 760, 560))
    아래 = A.crop((0, 300, 760, 560))
    d1 = ImageDraw.Draw(위)
    이름표(d1, (12, 10), f"끔 — 몸통 {명도(A끔, (150, 421, 550, 490))} · 무늬가 자글자글, 벽과 섞인다", 22)
    d2 = ImageDraw.Draw(아래)
    이름표(d2, (12, 10), f"켬 — 몸통 {명도(A, (150, 421, 550, 490))} · 어두운 덩어리 + 윗면 한 줄로 윤곽", 22)
    제목띠(세로로([위, 아래]), "04 · 앞 지형 명도(시안_명도조율 + 앞지형_깊이) 끔 → 켬", 26).save(출력 / "04_앞지형_깊이_끔켬.png")

    # 05 빛: 넓은 채움광(전) → 작고 진한 빛 웅덩이(후) — 기존 비교(위 두 칸)
    벽등 = Image.open(검토 / "lamp_depth_20260929" / "cmp_final.png").convert("RGB")
    윗줄 = 벽등.crop((0, 0, 벽등.width, 벽등.height // 2))
    제목띠(윗줄, "05 · 빛 — 전: 넓게 번진 채움광(평면적 · 거절) / 후: 작고 진한 빛 웅덩이 + 어두운 벽(통과)", 26).save(출력 / "05_빛_채움광_vs_빛웅덩이.png")

    # 06 흑백 맞물림·내부 무늬 + 주철 장치(2-3)
    s23 = Image.open(검토 / "stage8_all" / "2-3_3560.png").convert("RGB")
    제목띠(s23.crop((600, 460, 1840, 1000)), "06 · 검정 지형 안의 흰 벽돌(불규칙 맞물림) · 같은 주철 장치 · 흑백 물줄기  (9/29 캡처 · 벽이 지금보다 밝을 때)", 26).save(출력 / "06_흑백맞물림_주철장치.png")

    # 07 화면효과 끔/켬
    끔 = Image.open(검토 / "ver2_stage6" / "effects_off.png").convert("RGB")
    켬 = Image.open(검토 / "ver2_stage6" / "effects_on.png").convert("RGB")
    폭 = min(끔.width, 켬.width)
    끔 = 끔.resize((폭 // 2, 끔.height * (폭 // 2) // 끔.width))
    켬 = 켬.resize((폭 // 2, 켬.height * (폭 // 2) // 켬.width))
    이름표(ImageDraw.Draw(끔), (10, 10), "화면효과 끔", 22)
    이름표(ImageDraw.Draw(켬), (10, 10), "켬 — 비네트 0.075 · 입자 0.012 · 전경 먼지", 22)
    제목띠(가로로([끔, 켬]), "07 · 화면효과는 '있는 듯 없는 듯' — 블룸·블러 없음  (9/29 캡처)", 26).save(출력 / "07_화면효과_끔켬.png")

    # 08 거절 → 통과 사례: 호퍼 입구 물
    호퍼 = 검토 / "hopper_inlet_20260930"
    v2 = Image.open(호퍼 / "비교_2.5배확대.png").convert("RGB")
    v2 = v2.crop((v2.width // 2 + 5, v2.height * 2 // 3 + 5, v2.width, v2.height)).crop((0, 170, 995, 330))
    v3 = Image.open(호퍼 / "v3_둘다_입구확대.png").convert("RGB")
    v4 = Image.open(호퍼 / "v4_둘다_입구확대.png").convert("RGB")
    줄들 = []
    for im, 글 in [(v2, "거절 — 직사각형 물을 윗면에 '잘라 붙인' 느낌 · 윤곽선 때문에 물이 얹힌 것 같다"),
                   (v3, "거절 — 물줄기 끝이 뒤를 비춰 회색 사각형 · 전체 폭 밝은 줄"),
                   (v4, "통과 — 입구 사다리꼴 안에만 담긴 물 · 물줄기가 입구 가운데 깊이에서 수면 속으로")]:
        im = im.resize((1400, im.height * 1400 // im.width))
        이름표(ImageDraw.Draw(im), (10, 8), 글, 22, 노랑 if 글.startswith("통과") else 빨강)
        줄들.append(im)
    제목띠(세로로(줄들), "08 · 거절 → 통과 사례(호퍼 입구 물) — '공간 안에 담겨 있는가' 가 기준", 26).save(출력 / "08_거절과통과_호퍼입구.png")

    print("만든 그림:", sorted(p.name for p in 출력.glob("*.png")))


if __name__ == "__main__":
    main()
