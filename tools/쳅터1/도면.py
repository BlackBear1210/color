# -*- coding: utf-8 -*-
"""
도안 → 도면 PNG (Dungeon Scrawl 느낌의 모눈 도면) — 2026-10-04 Claude

양피지 바탕 · 칸마다 점 · 5칸(점프 높이)·10칸(점프 거리)마다 진한 선 · 구조는 빗금.
도면 한 칸 = 12px. 게임 한 칸 = 32px. (Dungeon Scrawl 원본 파일은 칸당 70px — 그림 해상도일 뿐)
"""
import math
import os

from PIL import Image, ImageDraw, ImageFont

import 규격
import 기믹 as 기믹모듈

S = 12                  # 도면 px / 칸
여백 = 3                 # 도안 둘레로 바깥 지형을 몇 칸 보여줄지
머리 = 170              # 제목 띠 높이(px)
바탕 = (237, 231, 219)
점색 = (190, 180, 162)
선5 = (222, 213, 197)
선10 = (205, 194, 175)
구조색 = (61, 58, 54)
빗금색 = (86, 81, 75)
글꼴경로 = [r"C:\Windows\Fonts\malgun.ttf", r"C:\Windows\Fonts\malgunbd.ttf"]


def _글꼴(크기, 굵게=False):
    p = 글꼴경로[1 if 굵게 else 0]
    try:
        return ImageFont.truetype(p, 크기)
    except OSError:
        return ImageFont.load_default()


