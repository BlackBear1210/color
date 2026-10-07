# -*- coding: utf-8 -*-
"""양동이 — 물이 차오르는 게 보이는 시안 2종. 앞 시안 스크립트의 그리기 도구를 빌린다."""
import os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(HERE, "시안_양동이_박스.py"), encoding="utf-8").read()
_a, _b = src.split("# ─────────────────────────────── 시트 조립")
exec(_a)
exec(_b.split("dr.text((40, 26)")[0])   # 배경 띠·그림자·플레이어 도구
OUT = sys.argv[1] if len(sys.argv) > 1 else "물참.png"


def _paint(s, m, col, alpha=1.0):
    """반투명을 제대로 — 알파를 곱하지 않은(straight) 색끼리 over 합성."""
    col = np.asarray(col, np.float32)
    if col.ndim == 1:
        col = np.broadcast_to(col, s.rgb.shape)
    k = np.clip(m * alpha, 0, 1)
    na = k + s.a * (1 - k)
    w1 = (k / np.maximum(na, 1e-4))[..., None]
    s.rgb = s.rgb * (1 - w1) + col * w1
    s.a = na


Canvas.paint = _paint
TOP, BOT, TW, BW = -100, -8, 47, 39


def half_w(y):
    return TW + (BW - TW) * (y - TOP) / (BOT - TOP)


def 손잡이(c):
    pts = [(-47 * np.cos(t), -92 - 44 * np.sin(t)) for t in np.linspace(0, np.pi, 40)]
    hm = c.line(pts, 3.2)
    c.paint(c.line([(x + 1, y + 1.5) for x, y in pts], 3.4), (0.02,) * 3, 0.55)
    c.outline(hm, 1.2)
    c.paint(hm, (IRON * 1.05,) * 3)
    c.paint(c.line(pts[3:20], 1.0), (0.66,) * 3, 0.6)
    grip = c.poly([(-13, -140), (13, -140), (13, -132), (-13, -132)])
    c.paint(grip, (0.30 * woodgrain(c.W, c.H, 5, vertical=False))[..., None] * np.ones(3))
    c.outline(grip, 1.2)
    for sx in (-1, 1):
        ear = c.poly([(sx * 40, -98), (sx * 52, -98), (sx * 52, -86), (sx * 44, -80), (sx * 40, -80)])
        c.paint(ear, (IRON * 0.95 * grain(c.W, c.H, 70 + sx))[..., None] * np.ones(3))
        c.outline(ear, 1.3)
        c.rivet(sx * 47, -92, 2.4)


def 수면(c, y, wc, inset, 색):
    """수면 = 얇은 타원 + 앞 가장자리 밝은 선(물 색과 상관없이 높이가 읽히게)."""
    rx = half_w(y) - inset
    c.paint(c.ell(0, y, rx, 3.2), np.asarray(wc) * 0.85 + 0.06)
    pts = [(rx * np.cos(t), y + 3.2 * np.sin(t)) for t in np.linspace(0.15, np.pi - 0.15, 30)]
    c.paint(c.line(pts, 1.3), (0.95, 0.96, 0.98) if 색 != 1 else (0.55, 0.57, 0.6), 0.85)


def 넘침(c, wc):
    d = c.line([(20, TOP + 4), (21, TOP + 16), (20.5, TOP + 22)], 2.4)
    c.paint(d, wc)
    c.paint(c.ell(20.5, TOP + 23, 2, 2.6), wc)


