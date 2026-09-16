"""엔진 없는 검증: 실제 씬 공유 경계의 노출 구간 계산과 비용 구조를 확인한다."""
from pathlib import Path
import sys
from apply_stage22_masonry_joint import parse,inside

ROOT=Path(__file__).resolve().parents[1]

def cross(a,b):return a[0]*b[1]-a[1]*b[0]
def sub(a,b):return a[0]-b[0],a[1]-b[1]
def exposed(a,b,others):
    d=sub(b,a);length=(d[0]**2+d[1]**2)**.5
    start=(a[0]+d[1]/length*.5,a[1]-d[0]/length*.5)
    cuts=[0.,1.]
    for poly in others:
        for c,e in zip(poly,poly[1:]):
            v=sub(e,c);den=cross(d,v)
            if abs(den)<1e-9:continue
            t=cross(sub(c,start),v)/den;u=cross(sub(c,start),d)/den
            if 0<=t<=1 and 0<=u<=1:cuts.append(t)
    cuts=sorted(set(cuts));spans=[]
    for lo,hi in zip(cuts,cuts[1:]):
        if hi-lo<.00001:continue
        point=(start[0]+d[0]*(lo+hi)/2,start[1]+d[1]*(lo+hi)/2)
        if not any(inside(point,p) for p in others):spans.append((lo,hi))
    return start,d,spans

def main():
    shader=(ROOT/'shaders/sewer_natural_platform.gdshader').read_text(encoding='utf-8')
    terrain=(ROOT/'scripts/스마트월드/하수도_자연발판.gd').read_text(encoding='utf-8')
    helper=(ROOT/'scripts/스마트월드/하수도_마감메시.gd').read_text(encoding='utf-8')
    light=(ROOT/'scripts/스마트월드/하수도_벽돌지형.gd').read_text(encoding='utf-8')
    assert shader.count('ground_face_distances(ground_visual_pos)')==1
    assert 'uniform int cached_draw_mode = 1;' in shader
    assert 'ground_platform && cached_draw_mode != 1 && ground_edge_count > 0' in shader
    assert '_접합_대기' not in terrain and '0.5' not in terrain
    assert 'points_modified.connect' in terrain and '마감_배치변경.emit()' in terrain
    assert '_셰이더들.erase(part.material)' in terrain and '_셰이더들.append(part.material)' in terrain
    assert 'ground_cover_count", 0' in helper and 'ground_edge_count", 1' in helper
    assert 'owner =' not in helper and 'CollisionPolygon2D' not in helper
    assert '1.0 / 30.0' in light and 'light.distance_to(to_global(closest))' in light
    # 시각용 배열만 변환하고 물감 좌표/충돌은 변경하지 않는 연결을 검사한다.
    assert 'terrain._get_uv_points(vertices' in helper
    assert 'part.position =' not in terrain and 'part.scale =' not in terrain
    sample_count=0;hidden_count=0;visible_count=0
    for file in ['stage_2-1.tscn','stage_2-2.tscn']:
        nodes=parse((ROOT/'scenes/world_2_클로드'/file).read_text(encoding='utf-8'))
        for name,(_,_,poly) in nodes.items():
            others=[p for n,(_,_,p) in nodes.items() if n!=name]
            for a,b in zip(poly,poly[1:]):
                if a==b:continue
                start,d,spans=exposed(a,b,others)
                for j in range(1,20):
                    t=j/20
                    if any(abs(t-q)<1e-6 for span in spans for q in span):continue
                    point=start[0]+d[0]*t,start[1]+d[1]*t
                    expected=not any(inside(point,p) for p in others)
                    actual=any(lo<t<hi for lo,hi in spans)
                    assert expected==actual,(file,name,point)
                    visible_count+=actual;hidden_count+=not actual;sample_count+=1
    print('Exposure interval samples:',sample_count,'PASS; hidden',hidden_count,'visible',visible_count)
    print('Static cache/paint registration/UV/light structure: PASS (NOT engine or FPS verification)')

if __name__=='__main__':main()
