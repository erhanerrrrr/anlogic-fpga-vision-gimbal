"""Native 1280x720 B4 closed-loop test with official Logo and latency OSD."""
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
from check_b3_target_stream import LOGO,LOGO_FILE
from run_b4c import reference as compact_reference

WIDTH,HEIGHT,NFRAMES=1280,720,2


def reference(index):
    image=np.zeros((HEIGHT,WIDTH,3),np.uint8)
    image[:480,:976]=compact_reference(index)
    patch=image[16:176,1104:1264]
    opaque=(LOGO>>24)!=0
    colors=np.stack(((LOGO>>16)&255,(LOGO>>8)&255,LOGO&255),axis=-1).astype(np.uint8)
    patch[opaque]=colors[opaque]
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
        'sim/tb_b4d_native720_latency.v']
    run=ROOT/'build/b4d_native720_latency'/datetime.now().strftime('run_%Y%m%d_%H%M%S')
    run.mkdir(parents=True,exist_ok=True)
    summary={'stage':'B4d','passed':False,'native_resolution':[WIDTH,HEIGHT],
             'synthetic_capture_identity':True,'synthetic_latency':True,
             'board_tested':False,'cases':[],
             'source_sha256':{name:hashlib.sha256((ROOT/name).read_bytes()).hexdigest()
                              for name in files},
             'logo_reference_sha256':hashlib.sha256(LOGO_FILE.read_bytes()).hexdigest()}
    print('Reports:',run,flush=True)
    try:
        for name in files:shutil.copy2(ROOT/name,run/Path(name).name)
        log=simulate(args.modelsim,run,[Path(name).name for name in files],
                     'tb_b4d_native720_latency','PASS B4D_NATIVE720_LATENCY:',timeout=1800)
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
        print('PASS: B4d native 720p Logo and latency OSD checks completed.',flush=True)
    finally:
        (run/'summary.json').write_text(json.dumps(summary,indent=2)+'\n',encoding='utf-8')


if __name__=='__main__':main()