# ─────────── 시안 A · 쇠살 유리 들통 — 몸통이 흐린 유리, 쇠살·테가 몸 색
def 유리들통(색, 수위):
    c = Canvas(150, 170, 75, 160)
    body = [(-TW, TOP), (TW, TOP), (BW, BOT), (-BW, BOT)]
    m_body = c.poly(body)
    # 유리 — 흐린 회색, 뒤가 조금 비친다
    c.paint(m_body, (0.62, 0.64, 0.67), 0.30)
    # 안쪽 뒷벽(원통 뒤쪽 유리) — 가장자리를 조금 더 진하게 = 두께
    edge = np.clip(np.abs(c.gx) / np.maximum(half_w(np.clip(c.gy, TOP, BOT)), 1) - 0.8, 0, 1) * 5
    c.paint(m_body * np.clip(edge, 0, 1), (0.8, 0.82, 0.85), 0.25)
    wc = np.asarray(WATER[색])
    if 수위 > 0:
        wy = BOT - 4 - 수위 * (BOT - TOP - 10)
        inner = [(-half_w(wy) + 3, wy), (half_w(wy) - 3, wy), (BW - 3, BOT - 4), (-BW + 3, BOT - 4)]
        wm = c.poly(inner)
        depth = np.clip((c.gy - wy) / 60, 0, 1)
        col = wc * (1 - 0.25 * depth[..., None]) + (0.04 if 색 == 0 else 0)
        c.paint(wm, col, 0.93)
        # 물 속 빛줄기 — 흔들리는 가는 선
        for x in (-18, 6, 24):
            c.paint(c.line([(x, wy + 6), (x + 3, BOT - 8)], 0.8) * wm, (1, 1, 1) if 색 != 1 else (0.6,) * 3, 0.12)
        수면(c, wy, wc, 3, 색)
    # 유리 앞 반사 — 세로 광택 두 줄
    for x, w, a in ((-31, 3.2, 0.35), (-24, 1.3, 0.25), (27, 1.0, 0.12)):
        c.paint(c.line([(x, TOP + 8), (x * 0.86, BOT - 6)], w) * m_body, (1, 1, 1), a)
    c.outline(m_body, 1.4, col=(0.05, 0.05, 0.06))
    # 쇠살 — 몸 색으로 칠함(검정/흰 = 미는 조건). 가장자리 두 개 + 가는 살 두 개
    p = PAINT[색]
    g = grain(c.W, c.H, 91 + 색)
    def 살(xt, xb, w):
        m = c.poly([(xt - w, TOP + 2), (xt + w, TOP + 2), (xb + w, BOT - 2), (xb - w, BOT - 2)])
        v = p * (1 + (g - 1) * 0.5) * cyl(c, xt - w, xt + w, hi=0.3, lo=0.4)
        c.paint(m, v[..., None] * np.ones(3) + (0.06 if 색 == 0 else 0))
        c.outline(m, 1.1)
    살(-TW + 3, -BW + 3, 3.5)
    살(TW - 3, BW - 3, 3.5)
    살(-24, -20, 1.8)
    살(24, 20, 1.8)
    # 몸 색 테 — 위(입구)·가운데 없음(수위가 가려지지 않게)·아래
    def 테(y, h):
        wt, wb = half_w(y) + 1.5, half_w(y + h) + 1.5
        m = c.poly([(-wt, y), (wt, y), (wb, y + h), (-wb, y + h)])
        v = p * (1 + (g - 1) * 0.5) * cyl(c, -wt, wt, spec=0.3)
        c.paint(m, v[..., None] * np.ones(3) + (0.07 if 색 == 0 else 0))
        c.paint(c.poly([(-wt, y), (wt, y), (wt, y + 1), (-wt, y + 1)]), (0.75,) * 3, 0.5)
        c.outline(m, 1.3)
        for xx in (-wt * 0.75, 0, wt * 0.75):
            c.rivet(xx, y + h / 2, 1.6)
    테(-96, 8)
    테(-14, 9)
    rim = c.ell(0, TOP, TW + 3, 7)
    c.paint(rim, ((p + 0.06 if 색 == 0 else p) * g)[..., None] * np.ones(3))
    c.outline(rim, 1.3)
    c.paint(c.ell(0, TOP + 0.5, TW - 2, 4.6), (0.05,) * 3, 0.9)
    if 수위 >= 0.99:
        수면(c, TOP + 1.5, wc, 4, 색)
        넘침(c, wc)
    손잡이(c)
    return c


