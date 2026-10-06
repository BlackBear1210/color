"""씬 전체를 재생성하지 않고 기존 방들의 지형 점·배경·가구만 교체한다.

원본 도안 또는 기존 모양.py 결과와 일치하는 지형만 다듬는다.
편집기에서 달라진 지형은 별도로 보고하고 덮어쓰지 않는다. 기믹·카메라·연결은 보존한다.
Godot를 실행하지 않는다. 최초 백업을 보관하고 같은 입력은 같은 결과를 만든다.
"""
import json
import re
import shutil
from pathlib import Path
import 도안
import 만들기
import 모양

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent/'아트_v02_검토'
THEMES = ['방_판자', '복도_줄무늬', '방_서재', '방_다마스크', '방_꽃무늬',
          '방_판자', '방_판자', '방_다마스크', '방_다마스크', '굴뚝_벽돌']
BRIGHTNESS = [.64, .62, .66, .61, .63, .60, .60, .63, .64, .65]

def theme_index(name):
    # 다른 작업자가 스테이지 번호를 옮겨도 방의 용도를 기준으로 같은 아트를 유지한다.
    suffixes=['방_시작방','복도_A','방_서재','복도_B','방_침실','복도_C','방_수납실','계단_중앙','거실','굴뚝']
    return next((i for i,s in enumerate(suffixes) if name.endswith(s)), None)

def blocks(text, kind):
    return list(re.finditer(r'^\['+kind+r' [^\n]+\]\n.*?(?=^\[|\Z)', text, re.M|re.S))

def backup(path):
    dst = OUT/'이전'/path.relative_to(ROOT)
    if not dst.exists():
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, dst)

def world_points(text, node):
    pa = re.search(r'_points = SubResource\("([^"]+)"\)', node).group(1)
    body = next(m.group() for m in blocks(text, 'sub_resource') if f'id="{pa}"' in m.group().splitlines()[0])
    ids = re.findall(r'\d+: SubResource\("([^"]+)"\)', body)
    pos = re.search(r'position = Vector2\(([^,]+), ([^)]+)\)', node)
    cx, cy = map(float, pos.groups())
    pts = []
    for pid in ids:
        p = re.search(r'id="'+re.escape(pid)+r'"\]\n.*?position = Vector2\(([^,]+), ([^)]+)\)', text, re.S)
        x,y = map(float, p.groups())
        pts.append((round(x+cx,2), round(y+cy,2)))
    return pa, pts[:-1]

def same(a,b):
    return len(a)==len(b) and all(abs(x-u)<.03 and abs(y-v)<.03 for (x,y),(u,v) in zip(a,b))

