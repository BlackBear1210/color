"""큰 물막 흔들림 대신 짧은 분사·절단·탄도 낙하를 굽는다. 엔진은 실행하지 않는다."""
from pathlib import Path
import sys, math, json, hashlib, zipfile
import numpy as np
from PIL import Image, ImageDraw
SOURCE,OUT=Path(sys.argv[1]),Path(sys.argv[2])
OUT.mkdir(parents=True,exist_ok=True)
W,H,N,FPS,BASELINE=384,128,48,30,112
DURATION=N/FPS
# 이전 힉스필드 원본의 색과 반투명 질감을 복원한다.
rgb=np.asarray(Image.open(SOURCE).convert("RGB"),dtype=np.float32)/255
alpha=np.clip(1-(np.maximum(rgb[:,:,0],rgb[:,:,2])-rgb[:,:,1]),0,1)
alpha[(alpha<.08)|(rgb[:,:,1]<.045)]=0
alpha[:220]=0; alpha[550:]=0
value=np.clip(rgb[:,:,1]/np.maximum(alpha,.0001),0,1)
src=np.dstack([value,value,value,alpha])
source_image=Image.fromarray(np.uint8(src*255))
scale=352/source_image.width
small=source_image.resize((352,round(source_image.height*scale)),Image.Resampling.LANCZOS)
base=Image.new("RGBA",(W,H))
base.alpha_composite(small,(16,BASELINE-round(500*scale)))
a=np.asarray(base,dtype=np.float32)/255
yy,xx=np.mgrid[:H,:W].astype(float)
# 원본의 길고 붙어 있는 물살을 제거한다. 지면 물막과 충돌점의 낮은 거품만 남긴다.
contact=np.clip((yy-91)/16,0,1)*np.clip((68-np.abs(xx-W/2))/22,0,1)
film=np.clip((yy-105)/3,0,1)
a[:,:,3]*=np.maximum(contact,film)
a[:,:,:3]*=a[:,:,3:4]
rng=np.random.default_rng(20261007)
def lookup(sx,sy):
    sx=np.clip(sx,0,src.shape[1]-1.001); sy=np.clip(sy,0,src.shape[0]-1.001)
    ix=sx.astype(int); iy=sy.astype(int)
    fx=(sx-ix)[...,None]; fy=(sy-iy)[...,None]
    return (src[iy,ix]*(1-fx)*(1-fy)+src[iy,ix+1]*fx*(1-fy)
            +src[iy+1,ix]*(1-fx)*fy+src[iy+1,ix+1]*fx*fy)
def over(dst,layer):
    # 배열끼리는 미리 곱한 색으로 합성해 가는 물살 가장자리의 검은 테두리를 막는다.
    return layer+dst*(1-layer[:,:,3:4])

# 서로 다른 시점에 짧게 분사한다. 주기는 1.6초의 약수라 반복 경계에서도 연속이다.
emitters=[]
for side in (-1,1):
    for j in range(7):
        period=DURATION/[2,3,4,5,4,3,5][j]
        emitters.append(dict(side=side,period=period,offset=float(rng.uniform(0,period)),
                             origin=float(rng.uniform(6,22)),
                             vx=float(rng.uniform(235,320)),vy=float(rng.uniform(320,450)),
                             width=float(rng.uniform(2.6,4.6)),g=2000.0))
# 원본 물방울의 명암과 비정형 외곽을 사용한다. 입자는 도형으로 다시 그리지 않는다.
patches=[]
for x,y,r in [(163,490,11),(216,442,12),(104,417,12),(1136,458,12),(1196,486,13)]:
    patch=source_image.crop((x-r,y-r,x+r+1,y+r+1))
    patch=patch.resize((max(3,round(patch.width*scale)),max(3,round(patch.height*scale))),Image.Resampling.LANCZOS)
    patches.append(patch)
def place_drop(frame,index,x,y,opacity,size,angle):
    patch=patches[index%len(patches)]
    patch=patch.resize((max(2,round(patch.width*size)),max(2,round(patch.height*size))),Image.Resampling.LANCZOS)
    patch=patch.rotate(-angle,resample=Image.Resampling.BICUBIC,expand=True)
    patch.putalpha(Image.fromarray(np.uint8(np.asarray(patch.getchannel("A"),dtype=float)*opacity)))
    frame.alpha_composite(patch,(round(x-patch.width/2),round(y-patch.height/2)))

