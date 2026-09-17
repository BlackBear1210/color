"""저장된 씬의 참조/콜리전/영역 분할/내부 무늬 여유 검사. 엔진 실행 검사를 대체하지 않는다."""
import re
import create_sewer_color_modules as modules
import apply_stage22_masonry_joint as kit

samples = 0
for path in sorted(modules.DEST.glob('*.tscn')):
    text = path.read_text(encoding='utf-8')
    declarations = re.findall(r'\[(?:ext_resource|sub_resource)[^\]]*id="([^"]+)"',text)
    assert len(declarations)==len(set(declarations))
    assert all(re.fullmatch(r'[A-Za-z0-9_]+',v) for v in declarations)
    assert set(re.findall(r'(?:ExtResource|SubResource)\("([^"]+)"\)',text))<=set(declarations)
    for resource in re.findall(r'path="res://([^"]+)"',text):
        assert (modules.ROOT/resource).exists(),resource
    polys=[]
    for raw in re.findall(r'polygon = PackedVector2Array\(([^)]+)\)',text):
        values=[float(v) for v in raw.split(',')]
        poly=list(zip(values[::2],values[1::2]));poly.append(poly[0]);polys.append(poly)
    if len(polys)==3:
        samples+=modules.validate(polys)
    else:
        assert len(polys)==1
        for raw in re.findall(r'Rect2\(([^)]+)\)',text):
            x,y,w,h=map(float,raw.split(','))
            assert min(x,y,340-x-w,288-y-h)>=24
        assert '"시작상태" = 0' in text
        white='흰색속' in path.stem
        assert f'"내부_바탕흰색" = {str(white).lower()}' in text
    print(path.stem,'PASS')
shader=(modules.ROOT/'shaders/sewer_natural_platform.gdshader').read_text(encoding='utf-8')
assert shader.index('i < inlay_count') < shader.index('i < MAX_SEEDS',shader.index('void fragment'))
assert not re.search('[가-힣]',shader)
print('Saved partition samples:',samples,'PASS; interior margins/references PASS')
