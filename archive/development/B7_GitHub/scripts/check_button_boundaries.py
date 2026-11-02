"""Check real 750000-cycle debounce boundaries and both polarities."""
import argparse,hashlib,json,re,shutil
from pathlib import Path
from datetime import datetime
from b1_tools import simulate
def main():
    p=argparse.ArgumentParser();p.add_argument('--modelsim',type=Path,required=True);p.add_argument('--small-only',action='store_true');a=p.parse_args()
    root=Path(__file__).resolve().parents[1]
    run=root/'build/button_boundaries'/datetime.now().strftime('run_%Y%m%d_%H%M%S');run.mkdir(parents=True)
    print(f'Reports: {run}',flush=True)
    files=['rtl/button_events.v','rtl/button_mode_request.v','sim/tb_button_boundaries.v']
    result=dict(passed=False,source_sha256={f:hashlib.sha256((root/f).read_bytes()).hexdigest() for f in files},cases=[])
    try:
        ns=[1,4,7] if a.small_only else [1,4,7,750000]
        for n in ns:
            for polarity in (0,1):
                dest=run/f'n{n}_polarity{polarity}';dest.mkdir()
                for f in files:shutil.copy2(root/f,dest/Path(f).name)
                out=simulate(a.modelsim,dest,[Path(f).name for f in files],'tb_button_boundaries','PASS BUTTON_BOUNDARIES:',[f'-gN={n}',f'-gACTIVE_LOW={polarity}'],timeout=900)
                scenarios=int(re.search(r'scenarios=(\d+)',out)[1])
                result['cases'].append(dict(n=n,active_low=polarity,scenarios=scenarios,passed=True))
                print(f'PASS: N={n}, ACTIVE_LOW={polarity}, scenarios={scenarios}',flush=True)
        result.update(passed=True,actual_default_count_tested=not a.small_only)
    finally:(run/'summary.json').write_text(json.dumps(result,indent=2)+'\n')
if __name__=='__main__':main()
