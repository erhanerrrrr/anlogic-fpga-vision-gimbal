"""B3g2 strict-source target overlay on four-mode status display."""
import argparse,hashlib,json,shutil,sys
from pathlib import Path
from datetime import datetime
import numpy as np
from PIL import Image,ImageDraw
from b1_tools import simulate
from check_calibration_status import pack as cal_pack,render as cal_render
from check_tracking_text import packet as track_pack,render as track_render
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'model'))
from target_osd_reference import packet as result_pack
from target_text_reference import lines as result_lines

ROOT=Path(__file__).resolve().parents[1]
FONT=json.loads((ROOT/'assets/osd/target_font_5x7.json').read_text())
LOGO_FILE=ROOT.parent/'boards/hx1p35a/h4e/assets/logo_reference.hex'
LOGO=np.array([int(v,16) for v in LOGO_FILE.read_text().split()],np.uint32).reshape(160,160)
def plans(native):
    if native:return [dict(mode=0,cal=cal_pack(phase=4,result=1,cfg=2,color=0,main=168,d1=148,d2=138),
                           track=track_pack(state=2,pan_us=1200,tilt_us=1800),roi=True)]
    return [
        dict(mode=0,cal=cal_pack(),track=track_pack(state=0),roi=True),
        dict(mode=1,cal=cal_pack(phase=3,result=1),track=track_pack(state=1),roi=True),
        dict(mode=2,cal=cal_pack(phase=4,result=1,cfg=2,color=0,main=168,d1=148,d2=138),
             track=track_pack(state=2,pan_us=1200,tilt_us=1800),roi=True),
        dict(mode=3,cal=cal_pack(phase=5,result=2,reason=5,cfg=2,color=0,main=168,d1=148,d2=138),
             track=track_pack(state=5,pan_limit=1,tilt_limit=1),roi=False)]
def paint_glyph(image,y,col,ch,ink):
    x=16+col*16
    for gy,row in enumerate(FONT.get(ch,['00000']*7)):
        for gx,on in enumerate(row):
            if on=='1':image[y+1+gy*2:y+3+gy*2,x+3+gx*2:x+5+gx*2]=ink
def target_reference(a,index,ready=True):
    valid=index!=3
    packet=result_pack(frame=index+1,cfg=3,color=0,valid=int(valid),
        area=500 if valid else 0,xmin=300 if valid else 0,ymin=250 if valid else 0,
        xmax=399 if valid else 0,ymax=349 if valid else 0,
        cx=349 if valid else 0,cy=299 if valid else 0,
        reason=0 if valid else 1,slots=7,components=2)
    if valid:
        a[250:350,300:302]=[0,255,0];a[250:350,398:400]=[0,255,0]
        a[250:252,300:400]=[0,255,0];a[348:350,300:400]=[0,255,0]
        a[298:301,341:358]=[0,255,255];a[291:308,348:351]=[0,255,255]
    ink=(0,255,0) if valid else (255,255,0)
    for row,(top,line) in enumerate(zip((16,40,64,88),result_lines(packet,ready,index+1))):
        a[top:top+16,16:976]=[32,32,32]
        for col,ch in enumerate(line):paint_glyph(a,top,col,ch,ink if row==0 else (255,255,255))
    return a
def reference(w,h,p):
    mode=p['mode']
    if mode==0:
        a=np.zeros((h,w,3),np.uint8);a[:,:,0]=200
    elif mode==1:a=np.full((h,w,3),60,np.uint8)
    elif mode==2:a=np.zeros((h,w,3),np.uint8)
    else:
        a=np.zeros((h,w,3),np.uint8);a[1:-1,1:-1]=255
    if p['roi']:
        left,top=(w-16)//2,(h-16)//2
        a[top,left:left+16]=[255,255,0];a[top+15,left:left+16]=[255,255,0]
        a[top:top+16,left]=[255,255,0];a[top:top+16,left+15]=[255,255,0]
    c=cal_render(p['cal'],w,h,FONT)
    for top in (112,136):a[top:top+16,16:976]=c[top:top+16,16:976]
    t=track_render(p['track'],w,h,FONT)
    for top in (160,184):a[top:top+16,16:976]=t[top:top+16,16:976]
    if h>=224:
        a[208:224,16:160]=[32,32,32]
        text=['RAW ','GRAY','EDGE','MASK'][mode]
        for col,ch in enumerate('MODE:'+text):paint_glyph(a,208,col,ch,(0,255,255))
    if w==1280:
        patch=a[16:176,1104:1264];opaque=(LOGO>>24)!=0
        colors=np.stack(((LOGO>>16)&255,(LOGO>>8)&255,LOGO&255),axis=-1).astype(np.uint8)
        patch[opaque]=colors[opaque]
    return a
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--modelsim',type=Path,required=True);a=parser.parse_args()
    run=ROOT/'build/b3_target_stream'/datetime.now().strftime('run_%Y%m%d_%H%M%S');run.mkdir(parents=True)
    print(f'Reports: {run}',flush=True)
    files=(ROOT/'b3g2_sources.f').read_text().splitlines()+['sim/tb_b3_target_stream.v']
    summary=dict(passed=False,board_tested=False,full_board_timing_verified=False,
        source_sha256={f:hashlib.sha256((ROOT/f).read_bytes()).hexdigest() for f in files},
        logo_sha256=hashlib.sha256(LOGO_FILE.read_bytes()).hexdigest(),cases=[])
    try:
        for name,w,h in [('four_modes',976,480),('native_720p',1280,720)]:
            dest=run/name;dest.mkdir()
            for f in files:shutil.copy2(ROOT/f,dest/Path(f).name)
            cases=plans(name=='native_720p')
            scenario=[]
            for i,p in enumerate(cases):
                scenario.append(f"expected_modes[{i}]=2'd{p['mode']};cal_packets[{i}]=51'h{p['cal']:013x};tracking_packets[{i}]=38'h{p['track']:010x};")
            (dest/'b3f_scenarios.vh').write_text('\n'.join(scenario)+'\n')
            simulate(a.modelsim,dest,[Path(f).name for f in files],'tb_b3_target_stream','PASS B3G2_TARGET:',
                [f'-gWIDTH={w}',f'-gHEIGHT={h}',f'-gNFRAMES={len(cases)}'],timeout=1800)
            actual=np.fromfile(dest/'actual.rgb',np.uint8).reshape(len(cases),h,w,3)
            for i,p in enumerate(cases):
                ref=target_reference(reference(w,h,p),i);diff=np.any(actual[i]!=ref,axis=2)
                stem=f'{i:02d}_mode{p["mode"]}'
                Image.fromarray(actual[i]).save(dest/f'{stem}_actual.png')
                Image.fromarray(ref).save(dest/f'{stem}_reference.png')
                Image.fromarray((diff*255).astype(np.uint8)).save(dest/f'{stem}_diff.png')
                assert not diff.any(),(name,i,int(diff.sum()),np.argwhere(diff)[:10].tolist())
                summary['cases'].append(dict(group=name,frame=i,mode=p['mode'],roi=p['roi'],
                    dimensions=[w,h],cal=f'{p["cal"]:013x}',track=f'{p["track"]:010x}',pixel_differences=0))
            print(f'PASS: {name}, {len(cases)} frame(s), zero pixel differences',flush=True)
        summary['passed']=True
    finally:(run/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
if __name__=='__main__':main()
