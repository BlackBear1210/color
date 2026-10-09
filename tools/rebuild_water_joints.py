"""승인 원본의 출수부와 넘침 턱을 복원해 수평 절단부를 제거한다."""
from pathlib import Path
from PIL import Image,ImageDraw
import numpy as np
root=Path(__file__).resolve().parents[1]
a=root/'assets/textures/obstacles/liquid/reference_20261008'
r=root/'docs/visual_review/water_reference_20261008'
src=Image.open(r/'source_outlet.png').convert('RGBA');w,h=src.size
cx,cy=w*.228,h*.149;rx,ry=w*.053,h*.093
box=(int(cx-rx-4),int(cy-ry-4),int(cx+rx+4),int(cy+ry+4))
p=src.crop(box).resize((320,320),Image.Resampling.LANCZOS)
arr=np.array(p);yy,xx=np.mgrid[:320,:320];v=arr[:,:,:3].mean(2)/255
# 구멍 안에서 시작하는 원본 물만 분리한다. 돌 테두리는 삼색으로 변색하지 않는다.
region=(yy>205)&(xx>94)&(xx<228)
alpha=np.clip((v-.48)/.18,0,1)*region
# 원본 물의 밝기로 자연스러운 출수 곡선과 양옆의 경사를 보존한다.
circle=Image.new('L',(320,320));ImageDraw.Draw(circle).ellipse((4,4,316,316),fill=255)
dry=arr.copy();dry[:,:,3]=np.array(circle)
# 물이 빠진 구멍은 원형 검정 내부로 남기고 외곽을 사각형으로 잘라내지 않는다.
dry[:,:,:3][region&(alpha>.05)]=5
dry[:,:,3][region&(alpha>.05)&(yy>=288)]=0
# 물과 맞닿는 돌 테두리 끝은 작은 둥근 접선으로 마감해 삼각형 꼭지가 남지 않게 한다.
for side in [-1,1]:
 center=78 if side<0 else 242
 terminal=(yy>268)&((xx>76)&(xx<105) if side<0 else (xx>215)&(xx<244))
 distance=np.sqrt(((xx-center)/25)**2+((yy-266)/24)**2)
 rounded=np.clip((1.025-distance)/.05,0,1)
 dry[:,:,3][terminal]=np.uint8(dry[:,:,3][terminal]*rounded[terminal])
Image.fromarray(dry).save(a/'pipe_joint_dry.png')
for tone in range(3):
 cap=arr.copy();val=v.copy()
 if tone==0:val=.015+v*.05
 elif tone==2:val=.34+v*.23
 cap[:,:,:3]=np.uint8(np.repeat(val[:,:,None],3,axis=2)*255)
 cap[:,:,3]=np.uint8(alpha*np.clip((320-yy)/24,0,1)*255)
 Image.fromarray(cap).save(a/f'pipe_joint_water_{tone}.png')
# 물받이 원본의 깊이를 유지하고 실제 넘침 부분을 별도 층으로 확보한다.
box=(int(w*.509),int(h*.244),int(w*.870),int(h*.54))
b=np.array(src.crop(box).resize((768,360),Image.Resampling.LANCZOS));yy,xx=np.mgrid[:360,:768]
val=b[:,:,:3].mean(2)/255
for tone in range(3):
 cap=b.copy();inside=(xx>76)&(xx<692)&(yy>140)&(yy<252)
 alpha=np.clip((val-.43)/.19,0,1)*inside*np.clip((252-yy)/38,0,1)
 col=val if tone==1 else (.035+val*.13 if tone==0 else .34+val*.23)
 cap[:,:,:3]=np.uint8(np.repeat(col[:,:,None],3,axis=2)*255);cap[:,:,3]=np.uint8(alpha*np.clip((320-yy)/24,0,1)*255)
 Image.fromarray(cap).save(a/f'basin_overflow_{tone}.png')
# 넓은 물의 무늬를 해상도 두 배로 만들어 확대 시 뭉개짐을 줄인다.
tex=np.array(src.crop((int(w*.578),int(h*.43),int(w*.803),int(h*.91))).resize((512,512),Image.Resampling.LANCZOS))[:,:,:3].mean(2)/255
v=np.maximum(tex,.70)
for k in range(24):
 mix=(k/24)**2;edge=(v[k]+v[-1-k])*.5;v[k]=edge*(1-mix)+v[k]*mix;v[-1-k]=edge*(1-mix)+v[-1-k]*mix
for tone in range(3):
 atlas=Image.new('RGBA',(4096,3072))
 for f in range(48):
  value=np.roll(v,int(f*512/48),axis=0)
  if tone==0:value=.025+(value-.70)*.5
  elif tone==2:value=.35+(value-.70)*.7
  rgba=np.uint8(np.dstack([np.repeat(value[:,:,None],3,axis=2),np.ones_like(value)])*255)
  atlas.paste(Image.fromarray(rgba),((f%8)*512,(f//8)*512))
 atlas.save(a/f'wide_joint_{tone}_48.png')
print('Original curved nozzle water, overflow joint and sharp wide frames restored')
# 뒤벽의 원본 급수 흔적을 지울 때 벽 자체가 뚫리지 않도록 옆 돌 질감을 잇는다.
base=b.copy()
base[:86,322:438]=base[:86,462:578]
mask=Image.new('L',(768,360));draw=ImageDraw.Draw(mask)
pts=[(.08,0),(.91,0),(1,.36),(1,.62),(.95,.62),(.95,.99),(.90,.99),(.90,.64),(.10,.64),(.10,.99),(.05,.99),(.05,.62),(0,.62),(0,.36)]
draw.polygon([(int(x*768),int(y*360)) for x,y in pts],fill=255)
draw.rectangle((76,172,691,360),fill=0)
for tone in range(3):
 hardware=base.copy();hardware[:,:,3]=np.array(mask)
 v=hardware[:,:,:3].mean(2)/255
 water=(xx>76)&(xx<692)&(yy>83)&(yy<176)&(v>.55)
 if tone!=1:
  col=.035+v*.13 if tone==0 else .34+v*.23
  hardware[:,:,:3][water]=np.uint8(np.repeat(col[:,:,None],3,axis=2)*255)[water]
 Image.fromarray(hardware).save(a/f'catch_joint_basin_{tone}.png')