# ─────────── 시안 B · 주철 들통 + 계량창 — 앞면 세로 창에 물기둥과 찌
def 계량창들통(색, 수위):
    c = Canvas(150, 170, 75, 160)
    g = grain(c.W, c.H, 11 + 색)
    body = [(-TW, TOP), (TW, TOP), (BW, BOT), (-BW, BOT)]
    m_body = c.poly(body)
    p = PAINT[색]
    shade = cyl(c, -TW, TW, spec=0.25 if 색 == 1 else 0.5)
    col = p * shade * (1 + (g - 1) * (0.35 if 색 == 1 else 0.8)) + (0.05 * shade if 색 == 0 else 0)
    c.paint(m_body, col[..., None] * np.ones(3))
    c.outline(m_body, 1.8)
    # 쇠테 — 창을 피해 위·아래에만
    for y in (-92, -20):
        wt, wb = half_w(y) + 1.5, half_w(y + 7) + 1.5
        m = c.poly([(-wt, y), (wt, y), (wb, y + 7), (-wb, y + 7)])
        c.paint(m, (IRON * cyl(c, -wt, wt, spec=0.6) * grain(c.W, c.H, 200 - y))[..., None] * np.ones(3))
        c.outline(m, 1.3)
        for xx in (-wt * 0.7, wt * 0.7):
            c.rivet(xx, y + 3.5, 1.7)
    # 계량창
    WX, WT_, WB_ = 13, -82, -26
    frame = c.poly([(-WX - 5, WT_ - 5), (WX + 5, WT_ - 5), (WX + 5, WB_ + 5), (-WX - 5, WB_ + 5)])
    c.paint(frame, (IRON * 1.05 * grain(c.W, c.H, 300))[..., None] * np.ones(3))
    c.outline(frame, 1.3)
    win = c.poly([(-WX, WT_), (WX, WT_), (WX, WB_), (-WX, WB_)])
    c.paint(win, (0.26, 0.27, 0.29))                     # 빈 유리 = 흐린 중간 회색(검은 물이 보이게)
    c.paint(c.poly([(-WX, WT_), (-WX + 4, WT_), (-WX + 4, WB_), (-WX, WB_)]), (0.1,) * 3, 0.5)
    wc = np.asarray(WATER[색])
    fy = WB_ - 수위 * (WB_ - WT_)
    if 수위 > 0:
        wm = c.poly([(-WX, fy), (WX, fy), (WX, WB_), (-WX, WB_)])
        c.paint(wm, wc * (1 - 0.2 * np.clip((c.gy - fy) / 50, 0, 1))[..., None] + (0.03 if 색 == 0 else 0))
    # 찌 — 밝은 쇠 원통. 물 색과 상관없이 수위를 가리킨다
    fyy = min(max(fy, WT_ + 3.5), WB_ - 3.5)
    fl = c.poly([(-WX + 3, fyy - 3.5), (WX - 3, fyy - 3.5), (WX - 3, fyy + 3.5), (-WX + 3, fyy + 3.5)])
    c.outline(fl, 1.2, col=(0.02, 0.02, 0.02))
    c.paint(fl, (0.86 * cyl(c, -WX, WX, hi=0.3, lo=0.35))[..., None] * np.ones(3))
    c.paint(c.line([(-WX + 4, fyy - 2), (WX - 4, fyy - 2)], 0.8), (1, 1, 1), 0.6)
    # 창 유리 반사
    c.paint(c.line([(-WX + 6, WT_ + 2), (-WX + 6, WB_ - 2)], 1.4) * win, (1, 1, 1), 0.22)
    # 눈금 3 개 — 창 오른쪽 틀
    for k in (1, 2, 3):
        y = WB_ - k * (WB_ - WT_) / 3
        c.paint(c.line([(WX + 1, y), (WX + 5, y)], 1.2), (0.05,) * 3)
    for x, y in ((-WX - 2.5, WT_ - 2.5), (WX + 2.5, WT_ - 2.5), (-WX - 2.5, WB_ + 2.5), (WX + 2.5, WB_ + 2.5)):
        c.rivet(x, y, 1.6)
    fm = c.poly([(-BW - 1, -10), (BW + 1, -10), (BW - 2, -2), (-BW + 2, -2)])
    c.paint(fm, (IRON * 0.75 * cyl(c, -BW, BW) * g)[..., None] * np.ones(3))
    c.outline(fm, 1.4)
    rim = c.ell(0, TOP, TW + 3, 8)
    c.paint(rim, (IRON * 1.15 * g)[..., None] * np.ones(3))
    c.outline(rim, 1.4)
    c.paint(c.ell(0, TOP + 0.5, TW - 2, 5.2), (0.035,) * 3)
    # 입구로 보이는 수면 — 2/3 넘으면 입구 안쪽이 물빛으로
    if 수위 >= 0.6:
        c.paint(c.ell(0, TOP + 1.8, TW - 3.5 - (1 - 수위) * 12, 3.9 - (1 - 수위) * 3), wc, 0.5 + 0.5 * (수위 >= 0.99))
    if 수위 >= 0.99:
        넘침(c, wc)
    손잡이(c)
    return c


