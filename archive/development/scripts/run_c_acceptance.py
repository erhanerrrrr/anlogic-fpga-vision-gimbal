"""Run selected C stages and optionally final TD synthesis, saving exit-code evidence."""
import argparse,json,subprocess,sys
from concurrent.futures import ThreadPoolExecutor,as_completed
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--stages',type=int,nargs='+',choices=range(1,11),default=list(range(1,11)))
    ap.add_argument('--jobs',type=int,choices=range(1,5),default=2);ap.add_argument('--td',action='store_true');args=ap.parse_args()
    out=ROOT/'reports/c10/generated/regressions';out.mkdir(parents=True,exist_ok=True)
    def run(stage):
        result=subprocess.run([sys.executable,'scripts/run_c%d.py'%stage],cwd=str(ROOT),stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=1800)
        text=result.stdout.decode('utf-8',errors='replace');(out/('c%d.log'%stage)).write_text(text,encoding='utf-8')
        return dict(stage='C%d'%stage,exit_code=result.returncode,last_line=text.strip().splitlines()[-1] if text.strip() else '')
    results=[]
    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        for future in as_completed([pool.submit(run,n) for n in sorted(set(args.stages))]):
            row=future.result();results.append(row);print(row['stage']+' exit='+str(row['exit_code'])+' '+row['last_line'],flush=True)
    if args.td:
        p=subprocess.run([sys.executable,'scripts/run_c10_td.py'],cwd=str(ROOT),stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=300)
        text=p.stdout.decode('utf-8',errors='replace');(out/'td.log').write_text(text,encoding='utf-8')
        results.append(dict(stage='TD',exit_code=p.returncode,last_line=text.strip()));print(text,flush=True)
    status='PASS' if all(r['exit_code']==0 for r in results) else 'FAIL'
    (out.parent/'regression_summary.json').write_text(json.dumps(dict(result=status,stages=sorted(results,key=lambda r:r['stage'])),indent=2)+'\n')
    (out.parent/'regression.log').write_text('\n'.join(r['stage']+' exit='+str(r['exit_code'])+' '+r['last_line'] for r in sorted(results,key=lambda r:r['stage']))+'\n',encoding='utf-8')
    return int(status!='PASS')

if __name__=='__main__':
    try:sys.exit(main())
    except Exception as exc:print('FAIL: '+str(exc),file=sys.stderr);sys.exit(1)
