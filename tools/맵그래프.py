"""하수도 스테이지 관계 그래프 — 씬(.tscn)과 주행검사 공략표를 읽어 graphify-out/맵그래프.html · 맵그래프.json 을 만든다.

[2026-09-17 Claude] graphify 는 .md/.py/.mjs 만 읽어서 씬 안의 게임플레이 관계(무슨 물이 어느 바닥을 덮고 누굴 죽이나,
호퍼가 어느 물을 켜나, 정답/헛걸음이 어디를 밟나)를 모른다. 이 도구가 그 관계를 씬에서 직접 뽑는다.

노드: 지형(검/흰/유령/선반) · 유체 · 웅덩이 · 호퍼 · 통과플랫폼(격자) · 물저장고 · 레버 · 가시 · 회전톱 · 체크포인트 · 출구/입구 · 경로
선: 호퍼→물(켠다) · 공급 물→호퍼 · 저장고→물(칠하면 켠다) · 물→덮인 지형(플레이어 색별 생존/사망) · 레버→물 · 유령→칠할 색
    · 경로→밟는 지형/칠하는 대상/조작(단계 번호) · 출구→다음 스테이지
좌표는 실제 월드 좌표라 HTML 에서는 **맵 모양 그대로** 놓인다(스테이지마다 한 판씩).

실행: python tools/맵그래프.py   (Godot 없이 텍스트만 읽는다)
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCENES = ['stage_2-1', 'stage_2-2', 'stage_2-3', 'stage_2-4']
OUT_DIR = ROOT / 'graphify-out'
ROUTE_FILE = ROOT / 'tools/하수도_주행검사.gd'

색이름 = {0: '검정', 1: '흰색', 2: '회색'}          # 유체·웅덩이 enum
지형색 = {0: '무색', 1: '검정', 2: '흰색', 3: '회색'}  # 지형 시작상태 enum


def vec(s):
    return [float(v) for v in s.split(',')]


def parse_props(block):
    props = {}
    for line in block.splitlines()[1:]:
        m = re.match(r'^"?([^"=]+?)"? = (.*)$', line)
        if m:
            props[m[1]] = m[2]
    return props


def parse_scene(path):
    text = path.read_text(encoding='utf-8')
    ext = {m[2]: m[1] for m in re.finditer(r'\[ext_resource [^\]]*path="([^"]+)"[^\]]*id="([^"]+)"', text)}
    blocks = re.split(r'(?=^\[(?:sub_resource|node|editable) )', text, flags=re.M)
    subs = {}
    nodes = []
    for b in blocks:
        head = b.splitlines()[0]
        if head.startswith('[sub_resource'):
            subs[re.search(r'id="([^"]+)"', head)[1]] = b
        elif head.startswith('[node'):
            name = re.search(r'name="([^"]+)"', head)[1]
            parent = (re.search(r'parent="([^"]+)"', head) or [None, None])[1]
            inst = re.search(r'instance=ExtResource\("([^"]+)"\)', head)
            typ = (re.search(r'type="([^"]+)"', head) or [None, None])[1]
            nodes.append({'name': name, 'parent': parent, 'inst': ext.get(inst[1]) if inst else None,
                          'type': typ, 'props': parse_props(b), 'block': b})
    return ext, subs, nodes


def points_of(props, subs):
    m = re.search(r'_points = SubResource\("([^"]+)"\)', props.get('_points', '') and 'x_points = ' + props['_points'])
    if not m:
        return None
    arr = subs.get(m[1])
    if not arr:
        return None
    pts = []
    for rid in re.findall(r'\d+: SubResource\("([^"]+)"\)', arr):
        p = re.search(r'position = Vector2\(([^)]+)\)', subs[rid])
        if p:
            pts.append(vec(p[1]))
    return pts


def bbox(pts, pos):
    xs = [p[0] + pos[0] for p in pts]
    ys = [p[1] + pos[1] for p in pts]
    return [min(xs), min(ys), max(xs), max(ys)]


def stage_graph(key):
    path = ROOT / f'scenes/world_2_클로드/{key}.tscn'
    ext, subs, nodes = parse_scene(path)
    G = {'id': key, 'title': key, 'frame': None, 'nodes': [], 'edges': [], 'routes': []}
    by_name = {}
    for n in nodes:
        p = n['props']
        pos = vec(re.search(r'\(([^)]+)\)', p['position'])[1]) if 'position' in p else [0.0, 0.0]
        inst = n['inst'] or ''
        item = None
        if n['parent'] is None:
            G['title'] = p.get('스테이지_이름', key).strip('"')
            G['frame'] = vec(re.search(r'\(([^)]+)\)', p['카메라_리밋'])[1])
            G['start'] = vec(re.search(r'\(([^)]+)\)', p['시작_위치'])[1])
            continue
        if n['parent'] == '지형' and ('지형' in inst or 'WALL' in inst):
            pts = points_of(p, subs)
            if not pts:
                continue
            bb = bbox(pts, pos)
            상태 = int(p.get('시작상태', '1' if ('검정' in inst or 'SOLID.tscn' in inst) else '2'))
            유령 = p.get('무색일때_통과') == 'true'
            선반 = '공중선반' in inst or p.get('metadata/terrain_style') == '"공중"'
            color = '유령' if 유령 else 지형색.get(상태, '검정')
            if '내부_바탕흰색' in p:  # 내부 무늬 지형: 시작상태 0 이지만 바탕은 실제 흑백
                color = '흰색' if p['내부_바탕흰색'] == 'true' else '검정'
            role = p.get('metadata/role', '"플랫폼"').strip('"')
            item = {'id': n['name'], 'kind': '지형', 'color': color, 'ledge': 선반, 'role': role,
                    'poly': [[q[0] + pos[0], q[1] + pos[1]] for q in pts], 'bbox': bb, 'x': (bb[0] + bb[2]) / 2, 'y': bb[1],
                    'detail': f"{'유령 발판(칠해야 밟힘)' if 유령 else color} · {'공중선반' if 선반 else '기본지형'} · {role} · {bb[2]-bb[0]:.0f}×{bb[3]-bb[1]:.0f}"
                             + (' · 내부 무늬' if 'color_inlays' in n['block'] else '')
                             + (' · 일방통행' if 'one_way_collision = true' in n['block'] else '')}
            if 유령:
                item['필요횟수'] = int(p.get('필요횟수_수동', '1'))
        elif '유체.tscn' in inst:
            size = vec(re.search(r'\(([^)]+)\)', p.get('크기', 'Vector2(64, 260)'))[1])
            # ⚠ 유체.tscn 기본 색은 회색(2)이고 편집상태 pack 은 기본값과 같은 값을 안 적는다 → 없으면 회색
            c = 색이름[int(p.get('색', '2'))]
            item = {'id': n['name'], 'kind': '유체', 'color': c, 'x': pos[0], 'y': pos[1],
                    'w': size[0], 'h': size[1], 'on': p.get('켜짐', 'true') != 'false',
                    'detail': f"물 {c} · 폭 {size[0]:.0f} · 길이 {size[1]:.0f} · {'켜짐' if p.get('켜짐', 'true') != 'false' else '꺼짐(호퍼·레버가 켠다)'}"}
        elif '웅덩이.tscn' in inst:
            size = vec(re.search(r'\(([^)]+)\)', p['크기'])[1])
            item = {'id': n['name'], 'kind': '웅덩이', 'color': 색이름[int(p.get('색', '2'))], 'x': pos[0], 'y': pos[1] - size[1],
                    'w': size[0], 'h': size[1], 'detail': f"웅덩이 {색이름[int(p.get('색', '2'))]} · {size[0]:.0f}×{size[1]:.0f}" + (' · 페인트 지움' if p.get('페인트_지움') == 'true' else '')}
        elif '호퍼.tscn' in inst:
            폭 = float(p.get('폭', '120')); 높이 = float(p.get('높이', '56'))
            item = {'id': n['name'], 'kind': '호퍼', 'x': pos[0], 'y': pos[1] - 높이, 'w': 폭, 'h': 높이,
                    'out': p.get('출구_유체', '').replace('NodePath("../', '').rstrip('")'),
                    'detail': f"호퍼(밟을 수 있음 · 색 규칙 밖) · 폭 {폭:.0f} · 밟는면 y {pos[1]-높이:.0f}"}
        elif '통과플랫폼.tscn' in inst:
            size = vec(re.search(r'\(([^)]+)\)', p['크기'])[1])
            item = {'id': n['name'], 'kind': '격자', 'x': pos[0], 'y': pos[1] - size[1] / 2, 'w': size[0], 'h': size[1],
                    'detail': f"통과플랫폼(물이 통과 · 페인트 안 지워짐 · 안 칠하면 검정) · {size[0]:.0f}×{size[1]:.0f} · 필요횟수 {p.get('필요횟수', '1')}"}
        elif '물저장고.tscn' in inst:
            # [2026-09-17] 2-4 「색이 흐른다」 — 칠하면 `공급_유체` 를 그 색으로 켠다(무색이면 끔 · E 로 되돌림). 밟을 수 있고 안 칠하면 검정.
            size = vec(re.search(r'\(([^)]+)\)', p.get('크기', 'Vector2(192, 96)'))[1])
            item = {'id': n['name'], 'kind': '저장고', 'x': pos[0], 'y': pos[1] - size[1] / 2, 'w': size[0], 'h': size[1],
                    'supply': p.get('공급_유체', '').replace('NodePath("../', '').rstrip('")'),
                    'detail': f"물저장고(칠할 수 있음 · 밟을 수 있음 · 안 칠하면 검정) · 필요횟수 {p.get('필요횟수', '1')} · 칠한 색으로 공급 물을 켠다"}
        elif '제어레버.tscn' in inst:
            item = {'id': n['name'], 'kind': '레버', 'x': pos[0], 'y': pos[1],
                    'targets': [v.replace('NodePath("../', '').rstrip('")') for k, v in p.items() if k in ('대상_유체', '갈래_A', '갈래_B')],
                    'detail': '레버 ' + ('원형(물 켜고 끔)' if p.get('종류', '0') == '0' else '직선(갈래 A/B)')}
        elif '가시.tscn' in inst:
            item = {'id': n['name'], 'kind': '가시', 'x': pos[0], 'y': pos[1], 'w': 32 * int(p.get('칸수', '3')), 'detail': f"가시 {p.get('칸수', '3')}칸 · 색 무관 즉사"}
        elif '회전톱.tscn' in inst:
            item = {'id': n['name'], 'kind': '회전톱', 'x': pos[0], 'y': pos[1],
                    'detail': f"회전톱 r{p.get('반지름', '26')} · 왕복 {p.get('이동거리', '0')}px / {p.get('왕복시간', '3')}s · 색 무관 즉사"}
        elif '체크포인트.tscn' in inst:
            item = {'id': n['name'], 'kind': '체크포인트', 'x': pos[0], 'y': pos[1], 'detail': '체크포인트'}
        elif '연결통로.tscn' in inst:
            nxt = p.get('다음_씬', '').strip('"').split('/')[-1].replace('.tscn', '')
            item = {'id': n['name'], 'kind': '통로', 'x': pos[0], 'y': pos[1], 'next': nxt,
                    'detail': ('출구 → ' + nxt) if nxt else '입구'}
        elif 'Player.tscn' in inst:
            item = {'id': 'Player', 'kind': '플레이어', 'x': pos[0], 'y': pos[1], 'detail': f"시작 · 점프 {p.get('점프_거리_칸', '10')}칸"}
        if item:
            item['stage'] = key
            G['nodes'].append(item)
            by_name[item['id']] = item

    def edge(a, b, rel, **kw):
        G['edges'].append({'from': a, 'to': b, 'rel': rel, **kw})

    지형들 = [n for n in G['nodes'] if n['kind'] == '지형']

    def 윗면들(t, x0, x1):
        # 폴리곤의 수평 변 중 [x0,x1] 과 겹치는 것의 y (턱·구덩이가 있는 폴리곤은 bbox 윗변이 바닥이 아니다)
        ys = []
        poly = t['poly']
        for i in range(len(poly)):
            a, b = poly[i], poly[(i + 1) % len(poly)]
            if abs(a[1] - b[1]) < 0.5 and min(a[0], b[0]) < x1 and max(a[0], b[0]) > x0:
                ys.append(a[1])
        return ys

    def 바닥찾기(x0, x1, y, tol=40):
        for t in 지형들:
            if any(abs(yy - y) <= tol for yy in 윗면들(t, x0, x1)):
                return t
        return None

    # 호퍼 출구 물의 색 = 공급 물의 혼합(검+흰=회 · 검+회=검 · 흰+회=흰). 씬에 적힌 초기색보다 이것이 실제다.
    for n in G['nodes']:
        if n['kind'] != '호퍼' or not n.get('out') or n['out'] not in by_name:
            continue
        ins = {f['color'] for f in G['nodes'] if f['kind'] == '유체' and f['on'] and abs(f['x'] - n['x']) < n['w'] * 0.6 and n['y'] - 84 <= f['y'] + f['h'] <= n['y'] + 30}
        if ins:
            mix = '회색' if ('검정' in ins and '흰색' in ins) else ('검정' if '검정' in ins else ('흰색' if '흰색' in ins else '회색'))
            out = by_name[n['out']]
            out['color'] = mix
            out['detail'] = out['detail'].replace('물 ' + out['detail'].split(' ')[1], '물 ' + mix, 1) + ' · 호퍼 혼합 ' + '+'.join(sorted(ins))

    for n in G['nodes']:
        if n['kind'] == '호퍼':
            if n.get('out') and n['out'] in by_name:
                edge(n['id'], n['out'], '켠다(색을 물려줌)')
            # 공급: 아랫끝이 입구 감지(밟는면 −84~+6)에 닿는 물. 꺼진 물(저장고가 켤 물)은 "칠하면 공급" 으로 따로 잇는다.
            for f in G['nodes']:
                if f['kind'] == '유체' and abs(f['x'] - n['x']) < n['w'] * 0.6 and n['y'] - 84 <= f['y'] + f['h'] <= n['y'] + 30:
                    edge(f['id'], n['id'], '공급' if f['on'] else '공급(저장고를 칠하면)')
        if n['kind'] == '저장고' and n.get('supply') and n['supply'] in by_name:
            edge(n['id'], n['supply'], '칠하면 켠다(내 색)')
        if n['kind'] == '레버':
            for t in n['targets']:
                if t in by_name:
                    edge(n['id'], t, '잠금/전환')
        if n['kind'] == '유체':
            bottom = n['y'] + n['h']
            splash = n['w'] * 0.38
            hit = set()
            for t in 지형들:
                if any(abs(yy - bottom) <= 40 for yy in 윗면들(t, n['x'] - splash, n['x'] + splash)):
                    hit.add(t['id'])
            for tid in hit:
                t = by_name[tid]
                c = n['color']
                if c == '회색':
                    verdict = '누구나 안전'
                else:
                    verdict = f"{c} 몸만 통과 · {'흰색' if c == '검정' else '검정'} 몸 사망"
                    if t['color'] not in ('회색', '유령') and t['color'] != c:
                        verdict += f" · 바닥은 {t['color']} → 둘 다 막힘(색 전환 없이는)"
                edge(n['id'], tid, '덮음: ' + verdict, hazard=(c != '회색'))
            for g in G['nodes']:
                if g['kind'] == '격자' and abs(g['x'] - n['x']) < n['w'] * 0.6 and n['y'] <= g['y'] <= bottom:
                    edge(n['id'], g['id'], '통과(페인트 안 지움)')
            for g in G['nodes']:
                if g['kind'] == '지형' and g['color'] == '유령' and abs(g['x'] - n['x']) < n['w'] * 0.5 and abs(g['y'] - bottom) <= 40:
                    pass  # 덮음 선에 이미 들어 있다
        if n['kind'] == '가시':
            b = 바닥찾기(n['x'] - n['w'] / 2, n['x'] + n['w'] / 2, n['y'] + 10, 30)
            if b:
                edge(n['id'], b['id'], '죽는 구멍 바닥')
        if n['kind'] == '통로' and n.get('next'):
            edge(n['id'], n['next'], '다음 스테이지', cross=True)
    return G, by_name


def parse_routes():
    text = ROUTE_FILE.read_text(encoding='utf-8')
    routes = {}
    for m in re.finditer(r'^\t"(stage_2-\d[^"]*)": \[\n(.*?)^\t\],', text, flags=re.M | re.S):
        steps = []
        for line in m[2].splitlines():
            line = line.split('#')[0].strip().rstrip(',')
            if not line.startswith('['):
                continue
            body = line[1:line.rindex(']')]
            parts = [x.strip().strip('"') for x in body.split(',')]
            steps.append(parts)
        routes[m[1]] = steps
    return routes


def attach_routes(G, by_name, routes):
    지형들 = [n for n in G['nodes'] if n['kind'] in ('지형', '호퍼', '격자')]

    def 서있는곳(x, y):
        for t in 지형들:
            if t['kind'] == '지형':
                poly = t['poly']
                for i in range(len(poly)):
                    a, b = poly[i], poly[(i + 1) % len(poly)]
                    if abs(a[1] - b[1]) < 0.5 and abs(a[1] - y) <= 12 and min(a[0], b[0]) - 24 <= x <= max(a[0], b[0]) + 24:
                        return t['id']
            else:
                if abs(t['x'] - x) <= t['w'] / 2 + 24 and abs(t['y'] - y) <= 12:
                    return t['id']
        return None

    for key, steps in routes.items():
        if not key.startswith(G['id']):
            continue
        label = key.replace(G['id'], '').strip() or '정답'
        rid = f"{G['id']} 경로:{label}"
        rnode = {'id': rid, 'kind': '경로', 'stage': G['id'], 'x': -600, 'y': 300 + 400 * len(G['routes']),
                 'steps': [' '.join(s) for s in steps], 'detail': f"{label} 경로 · {len(steps)} 단계"}
        G['nodes'].append(rnode)
        G['routes'].append(rid)
        color = '검정'
        seen = set()
        shots = 0
        for i, s in enumerate(steps, 1):
            cmd = s[0]
            tgt = None; rel = None
            if cmd in ('칠',):
                tgt, rel = s[1], f"#{i} 칠({s[2]})"; shots += 1
            elif cmd in ('레버', '확인', '밀기'):
                tgt, rel = s[1], f"#{i} {cmd}"
            elif cmd in ('뛰기', '뛰기색', '걸어'):
                x = float(s[2]) if cmd != '걸어' else float(s[1])
                y = float(s[3]) if cmd != '걸어' else float(s[2])
                tgt = 서있는곳(x, y)
                if cmd == '뛰기색':
                    color = s[4]; rel = f"#{i} 공중 전환→{color} · 착지"
                else:
                    rel = f"#{i} {'뛰어 ' if cmd == '뛰기' else '떨어져 '}착지"
            elif cmd == '색':
                color = s[1]; rel = f"#{i} 색 전환→{color}"; tgt = None
            if tgt and tgt in by_name:
                k = (tgt, rel.split(' ', 1)[1])
                if k not in seen:
                    seen.add(k)
                    G['edges'].append({'from': rid, 'to': tgt, 'rel': rel, 'route': True, 'color': color})
        rnode['detail'] += f" · 발사 {shots}"


HTML = r'''<!DOCTYPE html>
<html lang="ko"><head><meta charset="utf-8"><title>하수도 맵 그래프</title>
<style>
:root{--bg:#1b1d22;--panel:#25282f;--fg:#e8e8e8;--dim:#9aa0a8;--acc:#ffb347}
body{margin:0;background:var(--bg);color:var(--fg);font:13px/1.4 "Malgun Gothic",system-ui,sans-serif;display:flex;height:100vh;overflow:hidden}
#side{width:300px;background:var(--panel);padding:12px;overflow:auto;border-right:1px solid #333;flex:none}
#side h1{font-size:15px;margin:0 0 8px}#side h2{font-size:13px;color:var(--acc);margin:12px 0 4px}
label{display:block;margin:2px 0;color:var(--dim)}label input{margin-right:6px}
#info{white-space:pre-wrap;background:#1b1d22;padding:8px;border-radius:6px;min-height:80px;font-size:12px}
#legend span{display:inline-block;margin:2px 6px 2px 0}.sw{display:inline-block;width:12px;height:12px;border:1px solid #666;vertical-align:middle;margin-right:3px}
canvas{flex:1;cursor:grab}#hint{color:var(--dim);font-size:11px}
</style></head><body>
<div id="side"><h1>하수도 맵 그래프 — 2-1 · 2-2 · 2-3</h1>
<div id="hint">드래그 = 이동 · 휠 = 확대 · 노드 클릭 = 정보 · 경로 클릭 = 단계 목록. 좌표는 실제 월드 좌표(스테이지는 위→아래로 2-1 · 2-2 · 2-3).</div>
<h2>보기</h2><div id="filters"></div>
<h2>범례</h2><div id="legend">
<span><i class="sw" style="background:#111"></i>검정 지형</span><span><i class="sw" style="background:#eee"></i>흰 지형</span><span><i class="sw" style="background:#5a4a8a"></i>유령(칠해야)</span>
<span><i class="sw" style="background:#3b82f6"></i>물</span><span><i class="sw" style="background:#ffb347"></i>호퍼</span><span><i class="sw" style="background:#4ade80"></i>격자</span><span><i class="sw" style="background:#fb923c"></i>저장고</span>
<span><i class="sw" style="background:#ef4444"></i>가시·톱</span><span><i class="sw" style="background:#facc15"></i>체크포인트</span><span><i class="sw" style="background:#c084fc"></i>경로</span><span><i class="sw" style="background:#f472b6"></i>레버</span><span><i class="sw" style="background:#38bdf8"></i>통로</span></div>
<h2>선</h2><div id="legend2"><span style="color:#ffb347">━ 호퍼→물(켠다) · 공급</span><br><span style="color:#ef4444">━ 물이 덮음(사망 가능)</span> <span style="color:#9ca3af">━ 회색 물(안전)</span><br><span style="color:#f472b6">┄ 레버</span> <span style="color:#c084fc">┄ 경로가 밟음/칠함</span> <span style="color:#38bdf8">━ 다음 스테이지</span></div>
<h2>정보</h2><div id="info">노드를 클릭하세요.</div>
<h2>이 노드의 관계</h2><div id="rels" style="font-size:12px;color:var(--dim)"></div>
</div>
<canvas id="c"></canvas>
<script>
const DATA = __DATA__;
const kinds = ['지형','유체','웅덩이','호퍼','격자','저장고','레버','가시','회전톱','체크포인트','통로','플레이어','경로'];
const show = Object.fromEntries(kinds.map(k=>[k,true])); show['경로']=true;
const rel = {hazard:true, route:true, flow:true};
const fd = document.getElementById('filters');
kinds.forEach(k=>{const l=document.createElement('label');l.innerHTML=`<input type=checkbox checked data-k="${k}">${k}`;fd.appendChild(l);});
['hazard:물이 덮음 선','flow:호퍼·레버 선','route:경로 선'].forEach(s=>{const [k,t]=s.split(':');const l=document.createElement('label');l.innerHTML=`<input type=checkbox checked data-r="${k}">${t}`;fd.appendChild(l);});
fd.addEventListener('change',e=>{if(e.target.dataset.k)show[e.target.dataset.k]=e.target.checked;if(e.target.dataset.r)rel[e.target.dataset.r]=e.target.checked;draw();});
// 스테이지를 세로로 쌓는다
let oy=0; const stageY={}; DATA.stages.forEach(s=>{stageY[s.id]=oy; oy+=s.frame[3]+800;});
const nodes=[]; const byId={};
DATA.stages.forEach(s=>s.nodes.forEach(n=>{const m={...n, X:n.x, Y:n.y+stageY[n.stage]}; nodes.push(m); byId[n.stage+'/'+n.id]=m; if(n.kind==='경로'){m.X=-700;}}));
const edges=[]; DATA.stages.forEach(s=>s.edges.forEach(e=>{const a=byId[s.id+'/'+e.from]; let b=byId[s.id+'/'+e.to]; if(e.cross){const t=DATA.stages.find(x=>x.id===e.to); if(t){b=byId[t.id+'/Player']||{X:t.start[0],Y:t.start[1]+stageY[t.id],kind:'플레이어'};}} if(a&&b)edges.push({...e,a,b});}));
const cv=document.getElementById('c'),ctx=cv.getContext('2d'); let scale=0.11, tx=120, ty=40, drag=null, sel=null;
function resize(){cv.width=cv.clientWidth;cv.height=cv.clientHeight; if(!resize.done){resize.done=true; scale=Math.min((cv.width-40)/13000,(cv.height-40)/oy); tx=100*scale+20; ty=300*scale+20;} draw();} window.addEventListener('resize',resize);
const KC={'검정':'#111','흰색':'#eee','회색':'#888','유령':'#5a4a8a','무색':'#5a4a8a'};
function nodeColor(n){if(n.kind==='지형')return KC[n.color]||'#333'; if(n.kind==='유체'||n.kind==='웅덩이')return {'검정':'#1e3a8a','흰색':'#93c5fd','회색':'#64748b'}[n.color]||'#3b82f6'; return {'호퍼':'#ffb347','격자':'#4ade80','저장고':'#fb923c','레버':'#f472b6','가시':'#ef4444','회전톱':'#ef4444','체크포인트':'#facc15','통로':'#38bdf8','플레이어':'#fff','경로':'#c084fc'}[n.kind]||'#999';}
function rect(n){ // 화면 사각형 (월드 px)
  if(n.kind==='지형')return [n.bbox[0],n.bbox[1]+stageY[n.stage],n.bbox[2]-n.bbox[0],n.bbox[3]-n.bbox[1]];
  if(n.kind==='유체'||n.kind==='웅덩이')return [n.x-n.w/2,n.Y,n.w,n.h];
  if(n.kind==='호퍼'||n.kind==='격자'||n.kind==='저장고')return [n.x-n.w/2,n.Y,n.w,n.h];
  if(n.kind==='가시')return [n.x-n.w/2,n.Y-10,n.w,20];
  const r=n.kind==='경로'?260:90; return [n.X-r/2,n.Y-r/2,r,r];
}
function center(n){const r=rect(n);return [r[0]+r[2]/2,r[1]+r[3]/2];}
function draw(){
  ctx.setTransform(1,0,0,1,0,0);ctx.fillStyle='#1b1d22';ctx.fillRect(0,0,cv.width,cv.height);
  ctx.setTransform(scale,0,0,scale,tx,ty);
  DATA.stages.forEach(s=>{ctx.strokeStyle='#444';ctx.lineWidth=6;ctx.strokeRect(s.frame[0],s.frame[1]+stageY[s.id],s.frame[2],s.frame[3]);ctx.fillStyle='#777';ctx.font='bold 220px sans-serif';ctx.fillText(s.title,s.frame[0],s.frame[1]+stageY[s.id]-120);});
  for(const n of nodes){ if(!show[n.kind])continue; const r=rect(n); ctx.fillStyle=nodeColor(n); ctx.globalAlpha=(n.kind==='유체'||n.kind==='웅덩이')?0.55:1;
    if(n.kind==='체크포인트'||n.kind==='회전톱'||n.kind==='레버'||n.kind==='플레이어'||n.kind==='통로'||n.kind==='경로'){ctx.beginPath();ctx.arc(r[0]+r[2]/2,r[1]+r[3]/2,r[2]/2,0,7);ctx.fill();}
    else ctx.fillRect(r[0],r[1],r[2],r[3]);
    ctx.globalAlpha=1; if(n===sel){ctx.strokeStyle='#ffb347';ctx.lineWidth=18;ctx.strokeRect(r[0]-9,r[1]-9,r[2]+18,r[3]+18);}
    if(n.kind==='경로'){ctx.fillStyle='#fff';ctx.font='bold 90px sans-serif';ctx.textAlign='center';ctx.fillText(n.id.split('경로:')[1],r[0]+r[2]/2,r[1]+r[3]/2+30);ctx.textAlign='left';}
  }
  for(const e of edges){ if(!show[e.a.kind]||!show[e.b.kind])continue; const isRoute=e.route, isHaz=e.rel.startsWith('덮음'), isFlow=!isRoute&&!isHaz&&!e.cross;
    if(isRoute&&!rel.route)continue; if(isHaz&&!rel.hazard)continue; if(isFlow&&!rel.flow)continue;
    if(isRoute&&!(sel&&(e.a===sel||e.b===sel))) continue; // 경로 선은 그 경로(또는 밟는 노드)를 클릭했을 때만
    const [x1,y1]=center(e.a),[x2,y2]=center(e.b); ctx.beginPath();ctx.moveTo(x1,y1);ctx.lineTo(x2,y2);
    ctx.lineWidth=isRoute?10:14; ctx.setLineDash(isRoute||e.rel.includes('잠금')?[40,30]:[]);
    ctx.strokeStyle=e.cross?'#38bdf8':isRoute?'#c084fc':isHaz?(e.hazard?'#ef4444':'#9ca3af'):e.rel.includes('잠금')?'#f472b6':'#ffb347'; ctx.globalAlpha=sel&&e.a!==sel&&e.b!==sel?0.25:0.9; ctx.stroke(); ctx.globalAlpha=1; ctx.setLineDash([]);
    if(sel&&(e.a===sel||e.b===sel)){ctx.fillStyle='#fff';ctx.font='70px sans-serif';ctx.fillText(e.rel,(x1+x2)/2,(y1+y2)/2);}
  }
}
function pick(px,py){const wx=(px-tx)/scale,wy=(py-ty)/scale; let best=null,bd=1e18; for(const n of nodes){if(!show[n.kind])continue;const r=rect(n); if(wx>=r[0]-20&&wx<=r[0]+r[2]+20&&wy>=r[1]-20&&wy<=r[1]+r[3]+20){const d=r[2]*r[3]; if(d<bd){bd=d;best=n;}}} return best;}
cv.addEventListener('mousedown',e=>{drag={x:e.clientX,y:e.clientY,tx,ty,moved:false};});
window.addEventListener('mousemove',e=>{if(!drag)return; tx=drag.tx+(e.clientX-drag.x); ty=drag.ty+(e.clientY-drag.y); if(Math.abs(e.clientX-drag.x)+Math.abs(e.clientY-drag.y)>3)drag.moved=true; draw();});
window.addEventListener('mouseup',e=>{if(drag&&!drag.moved){const n=pick(e.clientX-cv.getBoundingClientRect().left,e.clientY-cv.getBoundingClientRect().top); sel=n; info(n);draw();} drag=null;});
cv.addEventListener('wheel',e=>{e.preventDefault();const f=e.deltaY<0?1.15:1/1.15;const mx=e.offsetX,my=e.offsetY; tx=mx-(mx-tx)*f; ty=my-(my-ty)*f; scale*=f; draw();},{passive:false});
function info(n){const box=document.getElementById('info'),rl=document.getElementById('rels'); if(!n){box.textContent='노드를 클릭하세요.';rl.textContent='';return;}
  box.textContent=`[${n.stage}] ${n.id}\n${n.kind} · ${n.detail}`+(n.steps?`\n\n단계:\n`+n.steps.map((s,i)=>`${i+1}. ${s}`).join('\n'):'');
  const lines=edges.filter(e=>e.a===n||e.b===n).map(e=>e.a===n?`→ ${e.b.id}: ${e.rel}`:`← ${e.a.id}: ${e.rel}`); rl.innerHTML=lines.map(l=>`<div>${l}</div>`).join('')||'(없음)';}
resize();
</script></body></html>
'''


def main():
    routes = parse_routes()
    stages = []
    for key in SCENES:
        G, by_name = stage_graph(key)
        attach_routes(G, by_name, routes)
        stages.append(G)
    data = {'stages': stages}
    OUT_DIR.mkdir(exist_ok=True)
    (OUT_DIR / '맵그래프.json').write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding='utf-8')
    (OUT_DIR / '맵그래프.html').write_text(HTML.replace('__DATA__', json.dumps(data, ensure_ascii=False)), encoding='utf-8')
    for s in stages:
        kinds = {}
        for n in s['nodes']:
            kinds[n['kind']] = kinds.get(n['kind'], 0) + 1
        print(s['id'], s['title'], '노드', len(s['nodes']), '선', len(s['edges']), kinds)
    print('→', OUT_DIR / '맵그래프.html')


if __name__ == '__main__':
    main()
