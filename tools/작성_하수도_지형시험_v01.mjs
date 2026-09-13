import fs from 'node:fs';
import path from 'node:path';
// 기존 맵을 보호하기 위해 신규 시험 자산만 만들며, 재실행은 기본적으로 검사만 한다.
const root = process.cwd();
const art = 'assets/textures/smartshape/sewer_masonry_v01';
const lab = 'scenes/테스트/하수도_지형_v01';
const files = new Map();
const put = (p,s) => files.set(p,s+'\n');
const ext = (type,p,id) => `[ext_resource type="${type}" path="res://${p}" id="${id}"]\n`;
// 원본 비트맵을 잘라 훼손하지 않고 독립 AtlasTexture 리소스로 부위를 참조한다.
for (const [name,rect] of Object.entries({top:[44,45,284,53],side:[636,634,278,49],corner:[42,633,56,56]})) {
 put(`${art}/${name}.tres`, `[gd_resource type="AtlasTexture" format=3]\n${ext('Texture2D',art+'/trim_atlas.png','atlas')}\n[resource]\natlas = ExtResource("atlas")\nregion = Rect2(${rect.join(', ')})\nfilter_clip = true`);
}
let mat = '[gd_resource type="Resource" script_class="SS2D_Material_Shape" format=3]\n';
for (const [id,p] of Object.entries({shape:'materials/shape_material.gd',edge:'materials/edge_material.gd',meta:'materials/edge_material_metadata.gd',range:'normal_range.gd'})) mat+=ext('Script','addons/rmsmartshape/'+p,id);
for(const n of ['top','side','corner']) mat+=ext('Texture2D',`${art}/${n}.tres`,n);
mat+=ext('Texture2D',art+'/brick_fill.png','fill');
// SS2D의 안쪽 오프셋과 용접을 사용해 장식이 충돌면 밖으로 두껍게 돌출되지 않게 한다.
for (const [i,begin] of [45,135,225,315].entries()) {
 const tex=i===0?'top':'side';
 mat+=`\n[sub_resource type="Resource" id="edge${i}"]\nscript = ExtResource("edge")\ntextures = Array[Texture2D]([ExtResource("${tex}")])\ntextures_corner_outer = Array[Texture2D]([ExtResource("corner")])\nuse_corner_texture = false\nuse_taper_texture = false\ntexture_scale = 0.16\nuniform_width = true\nfit_mode = 1\n\n[sub_resource type="Resource" id="range${i}"]\nscript = ExtResource("range")\nbegin = ${begin}.0\ndistance = 90.0\n\n[sub_resource type="Resource" id="meta${i}"]\nscript = ExtResource("meta")\nedge_material = SubResource("edge${i}")\nnormal_range = SubResource("range${i}")\noffset = -1.0\nweld = true\n`;
}
mat+='\n[resource]\nscript = ExtResource("shape")\n_edge_meta_materials = Array[ExtResource("meta")](['+[0,1,2,3].map(i=>`SubResource("meta${i}")`).join(', ')+'])\nfill_textures = Array[Texture2D]([ExtResource("fill")])\nfill_texture_scale = 0.28\nfill_texture_absolute_position = true\nfill_texture_z_index = -1';
// 고정 흰 테두리처럼 보이지 않도록 원본의 모서리 반사를 낮춘다.
mat=mat.replace('[sub_resource type="Resource" id="edge0"]', ext('Shader',art+'/trim_tone.gdshader','tone')+'\n[sub_resource type="ShaderMaterial" id="tone_material"]\nshader = ExtResource("tone")\n\n[sub_resource type="Resource" id="edge0"]');
mat=mat.replaceAll('use_corner_texture = false','use_corner_texture = true').replaceAll('fit_mode = 1','fit_mode = 1\nmaterial = SubResource("tone_material")');
put(art+'/masonry_black.tres',mat);
const shapes=[
 {name:'연속_경사_꺾임',points:[[0,460],[400,460],[600,360],[900,360],[900,660],[1450,660],[1450,1100],[0,1100]]},
 {name:'수직벽_모서리',points:[[1600,420],[1950,420],[1950,1100],[1600,1100]]},
 {name:'낮은_직사각',points:[[1080,400],[1350,400],[1350,495],[1080,495]]}
];
let s='[gd_scene format=3]\n';
for(const [id,p] of Object.entries({shape:'shapes/shape.gd',point:'shapes/point.gd',points:'shapes/point_array.gd'})) s+=ext('Script','addons/rmsmartshape/'+p,id);
s+=ext('Resource',art+'/masonry_black.tres','material');
s+=ext('Script',lab+'/보기.gd','viewer');
s+=ext('Texture2D','assets/background/stage_2/layers_v01/far_wall.png','far');
s+=ext('Texture2D','assets/background/stage_2/layers_v01/mid_arches.png','mid');
for(const [i,obj] of shapes.entries()) {
 const pts=[...obj.points,obj.points[0]];
 for(const [j,p] of pts.entries()) s+=`\n[sub_resource type="Resource" id="p${i}_${j}"]\nscript = ExtResource("point")\nresource_local_to_scene = true\nposition = Vector2(${p.join(', ')})\n`;
 s+=`\n[sub_resource type="Resource" id="a${i}"]\nscript = ExtResource("points")\nresource_local_to_scene = true\n_points = {\n${pts.map((_,j)=>`${j}: SubResource("p${i}_${j}")`).join(',\n')}\n}\n_point_order = PackedInt32Array(${pts.map((_,j)=>j).join(', ')})\n_constraints = { Vector2i(0, ${pts.length-1}): 15 }\n_next_key = ${pts.length}\n`;
}
s+='\n[node name="하수도_지형_재질시험" type="Node2D"]\nscript = ExtResource("viewer")\n';
for(const [name,id,ratio,z] of [['먼벽','far',0.25,-20],['아치배관','mid',0.6,-10]]) s+=`\n[node name="${name}" type="Parallax2D" parent="."]\nscroll_scale = Vector2(${ratio}, ${ratio})\nz_index = ${z}\n\n[node name="그림" type="Sprite2D" parent="${name}"]\ntexture = ExtResource("${id}")\ncentered = false\nscale = Vector2(1.8, 1.8)\nposition = Vector2(-500, -400)\n`;
s+='\n[node name="Camera2D" type="Camera2D" parent="."]\nposition = Vector2(950, 520)\nzoom = Vector2(0.7, 0.7)\n';
for(const [i,obj] of shapes.entries()) {
 s+=`\n[node name="${obj.name}" type="Node2D" parent="."]\nscript = ExtResource("shape")\n_points = SubResource("a${i}")\nshape_material = ExtResource("material")\ntexture_repeat = 2\ncollision_update_mode = 2\ncollision_polygon_node_path = NodePath("StaticBody2D/CollisionPolygon2D")\n\n[node name="StaticBody2D" type="StaticBody2D" parent="${obj.name}"]\n\n[node name="CollisionPolygon2D" type="CollisionPolygon2D" parent="${obj.name}/StaticBody2D"]\npolygon = PackedVector2Array(${obj.points.flat().join(', ')})\n`;
}
put(lab+'/지형_레이어_시험.tscn',s);
// --write도 이미 존재하는 결과는 덮어쓰지 않는다. 사용자가 편집한 시험 씬을 보존한다.
for(const [p,content] of files){
 for(const match of content.matchAll(/path="res:\/\/([^\"]+)"/g)) if(!files.has(match[1])&&!fs.existsSync(path.join(root,match[1]))) throw Error('누락: '+match[1]);
 if(process.argv.includes('--write')) {fs.mkdirSync(path.dirname(p),{recursive:true});fs.writeFileSync(p,content,{flag:'wx'});}
}
console.log(`${files.size}개 파일 경로 확인 완료. ${process.argv.includes('--write')?'신규 파일 저장.':'검사만 수행.'}`);
