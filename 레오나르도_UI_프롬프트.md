# Leonardo AI — UI 에셋 프롬프트 시트 (color 프로젝트)
> 작성: 2026-06-30 Claude. **Claude 가 Leonardo 에 직접 접속/생성은 불가**(브라우저 확장·계정 미연결)이라,
> 아래 프롬프트를 Leonardo(또는 다른 이미지 AI)에 붙여넣어 직접 뽑으세요. 톤만 맞추면 코드에 바로 연결됩니다.

## 0. 공통 스타일 키워드 (모든 프롬프트에 공유)
> ▼ 2026-06-30 변경: 보라/마젠타 강조가 게임과 안 어울려 **어두운 회색 톤**으로 통일.
게임 정체성 = **흑/백 모노톤 + 어두운 회색(차콜) + 페인트(물감) 느낌의 2D 플랫포머, 다크 무드**.
```
clean minimalist 2D game UI, dark moody theme, charcoal gray (#1A1A1F) panels with
light steel-gray (#9EA2AC) thin border, soft paint splatter motifs in grayscale, subtle grain,
flat vector with gentle gradients, high contrast on dark, crisp edges, game asset,
transparent background, no text, no watermark
```
- **색 규칙**: 강조/테두리 = 밝은 회색(#9EA2AC), 채움 = 차콜(#1A1A1F). **보라/마젠타 금지(아트에 넣지 말 것).**
- **배경 제거용 크로마키**: 그림 배경만 **선명한 초록(#00FF00)** 으로 깔고 "transparent background" 요청
  (예전엔 마젠타를 썼지만, 이제 회색 아트라 마젠타도 가능 — 단 아트에 회색만 쓰면 어떤 단색배경도 OK).
- 설정 권장: **Transparent PNG ON**, Style = "Graphic Design / UI", Guidance 7.
- 결과는 `assets/textures/ui/` 에 저장 → Godot 에서 TextureRect/StyleBoxTexture(9-slice)로 연결.

---

## 1. 메뉴/스테이지선택 배경 (1920×1080, 16:9)
```
dark atmospheric background for a 2D paint platformer menu, deep charcoal (#14141F) gradient,
faint light gray and white paint splatters drifting in the dark, soft vignette, subtle floating dust,
minimalist, empty center for UI, cinematic, no characters, no text
```

## 2. 버튼/패널 프레임 — 9-slice 용 (512×512, 가장자리 균일)
```
rounded rectangle UI panel frame, dark slate fill (#1A1A2B) with 2px light steel-gray (#9EA2AC) border,
soft inner shadow, paint-edge texture on corners, game button, flat, centered,
uniform borders for 9-slice scaling, transparent background, no text
```
> Godot: StyleBoxTexture 로 import 후 margin(예: 24px) 지정해 버튼/패널에 적용.

## 3. 인게임 HUD 프레임 칩 (좌상단 정보 배경, 600×260)
```
small HUD info panel, semi-transparent dark glass (#0E0E17 60%), rounded corners,
thin light gray rim light, faint paint drip at bottom edge, sci-fi minimal, transparent background, no text
```

## 4. 포탈 (512×512, 발광)
```
glowing circular portal, swirling light gray and white energy, soft radial glow, paint-like swirl,
2D game asset, centered, transparent background, no text
```

## 5. 아이콘 세트 (각 256×256, 단색 실루엣 + 회색 글로우)
- 해골(사망수): `minimalist white skull icon, light gray glow outline, flat game UI icon, transparent background`
- 자물쇠(잠금): `minimalist padlock icon, muted gray, flat game UI icon, transparent background`
- 체크(클리어): `bold check mark icon, teal-green (#5AD98C), flat game UI icon, transparent background`
- 시계(타임): `minimalist stopwatch icon, white, light gray accent, flat game UI icon, transparent background`

## 6. 색 에너지 게이지(배터리) 프레임 (256×128)
```
horizontal battery gauge frame, hand-drawn jittery outline, white chalk style on dark,
5 segment cells, small terminal nub on right, flat game UI, transparent background, no text
```
> 현재는 `scripts/ui/battery_gauge.gd` 가 코드로 그림 — 이 이미지로 교체하려면 그 스크립트의 _draw 를 TextureRect 로 바꾸면 됨.

---

## 적용 가이드(이미지 받은 뒤)
1. PNG 를 `assets/textures/ui/` 에 저장 → Godot 가 자동 import.
2. **버튼/패널**: 인스펙터 Theme Overrides → Styles → New StyleBoxTexture → texture 지정 + margin.
   (지금은 `stage_select.gd` 가 코드 StyleBoxFlat 로 그림. 이미지 쓰려면 `_mk_style` 를 StyleBoxTexture 반환으로 교체.)
3. **아이콘**: TextureRect 로 배치(해골은 이미 `Hud.tscn/Bar/Skull` 에 skull.png 사용 중 → 교체만).
4. **배경**: 메뉴/선택 화면 `Dim` ColorRect 를 TextureRect(배경 PNG)로 교체.

> ⚠ 톤 일관성: 전부 같은 밝은 회색(#9EA2AC)·같은 차콜(#1A1A1F)로 뽑아야 화면이 따로 놀지 않음.
> 어두운 무드 통일 — 보라/마젠타는 쓰지 않는다(코드 UI 도 회색으로 변경됨).
