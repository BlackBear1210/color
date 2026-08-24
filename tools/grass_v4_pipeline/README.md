# grass_v4 텍스처 파이프라인

`assets/textures/smartshape/grass_v4/` 의 PNG 를 **여기서 다시 만든다.**
AI 이미지 생성은 이미 끝났고, `src/` 에 들어 있는 것이 그 결과물(원본)이다.
여기 스크립트는 그 원본을 게임용으로 가공만 한다.

> `.gdignore` 가 있어서 Godot 은 이 폴더를 임포트하지 않는다. (게임 리소스가 아니다)

## 필요한 것

```bash
pip install pillow numpy
```

## 다시 굽기

```bash
python tools/grass_v4_pipeline/apply_final.py
```

**멱등이다.** 항상 `src/` 에서 다시 계산하므로 몇 번을 돌려도 결과가 같다.
돌린 뒤에는 Godot 을 한 번 열거나 `--import` 를 돌려 재임포트해야 한다.

## 무엇을 하는가 (apply_final.py)

1. **검정 엣지** — 원본 → 알파 바닥 제거(0.06) → 감마 대비 → 안쪽 알파 페이드(22%)
2. **검정 필** — 원본 → 감마 → 엣지 안쪽 톤에 평균 맞춤 → solid 파생(순환 블러)
3. **검정 코너** — 위 엣지에서 **극좌표로 합성**. 이음매 단면이 수식으로 일치한다
4. **흰색 테마** — 검정의 휘도를 그대로 반전. 알파는 복사
   → 흑백 구조 대응이 수식으로 보장된다 (반전 오차 0.0 실측)

## 값을 바꾸고 싶다면

`apply_final.py` 상단:

| 상수 | 현재 | 의미 |
|---|---|---|
| `GAMMA` | **1.60** | 대비. 크게 하면 더 검게/더 희게. 1.90 은 필 질감이 사라져 탈락했다 |
| `FADE` | 0.22 | 엣지 안쪽 알파 페이드 구간. 필로 녹아드는 길이 |
| `FLOOR` | 0.06 | 리샘플 잔여 알파 제거 임계 |

`texture_scale` 은 여기가 아니라 **`.tres` 에 있다**
(`assets/textures/smartshape/grass_v4/tres/*.tres`, 현재 0.35).

## 검사

```bash
python tools/grass_v4_pipeline/analyze_lum.py    # 휘도 분포
python tools/grass_v4_pipeline/check_tiling.py   # 이음매 · 반복 모티프
python tools/grass_v4_pipeline/contrast_sheet.py # 대비 후보 시트 생성
```

`check_tiling.py` 판정 기준:
- 이음매: 비율 ≤ 2.0 **또는** 절대차 < 1.0/255 이면 PASS
- 반복 모티프: 자기상관 최대 피크 < 0.5 이면 PASS (짧은 lag 는 제외 — 국소 부드러움일 뿐이다)
