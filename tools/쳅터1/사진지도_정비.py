"""기존 씬을 재생성하지 않고 연결·체크 노드만 수정한다. 다시 실행해도 같은 결과다."""
from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parents[2]
DESIGN = ROOT / 'scenes/쳅터1/도안'
SCENES = ROOT / 'scenes/쳅터1/스테이지'
BOARD = ROOT / 'scenes/lobby/퍼즐보드_쳅터1.json'
# 긴 상승/하강 퍼즐과 몹 안전지점은 남긴다. 입구 자동 부활과 출구 직전 중복은 제거한다.
KEEP = {1:[1,3,4],2:[3],3:[3,4,6],4:[3],5:[2,3,5],6:[3],7:[2,4],8:[3],9:[2,3],10:[3],11:[2,4],12:[3],13:[3],14:[2,3],15:[2,4],16:[3,5],17:[2,3],18:[3,4],19:[2,3,4]}
MAIN = ['01','02','04','06','08','09','10','11','12','13','14','15']
# 기존 벽 연결을 주 경로로 쓴다. 옆방은 화면 안의 안전한 구조 발판에 별도 출입문을 놓는다.
FORKS = [('02','서재문',180,19,'03','왼쪽위'),('04','침실문',180,19,'05','왼쪽아래'),('06','수납실문',12,31,'07','오른쪽아래'),('11','응접실문',212,65,'17','왼쪽'),('13','거미방문',180,31,'19','왼쪽')]
MERGES = [('04','서재길',8,31,'16','오른쪽'),('06','침실길',183,19,'05','왼쪽위'),('08','수납실길',8,19,'07','오른쪽위'),('12','응접실길',8,31,'17','오른쪽'),('14','거미방길',6,169,'19','오른쪽')]
NODE = re.compile(r'\[node [^\n]+\]\n.*?(?=\n\[node |\Z)', re.S)

def save_json(path, data):
    path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

