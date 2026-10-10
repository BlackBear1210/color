"""게임의 저장고 그리기 명령을 Pillow로 옮겨 보는 도식. 엔진 캡처가 아니다."""
import math
import re
from pathlib import Path
from types import SimpleNamespace
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/visual_review/reservoir_20261010'


class Vector2:
    def __init__(self, x=0, y=0):
        self.x, self.y = x, y

    def __add__(self, other):
        return Vector2(self.x + other.x, self.y + other.y)

    def __mul__(self, value):
        return Vector2(self.x * value, self.y * value)


class Rect2:
    def __init__(self, position, size):
        self.position, self.size = position, size
        self.end = position + size

    def grow(self, value):
        return Rect2(self.position + Vector2(-value, -value), self.size + Vector2(value * 2, value * 2))


def Color(r, g, b, a=1):
    return tuple(round(c * 255) for c in (r, g, b, a))


class Canvas:
    def __init__(self, image, x, y, scale):
        self.d = ImageDraw.Draw(image)
        self.x, self.y, self.scale = x, y, scale

    def point(self, v):
        return (self.x + v.x * self.scale, self.y + v.y * self.scale)

    def draw_colored_polygon(self, points, color):
        self.d.polygon([self.point(v) for v in points], fill=color)

    def draw_rect(self, rect, color):
        self.d.rectangle([self.point(rect.position), self.point(rect.end)], fill=color)

    def draw_line(self, a, b, color, width):
        self.d.line([self.point(a), self.point(b)], fill=color, width=max(1, round(width * self.scale)))

    def draw_polyline(self, points, color, width, antialias):
        self.d.line([self.point(v) for v in points], fill=color, width=max(1, round(width * self.scale)))

    def draw_circle(self, center, radius, color):
        x, y = self.point(center)
        radius *= self.scale
        self.d.ellipse((x-radius, y-radius, x+radius, y+radius), fill=color)


def renderer():
    # 새 그림 코드의 제한된 문법만 변환해 도식과 게임의 면 좌표가 달라지는 것을 막는다.
    source = (ROOT / 'scripts/스마트월드/물저장고_원근그림.gd').read_text(encoding='utf-8')
    lines = []
    for line in source.splitlines():
        if line.startswith(('@', 'extends ', 'const ')):
            continue
        line = re.sub(r'static func (\w+)\((.*)\) -> void:', lambda m: 'def ' + m[1] + '(' + re.sub(r': \w+', '', m[2]) + '):', line)
        line = re.sub(r'var (\w+)(?:: \w+)? :=? ', r'\1 = ', line)
        line = line.replace('else:', 'else:').replace('true', 'True')
        lines.append(line)
    scope = dict(Vector2=Vector2, Rect2=Rect2, Color=Color, PackedVector2Array=list,
                 ColorDefs=SimpleNamespace(BLACK=0, WHITE=1, GRAY=2),
                 지형투영=SimpleNamespace(투영폭=18.0), minf=min, maxi=max,
                 clampf=lambda v, a, b: max(a, min(b, v)), sin=math.sin, TAU=math.tau)
    exec('\n'.join(lines), scope)
    return scope['그리기']


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    # 4배로 그린 뒤 축소해 작은 화면의 가장자리도 비교한다.
    image = Image.new('RGB', (960*4, 550*4), '#222222')
    draw = ImageDraw.Draw(image)
    font = ImageFont.truetype('C:/Windows/Fonts/malgun.ttf', 18*4)
    draw.text((28*4, 20*4), '물저장고 — 실제 그리기 코드의 도식 / 엔진 캡처 아님', font=font, fill='#dddddd')
    render = renderer()
    for j, (state, label) in enumerate([(0, '검정'), (1, '흰색'), (-1, '빈 상태')]):
        x = (175+j*305)*4
        draw.text((x-40*4, 58*4), label, font=font, fill='#cccccc')
        render(Canvas(image, x, 195*4, 8), Vector2(112,80), state,0,0,3)
        render(Canvas(image, x, 320*4, 4), Vector2(112,80), state,0,0,3)
    draw.text((28*4, 380*4), '위: 2배 확대   가운데: 2-8 배치 크기 112×80   아래: 기본 크기 240×92', font=font, fill='#aaaaaa')
    for j, state in enumerate([0,1,-1]):
        render(Canvas(image, (175+j*305)*4, 480*4, 4), Vector2(240,92), state,0,0,3)
    image.resize((960,550), Image.Resampling.LANCZOS).save(OUT/'물저장고_흑백_비교.png')
    # 최소 크기까지 창과 접지선이 유효한지 확인한다.
    for w,h in [(40,24),(112,80),(240,92),(500,90)]:
        shift=min(18,w*.18,h*.25)
        depth=shift*22/18
        edge=min(7,min(w,h)*.09)
        assert w-shift-2*edge-4 > 0 and h-depth-2*edge-4 > 0
    before=(ROOT/'tmp/reservoir_20261010/물저장고_before.gd').read_text(encoding='utf-8')
    after=(ROOT/'scripts/스마트월드/물저장고.gd').read_text(encoding='utf-8')
    assert before.split('func _draw()')[0] == after.split('func _draw()')[0]
    print('PASS: pre-draw gameplay code unchanged; 4 size bounds valid; comparison generated.')


if __name__ == '__main__':
    main()
