"""힉스필드 원본 질감을 보존하는 착수 물보라 리그. Godot는 실행하지 않는다."""
from pathlib import Path
import sys, math, json, hashlib, zipfile
import numpy as np
from PIL import Image, ImageDraw

SOURCE = Path(sys.argv[1])
OUT = Path(sys.argv[2])
OUT.mkdir(parents=True, exist_ok=True)
W,H,N,FPS = 384,128,48,30
BASELINE = 112
# 마젠타가 회색 물에 섞여 남지 않게 배경 기여량을 빼고 무채색으로 복원한다.
rgb = np.asarray(Image.open(SOURCE).convert("RGB"),dtype=np.float32)/255
alpha = np.clip(1-(np.maximum(rgb[:,:,0],rgb[:,:,2])-rgb[:,:,1]),0,1)
alpha[(alpha<.08) | (rgb[:,:,1]<.045)]=0
# 원본의 빈 위·아래 여백에는 물이 없으므로 생성 배경의 희미한 무늬도 제거한다.
alpha[:220,:]=0
alpha[550:,:]=0
value = np.clip(rgb[:,:,1]/np.maximum(alpha,.0001),0,1)
rgba = np.dstack([value,value,value,alpha])
src = Image.fromarray(np.uint8(np.clip(rgba*255,0,255)))
# 원본의 지면 y=500을 모든 프레임의 같은 위치에 둔다. 프레임마다 자동 자르지 않는다.
scale=352/src.width
small=src.resize((352,round(src.height*scale)),Image.Resampling.LANCZOS)
base=Image.new("RGBA",(W,H))
base.alpha_composite(small,(16,BASELINE-round(500*scale)))
a=np.asarray(base,dtype=np.float32)/255
# 경계의 어두운 테두리를 막으려고 보간은 미리 곱한 색으로 수행한다.
premul=a.copy()
premul[:,:,:3]*=premul[:,:,3:4]
yy,xx=np.mgrid[:H,:W].astype(np.float32)
lift=np.clip((BASELINE-yy)/65,0,1)
dx=xx-W/2
def sample(x,y):
    x=np.clip(x,0,W-1.001); y=np.clip(y,0,H-1.001)
    x0=x.astype(int); y0=y.astype(int)
    fx=(x-x0)[:,:,None]; fy=(y-y0)[:,:,None]
    return (premul[y0,x0]*(1-fx)*(1-fy)+premul[y0,x0+1]*fx*(1-fy)
            +premul[y0+1,x0]*(1-fx)*fy+premul[y0+1,x0+1]*fx*fy)

# 물방울에도 원본의 비정형 윤곽과 내부 명암을 쓴다. 원·삼각형 도형으로 대체하지 않는다.
patches=[]
for x,y,r in [(163,490,12),(216,442,13),(104,417,14),(1136,458,13),(1196,486,15)]:
    patch=src.crop((x-r,y-r,x+r+1,y+r+1))
    patch=patch.resize((max(2,round(patch.width*scale)),max(2,round(patch.height*scale))),Image.Resampling.LANCZOS)
    patches.append(patch)
rng=np.random.default_rng(20261007)
particles=[(int(rng.integers(5)),float(rng.random()),int(rng.choice([-1,1])),
            float(rng.uniform(8,24)),float(rng.uniform(55,146)),float(rng.uniform(48,160)))
           for _ in range(30)]