frames=[]
events=[]
for k in range(N+1):
    t=(k%N)/FPS
    premul=a.copy()
    visible_jets=0
    # 물은 정현파로 흔들리지 않는다. 충돌점에서 발사된 물의 나이로 위치를 계산한다.
    for ei,e in enumerate(emitters):
        age=(t+e["offset"])%e["period"]
        side,vx,vy,g=e["side"],e["vx"],e["vy"],e["g"]
        origin=W/2+side*e["origin"]
        # 선두가 먼저 뻗고, 65ms 뒤 뿌리가 끊겨 짧은 물 조각이 바깥으로 이동한다.
        head=min(age,.14)
        tail=max(0,age-.065)
        if tail<head and age<.205:
            u=(xx-origin)/(side*vx)
            cy=BASELINE-vy*u+.5*g*u*u
            slope=(-vy+g*u)/(side*vx)
            cross=(yy-cy)/np.sqrt(1+slope*slope)
            width=e["width"]*(1-.65*np.clip(u/.14,0,1))
            across=cross/np.maximum(width,.4)
            longitudinal=np.clip(u/.14,0,1)
            # 원본의 유리 같은 물살을 종방향/폭방향으로 읽는다. 형태는 발사 궤적으로 결정한다.
            sx=548-213*longitudinal+across*15*.505
            sy=491-125*longitudinal-across*15*.863
            layer=lookup(sx,sy)
            edge=np.clip((1-np.abs(across))/.20,0,1)
            end=np.clip((u-tail)/.010,0,1)*np.clip((head-u)/.008,0,1)
            coverage=edge*end*np.clip((.205-age)/.025,0,1)
            layer[:,:,3]*=coverage
            layer[:,:,:3]*=layer[:,:,3:4]
            premul=over(premul,layer)
            visible_jets+=1
        # 착수 거품은 짧게 밝아졌다 바로 꺼진다. 넓은 덩어리를 좌우로 휘지 않는다.
        flash=max(0,1-age/.09)
        if flash:
            radius=(xx-origin)**2/55+(yy-BASELINE+3)**2/13
            pulse=np.exp(-radius)*flash*.35
            foam=np.dstack([pulse,pulse,pulse,pulse])
            premul=over(premul,foam)
    straight=premul.copy()
    straight[:,:,:3]/=np.maximum(straight[:,:,3:4],.0001)
    frame=Image.fromarray(np.uint8(np.clip(straight*255,0,255)))
    visible_drops=0
    # 분사가 끊어질 때 같은 궤도의 선두 물방울 3개가 분리된다. 중력으로 지면에 돌아오면 소멸한다.
    for ei,e in enumerate(emitters):
        age=(t+e["offset"])%e["period"]
        # 다음 분사가 시작되어도 앞서 나온 물방울은 지면에 닿을 때까지 따로 유지한다.
        for cycle_back in range(2):
            age=((t+e["offset"])%e["period"])+cycle_back*e["period"]
            for q in range(3):
                vx=e["vx"]*[1,.81,1.08][q]
                vy=e["vy"]*[1,.73,.55][q]
                flight=2*vy/e["g"]
                if age<.085 or age>=flight:
                    continue
                opacity=min(1,(age-.085)/.026)*min(1,(flight-age)/.035)
                x=W/2+e["side"]*(e["origin"]+vx*age)
                y=BASELINE-vy*age+.5*e["g"]*age*age
                size=[.90,.60,.40][q]
                angle=math.degrees(math.atan2(-vy+e["g"]*age,e["side"]*vx))
                # 현재 속도 방향으로 아주 짧은 흔적을 남겨 분출 속도를 보이게 한다.
                for lag,factor in [(.008,.12),(.004,.23),(0,1)]:
                    lt=age-lag
                    px=W/2+e["side"]*(e["origin"]+vx*lt)
                    py=BASELINE-vy*lt+.5*e["g"]*lt*lt
                    place_drop(frame,ei+q,px,py,opacity*factor,size,angle)
                visible_drops+=1
    frames.append(frame)
    events.append(dict(frame=k,jets=visible_jets,drops=visible_drops))
assert np.array_equal(np.asarray(frames[0]),np.asarray(frames[N]))
sheet=Image.new("RGBA",(W*8,H*6))
for k,f in enumerate(frames[:N]):
    assert f.getbbox() and f.getbbox()[0]>0 and f.getbbox()[2]<W and f.getbbox()[1]>0 and f.getbbox()[3]<H
    sheet.paste(f,((k%8)*W,(k//8)*H))
name="white_splash_f48_384x128_g8x6_fps30_loop.png"
sheet.save(OUT/name)
previews=[]
for f in frames[:N]:
    bg=Image.new("RGBA",(576,232),(18,20,23,255))
    draw=ImageDraw.Draw(bg)
    draw.line((0,200,576,200),fill=(85,86,88),width=2)
    bg.alpha_composite(f.resize((576,192),Image.Resampling.LANCZOS),(0,32))
    draw.text((12,10),"ASSET PREVIEW / burst > break > droplets > fall / 30 fps",fill="white")
    previews.append(bg.convert("RGB"))
previews[0].save(OUT/"splash_preview.webp",save_all=True,append_images=previews[1:],duration=[33,33,34]*16,loop=0,quality=95,method=6)
contact=Image.new("RGB",(1152,928),(18,20,23))
for j,k in enumerate(range(0,24,3)):
    contact.paste(previews[k],((j%2)*576,(j//2)*232))
    ImageDraw.Draw(contact).text(((j%2)*576+12,(j//2)*232+28),f"FRAME {k:02d} / {events[k]['jets']} jets + {events[k]['drops']} drops",fill="white")
contact.save(OUT/"splash_contact.jpg",quality=92)
arrays=[np.asarray(f,dtype=np.float32) for f in frames[:N]]
deltas=[float(np.abs(arrays[(i+1)%N]-arrays[i]).mean()) for i in range(N)]
meta=dict(version=2,source_sha256=hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
          frames=N,fps=FPS,loop_seconds=DURATION,cell=[W,H],grid=[8,6],anchor=[192,112],
          method="Ballistic texture emitters. No sinusoidal warping. No persistent long jets.",
          gravity=2000,root_detach_seconds=.065,jet_end_seconds=.205,
          visible_events=events[:N],periodic_endpoint_equal=True,
          boundary_delta=deltas[-1],median_frame_delta=float(np.median(deltas)),
          engine_visual_verification=False)
(OUT/"metadata.json").write_text(json.dumps(meta,indent=2),encoding="utf-8")
with zipfile.ZipFile(OUT/"white_splash_burst_v2.zip","w",zipfile.ZIP_DEFLATED) as z:
    for p in [name,"splash_preview.webp","splash_contact.jpg","metadata.json"]: z.write(OUT/p,p)
print(json.dumps({k:v for k,v in meta.items() if k!="visible_events"}))