def main():
    board=json.loads(BOARD.read_text(encoding='utf-8-sig'))
    cards={c['id']:c for c in board['조각']}
    designs={i: DESIGN/(c['씬']+'.json') for i,c in cards.items()}
    data={i:json.loads(p.read_text(encoding='utf-8-sig')) for i,p in designs.items()}
    original_total=0
    final_total=0
    checkpoint_report=[]
    report_path=ROOT/'docs/visual_review/로비_사진지도_20261009/배치_결과.json'
    previous=json.loads(report_path.read_text(encoding='utf-8')) if report_path.exists() else {}
    # 실제 씬의 좌표를 기준으로 남길 체크포인트를 선택한다. 번호 재정렬은 하지 않아 다른 연결을 보존한다.
    scene_text={i:(SCENES/(c['씬']+'.tscn')).read_text(encoding='utf-8-sig') for i,c in cards.items()}
    for i,d in data.items():
        kept=[]
        removed=[]
        def check(m):
            block=m.group(0)
            hit=re.search(r'\[node name="체크(\d+)"[^\n]*parent="체크포인트"',block)
            if not hit:
                return block
            pos=re.search(r'position = Vector2\(([-\d.]+), ([-\d.]+)\)',block)
            coords=(round((float(pos[1])-16)/32),round(float(pos[2])/32)) if pos else None
            # 도안을 나중에 다시 생성하면 체크 이름이 재번호된다. 이미 정비한 도안은 번호 대신 좌표로 보존한다.
            wanted=coords in {tuple(c) for c in d['체크']} if '체크_배치_이유' in d else int(hit[1]) in KEEP[int(i)]
            if not wanted:
                removed.append(hit[1]);return ''
            if pos: kept.append([round((float(pos[1])-16)/32),round(float(pos[2])/32)])
            return block
        scene_text[i]=NODE.sub(check,scene_text[i])
        original_total += len(kept)+len(removed)
        final_total += len(kept)
        d['체크']=kept
        d['체크_배치_이유']='입구는 연결 도착 시 자동 저장. 긴 퍼즐 전후 및 그을음/거미 안전구간에만 등불을 유지한다.'
        before=next((r for r in previous.get('스테이지',[]) if r['id']==i),{})
        checkpoint_report.append({'id':i,'남김':len(kept),'삭제한_노드':sorted(set(removed+before.get('삭제한_노드',[])))})
    # 메인 경로의 양쪽 벽을 재연결한다. 기존 서재·침실·수납실 등 퍼즐 내부는 변경하지 않는다.
    for a,b in zip(MAIN,MAIN[1:]):
        out=cards[a]['출구'][0]
        entry=cards[b]['입구']
        for c in data[a]['연결']:
            if c['이름']==out:c['연결']=[cards[b]['씬'],entry]
        for c in data[b]['연결']:
            if c['이름']==entry:c['연결']=[cards[a]['씬'],out]
    for hub,name,x,y,room,entry in FORKS+MERGES:
        doors=data[hub].setdefault('옆방문',[])
        doors[:]=[d for d in doors if d['이름']!=name]
        doors.append({'이름':name,'x':x,'바닥':y,'연결':[cards[room]['씬'],entry],'표제':cards[room]['이름'].split(' · ')[0]})
        for c in data[room]['연결']:
            if c['이름']==entry:c['연결']=[cards[hub]['씬'],name]
    for i,d in data.items():
        text=scene_text[i]
        for c in d['연결']:
            dest,entry=c['연결']
            dest=dest if dest.startswith('res://') else 'res://scenes/쳅터1/스테이지/'+dest+'.tscn'
            def update(m):
                block=m.group(0)
                if not re.search(r'\[node name="'+re.escape(c['이름'])+r'"[^\n]*parent="연결"',block):return block
                block=re.sub(r'"다음_씬" = "[^"]*"','"다음_씬" = "'+dest+'"',block)
                block=re.sub(r'"다음_연결" = "[^"]*"','"다음_연결" = "'+entry+'"',block)
                # Godot은 기본값인 왼쪽을 저장하지 않기도 한다. 분기 정비 후에는 도착점을 명시해 도안과 함께 검증한다.
                if '"다음_연결" =' not in block:
                    block=block.rstrip()+'\n"다음_연결" = "'+entry+'"\n'
                return block
            text=NODE.sub(update,text)
        if d.get('옆방문'):
            if 'id="codex_side_door"' not in text:
                at=text.index('[sub_resource')
                text=text[:at]+'[ext_resource type="Script" path="res://scripts/쳅터1/옆방문.gd" id="codex_side_door"]\n\n'+text[at:]
                text=re.sub(r'load_steps=(\d+)',lambda m:'load_steps='+str(int(m[1])+1),text,count=1)
            for door in d['옆방문']:
                # 노드만 교체해 에디터가 수정한 다른 지형·기믹 값에 손대지 않는다.
                text=NODE.sub(lambda m:'' if re.search(r'\[node name="'+re.escape(door['이름'])+r'"[^\n]*parent="연결"',m[0]) else m[0],text)
                dest,entry=door['연결']
                text += '\n[node name="'+door['이름']+'" type="Node2D" parent="연결"]\nposition = Vector2('+str(door['x']*32+16)+', '+str(door['바닥']*32)+')\nscript = ExtResource("codex_side_door")\n"다음_씬" = "res://scenes/쳅터1/스테이지/'+dest+'.tscn"\n"다음_연결" = "'+entry+'"\n"표제" = "'+door['표제']+'"\n'
        text=re.sub(r'\n{3,}','\n\n',text).rstrip()+'\n'
        (SCENES/(cards[i]['씬']+'.tscn')).write_text(text,encoding='utf-8')
        save_json(designs[i],d)
    # 카드 좌표와 앞 조건은 실제 문 연결의 갈림/합류와 일치시킨다.
    for n,i in enumerate(MAIN):
        # 12개를 한 줄에 몰면 사진 사이의 길이 가려진다. 큰 줄기를 두 층으로 접어 가지와 여백을 확보한다.
        cards[i]['위치']=[round(0.07+(n if n<6 else 11-n)*0.16,4),0.40 if n<6 else 0.61]
        cards[i]['앞']=[] if n==0 else [MAIN[n-1]]
        cards[i]['주경로']=True
    for hub,name,_,_,room,_ in FORKS:
        cards[room]['앞']=[hub]
        if name not in cards[hub]['출구']:cards[hub]['출구'].append(name)
    for hub,name,_,_,room,_ in MERGES:
        cards[hub]['앞'].append(room)
    positions={'03':[0.15,0.20],'16':[0.31,0.20],'05':[0.47,0.20],'07':[0.63,0.20],'17':[0.72,0.80],'18':[0.875,0.80],'19':[0.31,0.80]}
    for i,pos in positions.items():cards[i]['위치']=pos
    # [2026-10-10 Claude] 열쇠 스테이지 표시 — 출처는 도안 하나. 잠긴문이 있으면 True(이 스테이지 출구가 잠김),
    #   다른 스테이지 주인의 열쇠조각만 있으면 그 주인 씬 이름(18 → 17). 둘 다 없으면 칸을 지운다.
    #   보드 카드(사진카드.gd)가 오른쪽 위에 열쇠를 그리고 주운 조각만큼 채운다.
    for i,d in data.items():
        gs=d.get('기믹',[])
        if any(g.get('종류')=='잠긴문' for g in gs):
            cards[i]['열쇠']=True
        else:
            owner=next((g['주인'] for g in gs if g.get('종류')=='열쇠조각' and g.get('주인')),None)
            if owner:
                cards[i]['열쇠']=owner
            else:
                cards[i].pop('열쇠',None)
    board['제목']='쳅터 1 · 집의 기억'
    board['_설명']='사진 카드와 물감 가지 지도. 주경로는 복도를 따라 집→굴뚝→하수도로 이어지고 옆방은 E 출입문으로 갈라져 다음 복도에 합류한다. 숨은 서재는 기존 발견 규칙 유지.'
    board['다음_쳅터']['위치']=[0.12,0.84]
    save_json(BOARD,board)
    original_total=previous.get('체크포인트_전',original_total)
    report={'체크포인트_전':original_total,'체크포인트_후':final_total,'스테이지':checkpoint_report,'주경로':MAIN,'갈림':FORKS,'합류':MERGES}
    save_json(report_path,report)
    print(json.dumps({'체크포인트_전':original_total,'체크포인트_후':final_total,'주경로':MAIN},ensure_ascii=False))

if __name__=='__main__':main()
