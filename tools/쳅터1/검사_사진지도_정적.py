"""Godot을 실행하지 않고 사진 지도·씬 연결·체크 배치의 계약을 검사한다."""
from pathlib import Path
import ast
import json
import re
import hashlib
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[2]
BLOCK=re.compile(r'\[(node|sub_resource) ([^\n]+)\]\n(.*?)(?=\n\[|\Z)',re.S)
FAIL=[]
RESULT=[]

def check(label,ok,detail=''):
    RESULT.append({'검사':label,'통과':bool(ok),'상세':detail})
    print(('PASS ' if ok else 'FAIL ')+label+(' · '+detail if detail else ''))
    if not ok:FAIL.append(label)

def scene(path):
    text=path.read_text(encoding='utf-8-sig')
    nodes={}
    for kind,head,body in BLOCK.findall(text):
        if kind!='node':continue
        name=re.search(r'name="([^"]+)"',head)[1]
        parent=re.search(r'parent="([^"]+)"',head)
        key=('.' if not parent else (name if parent[1]=='.' else parent[1]+'/'+name))
        assert key not in nodes,(path,key)
        nodes[key]=body
    return text,nodes

def main():
    board=json.loads((ROOT/'scenes/lobby/퍼즐보드_쳅터1.json').read_text(encoding='utf-8'))
    cards={c['id']:c for c in board['조각']}
    designs={i:json.loads((ROOT/'scenes/쳅터1/도안'/f'{c["씬"]}.json').read_text(encoding='utf-8-sig')) for i,c in cards.items()}
    stages={i:scene(ROOT/'scenes/쳅터1/스테이지'/f'{c["씬"]}.tscn') for i,c in cards.items()}
    check('19개 도안·지도 JSON 읽기',len(cards)==19 and len(designs)==19)
    check('씬 노드 이름 중복 없음',len(stages)==19)
    check('앞 스테이지 ID 유효',all(a in cards for c in cards.values() for a in c.get('앞',[])))
    # 모든 선을 따라가도 순환이 없어야 잠김 상태가 서로를 기다리는 일이 생기지 않는다.
    reached=set()
    for _ in range(20):
        reached.update(i for i,c in cards.items() if not c.get('앞') or any(a in reached for a in c['앞']))
    check('시작방에서 모든 가지 도달',len(reached)==19)
    main_ids=['01','02','04','06','08','09','10','11','12','13','14','15']
    check('주경로 집→굴뚝→하수도',all(a in cards[b]['앞'] for a,b in zip(main_ids,main_ids[1:])))
    bad_refs=[]
    bad_links=[]
    for i,(text,nodes) in stages.items():
        for p in re.findall(r'path="(res://[^"]+)"',text):
            if not (ROOT/p.removeprefix('res://')).exists():bad_refs.append(p)
        ext=set(re.findall(r'\[ext_resource[^\n]* id="([^"]+)"',text))
        sub=set(re.findall(r'\[sub_resource[^\n]* id="([^"]+)"',text))
        for kind,ids in [('ExtResource',ext),('SubResource',sub)]:
            for ref in re.findall(kind+r'\("([^"]+)"\)',text):
                if ref not in ids:bad_refs.append(i+':'+ref)
        for name,body in nodes.items():
            if not name.startswith('연결/'):continue
            path=re.search(r'"다음_씬" = "([^"]+)"',body)
            entry=re.search(r'"다음_연결" = "([^"]*)"',body)
            if path is None:continue
            target=ROOT/path[1].removeprefix('res://')
            if not target.exists():bad_links.append(i+':'+name);continue
            if entry and entry[1]:
                _,dest=scene(target)
                if not any(n==entry[1] or n.endswith('/'+entry[1]) for n in dest):bad_links.append(i+':'+name+'→'+entry[1])
    check('리소스 경로·ID 전부 존재',not bad_refs,repr(bad_refs))
    check('씬 목적지·도착 노드 전부 존재',not bad_links,repr(bad_links))
    # 도안의 문과 실제 씬이 같은 방향을 가리키는지 확인한다. 별도로 만든 가지가 UI에만 존재하면 안 된다.
    mismatch=[]
    for i,d in designs.items():
        nodes=stages[i][1]
        for c in d['연결']+d.get('옆방문',[]):
            body=nodes['연결/'+c['이름']]
            dest,entry=c['연결']
            dest=dest if dest.startswith('res://') else 'res://scenes/쳅터1/스테이지/'+dest+'.tscn'
            if f'"다음_씬" = "{dest}"' not in body or f'"다음_연결" = "{entry}"' not in body:mismatch.append(i+':'+c['이름'])
    check('도안·실제 씬 연결 일치',not mismatch,repr(mismatch))
    checkpoints=[]
    for i,d in designs.items():
        actual=[]
        for n,b in stages[i][1].items():
            if n.startswith('체크포인트/체크'):
                xy=re.search(r'position = Vector2\(([-\d.]+), ([-\d.]+)\)',b)
                actual.append([round((float(xy[1])-16)/32),round(float(xy[2])/32)])
        assert actual==d['체크'],i
        checkpoints.append(len(actual))
    check('체크포인트 도안·씬 일치 및 1~3개',sum(checkpoints)==34 and all(1<=n<=3 for n in checkpoints),'전체 34개')
    geometry=json.loads((ROOT/'docs/visual_review/로비_사진지도_20261009/지형_정적확인.json').read_text(encoding='utf-8'))
    doors=[d for s in geometry for d in s['문']]
    check('10개 옆방 출입문 바닥·몸 공간',len(doors)==10 and all(d['바닥'] and not d['몸_막힘'] for d in doors),'저장한 실제 다각형 좌표 검사 결과')
    # 공개된 클리어 함수를 검사해 자동 지도 복귀가 되살아나지 않게 한다.
    text=(ROOT/'scripts/진행/게임진행.gd').read_text(encoding='utf-8')
    tail=text.split('static func 통로_가로채기(',1)[1]
    flow=(ROOT/'scripts/쳅터1/전경전환.gd').read_text(encoding='utf-8')
    check('클리어 후 자동 지도 복귀 없음','return 지도_씬' not in tail and '경로 = 게임진행.보드_씬' not in flow)
    for p in [ROOT/'tools/쳅터1/사진지도_정비.py',ROOT/'tools/쳅터1/만들기.py']:
        ast.parse(p.read_text(encoding='utf-8'))
    check('수정한 Python 문법',True)
    paths=list((ROOT/'scenes/쳅터1/도안').glob('*.json'))+list((ROOT/'scenes/쳅터1/스테이지').glob('*.tscn'))+[ROOT/'scenes/lobby/퍼즐보드_쳅터1.json',ROOT/'docs/visual_review/로비_사진지도_20261009/배치_결과.json']
    hashes={p:hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
    subprocess.run([sys.executable,str(ROOT/'tools/쳅터1/사진지도_정비.py')],cwd=ROOT,check=True,stdout=subprocess.DEVNULL)
    check('씬 정비 멱등성',all(hashlib.sha256(p.read_bytes()).hexdigest()==v for p,v in hashes.items()))
    report={'범위':'Godot 미실행. 파일·문법·연결만 정적 확인. 런타임·렌더링 성공을 뜻하지 않는다.','검사':RESULT,'실패':FAIL}
    (ROOT/'docs/visual_review/로비_사진지도_20261009/정적_검사.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    sys.exit(bool(FAIL))

if __name__=='__main__':main()