def main():
    OUT.mkdir(exist_ok=True)
    (OUT/'.gdignore').write_text('', encoding='utf-8')
    reports = []
    for path in sorted((ROOT/'scenes/쳅터1/도안').glob('*.json')):
        index=theme_index(path.stem)
        if index is None:
            # 새 방은 도안 작성자가 정한 프리셋을 따르며 공통 목재·어둠·시차를 상속한다.
            continue
        scene = ROOT/'scenes/쳅터1/스테이지'/f'{path.stem}.tscn'
        if not scene.exists():
            print(f'씬 작성 대기: {path.stem}')
            continue
        backup(path)
        d = json.loads(path.read_text(encoding='utf-8'))
        d['배경'].update(프리셋=THEMES[index], 명도=BRIGHTNESS[index])
        # 복도 세 곳이 동일한 가구 복사본이 되지 않도록 각자 용도를 부여한다.
        if index == 3:
            d['가구'] = [['문_닫힘',32,31], ['액자_팔각',48,9], ['거울',74,31],
                         ['벽등',91,12], ['소파',113,31], ['액자',140,8],
                         ['괘종시계',160,31], ['창문',180,7], ['샹들리에',110,5]]
        if index == 5:
            d['가구'] = [['문_열림',32,31], ['벽등',49,10], ['선반',72,31],
                         ['상자더미',91,31], ['액자',112,7], ['벽등',130,11],
                         ['사다리',152,31], ['상자더미',176,31], ['샹들리에',110,5]]
        # 들여쓰기 이외의 편집을 최소화하고, 반복 실행 때 파일 변화가 없게 한다.
        path.write_text(json.dumps(d, ensure_ascii=False, indent=1)+'\n', encoding='utf-8')
        dn = 도안.도안(str(path))
        scene = ROOT/'scenes/쳅터1/스테이지'/f'{dn.이름}.tscn'
        backup(scene)
        old = scene.read_text(encoding='utf-8')
        candidate = 만들기.씬_글(dn)
        raw = {name:pts for _,name,pts,_ in dn.다각형들()}
        shaped = {name:pts for _,name,pts,_ in 모양.다각형들(dn)}
        candidates = {re.search(r'name="([^"]+)"',m.group()).group(1):m.group() for m in blocks(candidate,'node')}
        accepted, skipped = [], []
        replacements = []
        for m in blocks(old,'node'):
            node = m.group()
            if 'parent="지형"' not in node.splitlines()[0] or '_points = SubResource' not in node:
                continue
            name = re.search(r'name="([^"]+)"',node).group(1)
            pa, pts = world_points(old,node)
            if name not in raw or not (same(pts,raw[name]) or same(pts,shaped[name])):
                skipped.append(name)
                continue
            accepted.append(pa)
            position = re.search(r'^position = .*$',candidates[name],re.M).group()
            replacements.append((m.start(),m.end(),re.sub(r'^position = .*$',position,node,flags=re.M)))
        for a,b,value in reversed(replacements):
            old=old[:a]+value+old[b:]
        # 점 배열과 그 점 리소스만 새 것으로 바꾸고 기존 노드 속성은 그대로 둔다.
        def selected(m):
            rid = re.search(r'id="([^"]+)"',m.group()).group(1)
            return any(rid==pa or rid.startswith('P_'+pa[3:]+'_') for pa in accepted)
        for m in reversed(blocks(old,'sub_resource')):
            if selected(m): old=old[:m.start()]+old[m.end():]
        new_sub=''.join(m.group() for m in blocks(candidate,'sub_resource') if selected(m))
        at=old.index('[node ')
        old=old[:at]+new_sub+old[at:]
        # 가구 리소스는 전용 ID를 써서 기존 기믹이 참조하는 ext ID를 절대 바꾸지 않는다.
        furniture=[]
        for m in blocks(candidate,'node'):
            if 'parent="배경/가구"' in m.group().splitlines()[0]: furniture.append(m.group())
        refs=set(re.findall(r'ExtResource\("([^"]+)"\)', ''.join(furniture)))
        new_ext=[]
        for ref in sorted(refs):
            line=next(line for line in candidate.splitlines() if line.startswith('[ext_resource') and f'id="{ref}"' in line)
            new_id='art_v02_'+ref
            new_ext.append(line.replace(f'id="{ref}"',f'id="{new_id}"'))
            furniture=[n.replace(f'ExtResource("{ref}")',f'ExtResource("{new_id}")') for n in furniture]
        old=re.sub(r'^\[ext_resource [^\n]*id="art_v02_[^\n]*\]\n', '', old, flags=re.M)
        for m in reversed(blocks(old,'node')):
            if 'parent="배경/가구"' in m.group().splitlines()[0]: old=old[:m.start()]+old[m.end():]
        marker=next(m.end() for m in blocks(old,'node') if 'name="가구"' in m.group().splitlines()[0] and 'parent="배경"' in m.group().splitlines()[0])
        old=old[:marker]+''.join(furniture)+old[marker:]
        at=old.index('[sub_resource ')
        old=old[:at]+'\n'.join(new_ext)+'\n'+old[at:]
        old=re.sub(r'프리셋/[^"/]+\.tres',f'프리셋/{THEMES[index]}.tres',old)
        old=old.replace('color = Color(0.72, 0.74, 0.7, 1)','color = Color(0.74, 0.74, 0.74, 1)')
        old=re.sub(r'^"(?:배경_명도|레이어_움직임)" = .*\n','',old,flags=re.M)
        old=re.sub(r'(^"씨앗" = [^\n]+\n)',r'\1'+f'"배경_명도" = {BRIGHTNESS[index]}\n"레이어_움직임" = true\n',old,flags=re.M)
        # 새 점·가구 참조 수만 반영한다. 카메라·기믹·색 판정 노드는 원문을 유지한다.
        count=len(re.findall(r'^\[(?:ext_resource|sub_resource) ',old,re.M))+1
        old=re.sub(r'load_steps=\d+',f'load_steps={count}',old,count=1)
        old=re.sub(r'^; 생성:.*\n','; 아트 v02 부분 갱신: 지형 점·배경·가구 / 기믹·카메라·연결 속성 보존\n',old,count=1)
        # 리소스 블록을 재배치하며 남는 빈 줄도 정규화하여 재실행 결과가 바이트까지 같다.
        old=re.sub(r'\n{3,}', '\n\n', old)
        scene.write_text(old,encoding='utf-8')
        reports.append(dict(stage=dn.이름,terrain=len(accepted),preserved_manual_terrain=skipped,
                            theme=THEMES[index],brightness=BRIGHTNESS[index],furniture=len(furniture)))
    (OUT/'적용결과.json').write_text(json.dumps(reports,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(reports,ensure_ascii=False,indent=2))

if __name__=='__main__': main()
