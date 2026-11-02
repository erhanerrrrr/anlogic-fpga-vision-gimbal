"""Request timing and video-abort recovery through the real B3a/B2d chain."""
import argparse,hashlib,json,shutil
from pathlib import Path
from datetime import datetime
from b1_tools import simulate

def main():
    p=argparse.ArgumentParser();p.add_argument('--modelsim',type=Path,required=True);a=p.parse_args()
    root=Path(__file__).resolve().parents[1]
    run=root/'build/frame_mode_control'/datetime.now().strftime('run_%Y%m%d_%H%M%S');run.mkdir(parents=True)
    print(f'Reports: {run}',flush=True)
    files=(root/'b3a_sources.f').read_text().splitlines()+['sim/tb_frame_mode_control.v']
    result=dict(passed=False,source_sha256={f:hashlib.sha256((root/f).read_bytes()).hexdigest() for f in files})
    try:
        for f in files:shutil.copy2(root/f,run/Path(f).name)
        simulate(a.modelsim,run,[Path(f).name for f in files],'tb_frame_mode_control','PASS FRAME_MODE_CONTROL: frames=9')
        result.update(passed=True,recovery_and_control_frames=9)
        print('PASS: frame-mode requests, invalid requests, abort, timeout and reset.',flush=True)
    finally:(run/'summary.json').write_text(json.dumps(result,indent=2)+'\n')
if __name__=='__main__':main()
