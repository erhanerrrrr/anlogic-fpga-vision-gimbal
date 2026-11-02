"""Check native 720p B4c+B4f pixels and same-source result metadata."""
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
from run_b4d import reference as b4d_reference
from run_b4f import CASES,reference as panel_reference

WIDTH,HEIGHT,NFRAMES=1280,720,2


def reference(index):
    image=b4d_reference(index)
    panel=panel_reference(CASES[index])
    patch=image[208:320,976:1280]
    mask=np.any(panel!=16,axis=2)
    patch[mask]=panel[mask]
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
        'rtl/osd_fps_decimal.v',
        'rtl/video_performance_text.v',
        'rtl/video_b4g_h4e_sameclk.v',
        'sim/tb_b4g_native720_performance.v']
    run=ROOT/'build/b4g_native720_performance'/datetime.now().strftime('run_%Y%m%d_%H%M%S')
    run.mkdir(parents=True,exist_ok=True)
    summary={'stage':'B4g','passed':False,'native_resolution':[WIDTH,HEIGHT],
             'synthetic_capture_identity':True,'synthetic_latency':True,
             'synthetic_rates':True,'board_tested':False,'cases':[],
             'source_sha256':{name:hashlib.sha256((ROOT/name).read_bytes()).hexdigest()
                              for name in [*files,'run_b4g.py']}}
    print('Reports:',run,flush=True)
    try:
        for name in files:shutil.copy2(ROOT/name,run/Path(name).name)
        log=simulate(args.modelsim,run,[Path(name).name for name in files],
                     'tb_b4g_native720_performance','PASS B4G_NATIVE720_PERFORMANCE:',
                     timeout=1800)
        if 'Errors: 0, Warnings: 0' not in log or \
                'Errors: 0, Warnings: 0' not in (run/'compile.log').read_text():
            raise RuntimeError('ModelSim errors or warnings')
        raw=np.fromfile(run/'actual.rgb',np.uint8)
        if raw.size!=NFRAMES*WIDTH*HEIGHT*3:
            raise RuntimeError(f'RGB length {raw.size} is incorrect')
        actual=raw.reshape(NFRAMES,HEIGHT,WIDTH,3)
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
        print('PASS: B4g native 720p target, Logo, latency and performance OSD checks completed.',flush=True)
    finally:
        (run/'summary.json').write_text(json.dumps(summary,indent=2)+'\n',encoding='utf-8')


if __name__=='__main__':main()
