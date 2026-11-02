"""Run the isolated B4a latency-window simulation in ModelSim."""
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
    files=(ROOT/'b4a_sources.f').read_text().splitlines()
    run=ROOT/'build/b4a_latency_window'/datetime.now().strftime('run_%Y%m%d_%H%M%S')
    run.mkdir(parents=True,exist_ok=True)
    for name in files:
        shutil.copy2(ROOT/name,run/Path(name).name)
    summary={'stage':'B4a','passed':False,'synthetic_input':True,
             'board_tested':False,'source_sha256':{
                 name:hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in files}}
    try:
        log=simulate(a.modelsim,run,[Path(n).name for n in files],
                     'tb_b4a_latency_window','PASS B4A_LATENCY_WINDOW:',timeout=120)
        if 'Errors: 0, Warnings: 0' not in log:
            raise RuntimeError('ModelSim errors or warnings: '+str(run/'simulation.log'))
        summary['passed']=True
        print('PASS: B4a latency window checks completed.')
    finally:
        (run/'summary.json').write_text(json.dumps(summary,indent=2)+'\n',encoding='utf-8')
        print('Reports:',run)

if __name__=='__main__':main()
