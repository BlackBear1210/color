"""원본 주철 재질과 실제 코드 면 배치의 비교 SVG. 엔진 화면 검증을 대체하지 않는다."""
import base64
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/visual_review/platform_finish_20261009'


def build():
    raw = (ROOT / 'assets/textures/obstacles/switch/cast_iron_v1/parts.png').read_bytes()
    data = base64.b64encode(raw).decode()
    svg = ['<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="960" height="450" viewBox="0 0 960 450">',
           '<defs>', f'<image id="parts" width="1280" height="1280" xlink:href="data:image/png;base64,{data}"/>']
    for shade in [0.48, 0.67, 0.52, 0.76, 0.58, 0.42]:
        svg.append(f'<filter id="tone{shade}" color-interpolation-filters="sRGB"><feComponentTransfer><feFuncR type="linear" slope="{shade}"/><feFuncG type="linear" slope="{shade}"/><feFuncB type="linear" slope="{shade}"/></feComponentTransfer></filter>')
    svg.extend(['</defs>', '<rect width="960" height="450" fill="#202020"/>',
                '<g fill="#ddd" font-family="Malgun Gothic, sans-serif" font-size="18">',
                '<text x="24" y="32">누름 발판 · 원본 재질을 면별로 재배치</text>',
                '<text x="70" y="74">기존 대칭 원근</text><text x="368" y="74">지형과 같은 원근</text><text x="680" y="74">눌린 상태</text></g>'])
    seq = 0

    def face(points, source, shade=1.0):
        nonlocal seq
        seq += 1
        sx, sy, sw, sh = source
        x, y = points[0]
        a, b = (points[1][0] - x) / sw, (points[1][1] - y) / sw
        c, d = (points[3][0] - x) / sh, (points[3][1] - y) / sh
        e, f = x - a * sx - c * sy, y - b * sx - d * sy
        poly = ' '.join(f'{px},{py}' for px, py in points)
        filt = '' if shade == 1.0 else f' filter="url(#tone{shade})"'
        svg.extend([f'<defs><clipPath id="clip{seq}"><polygon points="{poly}"/></clipPath></defs>',
                    f'<g clip-path="url(#clip{seq})"{filt}><use xlink:href="#parts" transform="matrix({a},{b},{c},{d},{e},{f})"/></g>'])

    def strip(left, run, back, front, shift, source, cap, shade):
        sx, sy, sw, sh = source
        edge = min(18, run * .24)
        cuts = [0, edge, run - edge, run]
        sources = [(sx, sy, cap, sh), (sx + cap, sy, sw - cap * 2, sh), (sx + sw - cap, sy, cap, sh)]
        for i in range(3):
            a, b = cuts[i:i + 2]
            face([(left + a, back), (left + b, back), (left + b + shift, front), (left + a + shift, front)], sources[i], shade)

    for height, y in [(32, 168), (16, 320)]:
        for col, x in enumerate([175, 480, 785]):
            svg.append(f'<g transform="translate({x},{y}) scale(1.25)">')
            w, s = 192, 18
            l, run = -w / 2, w - s
            back, front = -height - 4, -height + 18
            t = min(14, max(6, height * .4375))
            # 지형 깊이 방향 비교용 도식이다. 실제 돌 셰이더나 카메라 화면으로 표시하지 않는다.
            svg.extend([f'<path d="M-160,{back} H-96 L-78,{front} H-142 Z M78,{back} H140 L158,{front} H96 Z" fill="#424242" stroke="#191919"/>',
                        f'<path d="M-142,{front} H-78 V46 H-142 Z M96,{front} H158 V46 H96 Z" fill="#292929"/>'])
            if col == 0:
                face([(l, -height*.55), (-l, -height*.55), (-l, 0), (l, 0)], (28, 425, 570, 72))
                face([(-w*.455, -height), (w*.455, -height), (w*.455, -height*.45), (-w*.455, -height*.45)], (679, 395, 520, 89))
            else:
                face([(l, back), (l+s, front), (l+s, front+t), (l, back+t)], (36, 432, 26, 54), .48)
                strip(l+s, run, front, front+t, 0, (32, 429, 562, 60), 86, .67)
                svg.append(f'<polygon points="{l},{back} {l+run},{back} {l+run+s},{front} {l+s},{front}" fill="#0f0f0f"/>')
                # 실제 생성기의 8px 스트로크/4px 판 두께와 맞춘다. 브라우저를 실행하지 않고 SVG만 저장한다.
                lift = 0 if col == 2 else 8
                inset = min(3, run*.05)
                if lift:
                    for ratio in [.18, .82]:
                        px = l+inset+s+(run-2*inset)*ratio
                        face([(px-2, front-lift+4), (px+2, front-lift+4), (px+2, front+4), (px-2, front+4)], (694, 442, 18, 30), .42)
                face([(l+inset, back-lift), (l+inset+s, front-lift), (l+inset+s, front-lift+4), (l+inset, back-lift+4)], (694, 445, 22, 26), .52)
                strip(l+inset, run-2*inset, back-lift, front-lift, s, (718, 401, 444, 31), 68, .76)
                strip(l+inset+s, run-2*inset, front-lift, front-lift+4, 0, (694, 442, 492, 30), 60, .58)
                if col == 2:
                    svg.append(f'<rect x="{-w*.12+s*.5}" y="{front+t*.52}" width="{w*.24}" height="2.5" fill="#deded9"/>')
            svg.append('</g>')
        svg.append(f'<text x="24" y="{y+84}" fill="#aaa" font-family="Malgun Gothic, sans-serif" font-size="14">높이 {height}px · 동일한 너비 192px</text>')
    svg.append('<text x="24" y="432" fill="#aaa" font-family="Malgun Gothic, sans-serif" font-size="14">면 배치 비교 미리보기 · 실제 엔진 캡처 아님</text></svg>')
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / 'pressure_platform_press_readability.svg'
    path.write_text('\n'.join(svg), encoding='utf-8')
    print(path)


if __name__ == '__main__':
    build()
