"""Check B3g6 closed-loop pixels with B4 latency statistics and text added."""
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
from b1_tools import simulate
from check_b3_target_stream import paint_glyph
from run_b3g6 import reference as b3_reference
from run_b4b import paint_slash

WIDTH,HEIGHT,NFRAMES=976,480,4
LINES=[
    ['LAT:N/A',''],
    ['LAT TYPE:RES N HEX:008 MIN HEX US:0000000A',
     'AVG HEX US:00000014 MAX HEX US:0000001E SIM'],
    ['LAT TYPE:EXT N HEX:008 MIN HEX US:FFFFFFFF',
     'AVG HEX US:FFFFFFFF MAX HEX US:FFFFFFFF SIM'],
    ['LAT TYPE:EXT N HEX:008 MIN HEX US:00000000',
     'AVG HEX US:00000000 MAX HEX US:00000000 SIM'],
]


def reference(index):
    image=b3_reference(bool(index%2),stale=index==2)
    for top,line in zip((208,232),LINES[index]):
        if top==208:image[top:top+16,176:880]=32
        else:image[top:top+16,16:720]=32
        for col,ch in enumerate(line):
            shifted=col+10 if top==208 else col
            if ch=='/':paint_slash(image,top,shifted)
            else:paint_glyph(image,top,shifted,ch,(0,255,255))
    return image


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--modelsim',type=Path,required=True)
    args=parser.parse_args()
    files=(ROOT/'b3g2_sources.f').read_text().splitlines()+[
        '../boards/hx1p35a/h4e/user_source/hdl_source/h4e_region_select.v',
        'rtl/video_b3_h4e_sameclk.v',
        'rtl/latency_window_stats.v',
        'rtl/video_latency_text.v',
        'rtl/video_b4_h4e_sameclk.v',
        'sim/tb_b4c_sameclk_latency.v']
    run=ROOT/'build/b4c_sameclk_latency'/datetime.now().strftime('run_%Y%m%d_%H%M%S')
    run.mkdir(parents=True,exist_ok=True)
    summary={'stage':'B4c','passed':False,'synthetic_latency':True,
             'synthetic_epoch':True,'board_tested':False,'cases':[],
             'source_sha256':{name:hashlib.sha256((ROOT/name).read_bytes()).hexdigest()
                              for name in files}}
    print('Reports:',run,flush=True)
    try:
        for name in files:shutil.copy2(ROOT/name,run/Path(name).name)
        log=simulate(args.modelsim,run,[Path(name).name for name in files],
                     'tb_b4c_sameclk_latency','PASS B4C_SAMECLK_LATENCY:',timeout=1200)
        if 'Errors: 0, Warnings: 0' not in log:
            raise RuntimeError('ModelSim errors or warnings')
        actual=np.fromfile(run/'actual.rgb',np.uint8).reshape(NFRAMES,HEIGHT,WIDTH,3)
        for index in range(NFRAMES):
            expected=reference(index)
            diff=np.any(actual[index]!=expected,axis=2)
            mismatch=int(diff.sum())
            Image.fromarray(actual[index]).save(run/f'{index:02d}_actual.png')
            Image.fromarray(expected).save(run/f'{index:02d}_reference.png')
            Image.fromarray((diff*255).astype(np.uint8)).save(run/f'{index:02d}_diff.png')
            summary['cases'].append({'frame':index,'pixels':WIDTH*HEIGHT,
                                     'pixel_differences':mismatch})
            if mismatch:
                raise RuntimeError(f'frame {index}: {mismatch} different pixels; '
                                   f'first {np.argwhere(diff)[:10].tolist()}')
        summary['passed']=True
        print('PASS: B4c closed-loop latency OSD checks completed.',flush=True)
    finally:
        (run/'summary.json').write_text(json.dumps(summary,indent=2)+'\n',encoding='utf-8')


if __name__=='__main__':main()
