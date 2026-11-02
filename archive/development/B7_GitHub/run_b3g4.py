"""Real H4E C region result over two repeated-source B3g2 video frames."""
import argparse
import hashlib
import json
import shutil
import sys
from datetime import datetime
from pathlib import Path

import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT/'scripts'))
sys.path.insert(0,str(ROOT/'model'))
from b1_tools import simulate
from check_b3_target_stream import FONT,paint_glyph
from check_calibration_status import render as cal_render
from check_tracking_text import render as track_render
from target_osd_reference import packet as result_pack,pack
from target_text_reference import lines as result_lines

WIDTH,HEIGHT=976,480


def reference(second):
    a=np.zeros((HEIGHT,WIDTH,3),np.uint8)
    a[250:350,300:400]=[200,0,0]
    c=cal_render(0,WIDTH,HEIGHT,FONT)
    for top in (112,136):a[top:top+16,16:976]=c[top:top+16,16:976]
    t=track_render(0,WIDTH,HEIGHT,FONT)
    for top in (160,184):a[top:top+16,16:976]=t[top:top+16,16:976]
    a[208:224,16:160]=[32,32,32]
    for col,ch in enumerate('MODE:RAW '):paint_glyph(a,208,col,ch,(0,255,255))
    if second:
        a[250:350,300:302]=[0,255,0];a[250:350,398:400]=[0,255,0]
        a[250:252,300:400]=[0,255,0];a[348:350,300:400]=[0,255,0]
        a[298:301,341:358]=[0,255,255];a[291:308,348:351]=[0,255,255]
        result=result_pack(frame=42,cfg=3,color=0,valid=1,area=9996,
            xmin=300,ymin=250,xmax=399,ymax=349,cx=349,cy=299,
            reason=0,slots=1,components=1)
    else:
        result=pack(dict(reason=4))
    for row,(top,line) in enumerate(zip((16,40,64,88),result_lines(result,second,42))):
        a[top:top+16,16:976]=[32,32,32]
        ink=(0,255,0) if second else (255,128,0)
        for col,ch in enumerate(line):
            paint_glyph(a,top,col,ch,ink if row==0 else (255,255,255))
    return a


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--modelsim',type=Path,required=True)
    a=p.parse_args()
    files=(ROOT/'b3g2_sources.f').read_text().splitlines()+[
        '../boards/hx1p35a/h4e/user_source/hdl_source/h4e_region_select.v',
        'sim/tb_b3g4_real_result_stream.v']
    run=ROOT/'build/b3g4_real_result_stream'/datetime.now().strftime('run_%Y%m%d_%H%M%S')
    run.mkdir(parents=True)
    summary=dict(passed=False,scope='real unchanged H4E region selector on B3g2 filtered mask',
        synthetic_epoch=True,board_tested=False,full_board_timing_verified=False,
        source_sha256={name:hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in files},cases=[])
    print(f'Reports: {run}',flush=True)
    try:
        for name in files:shutil.copy2(ROOT/name,run/Path(name).name)
        log=simulate(a.modelsim,run,[Path(name).name for name in files],
            'tb_b3g4_real_result_stream','PASS B3G4_REAL_RESULT:',timeout=900)
        if 'Errors: 0, Warnings: 0' not in log:
            raise RuntimeError('ModelSim reported errors or warnings')
        actual=np.fromfile(run/'actual.rgb',np.uint8).reshape(2,HEIGHT,WIDTH,3)
        for i in range(2):
            ref=reference(i==1)
            diff=np.any(actual[i]!=ref,axis=2)
            count=int(diff.sum())
            stem=f'{i:02d}_'+('repeat_with_target' if i else 'first_wait')
            Image.fromarray(actual[i]).save(run/f'{stem}_actual.png')
            Image.fromarray(ref).save(run/f'{stem}_reference.png')
            Image.fromarray((diff*255).astype(np.uint8)).save(run/f'{stem}_diff.png')
            summary['cases'].append(dict(frame=i,pixels=WIDTH*HEIGHT,
                result_visible=bool(i),pixel_differences=count))
            if count:
                raise RuntimeError(f'pixel mismatch frame {i}: {count} '
                    f'{np.argwhere(diff)[:10].tolist()}')
        summary['passed']=True
        print('PASS: B3g4 real C result video checks completed.',flush=True)
    finally:
        (run/'summary.json').write_text(json.dumps(summary,indent=2)+'\n',encoding='utf-8')


if __name__=='__main__':main()
