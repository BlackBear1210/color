"""승인된 다리 모양을 유지하고 이동 시간만 바꾸는 미적용 시안."""
import json
import math
from PIL import Image,ImageDraw
import 시안_발교대_발목보존 as preview

ORIGINAL_OUT=preview.OUT
OUT=preview.ROOT/'docs/visual_review/player_walk_20261012/발교대_박자조정_미적용시안'


def steady_progress(t,edge=.08):
    # 끝에서만 짧게 가속/감속하고 중간에서는 일정한 속도를 유지한다.
    if t<edge:
        return .5*(t-edge/math.pi*math.sin(math.pi*t/edge))/(1-edge)
    if t>1-edge:
        return 1-steady_progress(1-t,edge)
    return (t-edge*.5)/(1-edge)


def foot_position(q):
    # 돌아오는 발은 45%, 뒤로 가는 지지 동작은 55%를 사용한다.
    # 두 다리는 여전히 정확히 반 주기 차이이므로 좌우 박자는 같다.
    if q<.45:
        return 260+120*steady_progress(q/.45)
    return 380-120*steady_progress((q-.45)/.55)


def main():
    preview.OUT=OUT
    preview.foot_position=foot_position
    # GIF는 10ms 단위이므로 20/30ms를 교대해 한 주기 800ms를 정확히 맞춘다.
    preview.FRAME_DURATIONS=[20,30]*16
    preview.main()
    generated=OUT/'발목보존_발교대.gif'
    new_name=OUT/'발교대_박자조정.gif'
    generated.replace(new_name)
    old=Image.open(ORIGINAL_OUT/'발목보존_발교대.gif')
    new=Image.open(new_name)
    compare=[]
    for i in range(32):
        old.seek(i);new.seek(i)
        canvas=Image.new('RGB',(640,640),'#444950')
        for row in range(2):
            box=(0,row*320,320,(row+1)*320)
            canvas.paste(old.convert('RGB').crop(box),(0,row*320))
            canvas.paste(new.convert('RGB').crop(box),(320,row*320))
        d=ImageDraw.Draw(canvas)
        for row in range(2):
            d.rectangle((0,row*320,640,row*320+26),fill='#444950')
            d.text((8,row*320+8),'BEFORE / same 800ms cycle',fill='white')
            d.text((328,row*320+8),'AFTER / steady rhythm',fill='white')
        compare.append(canvas)
    compare[0].save(OUT/'같은속도_박자비교.gif',save_all=True,append_images=compare[1:],duration=preview.FRAME_DURATIONS,loop=0,optimize=False)
    # 전체 순서를 직접 관찰할 수 있도록 최종 GIF의 모든 교차 자세를 모은다.
    for color,top in [('black',95),('white',415)]:
        sheet=Image.new('RGB',(1280,1440),'#444950');d=ImageDraw.Draw(sheet)
        for i in range(32):
            new.seek(i);x,y=i%4*320,i//4*180
            sheet.paste(new.convert('RGB').crop((320,top,640,top+160)),(x,y+20))
            d.text((x+4,y+3),str(i),fill='white')
        sheet.save(OUT/f'{color}_32프레임_박자검토.png')
    # 실제 GIF의 지속 시간과 두 교차 시점, 중간 구간의 속도 편차를 확인한다.
    durations=[]
    for i in range(new.n_frames):
        new.seek(i);durations.append(new.info['duration'])
    assert sum(durations)==800
    assert abs(foot_position(.225)-foot_position(.725))<1e-8
    assert foot_position(0)<foot_position(.5)
    assert abs(steady_progress(.5)-.5)<1e-8
    report=json.loads((OUT/'검토.json').read_text(encoding='utf-8'))
    report.update({'cycle_ms':sum(durations),'step_interval_ms':400,'recovery_fraction':.45,'support_fraction':.55,'crossing_phases':[.225,.725],'geometry_changed':False,'old_cycle_ms':1600,'comparison_cycle_ms':800})
    (OUT/'검토.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print('Timing preview: 800ms cycle / 400ms alternating steps.',flush=True)


if __name__=='__main__':main()
