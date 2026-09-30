"""요약 도구가 실제 값/생략 여부를 정직하게 출력하고 파일을 바꾸지 않는지 검사."""
import hashlib
import re
import summarize_sewer_scene as tool

path=tool.ROOT/'scenes/world_2_클로드/stage_2-1.tscn'
before=path.read_bytes()
result=tool.summarize(path,'Player',1)
assert result['sha256']==hashlib.sha256(before).hexdigest()
assert result['nodes'][0]['node']=='Player'
assert result['nodes'][0]['점프_거리_칸']=='20.0'
assert result['nodes'][0]['instance'].endswith('/Player.tscn')
small=tool.summarize(path,limit=2)
assert len(small['nodes'])==2 and small['omitted']==small['matched']-2
assert not tool.summarize(path,'__없는노드__')['nodes']
polygons=tool.summarize(path,'CollisionPolygon2D',1000)['nodes']
assert polygons and all('saved_local_polygon' in p for p in polygons)
assert before==path.read_bytes()
# 새 진입점의 상대 Markdown 링크가 보관 경로 포함 실제 존재하는지 검사한다.
folder=tool.ROOT/'scenes/world_2_클로드'
count=0
for name in ['맵제작_시작.md','프롬프트_아스트라_스테이지2_맵제작.md',
             '프롬프트_클로드_하수도_SS2D_지형배경_적용과검증.md',
             '필독_오퍼스_현재지형디자인_인계.md','README_맵제작_인계.md',
             '가이드라인_스테이지2_분기형맵_2026-09-12.md']:
    for link in re.findall(r'\]\(([^)]+)\)',(folder/name).read_text(encoding='utf-8')):
        assert (folder/link).exists(),(name,link)
        count+=1
print('Scene summary fields/limits/missing-node/read-only: PASS; document links:',count,'PASS')