def 그리기(dn, 검사결과, 출력경로):
    W = (dn.w + 여백 * 2) * S
    H = (dn.h + 여백 * 2) * S + 머리 + 26 * max(1, len(dn.d.get("메모", [])))
    img = Image.new("RGB", (max(W, 1100), H), 바탕)
    d = ImageDraw.Draw(img, "RGBA")
    ox, oy = 여백 * S, 머리 + 여백 * S          # 도안 (0,0) 칸의 도면 위치

    def P(cx, cy):
        return (ox + cx * S, oy + cy * S)

    # ── 모눈 ──
    for cx in range(-여백, dn.w + 여백 + 1):
        x = ox + cx * S
        if cx % 10 == 0:
            d.line([(x, oy - 여백 * S), (x, oy + (dn.h + 여백) * S)], fill=선10, width=1)
        elif cx % 5 == 0:
            d.line([(x, oy - 여백 * S), (x, oy + (dn.h + 여백) * S)], fill=선5, width=1)
    for cy in range(-여백, dn.h + 여백 + 1):
        y = oy + cy * S
        if cy % 10 == 0:
            d.line([(ox - 여백 * S, y), (ox + (dn.w + 여백) * S, y)], fill=선10, width=1)
        elif cy % 5 == 0:
            d.line([(ox - 여백 * S, y), (ox + (dn.w + 여백) * S, y)], fill=선5, width=1)
    for cy in range(-여백, dn.h + 여백 + 1):
        for cx in range(-여백, dn.w + 여백 + 1):
            x, y = P(cx, cy)
            d.point((x, y), fill=점색)

    # ── 칸 채우기 ──
    빗금 = Image.new("RGBA", img.size, (0, 0, 0, 0))
    bd = ImageDraw.Draw(빗금)
    for cy in range(-여백, dn.h + 여백):
        for cx in range(-여백, dn.w + 여백):
            v = dn.칸(cx, cy)
            x, y = P(cx, cy)
            r = [x, y, x + S, y + S]
            if v == 1:
                d.rectangle(r, fill=구조색)
                for k in range(-S, S, 6):
                    bd.line([(x + k, y + S), (x + k + S, y)], fill=빗금색 + (255,), width=1)
            elif v == 2:
                d.rectangle(r, fill=(14, 14, 14))
            elif v == 3:
                d.rectangle(r, fill=(252, 252, 250))
            elif v == 4:
                d.rectangle(r, fill=(255, 255, 255, 90))
            elif v == 5:
                d.rectangle(r, fill=(236, 234, 226))      # [2026-10-10] 흰구조(달빛 깔개 · 칠 못 함)
    # 빗금은 구조 칸 안에만
    마스크 = Image.new("L", img.size, 0)
    md = ImageDraw.Draw(마스크)
    for cy in range(-여백, dn.h + 여백):
        for cx in range(-여백, dn.w + 여백):
            if dn.칸(cx, cy) == 1:
                x, y = P(cx, cy)
                md.rectangle([x, y, x + S - 1, y + S - 1], fill=255)
    img.paste(빗금, (0, 0), Image.composite(빗금, Image.new("RGBA", img.size, (0, 0, 0, 0)), 마스크))
    d = ImageDraw.Draw(img, "RGBA")
    # 발판 테두리 (검정·흰·유령)
    for k, 이름, 점, _n in dn.다각형들():
        if k == "구조":
            continue
        pts = [(ox + px / 규격.칸 * S, oy + py / 규격.칸 * S) for px, py in 점]
        if k == "검정":
            d.line(pts + [pts[0]], fill=(150, 150, 150), width=1)
        elif k == "흰":
            d.line(pts + [pts[0]], fill=(30, 30, 30), width=2)
        else:
            _점선(d, pts + [pts[0]], (70, 70, 140), 2)

    # ── 가구(배경) ──
    f작 = _글꼴(10)
    for 이름, x, y, *_ in dn.d.get("가구", []):
        if 이름 not in 규격.가구표:
            continue
        x0, y0, w, h = 규격.가구_사각(이름, x, y)
        a, b = P(x0, y0)
        c, e = P(x0 + w, y0 + h)
        d.rectangle([a, b, c, e], outline=(150, 112, 70, 200), width=1, fill=(176, 140, 96, 40))
        d.text((a + 2, b + 1), 이름, font=f작, fill=(120, 84, 44))

    # ── 구역 ──
    f구 = _글꼴(13, True)
    for 이름, x, y, w, h in dn.d.get("구역", []):
        a, b = P(x, y)
        c, e = P(x + w, y + h)
        _점선(d, [(a, b), (c, b), (c, e), (a, e), (a, b)], (40, 80, 150, 210), 2)
        d.rectangle([a + 2, b + 2, a + 6 + d.textlength(이름, font=f구), b + 20], fill=(237, 231, 219, 220))
        d.text((a + 4, b + 2), 이름, font=f구, fill=(30, 60, 130))

    # ── 가시 ──
    for gx, gy, gw in dn.d.get("가시", []):
        for xx in range(gx, gx + gw):
            x, y = P(xx, gy)
            d.polygon([(x + 1, y), (x + S / 2, y - S + 3), (x + S - 1, y)], fill=(176, 52, 40))

    # ── 기믹 (2026-10-05) ──
    f기 = _글꼴(11, True)
    for g in 기믹모듈.목록(dn):
        if isinstance(g, 기믹모듈.빛줄기):
            색 = (255, 236, 120) if g.색 == "흰" else (60, 40, 120)
            pts = [P(x / 규격.칸, y / 규격.칸) for x, y in g.꼭짓점()]
            d.polygon(pts, fill=색 + (110 if g.고정 else 50,), outline=색 + (230,))
            # [2026-10-10] 예전엔 ox, oy 에 받아서 P() 의 도면 원점이 빛 근원으로 바뀌었다 → 빛 뒤에 그리는 것(체크포인트·닿는 바닥 줄·기믹)이 전부 어긋났다
            lx, ly = P(g.원점[0] / 규격.칸, g.원점[1] / 규격.칸)
            d.ellipse([lx - 5, ly - 5, lx + 5, ly + 5], fill=색 + (255,), outline=(60, 50, 30))
            표 = f"{g.근원} {g.색}" + ("" if g.고정 else (" 점멸" if g.점멸 else f" {g.주기:g}초"))
            d.text((lx + 8, ly - 6), 표, font=f기, fill=(90, 70, 20) if g.색 == "흰" else (60, 40, 120))
        elif isinstance(g, 기믹모듈.도약대):
            l, t, r, b = g.사각()
            a, bb = P(l / 규격.칸, t / 규격.칸)
            c, e = P(r / 규격.칸, b / 규격.칸)
            d.polygon([(a, e), (a + 3, bb + 3), (c - 3, bb + 3), (c, e)], fill=(40, 150, 140), outline=(20, 90, 80))
            x0 = (a + c) / 2
            d.line([(x0, bb), (x0, bb - g.오름 * S)], fill=(40, 150, 140, 160), width=2)
            d.polygon([(x0 - 5, bb - g.오름 * S + 8), (x0, bb - g.오름 * S), (x0 + 5, bb - g.오름 * S + 8)], fill=(40, 150, 140))
            d.text((c + 3, bb - 14), f"도약 {g.오름}칸" + (f"({g.색}만)" if g.색 else ""), font=f기, fill=(20, 110, 100))
        elif isinstance(g, 기믹모듈.부서지는판):
            # [2026-10-09] 부서지는 판 — 갈색 판 + 금 표시
            for k in range(g.장수):
                a, bb = P(g.x + 3 * k, g.y)
                c, e = P(g.x + 3 * (k + 1), g.y + 0.6)
                d.rectangle([a + 1, bb, c - 1, e], fill=(150, 110, 70), outline=(90, 60, 30))
                d.line([((a + c) / 2 - 3, bb), ((a + c) / 2 + 2, e)], fill=(60, 40, 20), width=2)
            d.text((a + 3, bb - 14), f"부서지는판 ×{g.장수}", font=f기, fill=(120, 80, 40))
        elif isinstance(g, 기믹모듈.반딧불몹):
            # [2026-10-09 거미방] 반딧불 몹 — 정지점(번호) · 날아다니는 길(점선) · 빛 반경(옅은 원 = 색 규칙이 걸리는 곳)
            r = g.반경 / 규격.칸 * S
            for (ax, ay), (bx, by) in g.길():
                _점선(d, [P(ax, ay), P(bx, by)], (200, 160, 30), 2)
            for k, (mx, my) in enumerate(g.멈춤):
                x, y = P(mx, my)
                d.ellipse([x - r, y - r, x + r, y + r], outline=(225, 190, 60), width=1)
                d.ellipse([x - 7, y - 7, x + 7, y + 7], fill=(255, 235, 140), outline=(120, 90, 10))
                d.text((x + 9, y - 14), f"반딧불{g.i}·{k}" + (" 새장" if g.새장 and int(g.새장["멈춤"]) == k else ""), font=f기, fill=(140, 100, 10))
            if g.새장:
                lx, ly = g.새장["레버"]
                x, y = P(lx + 0.5, ly)
                d.rectangle([x - 5, y - 40, x + 5, y - 20], fill=(180, 150, 80), outline=(80, 60, 20))
                d.text((x - 20, y - 56), "새장 레버", font=f기, fill=(120, 90, 20))
        elif isinstance(g, 기믹모듈.누름계단):
            # [2026-10-09] 누름계단 — 발판(홈) · 숨은 자리(점선) → 나온 자리(돌 판) · 상자
            x0, 바닥, 폭 = g.발판
            a, bb = P(x0, 바닥)
            c, e = P(x0 + 폭, 바닥 + 1)
            d.rectangle([a, bb, c, e], fill=(160, 120, 60), outline=(90, 60, 20))
            d.text((a, e + 2), "누름 발판" + (" (유지)" if g.유지 else " (누르는 동안)"), font=f기, fill=(120, 80, 20))
            for k, p in enumerate(g.판들):
                a, bb = P(p["x"], p["y"])
                c, e = P(p["x"] + p["w"], p["y"] + p["h"])
                d.rectangle([a, bb, c, e], fill=(120, 116, 110), outline=(60, 58, 55), width=2)
                ha, hb = P(p["x"] + p["나옴"], p["y"])
                _점선(d, [(ha, hb), (ha + (c - a), hb), (ha + (c - a), e), (ha, e), (ha, hb)], (200, 200, 200), 1)
                d.text((a + 2, bb - 14), f"튀어나옴{k + 1}({p.get('지연', 0)}초)", font=f기, fill=(60, 58, 55))
            if g.상자:
                sx, sb = g.상자
                a, bb = P(sx - 1, sb - 3)
                c, e = P(sx + 2, sb)
                d.rectangle([a, bb, c, e], fill=(70, 66, 60), outline=(200, 190, 170), width=2)
                d.line([(a, bb), (c, e)], fill=(200, 190, 170), width=1)
                d.line([(c, bb), (a, e)], fill=(200, 190, 170), width=1)
                d.text((a, bb - 14), "상자(무게)", font=f기, fill=(90, 80, 60))
        elif isinstance(g, 기믹모듈.그을음거미):
            x, y = P(g.x + 0.5, g.바닥)
            d.ellipse([x - 13, y - 15, x + 13, y], fill=(25, 25, 25), outline=(150, 150, 150))
            for s_ in (-1, 1):
                for k in range(3):
                    d.line([(x + s_ * 8, y - 8), (x + s_ * (18 + k * 3), y - 2 - k * 5)], fill=(25, 25, 25), width=2)
            d.text((x + 16, y - 18), "거미(그을음)", font=f기, fill=(40, 40, 40))
            for k, w in enumerate(g.줄):
                a1, a2 = P(*w["가"]), P(*w["나"])
                d.line([a1, a2], fill=(150, 150, 170), width=3 if w["처음부터"] else 1)
                mx, my = (a1[0] + a2[0]) / 2, (a1[1] + a2[1]) / 2
                for t in range(6):
                    ang = t * math.pi / 3
                    d.line([(mx, my), (mx + 14 * math.cos(ang), my + 14 * math.sin(ang))], fill=(150, 150, 170), width=1)
                d.text((mx + 6, my + 4), f"거미줄{k + 1}" + (" (처음부터)" if w["처음부터"] else ""), font=f기, fill=(90, 90, 120))
        elif isinstance(g, 기믹모듈.빛받이):
            x, y = P(g.x, g.y)
            테 = (20, 20, 20) if g.색 == "검정" else (250, 250, 240)
            d.ellipse([x - 11, y - 11, x + 11, y + 11], fill=(150, 120, 60))
            d.ellipse([x - 8, y - 8, x + 8, y + 8], fill=테, outline=(90, 70, 30))
            d.text((x + 13, y - 8), f"빛받이({g.색}{'' if g.유지 else ' · 켜진 동안'})", font=f기, fill=(120, 90, 20))
            if g.문:
                dd = g.문
                w, h = dd.get("크기", [3, 5])
                a, bb = P(dd["x"] - w / 2, dd["바닥"] - h)
                c, e = P(dd["x"] + w / 2, dd["바닥"])
                _점선(d, [(a, bb), (c, bb), (c, e), (a, e), (a, bb)], (110, 110, 110), 2)
                for t in range(1, 4):
                    xx = a + (c - a) * t / 4
                    d.line([(xx, bb), (xx, e)], fill=(110, 110, 110), width=1)
                d.line([(x, y), ((a + c) / 2, bb)], fill=(150, 130, 70), width=1)
                d.text((a, e + 2), "창살문", font=f기, fill=(90, 90, 90))
        elif isinstance(g, 기믹모듈.그을음):
            x, y = P(g.x + 0.5, g.바닥)
            d.ellipse([x - 12, y - 14, x + 12, y], fill=(30, 30, 30), outline=(120, 120, 120))
            d.ellipse([x - 5, y - 10, x - 2, y - 7], fill=(255, 255, 255))
            d.ellipse([x + 2, y - 10, x + 5, y - 7], fill=(255, 255, 255))
            d.text((x + 14, y - 16), "그을음", font=f기, fill=(40, 40, 40))
        elif isinstance(g, 기믹모듈.열쇠조각):
            x, y = P(g.x, g.y)
            색 = (20, 20, 20) if g.색 == "검정" else (245, 245, 240)
            d.ellipse([x - 9, y - 16, x + 9, y + 2], fill=색, outline=(200, 160, 40), width=2)
            d.rectangle([x - 2, y + 2, x + 2, y + 16], fill=색, outline=(200, 160, 40))
            d.text((x + 12, y - 12), f"열쇠 {g.색}" + (f" → {g.주인[6:]}" if g.주인 else ""), font=f기, fill=(160, 120, 20))
        elif isinstance(g, 기믹모듈.레버퍼즐):
            for k, (x0, y0) in enumerate(g.레버):
                x, y = P(x0 + 0.5, y0)
                d.rectangle([x - 5, y - 40, x + 5, y - 20], fill=(180, 150, 80), outline=(80, 60, 20))
                d.text((x - 4, y - 56), "켬" if g.정답[k] else "끔", font=f기, fill=(120, 90, 20))
            x, y = P(g.손잡이[0] + 0.5, g.손잡이[1])
            d.ellipse([x - 7, y - 34, x + 7, y - 20], outline=(120, 90, 20), width=3)
            d.text((x + 9, y - 40), "손잡이", font=f기, fill=(120, 90, 20))
            if g.샹들리에:
                x, y = P(g.샹들리에[0], g.샹들리에[1])
                d.polygon([(x - 3 * S, y + 2 * S), (x + 3 * S, y + 2 * S), (x, y + 5 * S)], outline=(170, 40, 40))
                d.text((x + 3 * S + 3, y + 2 * S), "샹들리에 함정", font=f기, fill=(170, 40, 40))
            if g.단서:
                x, y = P(g.단서[0], g.단서[1])
                d.rectangle([x - 2.3 * S, y - 1.5 * S, x + 2.3 * S, y + 1.5 * S], outline=(120, 90, 20), width=2)
                d.text((x - 2.3 * S, y + 1.6 * S), "단서판", font=f기, fill=(120, 90, 20))
            if g.비밀문:
                b = g.비밀문
                a, bb = P(b["x"] - 3.5, b["바닥"] - 12)
                c, e = P(b["x"] + 3.5, b["바닥"])
                _점선(d, [(a, bb), (c, bb), (c, e), (a, e), (a, bb)], (120, 60, 160), 2)
                d.text((a + 3, bb + 3), "비밀문(책장)", font=f기, fill=(120, 60, 160))
        elif isinstance(g, 기믹모듈.움직이는발판):
            칸들 = g.위치들()
            l0, t0, r0, _ = 칸들[0]
            l1, t1, r1, b1 = 칸들[-1]
            a, bb = P(l0 / 규격.칸, t0 / 규격.칸)
            c, e = P(r1 / 규격.칸, b1 / 규격.칸)
            _점선(d, [(a, bb), (c, bb), (c, e), (a, e), (a, bb)], (200, 90, 30), 2)
            a0, b0 = P(l0 / 규격.칸, t0 / 규격.칸)
            c0, e0 = P(r0 / 규격.칸, t0 / 규격.칸 + 0.9)
            d.rectangle([a0, b0, c0, e0], fill=(200, 90, 30), outline=(120, 50, 10))
            d.text((c + 3, bb), f"움직이는 발판 {g.방향} {g.거리}칸 · {g.왕복:g}초", font=f기, fill=(160, 70, 20))

    # ── 도달 구간(검사) ──
    if 검사결과:
        구간 = 검사결과["구간"]
        for i, (cy, a, b) in enumerate(구간):
            ok = i in 검사결과["도달구간"]
            y = oy + cy * S - 2
            d.line([(ox + a / 규격.칸 * S, y), (ox + b / 규격.칸 * S, y)],
                   fill=(40, 170, 70, 230) if ok else (220, 60, 60, 230), width=2)

    # ── 시작 · 체크포인트 ──
    f중 = _글꼴(14, True)
    sx, sy = dn.d["시작"]
    x, y = P(sx + 0.5, sy)
    d.ellipse([x - 9, y - 22, x + 9, y - 4], fill=(40, 150, 70), outline=(255, 255, 255), width=2)
    d.text((x - 4, y - 22), "S", font=f중, fill=(255, 255, 255))
    for cx, cy in dn.d.get("체크", []):
        x, y = P(cx + 0.5, cy)
        d.line([(x, y), (x, y - 20)], fill=(40, 90, 200), width=2)
        d.polygon([(x, y - 20), (x + 10, y - 16), (x, y - 12)], fill=(40, 90, 200))

    # ── 첫 화면(카메라) ──
    vw, vh = 규격.화면_칸
    cx = min(max(sx + 0.5 - vw / 2, 0), max(dn.w - vw, 0))
    cy = min(max(sy - 2 - vh / 2, 0), max(dn.h - vh, 0))
    a, b = P(cx, cy)
    c, e = P(cx + vw, cy + vh)
    _점선(d, [(a, b), (c, b), (c, e), (a, e), (a, b)], (230, 120, 20, 230), 2)
    d.text((a + 4, e - 18), "첫 화면 1920×1080", font=_글꼴(12, True), fill=(200, 100, 10))

    # ── 문 ──
    for 문 in dn.문:
        i = dn.문_정보(문)
        yy = 문["바닥"] - 문["높이"] / 2
        if i["d"] < 0:
            x, y = P(0, yy)
            끝 = x - S * 2.6
        else:
            x, y = P(dn.w, yy)
            끝 = x + S * 2.6
        막힘 = not 문.get("연결")
        색 = (150, 40, 40) if 막힘 else (210, 120, 10)
        d.line([(x, y), (끝, y)], fill=색, width=4)
        d.polygon([(끝, y - 7), (끝 + i["d"] * 10, y), (끝, y + 7)], fill=색)
        표 = f"{문['이름']} → " + ("막힘" if 막힘 else f"{문['연결'][0].replace('쳅터1_', '')}·{문['연결'][1]}")
        if 문.get("되돌아가기") and not 막힘:
            표 += " ↔"
        tw = d.textlength(표, font=f중)
        tx = x - tw - 8 if i["d"] < 0 else x + 8
        tx = min(max(tx, 4), img.size[0] - tw - 4)
        d.rectangle([tx - 3, y - 30, tx + tw + 3, y - 12], fill=(255, 248, 230, 230))
        d.text((tx, y - 30), 표, font=f중, fill=색)

    # ── 제목 띠 ──
    d.rectangle([0, 0, img.size[0], 머리 - 8], fill=(226, 218, 203))
    d.text((14, 8), dn.제목, font=_글꼴(30, True), fill=(40, 34, 28))
    큰틀 = "  ·  큰 틀(지형 미배치 — 임시 길)" if dn.d.get("큰틀") else ""
    d.text((16, 50), f"{dn.이름}.json  ·  {dn.종류}  ·  {dn.w}×{dn.h}칸 = {dn.w * 규격.칸}×{dn.h * 규격.칸}px  "
                     f"(화면 {dn.w * 규격.칸 / 1920:.2f}×{dn.h * 규격.칸 / 1080:.2f}장)  ·  흐름 {dn.d.get('흐름', '')}{큰틀}",
           font=_글꼴(15), fill=(60, 52, 44))
    # 범례
    ly = 78
    lx = 16
    for 표, 칠 in [("구조(검정·칠 안 됨)", 구조색), ("검정 판", (14, 14, 14)), ("흰 판", (252, 252, 250)), ("유령 판(칠해야 밟힘)", None)]:
        if 칠:
            d.rectangle([lx, ly, lx + 18, ly + 14], fill=칠, outline=(30, 30, 30))
        else:
            _점선(d, [(lx, ly), (lx + 18, ly), (lx + 18, ly + 14), (lx, ly + 14), (lx, ly)], (70, 70, 140), 2)
        d.text((lx + 24, ly - 2), 표, font=_글꼴(13), fill=(50, 44, 38))
        lx += 34 + d.textlength(표, font=_글꼴(13))
    for 표, 색 in [("가시", (176, 52, 40)), ("빛줄기(흰/검정)", (230, 200, 90)), ("도약대", (40, 150, 140)), ("움직이는 발판", (200, 90, 30)), ("S 시작", (40, 150, 70)), ("체크포인트", (40, 90, 200)), ("연결(↔ 되돌아가기)", (210, 120, 10)),
                  ("검사: 닿는 바닥", (40, 170, 70)), ("못 닿는 바닥", (220, 60, 60))]:
        d.rectangle([lx, ly + 3, lx + 12, ly + 11], fill=색)
        d.text((lx + 16, ly - 2), 표, font=_글꼴(13), fill=(50, 44, 38))
        lx += 30 + d.textlength(표, font=_글꼴(13))
    # 축척 막대
    by = 112
    d.line([(16, by + 40), (16 + 10 * S, by + 40)], fill=(40, 34, 28), width=3)
    d.text((16, by + 18), "점프 거리 10칸 = 320px", font=_글꼴(12), fill=(40, 34, 28))
    d.line([(180, by + 40), (180, by + 40 - 5 * S)], fill=(40, 34, 28), width=3)
    d.text((188, by + 24), "점프 높이 5칸 = 160px (오르기 4칸까지)", font=_글꼴(12), fill=(40, 34, 28))
    if 검사결과:
        결 = " · ".join(f"{k}{'○' if v else '×'}" for k, v in {**검사결과["문"], **검사결과["문간"]}.items())
        비 = 검사결과.get("색비율", {})
        if 비.get("칸"):
            결 += f"   |   색 비율 검정 {비['검정']:.0%} · 흰 {비['흰']:.0%} · 유령 {비['유령']:.0%} (최대 70·30)"
        d.text((520, by + 10), f"도달 검사(점프 물리 흉내): {결}", font=_글꼴(13, True),
               fill=(40, 120, 60) if not 검사결과["실패"] else (180, 40, 40))

    # ── 메모 ──
    my = oy + (dn.h + 여백) * S + 6
    for 줄 in dn.d.get("메모", []):
        d.text((16, my), "· " + 줄, font=_글꼴(14), fill=(50, 44, 38))
        my += 26

    os.makedirs(os.path.dirname(출력경로), exist_ok=True)
    안전저장(img, 출력경로)
    return 출력경로


