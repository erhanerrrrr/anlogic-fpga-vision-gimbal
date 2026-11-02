"""Real pins -> shared debounce -> source-frame mode -> real C video, both polarities."""
import argparse,hashlib,json,shutil
import numpy as np
from PIL import Image
from pathlib import Path
from datetime import datetime
from b1_tools import simulate
def main():
    p=argparse.ArgumentParser();p.add_argument('--modelsim',type=Path,required=True);a=p.parse_args()
    root=Path(__file__).resolve().parents[1]
    run=root/'build/video_buttons'/datetime.now().strftime('run_%Y%m%d_%H%M%S');run.mkdir(parents=True)
    print(f'Reports: {run}',flush=True)
    files=(root/'b3b_sources.f').read_text().splitlines()+['sim/tb_video_buttons_control.v']
    result=dict(passed=False,source_sha256={f:hashlib.sha256((root/f).read_bytes()).hexdigest() for f in files},cases=[])
    try:
        for polarity in (0,1):
            dest=run/f'polarity{polarity}';dest.mkdir()
            for f in files:shutil.copy2(root/f,dest/Path(f).name)
            simulate(a.modelsim,dest,[Path(f).name for f in files],'tb_video_buttons_control','PASS VIDEO_BUTTONS: frames=9',[f'-gACTIVE_LOW={polarity}'])
            modes=[0,2,2,3,3,0,1,2,1]
            actual=np.fromfile(dest/'actual.rgb',np.uint8).reshape(9,12,16,3)
            for index,mode in enumerate(modes):
                expected=np.zeros((12,16,3),np.uint8)
                if mode==0:expected[:,:,0]=200
                elif mode==1:expected[:]=60
                elif mode==3:expected[1:-1,1:-1]=255
                assert np.array_equal(actual[index],expected),(polarity,index)
                Image.fromarray(actual[index]).save(dest/f'{index+1:02d}_mode{mode}_actual.png')
                Image.fromarray(expected).save(dest/f'{index+1:02d}_mode{mode}_reference.png')
            result['cases'].append(dict(active_low=polarity,frames=9,pixels=9*16*12,modes=modes,pixel_differences=0,passed=True))
            print(f'PASS: button/video integration, ACTIVE_LOW={polarity}, 9 frames',flush=True)
        result['passed']=True
    finally:(run/'summary.json').write_text(json.dumps(result,indent=2)+'\n')
if __name__=='__main__':main()
