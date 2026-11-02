"""C3 direct-mask and RGB->C2->C3 simulation with fixed independent geometry."""
import argparse
import csv
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT=Path(__file__).resolve().parents[1]


def reference(case):
    # Independent set membership, not the RTL accumulator implementation.
    w,h,p=case['width'],case['height'],case['pattern']
    if case.get('abort_at') is not None: return None
    if p==0: return [41*31,100,80,140,110]
    if p==1: return [1,0,0,0,0]
    if p in (2,7): return [0,0,0,0,0]
    if p==3: return [1,w-1,h-1,w-1,h-1]
    if p==4: return [w*h,0,0,w-1,h-1]
    if p==5: return [4,w-2,h-2,w-1,h-1]
    if p==6: return [2,0,0,w-1,h-1]
    raise ValueError('unknown reference pattern')


def check(out,cases,inject=False):
    expected=[]
    for c in cases:
        values=reference(c)
        if values!=c['expected']: raise ValueError('fixture disagrees with independent geometry')
        if values is not None: expected.append([c['id']]+values)
    if inject: expected[0][1]+=1
    with (out/'actual.csv').open(newline='') as f: rows=list(csv.DictReader(f))
    by_path={name:[] for name in ('direct','chain')}
    cycles={name:[] for name in by_path}
    for row in rows:
        name=row['path']
        if name not in by_path: raise ValueError('unknown output path')
        by_path[name].append([int(row[k]) for k in ('frame_id','count','xmin','ymin','xmax','ymax')])
        cycles[name].append(int(row['cycle']))
    for name,actual in by_path.items():
        if actual!=expected: raise ValueError(name+' raw statistics differ from independent expectations')
    if any(b-a!=1 for a,b in zip(cycles['direct'],cycles['chain'])):
        raise ValueError('C2 chain latency differs from one additional register')
    return len(expected)


def run(command,work,log):
    result=subprocess.run(command,cwd=str(work),stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=300)
    text=result.stdout.decode('utf-8',errors='replace'); log.write_text(text,encoding='utf-8')
    if result.returncode: raise RuntimeError('tool failure: '+str(log))
    return text


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--check-only',action='store_true')
    parser.add_argument('--inject-error',action='store_true');args=parser.parse_args()
    cases=json.loads((ROOT/'tests/fixtures/c3/cases.json').read_text(encoding='utf-8'))['cases']
    out=ROOT/'reports/c3/generated';out.mkdir(parents=True,exist_ok=True)
    if args.check_only:
        count=check(out,cases,args.inject_error);print('PASS: {} results per path'.format(count));return
    summary={'stage':'C3','result':'FAIL','interface_version':'c3-draft-1'}
    (out/'summary.json').write_text(json.dumps(summary),encoding='utf-8')
    tools={name:shutil.which(name) for name in ('vlib','vlog','vsim')}
    if not all(tools.values()): raise RuntimeError('ModelSim not on PATH')
    with tempfile.TemporaryDirectory(prefix='fpga_c3_') as directory:
        work=Path(directory)
        sources=['color_classifier.v','color_mask_stream.v','mask_frame_stats.v']
        for name in sources: shutil.copy2(str(ROOT/'rtl/recognition'/name),str(work/name))
        shutil.copy2(str(ROOT/'sim/c3/tb_mask_frame_stats.v'),str(work/'tb_mask_frame_stats.v'))
        with (work/'cases.txt').open('w',encoding='ascii') as f:
            for c in cases:
                f.write('{} {} {:08x} {} {}\n'.format(c['width'],c['height'],c['id'],c['pattern'],c.get('abort_at',-1)))
        shutil.copy2(str(work/'cases.txt'),str(out/'cases.txt'))
        (work/'run.do').write_text('onerror {quit -f -code 1}\nonbreak {quit -f -code 1}\nrun -all\nquit -f -code 0\n',encoding='ascii')
        version=run([tools['vsim'],'-version'],work,out/'tool_version.log').strip()
        run([tools['vlib'],'work'],work,out/'vlib.log')
        run([tools['vlog'],'-sv']+sources+['tb_mask_frame_stats.v'],work,out/'compile.log')
        print('C3: running direct and chained full-frame simulation...',flush=True)
        log=run([tools['vsim'],'-c','work.tb_mask_frame_stats','-do','run.do'],work,out/'simulation.log')
        for name in ('actual.csv','timing.csv','eof_trace.vcd'):
            if (work/name).is_file(): shutil.copy2(str(work/name),str(out/name))
        if 'C3_SIM_COMPLETE' not in log: raise RuntimeError('simulation incomplete')
    count=check(out,cases,args.inject_error)
    try: check(out,cases,True)
    except ValueError as exc: (out/'checker_selftest.log').write_text('EXPECTED FAILURE: '+str(exc),encoding='utf-8')
    else: raise RuntimeError('checker accepted wrong area')
    summary.update(result='PASS',modelsim=version,cases=len(cases),results_per_path=count,
                   paths=['direct mask','RGB -> C2 -> C3'],field_mismatches=0,timing_errors=0,
                   count_width=20,empty_bbox=[0,0,0,0],eof_included=True,half_frame_discarded=True,
                   hardware='not_tested',team_acceptance='pending_A_B',td='last checked C2; C3 not synthesized')
    (out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n',encoding='utf-8')
    print('PASS: {} cases; {} raw results per path; geometry, EOF, reset and hold checks passed'.format(len(cases),count))


if __name__=='__main__':
    try: main()
    except Exception as exc:
        print('FAIL: '+str(exc),file=sys.stderr);sys.exit(1)
