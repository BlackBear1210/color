"""실제 힉스필드 영상의 착수 프레임과 폭별 분리 렌더 미리보기를 만든다."""
from pathlib import Path
import sys, json, subprocess, hashlib, zipfile
import numpy as np
from PIL import Image, ImageDraw

video, out, job = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3]
out.mkdir(parents=True, exist_ok=True)
raw = out / "raw"
raw.mkdir(exist_ok=True)
subprocess.run(["ffmpeg", "-v", "error", "-i", str(video), "-vsync", "0", str(raw / "%04d.png")], check=True)
paths = sorted(raw.glob("*.png"))
assert len(paths) >= 96
indices = np.rint(np.linspace(0, len(paths)-1, 97)).astype(int)
frames = []
for index in indices:
    rgb = np.asarray(Image.open(paths[index]).convert("RGB"), dtype=float)/255
    bg = np.median(rgb[:40, :80].reshape(-1, 3), axis=0)
    # 분홍 배경만 빼고 회색/흰색 물방울의 원래 움직임과 투명도를 보존한다.
    a = np.clip(1-(np.maximum(rgb[:,:,0], rgb[:,:,2])-rgb[:,:,1])/max(max(bg[0],bg[2])-bg[1], .01), 0, 1)
    a[(a < .10) | (rgb[:,:,1]-bg[1] < .04)] = 0
    v = np.clip((rgb[:,:,1]-bg[1]*(1-a))/np.maximum(a,.001), 0, 1)
    f = Image.fromarray(np.uint8(np.dstack([v,v,v,a])*255)).resize((512,288), Image.Resampling.LANCZOS)
    assert f.getbbox() and f.getbbox()[0] > 0 and f.getbbox()[1] > 0 and f.getbbox()[2] < 512 and f.getbbox()[3] < 288
    frames.append(f)
first = np.asarray(frames[0], dtype=float)/255
density = first[60:120,:,3].sum(axis=0)
cx = int(np.argmax(density))
ys = np.flatnonzero(first[:,cx,3] > .3)
ground = int(ys.max())
layout = [cx, ground, 8, .4]
name = "white_impact_f96_512x288_g8x12_fps24.png"
atlas = Image.new("RGBA", (4096,3456))
for k, frame in enumerate(frames[:96]):
    atlas.paste(frame, ((k%8)*512, (k//8)*288))
atlas.save(out/name)
frames[0].save(out/"white_impact_cutout.png")

def smooth(a,b,x):
    k=np.clip((x-a)/(b-a),0,1)
    return k*k*(3-2*k)

def noise(x,y):
    # 색 구분을 해치는 저해상도 본체 텍스처 대신 셰이더와 같은 연속 명암만 쓴다.
    def h(x,y):
        a=np.mod(x*123.34,1);b=np.mod(y*456.21,1)
        d=a*(a+45.32)+b*(b+45.32)
        return np.mod((a+d)*(b+d),1)
    ix=np.floor(x);iy=np.floor(y);fx=smooth(0,1,x-ix);fy=smooth(0,1,y-iy)
    return (h(ix,iy)*(1-fx)+h(ix+1,iy)*fx)*(1-fy)+(h(ix,iy+1)*(1-fx)+h(ix+1,iy+1)*fx)*fy

def render(frame, width, height, time, canvas_width=400):
    # 셰이더와 같은 좌표 매핑으로 확인한다. 엔진 캡처가 아니며 움직임을 새로 합성하지 않는다.
    arr=np.asarray(frame,dtype=float)/255
    yy,xx=np.mgrid[:height+30,:canvas_width]
    dx=xx-canvas_width/2
    edge=1-smooth(width/2-1,width/2+1,np.abs(dx))
    u=np.clip(dx/max(width/2,1),-1,1)
    rim=np.exp(-((np.abs(u)-.88)/.07)**2)
    detail=noise(u*5+12, yy/48-time*9)
    body_a=(.84+.08*rim+.03*detail)*edge*(1-smooth(height-2,height+1,yy))
    body_v=.92+.04*detail+.03*rim
    scale=.4
    imp_x=np.where(np.abs(dx)<=width/2,cx+dx*8/max(width/2,1),cx+np.sign(dx)*(8+(np.abs(dx)-width/2)/scale))
    imp_y=ground+(yy-height)/scale
    valid=(imp_x>=.5)&(imp_x<=511.5)&(imp_y>=.5)&(imp_y<=287.5)&(yy>=height-90)
    sample=arr[np.clip(imp_y.astype(int),0,287),np.clip(imp_x.astype(int),0,511)]
    stem=(1-smooth(10,16,np.abs(imp_x-cx)))*(1-smooth(ground-16,ground-8,imp_y))
    footprint=1-smooth(max(0,width/2-2),width/2,np.abs(dx))
    imp_a=.72*sample[:,:,3]*valid*(1-stem)*(1-smooth(height+1,height+3,yy))
    imp_a*=1-smooth(height-2,height,yy)+smooth(height-2,height,yy)*footprint
    foam=(1-smooth(0,2,np.abs(yy-height)))*edge*.42
    imp_v=sample[:,:,0]
    bg=np.full(yy.shape,.065)
    value=bg*(1-body_a)+body_v*body_a
    value=value*(1-imp_a)+imp_v*imp_a
    value=value*(1-foam)+.94*foam
    rgb=np.repeat(np.uint8(np.clip(value*255,0,255))[:,:,None],3,axis=2)
    return Image.fromarray(rgb)

preview=[]
for k,f in enumerate(frames[:96]):
    image=Image.new("RGB",(900,610),(17,17,17))
    image.paste(render(f,26,500,k/24),(-35,65))
    image.paste(render(f,110,210,k/24),(265,65))
    image.paste(render(f,220,360,k/24),(565,65))
    draw=ImageDraw.Draw(image)
    draw.text((12,12),"WHITE WATER V2 - SEPARATE BODY / IMPACT - ASSET PREVIEW",fill="white")
    draw.text((100,40),"NARROW / TALL",fill="white")
    draw.text((390,40),"WIDE / SHORT",fill="white")
    draw.text((700,40),"WIDE / TALL",fill="white")
    preview.append(image)
preview[0].save(out/"white_v2_preview.webp", save_all=True, append_images=preview[1:],duration=[42,42,41]*32,loop=0,quality=90,method=4)
contact=Image.new("RGB",(1800,1220))
for j,k in enumerate([0,24,48,72]):
    contact.paste(preview[k],((j%2)*900,(j//2)*610))
contact.save(out/"white_v2_contact.jpg",quality=88)
meta=dict(version=2,source_video_job=job,source_video_sha256=hashlib.sha256(video.read_bytes()).hexdigest(),native_frames=len(paths),selected_indices=indices.tolist(),frames=96,fps=24,loop_seconds=4,cell=[512,288],grid=[8,12],layout=layout,separate_body_and_impact=True,body_method="Smooth bright white procedural material for three-tone readability; no video stretching",body_alpha_min=.84,impact_fixed_scale=.4,impact_alpha=.72,engine_visual_verification=False)
(out/"metadata.json").write_text(json.dumps(meta,indent=2),encoding="utf-8")
with zipfile.ZipFile(out/"white_v2.zip","w",zipfile.ZIP_DEFLATED) as z:
    for n in [name,"metadata.json","white_v2_preview.webp","white_v2_contact.jpg","white_impact_cutout.png"]:
        z.write(out/n,n)
print(json.dumps(meta))
