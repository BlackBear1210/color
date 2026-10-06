"""목재 점만 부분 교체한다. 기믹·배경·카메라·연결 및 수동 편집 지형은 보존한다."""
import importlib.util
import json
import re
import difflib
import copy
from pathlib import Path
import 도안, 만들기, 모양
from 아트_v02_적용 import blocks, world_points, same

ROOT=Path(__file__).resolve().parents[2]
OUT=Path(__file__).parent/'목재_v03_검토'
spec=importlib.util.spec_from_file_location('old_shape',OUT/'이전/tools/쳅터1/모양.py')
previous=importlib.util.module_from_spec(spec)
spec.loader.exec_module(previous)

def main():
    reports=[]
    for path in sorted((ROOT/'scenes/쳅터1/도안').glob('*.json')):
        dn=도안.도안(str(path))
        scene=ROOT/'scenes/쳅터1/스테이지'/f'{dn.이름}.tscn'
        old=scene.read_text(encoding='utf-8')
        candidate=만들기.씬_글(dn)
        forms=[{name:pts for _,name,pts,_ in f} for f in (dn.다각형들(),previous.다각형들(dn),모양.다각형들(dn))]
        plain=copy.deepcopy(dn)
        plain.d['목재_맞물림']=False
        plain._격자_만들기()
        forms.append({name:pts for _,name,pts,_ in 모양.다각형들(plain)})
        interim=OUT/'맞물림_이전점.json'
        if interim.exists():
            forms.append(json.loads(interim.read_text(encoding='utf-8')).get(dn.이름,{}))
        nodes={re.search(r'name="([^"]+)"',m.group()).group(1):m.group() for m in blocks(candidate,'node')}
        accepted=[]; skipped=[]; replacements=[]; before=after=0
        for m in blocks(old,'node'):
            node=m.group()
            if 'parent="지형"' not in node.splitlines()[0] or '_points = SubResource' not in node: continue
            name=re.search(r'name="([^"]+)"',node).group(1)
            pa,pts=world_points(old,node)
            # 기존 점을 몇 개 삭제한 단순화도 이번 경량화 대상이다. 이동/추가 편집은 보존한다.
            old_points=forms[1].get(name,[])
            operations=difflib.SequenceMatcher(a=old_points,b=pts,autojunk=False).get_opcodes()
            removed_only=0 < len(old_points)-len(pts) <= 4 and all(op in ('equal','delete') for op,*_ in operations)
            if not removed_only and not any(name in f and same(pts,f[name]) for f in forms):
                skipped.append(name); continue
            accepted.append(pa); before+=len(pts); after+=len(forms[2][name])
            position=re.search(r'^position = .*$',nodes[name],re.M).group()
            replacements.append((m.start(),m.end(),re.sub(r'^position = .*$',position,node,flags=re.M)))
        for a,b,value in reversed(replacements): old=old[:a]+value+old[b:]
        def selected(m):
            rid=re.search(r'id="([^"]+)"',m.group()).group(1)
            return any(rid==pa or rid.startswith('P_'+pa[3:]+'_') for pa in accepted)
        for m in reversed(blocks(old,'sub_resource')):
            if selected(m): old=old[:m.start()]+old[m.end():]
        new_sub=''.join(m.group() for m in blocks(candidate,'sub_resource') if selected(m))
        at=old.index('[node '); old=old[:at]+new_sub+old[at:]
        count=len(re.findall(r'^\[(?:ext_resource|sub_resource) ',old,re.M))+1
        old=re.sub(r'load_steps=\d+',f'load_steps={count}',old,count=1)
        # 생성기 전체 덮어쓰기 대신 부분 적용 사실을 기록하여 수동 변경을 보호한다.
        old=re.sub(r'^; 생성:.*\n','; 목재 v03: 지형 점 부분 갱신 / 나머지 노드 보존\n',old,count=1)
        old=re.sub(r'\n{3,}','\n\n',old)
        scene.write_text(old,encoding='utf-8')
        reports.append(dict(stage=dn.이름,terrain=len(accepted),before=before,after=after,skipped=skipped))
    (OUT/'지형적용.json').write_text(json.dumps(reports,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(reports,ensure_ascii=False))

if __name__=='__main__': main()