# ─────────── 시트
W, H = 1800, 1560
sheet = Image.new("RGB", (W, H), BG)
dr = ImageDraw.Draw(sheet)
hopper = Image.open(os.path.join(ROOT, "assets/textures/obstacles/hopper/cast_iron_v1/hopper_atlas_flat.png")).convert("RGBA").crop((0, 0, 512, 1024))
stream = {0: Image.open(os.path.join(ROOT, "assets/textures/obstacles/liquid/fluid_stream_black_v1.png")).convert("RGBA"),
          1: Image.open(os.path.join(ROOT, "assets/textures/obstacles/liquid/fluid_stream_white_v1.png")).convert("RGBA")}


def label(x, y, t, sz=18, b=False, col=(215, 215, 215)):
    dr.text((x, y), t, font=FONT(sz, b), fill=col)


dr.text((40, 26), "양동이 — 물이 차오르는 게 보이게", font=FONT(40, True), fill=(230, 230, 230))
label(40, 84, "수위 0 · ⅓ · ⅔ · 가득 × 검정/흰색 · 확대 1.3배 + 게임 1:1 띠(위에서 떨어지는 물 / 쏴서 채우기)", 18, col=(160, 160, 160))


def _타일(img, w, h, ox=0, oy=0):
    t = img.resize((420, 420))
    out = Image.new("RGB", (w, h))
    for x in range(-ox, w, t.width):
        out.paste(t.crop((0, oy, t.width, oy + h)), (x, 0))
    return out


