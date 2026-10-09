"""승인된 힉스필드 원본에서 삼색 물 프레임과 출수구 부품을 분리한다.
벽 배경은 게임 배경과 중복되지 않게 제거하고, 세 색의 원본 명암을 보존한다.
"""
from pathlib import Path
import json, shutil, hashlib
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/textures/obstacles/liquid/reference_20261008'; OUT.mkdir(parents=True,exist_ok=True)
REVIEW=ROOT/'docs/visual_review/water_reference_20261008'; REVIEW.mkdir(parents=True,exist_ok=True)
src=REVIEW/'source_water.png'
pipe=REVIEW/'source_outlet.png'
a=np.asarray(Image.open(src).convert('RGB'),dtype=float)/255; H,W=a.shape[:2]
# 물 본체만 표본으로 읽는다. 바닥 물보라는 기존 실제 영상 프레임을 별도 재생한다.
frames_all=[]
for tone,(cx,left,right) in enumerate([(0.795,0.727,0.857),(0.212,0.145,0.278),(0.501,0.434,0.569)]):
 crop=Image.fromarray(np.uint8(a[:int(H*.87),int(W*left):int(W*right)]*255)).resize((192,512),Image.Resampling.LANCZOS)
 tex=np.asarray(crop,dtype=float)/255
 # 수직 반복 이음은 원본 위아래 표본을 부드럽게 만나게 한다. 거울 반전으로 가로 띠를 만들지 않는다.
 for k in range(24):
  mix=(k/24)**2; edge=(tex[k]+tex[-1-k])*.5
  tex[k]=edge*(1-mix)+tex[k]*mix;tex[-1-k]=edge*(1-mix)+tex[-1-k]*mix
 yy,xx=np.mgrid[:512,:256]; yn=yy/512
 atlas=Image.new('RGBA',(2048,3072)); frames=[]
 for f in range(48):
  t=f/48*2*np.pi
  # 세로 무늬와 윤곽 위상이 아래로 진행한다. 본체 전체가 좌우로 흔들리는 변형은 쓰지 않는다.
  shift=3*np.sin(yn*18-t*2)+1.4*np.sin(yn*37-t*3)
  half=81+3*np.sin(yn*24-t*2)+2*np.sin(yn*41-t*3)
  alpha=np.clip((half-np.abs(xx-128-shift))/1.1,0,1)
  u=(xx-128-shift)/np.maximum(half,1)
  sx=np.clip(((u*.46+.5)*191).astype(int),0,191)
  # 끝단이 되돌아갈 때 무늬가 튀지 않도록 표본을 거울 반복해 두 초마다 같은 프레임이 된다.
  sy=((yy-f*512/48)%512).astype(int)
  rgb=tex[sy,sx].copy()
  # 게임 색 판정에 맞춰 벽 조각과 과도한 투명도만 제거한다. 반사선은 원본에서 가져온다.
  v=rgb.mean(2)
  if tone==1: rgb=np.maximum(rgb,.80)
  elif tone==2: rgb=np.clip(rgb,.35,.64)
  else: rgb=np.clip(rgb,0,.30)
  # 긴 찢김 대신, 소수의 짧은 틈이 내려오며 생겼다가 닫힌다.
  for j in range(2):
   phase=(f/48+j*.5)%1
   gy=phase*540-14; gx=128+(-17 if j==0 else 21)
   envelope=np.sin(np.pi*phase)**2
   gap=np.clip(1-(((xx-gx)/2.5)**2+((yy-gy)/10)**2),0,1)*envelope
   alpha*=1-gap
  rgba=np.uint8(np.dstack([rgb,alpha])*255)
  im=Image.fromarray(rgba)
  # 좌우 한 개씩, 비동기 낙하. 물색을 공유하고 폭이 커져도 개수가 증가하지 않는다.
  draw=ImageDraw.Draw(im)
  col=[(26,26,26,255),(240,240,240,255),(135,135,135,255)][tone]
  for side in [-1,1]:
   ph=(f/48+(0 if side<0 else .47))%1; dy=28+ph*ph*415; dx=128+side*(94+ph*5)
   draw.ellipse((dx-1.5,dy-3.5,dx+1.5,dy+3.5),fill=col)
   draw.line((dx-0.3,dy-2,dx-0.3,dy),fill=(210,210,210,220),width=1)
  atlas.paste(im,((f%8)*256,(f//8)*512)); frames.append(im)
 atlas.save(OUT/f'water_{tone}_48.png'); frames_all.append(frames)
# 原본 원형 배관의 둥근 외곽만 분리한다. 관 내부의 검정은 투명 처리하지 않는다.
b=Image.open(pipe).convert('RGBA'); pw,ph=b.size
cx,cy=pw*.228,ph*.149; rx,ry=pw*.053,ph*.093
box=(int(cx-rx-4),int(cy-ry-4),int(cx+rx+4),int(cy+ry+4))
part=b.crop(box); mask=Image.new('L',part.size); d=ImageDraw.Draw(mask); d.ellipse((4,4,part.width-4,part.height-4),fill=255)
part.putalpha(mask); part.resize((320,320),Image.Resampling.LANCZOS).save(OUT/'round_pipe.png')
# 받이의 상판/벽/지지대만 따낸다. 아래 폭포와 배경은 포함하지 않는다.
box=(int(pw*.509),int(ph*.244),int(pw*.870),int(ph*.54)); basin=b.crop(box)
mask=Image.new('L',basin.size); d=ImageDraw.Draw(mask)
pts=[(.08,0),(.91,0),(1,.36),(1,.62),(.95,.62),(.95,.99),(.90,.99),(.90,.64),(.10,.64),(.10,.99),(.05,.99),(.05,.62),(0,.62),(0,.36)]
d.polygon([(int(x*basin.width),int(y*basin.height)) for x,y in pts],fill=255)
# 낙수 시작점 아래 가운데는 투명하게 하여 물을 가리지 않는다.
d.rectangle((int(.10*basin.width),int(.48*basin.height),int(.90*basin.width),basin.height),fill=0)
basin.putalpha(mask); basin.resize((768,360),Image.Resampling.LANCZOS).save(OUT/'catch_basin.png')
canvas=Image.new('RGBA',(900,570),(25,25,25,255))
for tone in range(3): canvas.alpha_composite(frames_all[tone][0],(tone*300+20,30))
canvas.convert('RGB').save(REVIEW/'frames_preview.jpg',quality=92)
preview=[]
for f in range(48):
 im=Image.new('RGBA',(900,570),(25,25,25,255))
 for tone in range(3): im.alpha_composite(frames_all[tone][f],(tone*300+20,30))
 preview.append(im.convert('RGB'))
preview[0].save(REVIEW/'three_colors_motion.webp',save_all=True,append_images=preview[1:],duration=[42,42,41]*16,loop=0,quality=86)
meta={'source_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'pipe_source_sha256':hashlib.sha256(pipe.read_bytes()).hexdigest(),'frames':48,'fps':24,'loop_seconds':2,'cell':[256,512],'grid':[8,6],'method':'reference texture advection + downward edge phases + sparse falling beads; no newly generated video','tone_ids':{'black':0,'white':1,'gray':2}}
(OUT/'metadata.json').write_text(json.dumps(meta,indent=2),encoding='utf8')
print('Generated three 48-frame atlases, pipe and basin')

# 넓은 물막은 승인된 받이 시안의 실제 넓은 물 무늬를 사용한다.
from pathlib import Path
from PIL import Image
import numpy as np
out=Path("assets/textures/obstacles/liquid/reference_20261008")
src=Image.open(REVIEW/'source_outlet.png').convert("RGB");w,h=src.size
tex=np.asarray(src.crop((int(w*.578),int(h*.43),int(w*.803),int(h*.91))).resize((256,512),Image.Resampling.LANCZOS),dtype=float)/255
v=np.maximum(tex.mean(2),.80)
for k in range(24):
 mix=(k/24)**2;edge=(v[k]+v[-1-k])*.5;v[k]=edge*(1-mix)+v[k]*mix;v[-1-k]=edge*(1-mix)+v[-1-k]*mix
y,x=np.mgrid[:512,:256]
for tone in range(3):
 atlas=Image.new("RGBA",(2048,3072))
 for f in range(48):
  sy=((y-f*512/48)%512).astype(int);value=v[sy,x]
  if tone==0: value=.025+(value-.80)*.80
  elif tone==2: value=.38+(value-.80)*1.0
  rgb=np.repeat(value[:,:,None],3,axis=2);im=Image.fromarray(np.uint8(np.dstack([rgb,np.ones_like(value)])*255));atlas.paste(im,((f%8)*256,(f//8)*512))
 atlas.save(out/f"wide_{tone}_48.png")