frames=[]
for k in range(N+1):
    loop_k=k%N
    phase=2*math.pi*loop_k/N
    # 지면은 고정하고 위로 갈수록 물살만 1~4px 흔든다. 전체 덩어리 팽창은 하지 않는다.
    sx=xx+lift*(3.2*np.sin(phase*3+yy*.12+dx*.045)+1.4*np.sin(phase*5+dx*.07))
    sy=yy+lift*2.8*np.sin(phase*2+dx*.05)
    warped=sample(sx,sy)
    # 조밀한 착수 거품의 잔질감은 바뀌되 큰 외곽은 유지한다.
    shimmer=1+.10*np.sin(phase*6+xx*.42+yy*.31)
    warped[:,:,:3]=np.minimum(warped[:,:,3:4],warped[:,:,:3]*shimmer[:,:,None])
    out=warped.copy()
    out[:,:,:3]=warped[:,:,:3]/np.maximum(warped[:,:,3:4],.0001)
    frame=Image.fromarray(np.uint8(np.clip(out*255,0,255)))
    for idx,offset,side,start,travel,height in particles:
        u=(loop_k/N*2+offset)%1
        opacity=min(1,u/.08)*min(1,(1-u)/.18)
        drop=patches[idx].copy()
        mask=np.asarray(drop.getchannel("A"),dtype=np.float32)*opacity
        drop.putalpha(Image.fromarray(np.uint8(mask)))
        px=W/2+side*(start+travel*u)
        py=BASELINE-height*u*(1-u)
        frame.alpha_composite(drop,(round(px-drop.width/2),round(py-drop.height/2)))
    frames.append(frame)

# 49번째 검사용 프레임은 첫 프레임과 같다. 중복 마지막 프레임은 시트에서 뺀다.
assert np.array_equal(np.asarray(frames[0]),np.asarray(frames[N]))
sheet=Image.new("RGBA",(W*8,H*6))
for k,frame in enumerate(frames[:N]):
    assert frame.getbbox() and not frame.getchannel("A").getextrema()[0]
    sheet.paste(frame,((k%8)*W,(k//8)*H))
name="white_impact_f48_384x128_g8x6_fps30_loop.png"
sheet.save(OUT/name)
base.save(OUT/"source_matte.png")
# 검토 영상에는 엔진 캡처로 오해하지 않도록 자산 미리보기라는 문구를 넣는다.
previews=[]
for frame in frames[:N]:
    canvas=Image.new("RGBA",(576,232),(18,20,23,255))
    draw=ImageDraw.Draw(canvas)
    draw.line((0,200,576,200),fill=(90,91,92),width=2)
    scaled=frame.resize((576,192),Image.Resampling.LANCZOS)
    canvas.alpha_composite(scaled,(0,32))
    draw.text((12,10),"ASSET PREVIEW / Higgsfield source + texture rig / 30 fps",fill="white")
    previews.append(canvas.convert("RGB"))
previews[0].save(OUT/"preview.webp",save_all=True,append_images=previews[1:],
                 duration=[33,33,34]*16,loop=0,quality=95,method=6)
contact=Image.new("RGB",(1152,928),(18,20,23))
for j,k in enumerate(range(0,N,6)):
    contact.paste(previews[k],((j%2)*576,(j//2)*232))
    ImageDraw.Draw(contact).text(((j%2)*576+12,(j//2)*232+28),f"FRAME {k:02d}",fill="white")
contact.save(OUT/"contact.jpg",quality=91)
arrays=[np.asarray(f,dtype=np.float32) for f in frames[:N]]
deltas=[float(np.abs(arrays[(i+1)%N]-arrays[i]).mean()) for i in range(N)]
metadata=dict(version=1,source_sha256=hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
              source_job_id="ddbf34e6-7862-4354-a9b8-2f2cb360328c",
              method="Higgsfield generated source + deterministic texture rig; both video generations rejected",
              frames=N,fps=FPS,loop_seconds=N/FPS,cell=[W,H],grid=[8,6],
              anchor=[192,BASELINE],periodic_endpoint_equal=True,
              boundary_delta=deltas[-1],median_frame_delta=float(np.median(deltas)),
              engine_visual_verification=False,
              note="Dense contact silhouette preserved. Original textured jets deformed mildly; textured drops move ballistically.")
(OUT/"metadata.json").write_text(json.dumps(metadata,ensure_ascii=False,indent=2),encoding="utf-8")
with zipfile.ZipFile(OUT/"white_impact_source_rig_v1.zip","w",zipfile.ZIP_DEFLATED) as z:
    for name in [name,"source_matte.png","preview.webp","contact.jpg","metadata.json"]:
        z.write(OUT/name,name)
print(json.dumps(metadata,ensure_ascii=False))