def scene_strip(w, h, floor_split=None):
    k = w / bg_src.width
    big = bg_src.resize((w, int(bg_src.height * k)))
    im = big.crop((0, big.height - h - 40, w, big.height - 40))
    im = Image.eval(im, lambda v: int(v * 0.8))
    fy = h - 60
    im.paste(_타일(brick, w, 60), (0, fy))
    if floor_split:
        im.paste(_타일(brick_w, w - floor_split, 60, 40, 20), (floor_split, fy))
    t = top_b.resize((top_b.width * 18 // top_b.height, 18))
    for x in range(0, floor_split or w, t.width):
        im.paste(t, (x, fy - 6), t)
    return im.convert("RGBA"), fy


def 띠(fn, w, h):
    strip, fy = scene_strip(w, h, floor_split=int(w * 0.55))
    # 왼쪽: 호퍼 물줄기가 검정 양동이로 — 반쯤 참
    hx = 230
    hp = hopper.resize((int(512 * 0.36), int(1024 * 0.36)))
    bb = hp.getbbox()
    hp = hp.crop(bb)
    top_bucket = fy - 100
    L = max(10, top_bucket - 60)
    halo = Image.new("RGBA", (34, L), (0, 0, 0, 0))
    ImageDraw.Draw(halo).rectangle((0, 0, 34, L), fill=(150, 150, 155, 90))   # 검은 물줄기 가장자리 빛(어두운 배경에서 읽히게)
    strip.alpha_composite(halo.filter(ImageFilter.GaussianBlur(3)), (hx - 17, 60))
    st = stream[0].resize((24, 512)).crop((0, 0, 24, L))
    strip.alpha_composite(st, (hx - 12, 60))
    strip.alpha_composite(hp, (hx - hp.width // 2, 60 - hp.height + 20))
    shadow(strip, hx, fy, 80)
    place(strip, fn(0, 0.5).image(1), hx, fy, 75, 160)
    d = ImageDraw.Draw(strip)
    for dx, dy in ((-14, -6), (12, -9), (-6, -12), (18, -3)):
        d.ellipse((hx + dx - 2, top_bucket + dy - 2, hx + dx + 2, top_bucket + dy + 2), fill=(20, 20, 22, 255))
    player(strip, hx + 130, fy)
    d.text((hx - 90, 14), "위에서 떨어지는 물 → 조금씩 참", font=FONT(15, True), fill=(235, 235, 235))
    # 가운데: 검정 가득 = 발판
    shadow(strip, 560, fy, 80)
    place(strip, fn(0, 1.0).image(1), 560, fy, 75, 160)
    d.text((500, 14), "가득 = 넘친다", font=FONT(15, True), fill=(235, 235, 235))
    # 오른쪽: 흰 플레이어가 흰 양동이를 쏜다
    bx = int(w * 0.55) + 260
    shadow(strip, bx, fy, 80)
    place(strip, fn(1, 0.33).image(1), bx, fy, 75, 160)
    player(strip, bx + 230, fy, white=True)
    # 날아가는 물감 + 입구에 튄 것
    for i, x in enumerate(range(bx + 60, bx + 190, 34)):
        r = 5 - i * 0.6
        d.ellipse((x - r * 1.6, fy - 118 - r + i * 3, x + r * 1.6, fy - 118 + r + i * 3), fill=(240, 242, 245, int(255 - i * 45)))
    for dx, dy in ((30, -6), (38, 2), (26, 6)):
        d.ellipse((bx + dx - 3, fy - 112 + dy - 3, bx + dx + 3, fy - 112 + dy + 3), fill=(240, 242, 245, 255))
    d.text((bx - 110, 14), "같은 색으로 쏘면 한 칸씩 참 (규칙 미정)", font=FONT(15, True), fill=(235, 235, 235))
    return strip


def panel(py, title, sub, fn):
    PW, PH = W - 80, 700
    dr.rectangle((40, py, 40 + PW, py + PH), outline=(70, 70, 74), width=2, fill=(30, 30, 33))
    label(58, py + 12, title, 26, True, (235, 235, 235))
    label(58, py + 50, sub, 16, col=(165, 165, 165))
    base = py + 330
    sc = 1.3
    items = [(색, l) for 색 in (0, 1) for l in (0, 0.33, 0.66, 1.0)]
    for i, (색, l) in enumerate(items):
        x = 150 + i * 205 + (40 if 색 == 1 else 0)
        im = fn(색, l).image(sc)
        sheet.paste(im, (int(x - 75 * sc), int(base - 160 * sc)), im)
        name = f"{'검정' if 색 == 0 else '흰색'} · " + {0: "빔", 0.33: "⅓", 0.66: "⅔", 1.0: "가득"}[l]
        label(x - 35, base + 8, name, 16, col=(190, 190, 190))
    s = 띠(fn, PW - 36, 280)
    sheet.paste(s.convert("RGB"), (58, py + PH - 300))


panel(125, "양동이 물참 시안 A — 쇠살 유리 들통",
      "몸통 = 흐린 유리(반투명) · 쇠살·테 = 몸 색(검정/흰 = 미는 조건) · 물이 바닥부터 차오르고 수면 앞 가장자리에 밝은 선(검은 물도 높이가 읽힘)", 유리들통)
panel(845, "양동이 물참 시안 B — 주철 들통 + 계량창",
      "앞 시안 1 몸통 그대로 · 앞면 세로 유리창에 물기둥 + 밝은 찌(물 색과 상관없이 수위를 가리킴) · 눈금 3 · ⅔ 넘으면 입구에 수면", 계량창들통)
sheet.save(OUT)
print("saved", OUT)
