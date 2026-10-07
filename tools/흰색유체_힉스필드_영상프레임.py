"""힉스필드 생성 영상의 실제 프레임을 투명 흰색 유체 시트로 조립한다."""
from pathlib import Path
import sys,json,subprocess,zipfile,hashlib
import numpy as np
from PIL import Image,ImageDraw
VIDEO,OUT=Path(sys.argv[1]),Path(sys.argv[2])
OUT.mkdir(parents=True,exist_ok=True)
raw=OUT/"raw";raw.mkdir(exist_ok=True)
subprocess.run(["ffmpeg","-v","error","-i",str(VIDEO),"-vsync","0",str(raw/"%04d.png")],check=True)
paths=sorted(raw.glob("*.png"))
assert len(paths)>=49
# 모든 원본 프레임을 뽑은 뒤 첫·마지막을 포함한 49개를 고른다. 중복 마지막은 조립에서 제외한다.
indices=np.rint(np.linspace(0,len(paths)-1,49)).astype(int)
N,W,H,FPS=48,256,512,12
arrays=[]
backgrounds=[]
for i in indices:
    rgb=np.asarray(Image.open(paths[i]).convert("RGB"),dtype=float)/255
    bg=np.median(rgb[:60,:120].reshape(-1,3),axis=0)
    # 전용 배경 제거가 물방울을 지우고 분홍 테두리를 남겼으므로 프레임별 색 분리로 얇은 물을 보존한다.
    contrast=max(bg[0],bg[2])-bg[1]
    alpha=np.clip(1-(np.maximum(rgb[:,:,0],rgb[:,:,2])-rgb[:,:,1])/max(contrast,.01),0,1)
    alpha[(alpha<.12)|(rgb[:,:,1]-bg[1]<.075)]=0
    value=np.clip((rgb[:,:,1]-bg[1]*(1-alpha))/np.maximum(alpha,.0001),0,1)
    arrays.append(np.dstack([value,value,value,alpha]))
    backgrounds.append(bg.tolist())
rh,rw=arrays[0].shape[:2]
dense=arrays[0][160:900,:,3].sum(axis=0)
xs=np.flatnonzero(dense>dense.max()*.85)
cx=int(round((xs.min()+xs.max())*.5))
# 고정 카메라의 최초 프레임에서 기준점을 읽는다. 프레임마다 재정렬하지 않아 물이 흔들려 배치되지 않는다.
center=arrays[0][:,cx,3]>.85
ys=np.flatnonzero(center)
top=int(ys.min())+6
ground=int(ys.max())
widths=[]
for a in arrays:
    for y in np.linspace(top+60,ground-250,7).astype(int):
        row=a[y,:,3]>.35
        assert row[cx], "White stream core has a gap"
        left,right=cx,cx
        while left>0 and row[left-1]:left-=1
        while right<rw-1 and row[right+1]:right+=1
        widths.append(right-left+1)
# 최소 본체 폭을 기준으로 그려 실제 표시가 게임의 판정 폭보다 좁아지지 않게 한다.
beam=float(np.percentile(widths,5))
frames=[]
for a in arrays:
    # 바닥 물막만 제한한다. 지면 위의 분리 물방울은 원래 영상의 움직임을 그대로 유지한다.
    xx=np.arange(rw)
    footprint=np.clip((beam*.5-np.abs(xx-cx))/(beam*.06),0,1)
    floor_weight=np.clip((np.arange(rh)-(ground-16))/10,0,1)
    a[:,:,3]*=1-floor_weight[:,None]+floor_weight[:,None]*footprint[None,:]
    # 생성 영상이 덧붙인 바닥 반사는 유체가 아니므로 지면 아래에서 제거한다.
    a[ground+6:,:,3]=0
    im=Image.fromarray(np.uint8(np.clip(a*255,0,255)))
    # 컬러와 알파를 함께 조절하는 Pillow의 RGBA 보간을 사용한다.
    frames.append(im.resize((W,H),Image.Resampling.LANCZOS))
layout=[cx*W/rw,top*H/rh,ground*H/rh,beam*W/rw]
sheet=Image.new("RGBA",(W*8,H*6))
for k,f in enumerate(frames[:N]):
    assert f.getbbox() and f.getbbox()[0]>0 and f.getbbox()[2]<W and f.getbbox()[1]>0 and f.getbbox()[3]<H
    sheet.paste(f,((k%8)*W,(k//8)*H))
name="white_fluid_f48_256x512_g8x6_fps12_loop.png"
sheet.save(OUT/name)
frames[0].save(OUT/"white_fluid_cutout.png")
previews=[]
for f in frames[:N]:
    bg=Image.new("RGBA",(384,800),(18,20,23,255))
    bg.alpha_composite(f.resize((384,768),Image.Resampling.LANCZOS),(0,25))
    ImageDraw.Draw(bg).text((10,7),"HIGGSFIELD VIDEO FRAMES / ASSET PREVIEW",fill="white")
    previews.append(bg.convert("RGB"))
previews[0].save(OUT/"white_fluid_preview.webp",save_all=True,append_images=previews[1:],duration=[83,83,84]*16,loop=0,quality=95,method=4)
contact=Image.new("RGB",(1536,1600),(18,20,23))
for j,k in enumerate(range(0,48,6)):
    contact.paste(previews[k],((j%4)*384,(j//4)*800))
contact.save(OUT/"white_fluid_contact.jpg",quality=88)
# 얇은 물방울과 접촉부를 확대해 배경 제거 흔적을 검사한다.
detail=Image.new("RGB",(1024,496),(18,20,23))
for j,k in enumerate([0,12,24,36]):
    crop=frames[k].crop((0,388,W,512)).resize((512,248),Image.Resampling.LANCZOS)
    bg=Image.new("RGBA",crop.size,(18,20,23,255));bg.alpha_composite(crop)
    detail.paste(bg.convert("RGB"),((j%2)*512,(j//2)*248))
detail.save(OUT/"white_fluid_impact_detail.jpg",quality=91)
a=[np.asarray(f,dtype=float) for f in frames[:N]]
deltas=[float(np.abs(a[(i+1)%N]-a[i]).mean()) for i in range(N)]
meta=dict(version=1,source_video_job="d1cdeff6-da65-4c4a-a743-6c24e171acf4",
          source_video_sha256=hashlib.sha256(VIDEO.read_bytes()).hexdigest(),
          native_frames=len(paths),native_fps=24,selected_indices=indices.tolist(),
          frames=N,fps=FPS,loop_seconds=4,cell=[W,H],grid=[8,6],
          layout_center_top_ground_beam=layout,frame_anchoring="fixed original camera",
          method="Actual Higgsfield video frames; per-frame neutral chroma matte; floor strip width limited",
          no_procedural_motion=True,median_delta=float(np.median(deltas)),boundary_delta=deltas[-1],
          first_last_delta=float(np.abs(np.asarray(frames[0],dtype=float)-np.asarray(frames[-1],dtype=float)).mean()),
          engine_visual_verification=False)
(OUT/"metadata.json").write_text(json.dumps(meta,indent=2),encoding="utf-8")
with zipfile.ZipFile(OUT/"white_fluid_frames.zip","w",zipfile.ZIP_DEFLATED) as z:
    for n in [name,"white_fluid_cutout.png","white_fluid_preview.webp","white_fluid_contact.jpg","white_fluid_impact_detail.jpg","metadata.json"]:
        z.write(OUT/n,n)
print(json.dumps(meta))
