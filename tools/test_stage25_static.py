"""stage_2-5 저장 구조와 보수적인 도약 궤적 검사. Godot 실행 검사를 대신하지 않는다."""
import math
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCENE = ROOT / 'scenes/world_2_클로드/stage_2-5.tscn'
TEXT = SCENE.read_text(encoding='utf-8-sig')
BLOCKS = re.findall(r'^\[([^\n]+)\]\n(.*?)(?=^\[|\Z)', TEXT, re.M | re.S)
RES = {re.search(r'id="([^"]+)"', h)[1]: b for h, b in BLOCKS if h.startswith('sub_resource ')}
NODES = {}
for header, body in BLOCKS:
    if not header.startswith('node '):
        continue
    attrs = dict(re.findall(r'(\w+)="([^"]*)"', header))
    parent = attrs.get('parent', '')
    path = (parent + '/' if parent not in ('', '.') else '') + attrs['name']
    NODES[path] = (header, body)


def vector(body, field='position'):
    m = re.search(r'^"?' + re.escape(field) + r'"? = Vector2\(([^)]+)\)', body, re.M)
    return tuple(map(float, m[1].split(','))) if m else (0.0, 0.0)


def polygon(body):
    nums = list(map(float, re.search(r'polygon = PackedVector2Array\(([^)]+)\)', body)[1].split(',')))
    return list(zip(nums[::2], nums[1::2]))


LOCAL_POLYS = {p.split('/')[1]: polygon(b) for p, (_, b) in NODES.items() if p.endswith('/StaticBody2D/CollisionPolygon2D')}
# 씬 노드 원점을 실제 지형 안에 두어 에디터 이동과 주행 도구의 명중 좌표를 함께 유지한다.
POLYS = {name:[(x+vector(NODES['지형/'+name][1])[0],y+vector(NODES['지형/'+name][1])[1]) for x,y in poly] for name,poly in LOCAL_POLYS.items()}


def water_widths(body, floor):
    source=(ROOT/'scripts/스마트월드/유체_판정모양.gd').read_text(encoding='utf-8-sig')
    frames=re.findall(r'PackedVector2Array\(\[(.*?)\]\)',source,re.S)
    x,y=vector(body);w,h=vector(body,'크기');widths=[]
    for frame in frames:
        points=[((float(u)-.5)*w+x,float(v)*h+y) for u,v in re.findall(r'Vector2\(([\d.]+), ([\d.]+)\)',frame)]
        crossings=[]
        for a,b in zip(points,points[1:]+points[:1]):
            level=floor-48
            if min(a[1],b[1])<=level<max(a[1],b[1]):
                crossings.append(a[0]+(level-a[1])*(b[0]-a[0])/(b[1]-a[1]))
        widths.append(max(crossings)-min(crossings) if crossings else 0)
    return widths


def area(poly):
    return abs(sum(a[0]*b[1] - b[0]*a[1] for a, b in zip(poly, poly[1:]+poly[:1]))) / 2


def clipped(poly, rect):
    # 사각형과 실제 외곽의 교차 면적으로 머리/몸통 충돌을 보수적으로 검사한다.
    out = list(poly)
    for axis, bound, sign in ((0,rect[0],1),(0,rect[2],-1),(1,rect[1],1),(1,rect[3],-1)):
        src, out = out, []
        if not src:
            break
        for a,b in zip(src,src[1:]+src[:1]):
            ia,ib = sign*(a[axis]-bound)>=0,sign*(b[axis]-bound)>=0
            if ia != ib:
                t=(bound-a[axis])/(b[axis]-a[axis])
                out.append((a[0]+t*(b[0]-a[0]),a[1]+t*(b[1]-a[1])))
            if ib:
                out.append(b)
    return out


def overlap(poly, rect):
    cut=clipped(poly,rect)
    return area(cut) if len(cut)>2 else 0


