"""Sobel arithmetic at exact thresholds, plus independent edge-stage fault recovery."""
import argparse,hashlib,json,shutil
from pathlib import Path
from datetime import datetime
import numpy as np
from b1_tools import simulate

def main():
    p=argparse.ArgumentParser();p.add_argument('--modelsim',type=Path,required=True);a=p.parse_args()
    root=Path(__file__).resolve().parents[1];run=root/'build/edge_stage'/datetime.now().strftime('run_%Y%m%d_%H%M%S');run.mkdir(parents=True)
    print(f'Reports: {run}',flush=True)
    rng=np.random.default_rng(0xB2C);kx=np.array([[-1,0,1],[-2,0,2],[-1,0,1]])
    patches=[np.full((3,3),v) for v in (0,255,128)]
    patches += [np.array([[0,0,255],[0,0,255],[0,0,255]]),np.array([[255,0,0],[255,0,0],[255,0,0]])]
    patches += [np.array([[(i>>j)&1 for j in range(9)]]).reshape(3,3)*255 for i in range(512)]
    patches += list(rng.integers(0,256,(256,3,3)))
    lines=[];peak=0
    for patch in patches:
        gx=int(np.sum(patch*kx));gy=int(np.sum(patch*kx.T));m=abs(gx)+abs(gy);peak=max(peak,m)
        packed=''.join(f'{int(v):02x}' for v in patch.flat)
        for t in sorted({0,128,2047,max(0,m-1),m,min(2047,m+1)}):
            lines.append(f'1 {packed} {t:03x} {gx} {gy} {m} {255 if m>=t else 0}')
        lines.append(f'0 {packed} 080 0 0 0 0')
    (run/'sobel_vectors.txt').write_text('\n'.join(lines)+'\n')
    files=['rtl/sobel_core.v','rtl/window_3x3.v','rtl/video_gray_edge_stream.v','sim/tb_sobel_arithmetic.v','sim/tb_edge_stage_faults.v']
    for f in files:shutil.copy2(root/f,run/Path(f).name)
    simulate(a.modelsim,run,['sobel_core.v','tb_sobel_arithmetic.v'],'tb_sobel_arithmetic','PASS SOBEL_ARITHMETIC:')
    shutil.copy2(run/'simulation.log',run/'arithmetic.log');shutil.copy2(run/'compile.log',run/'arithmetic_compile.log')
    simulate(a.modelsim,run,[Path(f).name for f in files if not f.endswith('tb_sobel_arithmetic.v')],'tb_edge_stage_faults','PASS EDGE_STAGE_FAULTS:')
    files+=['scripts/check_edge_stage.py']
    result=dict(passed=True,arithmetic_vectors=len(lines),maximum_tested_magnitude=peak,stage_fault_scenarios=12,
        source_sha256={f:hashlib.sha256((root/f).read_bytes()).hexdigest() for f in files})
    (run/'summary.json').write_text(json.dumps(result,indent=2)+'\n')
    print(f'PASS: Sobel arithmetic {len(lines)} vectors; 12 edge-stage recovery scenarios.',flush=True)
if __name__=='__main__':main()
