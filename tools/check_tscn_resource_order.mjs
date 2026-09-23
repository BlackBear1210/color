// 참조 ID의 존재만으로는 로드 안전성을 알 수 없다. Godot 텍스트 씬의 선언 순서도 확인한다.
// 엔진 파싱을 대신하지 않는 정적 검사이며, 함수는 고장 예제 회귀 검사에서도 사용한다.
import assert from 'node:assert/strict';
export function checkResourceOrder(text,label='scene'){
  const declared={ExtResource:new Set(),SubResource:new Set()};
  const ranks={gd_scene:0,ext_resource:1,sub_resource:2,node:3,connection:4,editable:5};
  let phase=0;
  for(const [i,line] of text.split(/\r?\n/).entries()){
    const tag=line.match(/^\[(gd_scene|ext_resource|sub_resource|node|connection|editable)\b/);
    if(tag){
      const rank=ranks[tag[1]];
      assert(rank>=phase,`${label}:${i+1}: 선언 순서 오류 (${tag[1]})`);
      phase=rank;
      const kind=tag[1]==='ext_resource'?'ExtResource':tag[1]==='sub_resource'?'SubResource':null;
      if(kind){
        const id=line.match(/\bid="([^"]+)"/)?.[1];
        assert(id,`${label}:${i+1}: 리소스 ID 누락`);
        assert(!declared[kind].has(id),`${label}:${i+1}: 중복 리소스 ${id}`);
        declared[kind].add(id);
      }
    }
    for(const match of line.matchAll(/\b(ExtResource|SubResource)\("([^"]+)"\)/g))
      assert(declared[match[1]].has(match[2]),`${label}:${i+1}: 선언보다 먼저 참조한 ${match[0]}`);
  }
}

// 이번 고장과 같은 '맨 아래 선언'은 존재 검사를 통과해도 여기서는 반드시 실패해야 한다.
const declaration='[ext_resource type="Script" path="res://sample.gd" id="script"]';
const body='[node name="root" type="Node2D"]\nscript = ExtResource("script")';
assert.doesNotThrow(()=>checkResourceOrder('[gd_scene format=3]\n'+declaration+'\n'+body));
assert.throws(()=>checkResourceOrder('[gd_scene format=3]\n'+body+'\n'+declaration),/먼저 참조/);
assert.throws(()=>checkResourceOrder('[gd_scene format=3]\n[node name="root" type="Node2D"]\n'+declaration),/선언 순서/);
assert.throws(()=>checkResourceOrder('[gd_scene format=3]\n'+declaration+'\n'+declaration),/중복 리소스/);
