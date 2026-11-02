"""Render and compare B4b synthetic latency OSD from actual ModelSim pixels."""
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
from check_b3_target_stream import FONT,paint_glyph

WIDTH,HEIGHT,NFRAMES=896,288,4


def paint_slash(image,y,col):
    x=16+col*16
    for row in range(1,15):
        left=x+15-row
        image[y+row,left:left+2]=[0,255,255]


def reference(index):
    image=np.full((HEIGHT,WIDTH,3),16,np.uint8)
    image[208:224,176:880]=32
    image[232:248,16:720]=32
    if index==0:
        lines=['LAT:N/A','']
    elif index==1:
        lines=['LAT TYPE:RES N HEX:008 MIN HEX US:0000000A',
               'AVG HEX US:00000014 MAX HEX US:0000001E SIM']
    elif index==2:
        lines=['LAT TYPE:EXT N HEX:008 MIN HEX US:FFFFFFFF',
               'AVG HEX US:FFFFFFFF MAX HEX US:FFFFFFFF SIM']
    else:
        lines=['LAT TYPE:EXT N HEX:008 MIN HEX US:00000000',
               'AVG HEX US:00000000 MAX HEX US:00000000 SIM']
    for top,line in zip((208,232),lines):
        for col,ch in enumerate(line):
            shifted=col+10 if top==208 else col
            if ch=='/':paint_slash(image,top,shifted)
            else:paint_glyph(image,top,shifted,ch,(0,255,255))
    return image


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--modelsim',type=Path,required=True)
    args=parser.parse_args()
    files=(ROOT/'b4b_sources.f').read_text().splitlines()
    run=ROOT/'build/b4b_latency_text'/datetime.now().strftime('run_%Y%m%d_%H%M%S')
    run.mkdir(parents=True,exist_ok=True)
    summary={'stage':'B4b','passed':False,'synthetic_input':True,'board_tested':False,
             'cases':[], 'source_sha256':{
                 name:hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in files}}
    print('Reports:',run,flush=True)
    try:
        for name in files:shutil.copy2(ROOT/name,run/Path(name).name)
        log=simulate(args.modelsim,run,[Path(name).name for name in files],
                     'tb_b4b_latency_text','PASS B4B_LATENCY_TEXT:',timeout=1200)
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
        print('PASS: B4b latency OSD image and frame snapshot checks completed.',flush=True)
    finally:
        (run/'summary.json').write_text(json.dumps(summary,indent=2)+'\n',encoding='utf-8')


if __name__=='__main__':main()
