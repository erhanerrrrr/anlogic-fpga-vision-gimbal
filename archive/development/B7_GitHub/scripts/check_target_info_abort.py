"""B1b targeted interruption/recovery test, separate from full-image rendering."""
import argparse,hashlib,json,shutil
from pathlib import Path
from datetime import datetime
from b1_tools import simulate

def main():
    p=argparse.ArgumentParser();p.add_argument('--modelsim',type=Path,required=True);a=p.parse_args()
    root=Path(__file__).resolve().parents[1]
    run=root/'build/target_info_abort'/datetime.now().strftime('run_%Y%m%d_%H%M%S')
    run.mkdir(parents=True)
    files=(root/'b1b_sources.f').read_text().splitlines()+['sim/tb_target_info_abort.v']
    hashes={}
    for n in files:
        shutil.copy2(root/n,run/Path(n).name);hashes[n]=hashlib.sha256((root/n).read_bytes()).hexdigest()
    simulate(a.modelsim,run,[Path(n).name for n in files],'tb_target_info_abort','PASS TEXT ABORT:',timeout=120)
    (run/'summary.json').write_text(json.dumps(dict(passed=True,source_sha256=hashes,exit_code=0),indent=2)+'\n')
    print(f'PASS: B1b interruption/recovery. Reports: {run}',flush=True)
if __name__=='__main__':main()
