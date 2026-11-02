"""Simulate unchanged H4E C region results through same-source display gating."""
import argparse
import hashlib
import json
import shutil
import sys
from datetime import datetime
from pathlib import Path

ROOT=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT/'scripts'))
from b1_tools import simulate


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--modelsim',type=Path,required=True)
    a=p.parse_args()
    files=['../boards/hx1p35a/h4e/user_source/hdl_source/h4e_region_select.v',
           'rtl/capture_target_gate.v','rtl/b1_target_snapshot.v',
           'sim/tb_b3g3_h4e_result.v']
    run=ROOT/'build/b3g3_h4e_result'/datetime.now().strftime('run_%Y%m%d_%H%M%S')
    run.mkdir(parents=True)
    result=dict(passed=False,scope='unchanged H4E C region selector + strict source gate + B1a snapshot',
        synthetic_epoch=True,real_capture_id=False,board_tested=False,
        source_sha256={name:hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in files})
    print(f'Reports: {run}',flush=True)
    try:
        for name in files:shutil.copy2(ROOT/name,run/Path(name).name)
        log=simulate(a.modelsim,run,[Path(name).name for name in files],
            'tb_b3g3_h4e_result','PASS B3G3_H4E_RESULT:',timeout=120)
        if 'Errors: 0, Warnings: 0' not in log:
            raise RuntimeError('ModelSim reported errors or warnings')
        result['passed']=True
        print('PASS: B3g3 H4E result handshake checks completed.',flush=True)
    finally:
        (run/'summary.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')


if __name__=='__main__':main()