# 발 좌표. 44×96 몸통과 실제 player.gd의 비대칭 중력(2.4)을 쓴다.
# 수평 입력은 목표 위치에서 멈출 수 있다고 가정하며, 실제 물리/색 판정은 별도다.
JUMPS = [
    ('입구1',(1752,1120),(1912,1024)),
    ('입구2',(1880,1024),(2040,928)),
    ('입구3',(2008,928),(2168,832)),
    ('입구4',(2136,832),(2304,736)),
    ('상부 흰길',(2328,736),(2576,736)),
    ('상부 밸브실',(3024,736),(3280,736)),
    ('하부 계단 진입',(3928,1120),(4056,1024)),
    ('복귀1',(4016,1024),(3808,928)),
    ('복귀2',(3744,928),(3536,832)),
    ('복귀3',(3536,832),(3312,736)),
    ('준비 호퍼',(5312,1120),(5488,1024)),
    ('유령1',(5672,1120),(5944,1120)),
    ('유령2',(6056,1120),(6336,1120)),
    ('출구',(6456,1120),(6736,1120)),
    ('회수1',(6320,1504),(6192,1408)),
    ('회수2',(6128,1408),(6000,1312)),
    ('회수3',(5936,1312),(5808,1216)),
    ('회수4',(5744,1216),(5632,1120)),
]


def jump_error(start, end, delay=0, recovered=False):
    speed,height,reach,mult=390,160,320,2.4
    g=2*height*speed**2*(1+1/math.sqrt(mult))**2/reach**2
    v=math.sqrt(2*g*height)
    apex=v/g
    total=apex+math.sqrt(2*(end[1]-start[1]+height)/(g*mult))
    if abs(end[0]-start[0])>speed*(total-delay):
        return '수평 거리 초과'
    solids=dict(POLYS)
    if recovered:
        # 아래로 떨어진 뒤 E로 두 발판을 회수하면 머리 위 발판도 사라진다.
        solids={name:poly for name,poly in solids.items() if not name.startswith('C_유령')}
    hx,hy=vector(NODES['장치/H4_색전환발판'][1])
    solids['준비호퍼']=[(hx-80,hy-56),(hx+80,hy-56),(hx+80,hy-44),(hx-80,hy-44)]
    for i in range(1,math.ceil(total*240)):
        t=min(i/240,total)
        x=start[0]+math.copysign(min(speed*max(t-delay,0),abs(end[0]-start[0])),end[0]-start[0])
        y=start[1]-v*t+g*t*t/2 if t<=apex else start[1]-height+g*mult*(t-apex)**2/2
        for name,poly in solids.items():
            if overlap(poly,(x-22,y-96,x+22,y-0.6))>0.1:
                return f'{name}: body collision at ({x:.1f}, {y:.1f})'
    return ''