def 안전저장(img, 경로, 횟수=40):
    """[2026-10-05] Godot 편집기가 열려 있으면 PNG 를 다시 가져오느라(import) 잠깐 파일을 잡고 있어
    바로 덮어쓰면 Errno 22 가 난다. 옆에 임시 파일로 쓴 뒤 바꿔치기하고, 잡혀 있으면 잠깐 기다렸다 다시."""
    import time
    임시 = 경로 + ".임시"          # .png 로 끝나면 편집기가 이것까지 가져오려 한다
    img.save(임시, format="PNG", optimize=True)
    for _ in range(횟수):
        try:
            os.replace(임시, 경로)
            return
        except OSError:
            time.sleep(0.25)
    os.replace(임시, 경로)


def _점선(d, pts, 색, 굵기, 길이=7):
    for (x1, y1), (x2, y2) in zip(pts, pts[1:]):
        L = math.hypot(x2 - x1, y2 - y1)
        if L == 0:
            continue
        n = int(L // (길이 * 2)) + 1
        for i in range(n):
            t0 = i * 길이 * 2 / L
            t1 = min((i * 길이 * 2 + 길이) / L, 1)
            d.line([(x1 + (x2 - x1) * t0, y1 + (y2 - y1) * t0), (x1 + (x2 - x1) * t1, y1 + (y2 - y1) * t1)], fill=색, width=굵기)
