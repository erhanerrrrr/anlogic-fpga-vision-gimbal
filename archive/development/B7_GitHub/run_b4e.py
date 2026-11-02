"""Run the shared centi-FPS to decimal BCD converter test in ModelSim."""
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
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--modelsim',type=Path,required=True)
    args=parser.parse_args()
    files=(ROOT/'b4e_sources.f').read_text().splitlines()
    run=ROOT/'build/b4e_fps_decimal'/datetime.now().strftime('run_%Y%m%d_%H%M%S')
    run.mkdir(parents=True,exist_ok=True)
    summary={'stage':'B4e','passed':False,'synthetic_input':True,
             'provisional_rate_interface':True,'board_tested':False,
             'source_sha256':{name:hashlib.sha256((ROOT/name).read_bytes()).hexdigest()
                              for name in files}}
    print('Reports:',run,flush=True)
    try:
        for name in files:shutil.copy2(ROOT/name,run/Path(name).name)
        log=simulate(args.modelsim,run,[Path(name).name for name in files],
                     'tb_b4e_fps_decimal','PASS B4E_FPS_DECIMAL:',timeout=120)
        if 'Errors: 0, Warnings: 0' not in log:
            raise RuntimeError('ModelSim errors or warnings')
        summary['passed']=True
        print('PASS: B4e centi-FPS decimal conversion checks completed.',flush=True)
    finally:
        (run/'summary.json').write_text(json.dumps(summary,indent=2)+'\n',encoding='utf-8')


if __name__=='__main__':main()