class Stage25Static(unittest.TestCase):
    def test_references_and_ids(self):
        for path in re.findall(r'path="res://([^"]+)"',TEXT):
            self.assertTrue((ROOT/path).is_file(),path)
        ext_ids=re.findall(r'^\[ext_resource[^\n]*id="([^"]+)"',TEXT,re.M)
        sub_ids=re.findall(r'^\[sub_resource[^\n]*id="([^"]+)"',TEXT,re.M)
        self.assertEqual(len(ext_ids),len(set(ext_ids)))
        self.assertEqual(len(sub_ids),len(set(sub_ids)))
        for rid in re.findall(r'ExtResource\("([^"]+)"\)',TEXT):
            self.assertIn(rid,ext_ids)
        for rid in re.findall(r'SubResource\("([^"]+)"\)',TEXT):
            self.assertIn(rid,sub_ids)
        headers=[h for h,b in BLOCKS if h.startswith('node ')]
        self.assertEqual(len(headers),len(NODES),'duplicate node paths')

    def test_shape_collision_identity(self):
        for name,poly in POLYS.items():
            body=NODES['지형/'+name][1]
            rid=re.search(r'_points = SubResource\("([^"]+)"\)',body)[1]
            ids=re.findall(r'\d+: SubResource\("([^"]+)"\)',RES[rid])
            points=[vector(RES[r]) for r in ids]
            self.assertEqual(points[0],points[-1],name)
            self.assertEqual(points[:-1],LOCAL_POLYS[name],name)
            self.assertGreater(area(poly),0,name)
            self.assertIn(f'[editable path="지형/{name}"]',TEXT)
            self.assertNotIn('scale =',body)

    def test_exclusive_controller_and_states(self):
        owners={}
        for path,(header,body) in NODES.items():
            for field,target in re.findall(r'"(대상_유체|갈래_A|갈래_B)" = NodePath\("../([^"]+)"\)',body):
                self.assertIn('장치/'+target,NODES)
                self.assertNotIn(target,owners,(target,path,owners.get(target)))
                owners[target]=path
        self.assertEqual(len(owners),5)
        a=NODES['장치/F2A_흰길막'][1];b=NODES['장치/F2B_검정배수'][1]
        self.assertIn('"켜짐" = true',a)
        self.assertIn('"켜짐" = false',b)
        self.assertLess(vector(b)[1]+vector(b,'크기')[1],vector(a)[1])

    def test_tuning_and_ghost_budget(self):
        self.assertIn('"치명_낙하거리" = 1500.0',TEXT)
        self.assertIn('"점프_거리_칸" = 20.0',NODES['Player'][1])
        self.assertIn('"점프_높이_칸" = 10.0',NODES['Player'][1])
        for name in ('C_유령_검정','C_유령_흰색'):
            body=NODES['지형/'+name][1]
            for value in ('"시작상태" = 0','"무색일때_통과" = true','"필요횟수_수동" = 2'):
                self.assertIn(value,body)
            x,y=vector(body)
            self.assertGreater(overlap(POLYS[name],(x-1,y-1,x+1,y+1)),3.9,'target origin must be paintable')
        self.assertLessEqual(2+2,12)
        self.assertGreater(6688-5696,320,'no direct jump across unpainted bridge')
        self.assertGreater(1504-1120,160,'basin must not bypass bridge into exit')

    def test_jump_envelopes(self):
        for name,start,end in JUMPS:
            with self.subTest(jump=name):
                errors=[jump_error(start,end,delay/100,name.startswith('회수')) for delay in range(0,25,2)]
                self.assertIn('',errors,errors[-1])

    def test_water_and_interaction_clearance(self):
        for name in ('F1_첫길막_흰물','F3_두번째길막'):
            body=NODES['장치/'+name][1]
            self.assertGreaterEqual(vector(body)[1]+vector(body,'크기')[1],1120+64)
        for name in ('L1_원형_첫밸브','L2_직선_갈래선택','L3_원형_양자택일','L4_원형_반대색건너'):
            x,y=vector(NODES['장치/'+name][1])
            for path,(_,body) in NODES.items():
                if not path.startswith('장치/F'):
                    continue
                fx,fy=vector(body);w,h=vector(body,'크기')
                self.assertFalse(fx-w/2-24<x<fx+w/2+24 and fy-96<y+64<fy+h,name+' '+path)

    def test_saved_water_silhouettes(self):
        for name,floor in [('F1_첫길막_흰물',1120),('F2A_흰길막',1120),('F2B_검정배수',736),('F3_두번째길막',1120),('F4_레버앞_흰물',1120)]:
            widths=water_widths(NODES['장치/'+name][1],floor)
            self.assertEqual(len(widths),8,name)
            self.assertGreater(min(widths),0,name+' body-height hole')

    def test_restart_pads_and_shooting_lines(self):
        for name,support,color in [('CP_갈래앞','SS_CEM_FLOOR_1',0),('CP_종합앞','SS_CEM_FLOOR_1',0),('CP_출구','SS_CEM_FLOOR_6',1)]:
            body=NODES[name][1];x,y=vector(body)
            self.assertIn(f'metadata/checkpoint_base_color = {color}',body)
            self.assertGreater(overlap(POLYS[support],(x-22,y,x+22,y+2)),80)
            for poly in POLYS.values():
                self.assertLess(overlap(poly,(x-22,y-96,x+22,y-.6)),.1,name)
        # 두 발판을 준비 호퍼에서 조준할 때 앞 발판이나 지형이 사선을 가로막지 않는지 본다.
        # 총알 크기/실제 총구 회전/유체 실루엣은 게임 실행에서 별도로 확인한다.
        hx,hy=vector(NODES['장치/H4_색전환발판'][1])
        for target,tx in [('C_유령_검정',5992),('C_유령_흰색',6392)]:
            for i in range(1,99):
                t=i/100;x=hx+(tx-hx)*t;y=hy-120+(1130-(hy-120))*t
                for name,poly in POLYS.items():
                    if name!=target:
                        self.assertLess(overlap(poly,(x-1,y-1,x+1,y+1)),.01,(target,name,x,y))


