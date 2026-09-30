"""Godot 실행 없이 저장된 노드 속성만 요약. 상속/실행값/물리 검증으로 오인하지 않는다."""
import argparse
import hashlib
import json
import re
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
FIELDS={'position','scale','script','shape_material','크기','폭','높이','색','시작상태','켜짐',
        '입구_유체','출구_유체','공급_유체','대상_유체','갈래_A','갈래_B','대상들',
        '대상_이동량들','출구_물줄기_폭','출구_물줄기_길이','입구_물줄기_폭','입구_물줄기_길이',
        '카메라_줌','치명_낙하거리','점프_높이_칸','점프_거리_칸','visible','시작_켜짐','시작_갈래_A'}

def summarize(path,pattern='',limit=20):
    data=path.read_bytes();text=data.decode('utf-8-sig')
    refs={}
    for header in re.findall(r'^\[ext_resource[^\n]+',text,re.M):
        values=dict(re.findall(r'(\w+)="([^"]*)"',header))
        if 'id' in values and 'path' in values:refs[values['id']]=values['path']
    nodes=[]
    # 노드 블록의 필요한 속성만 읽고 거대한 리소스 배열은 출력하지 않는다.
    for match in re.finditer(r'^\[node ([^\n]+)\]\s*\n(.*?)(?=^\[|\Z)',text,re.M|re.S):
        header,body=match.groups();attrs=dict(re.findall(r'(\w+)="([^"]*)"',header))
        name=attrs.get('name','?');parent=attrs.get('parent','')
        nodepath=(parent+'/' if parent and parent!='.' else '')+name
        if pattern and pattern not in nodepath:continue
        row={'node':nodepath}
        instance=re.search(r'instance=ExtResource\("([^"]+)"\)',header)
        if instance:row['instance']=refs.get(instance[1],instance[1])
        for key,value in re.findall(r'^([^\n=]+?) = ([^\n]*)',body,re.M):
            key=key.strip().strip('"')
            if key not in FIELDS:continue
            value=value.strip()
            value=re.sub(r'ExtResource\("([^"]+)"\)',lambda m:refs.get(m[1],m[0]),value)
            # 생략은 명시하며 길이 제한을 실제 데이터 검증에 사용하지 않는다.
            row[key]=value if len(value)<=180 else value[:180]+'… [값 생략]'
        polygon=re.search(r'^polygon = PackedVector2Array\(([^\n]*)\)',body,re.M)
        if polygon:
            try:
                nums=[float(v) for v in polygon[1].split(',') if v.strip()]
                if len(nums)%2==0 and nums:
                    row['saved_local_polygon']={'points':len(nums)//2,'bounds':[min(nums[::2]),min(nums[1::2]),max(nums[::2]),max(nums[1::2])]}
            except ValueError:row['saved_local_polygon']='파싱 미지원'
        if len(row)>1:nodes.append(row)
    return {'scene':str(path.relative_to(ROOT)), 'sha256':hashlib.sha256(data).hexdigest(),
            'notice':'직접 저장값만 표시. 좌표는 로컬. 상속·실행·연결유효성·도달성은 미검증.',
            'matched':len(nodes),'omitted':max(0,len(nodes)-limit),'nodes':nodes[:limit]}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('scene');parser.add_argument('--node',default='');parser.add_argument('--limit',type=int,default=20)
    args=parser.parse_args()
    path=(ROOT/args.scene.removeprefix('res://')).resolve()
    if not path.is_relative_to(ROOT) or path.suffix!='.tscn':parser.error('저장소 안 .tscn만 지정하세요.')
    if args.limit<1:parser.error('--limit은 1 이상이어야 합니다.')
    print(json.dumps(summarize(path,args.node,args.limit),ensure_ascii=False,indent=2))

if __name__=='__main__':main()
