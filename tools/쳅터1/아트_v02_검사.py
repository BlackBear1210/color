"""엔진을 실행하지 않는 도안·씬·시각 설정 검사. 실행 검증을 대신하지 않는다."""
import argparse
import hashlib
import json
import re
from pathlib import Path
import 도안
import 검사
import 씬검사
from 아트_v02_적용 import blocks, world_points

ROOT=Path(__file__).resolve().parents[2]
OUT=Path(__file__).resolve().parent/'아트_v02_검토'

def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--blueprints',action='store_true')
    args=parser.parse_args()
    files=sorted((ROOT/'scenes/쳅터1/도안').glob('*.json'))
    before={str(p):digest(p) for p in files}
    designs=[도안.도안(str(p)) for p in files]
    if args.blueprints:
        # 경로 저장을 끄므로 다른 작업자의 재생 시험 입력을 덮어쓰지 않는다.
        results=[검사.검사(d,True,경로_저장=False) for d in designs]
        errors=[f for r in results for f in r['실패']]+검사.연결_높이_검사(designs)
        report={'stages':len(designs),'failures':errors,'engine_run':False,
                'inputs_unchanged':all(p.exists() and digest(p)==before[str(p)] for p in files)}
        (OUT/'도안검사.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
        print(report)
        return int(bool(errors) or not report['inputs_unchanged'])
    errors=[]
    scenes=[]
    terrain=0
    links={}
    for dn in designs:
        p=ROOT/'scenes/쳅터1/스테이지'/f'{dn.이름}.tscn'
        if not p.exists():
            errors.append(f'{dn.이름}: 씬 생성 대기')
            continue
        errs,_,_,_=씬검사.검사_파일(str(p)); errors+=errs
        text=p.read_text(encoding='utf-8')
        count=0
        for m in blocks(text,'node'):
            node=m.group()
            if 'parent="연결"' in node.splitlines()[0]:
                name=re.search(r'name="([^"]+)"',node).group(1)
                target=re.search(r'"다음_씬" = "([^"]*)"',node)
                door=re.search(r'"다음_연결" = "([^"]*)"',node)
                if target and door: links[(dn.이름,name)]=(Path(target.group(1)).stem,door.group(1))
            if 'parent="지형"' in node.splitlines()[0] and '_points = SubResource' in node:
                _,pts=world_points(text,node)
                assert len(pts)>=3
                count+=1
        terrain+=count
        # 새 생성기에서도 어둠 배수와 레이어 시차가 씬에 저장되는지 확인한다.
        if '"배경_명도"' not in text: errors.append(f'{dn.이름}: 배경 명도 설정 누락')
        if '"레이어_움직임" = true' not in text: errors.append(f'{dn.이름}: 레이어 움직임 누락')
        if 'Color(0.72, 0.74, 0.7, 1)' in text: errors.append(f'{dn.이름}: 기존 유색 조명')
        scenes.append({'name':dn.이름,'terrain':count,'sha256':digest(p)})
    for key,target in links.items():
        if target[0] and target not in links: errors.append(f'연결 대상 없음: {key} → {target}')
        elif target[0] and links[target]!=key: errors.append(f'왕복 연결 불일치: {key} → {target}')
    report={'stages':len(scenes),'terrain':terrain,'failures':errors,'engine_run':False,'scenes':scenes}
    (OUT/'씬검사.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(report,ensure_ascii=False,indent=2))
    return int(bool(errors))

if __name__=='__main__': raise SystemExit(main())