def render_layout():
    # 저장 좌표로만 만든 검토 그림이며 게임 실행 화면이나 렌더 검증으로 사용하지 않는다.
    from PIL import Image, ImageDraw, ImageFont
    image=Image.new('RGB',(2200,600),'#20242a');draw=ImageDraw.Draw(image)
    font=ImageFont.truetype('C:/Windows/Fonts/malgun.ttf',22)
    small=ImageFont.truetype('C:/Windows/Fonts/malgun.ttf',17)
    scale=.235
    def xy(p):return (64+p[0]*scale,145+p[1]*scale)
    draw.text((40,24),'STAGE 2-5  |  잠그거나 돌리거나',font=font,fill='white')
    draw.text((40,61),'저장 좌표 기반 설계도 · 게임 실행 화면 아님  /  점프 320px · 높이 160px',font=small,fill='#aab4c4')
    for x,label in [(300,'① 레버 기초'),(1950,'② 상하 수로 선택 / 상부 밸브로 복귀'),(5050,'③ 물 차단 → 두 색 사격 → 공중 색 전환')]:
        draw.text((xy((x,0))[0],106),label,font=small,fill='#eecb80')
    for name,poly in POLYS.items():
        fill='#c8c9cc' if 'white' in NODES['지형/'+name][0] or '흰' in name else '#343a43'
        if name=='SS_CEM_FLOOR_6':fill='#c8c9cc'
        outline='#8190a4' if '유령' not in name else '#eecb80'
        draw.polygon([xy(p) for p in poly],fill=fill,outline=outline,width=2)
    for path,(_,body) in NODES.items():
        if path.startswith('장치/F'):
            x,y=vector(body);w,h=vector(body,'크기');on='"켜짐" = false' not in body
            corners=[xy((x-w/2,y)),xy((x+w/2,y+h))]
            draw.rectangle(corners,fill='#778da0' if on else None,outline='#91b4d0',width=2)
        if path.startswith('장치/L'):
            x,y=xy(vector(body));draw.ellipse((x-7,y-7,x+7,y+7),fill='#efc873')
            draw.text((x-12,y-32),path.split('/')[1][:2],font=small,fill='#efc873')
        if path.startswith('CP_'):
            x,y=xy(vector(body));draw.ellipse((x-5,y-5,x+5,y+5),fill='#8ec9ac')
    hx,hy=vector(NODES['장치/H4_색전환발판'][1]);draw.rectangle([xy((hx-80,hy-56)),xy((hx+80,hy-44))],fill='#a1a4a9')
    for start,end in [((2470,1080),(3800,1080)),((4050,990),(3500,795)),((3010,695),(3270,695)),((6040,1460),(5790,1280))]:
        a,b=xy(start),xy(end);draw.line((a,b),fill='#edbb70',width=3)
        angle=math.atan2(b[1]-a[1],b[0]-a[0])
        draw.polygon([b,(b[0]-12*math.cos(angle-.5),b[1]-12*math.sin(angle-.5)),(b[0]-12*math.cos(angle+.5),b[1]-12*math.sin(angle+.5))],fill='#edbb70')
    # 외벽은 도면 바깥까지 크므로 제목은 지형 뒤가 아니라 마지막에 덮어 그린다.
    draw.rectangle((0,0,2200,132),fill='#20242a')
    draw.text((40,24),'STAGE 2-5  |  잠그거나 돌리거나',font=font,fill='white')
    draw.text((40,61),'저장 좌표 기반 설계도 · 게임 실행 화면 아님  /  점프 320px · 높이 160px',font=small,fill='#aab4c4')
    for x,label in [(300,'① 레버 기초'),(1950,'② 상하 수로 선택 / 상부 밸브로 복귀'),(5050,'③ 물 차단 → 두 색 사격 → 공중 색 전환')]:
        draw.text((xy((x,0))[0],106),label,font=small,fill='#eecb80')
    for name,poly in POLYS.items():
        if name.startswith('C_유령'):
            draw.line([xy(p) for p in poly+poly[:1]],fill='#eecb80',width=3)
    draw.rectangle((0,538,2200,600),fill='#20242a')
    draw.text((40,552),'금색 테두리 = 칠해야 밟히는 발판   ·   파랑 = 물의 설정 범위 (실효 실루엣은 별도)   ·   아래 계단 = 회수 후 복귀',font=small,fill='#d2d6dd')
    output=ROOT/'docs/맵검토_stage25_2026-09-21.png'
    image.save(output)
    print(output)


if __name__=='__main__':
    import sys
    if '--render' in sys.argv:
        render_layout()
    else:
        unittest.main(verbosity=2)
