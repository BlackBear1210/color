"""실제 씬을 다시 쓰지 않고 복사본으로 멱등성·기믹 보존을 확인한다."""
import contextlib
import hashlib
import io
import json
import re
import shutil
from pathlib import Path
import 아트_v02_적용 as apply

ROOT=apply.ROOT
OUT=apply.OUT

def nodes(text):
    result={}
    for m in apply.blocks(text,'node'):
        h=m.group().splitlines()[0]
        name=re.search(r'name="([^"]+)"',h).group(1)
        parent=re.search(r'parent="([^"]+)"',h)
        result[((parent.group(1) if parent else ''),name)]=m.group().strip()
    return result

def main():
    sandbox=OUT/'복사본검사'
    originals={}
    for folder in ('scenes/쳅터1/도안','scenes/쳅터1/스테이지'):
        dst=sandbox/folder; dst.mkdir(parents=True,exist_ok=True)
        for p in (ROOT/folder).glob('*'):
            if p.suffix in ('.json','.tscn'):
                data=p.read_bytes()
                (dst/p.name).write_bytes(data)
                if p.suffix=='.tscn': originals[p.name]=data.decode('utf-8')
    apply.ROOT=sandbox
    apply.OUT=sandbox/'검토'
    with contextlib.redirect_stdout(io.StringIO()):
        apply.main()
        files=sorted((sandbox/'scenes').rglob('*'))
        hashes={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in files if p.is_file()}
        apply.main()
    assert all(hashlib.sha256(Path(p).read_bytes()).hexdigest()==h for p,h in hashes.items()), '누적 변경'
    protected=0
    for name,text in originals.items():
        before=nodes(text)
        after=nodes((sandbox/'scenes/쳅터1/스테이지'/name).read_text(encoding='utf-8'))
        for key,value in before.items():
            parent,name=key
            if parent.startswith('배경') or name in ('배경','어둠'): continue
            expected=after[key]
            if parent=='지형':
                value=re.sub(r'^position = .*\n','',value,flags=re.M)
                expected=re.sub(r'^position = .*\n','',expected,flags=re.M)
            assert value==expected, f'비시각 속성이 달라짐: {name}/{key}'
            protected+=1
    result={'idempotent':True,'protected_node_count':protected,'live_scene_writes':False}
    (OUT/'보존검사.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    print(result)

if __name__=='__main__': main()
