"""Protocol/capacity injections and real-C recovery; includes a 720p mid-frame reset."""
import argparse,hashlib,json,shutil,re
from pathlib import Path
from datetime import datetime
from b1_tools import simulate

def main():
    p=argparse.ArgumentParser();p.add_argument('--modelsim',type=Path,required=True);p.add_argument('--small-only',action='store_true');a=p.parse_args()
    root=Path(__file__).resolve().parents[1]
    run=root/'build/edge_stream_faults'/datetime.now().strftime('run_%Y%m%d_%H%M%S');run.mkdir(parents=True)
    print(f'Reports: {run}',flush=True)
    files=(root/'b2c_sources.f').read_text().splitlines()+['sim/tb_edge_stream_faults.v']
    result=dict(passed=False,cases=[],source_sha256={f:hashlib.sha256((root/f).read_bytes()).hexdigest() for f in files})
    try:
        cases=[('faults_small',[]),('capacity',['-gCAPACITY=1'])]
        if not a.small_only:cases.append(('reset_720p',['-gFULL=1','-gW=1280','-gH=720','-gHT=1650','-gGUARD=4']))
        for name,args in cases:
            dest=run/name;dest.mkdir()
            for f in files:shutil.copy2(root/f,dest/Path(f).name)
            out=simulate(a.modelsim,dest,[Path(f).name for f in files],'tb_edge_stream_faults','PASS EDGE_STREAM_FAULTS:',args)
            n=int(re.search(r'PASS EDGE_STREAM_FAULTS: tests=(\d+)',out)[1])
            result['cases'].append(dict(name=name,tests=n,passed=True));print(f'PASS: {name}, {n} scenarios',flush=True)
        result['passed']=True
    finally:(run/'summary.json').write_text(json.dumps(result,indent=2)+'\n')
if __name__=='__main__':main()
