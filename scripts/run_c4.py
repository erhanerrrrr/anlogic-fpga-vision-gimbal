"""C4 packet comparison and measured EOF-to-result latency, Python 3.7+."""
import argparse
import csv
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT=Path(__file__).resolve().parents[1]
FIELDS=('frame_id','cfg_id','target_id','valid','area','xmin','ymin','xmax','ymax','cx','cy')


def expected_packet(c):
    if 'abort_at' in c: return None
    p,w,h=c['pattern'],c['w'],c['h']
    if p==0: n,l,t,r,b=1271,100,80,140,110
    elif p==1: n,l,t,r,b=4,10,20,11,21
    elif p==2: n,l,t,r,b=0,0,0,0,0
    elif p==3: n,l,t,r,b=w*h,0,0,w-1,h-1
    elif p==4: n,l,t,r,b=1,w-1,h-1,w-1,h-1
    else: raise ValueError('unknown reference pattern')
    geometry=[int(n>0),n,l,t,r,b,(l+r)//2,(t+b)//2]
    if geometry!=c['expected']: raise ValueError('independent arithmetic disagrees with fixed anchor')
    return [c['id'],c['cfg'],c['color']]+geometry


def check(out,cases,inject=False):
    expected=[expected_packet(c) for c in cases if 'abort_at' not in c]
    if inject: expected[0][-2]+=1
    with (out/'actual.csv').open(newline='') as f: rows=list(csv.DictReader(f))
    with (out/'timing.csv').open(newline='') as f: timing=list(csv.DictReader(f))
    eof_cycles={int(row['input_id']):int(row['cycle']) for row in timing if row['input_eof']=='1'}
    latencies={0:[],1:[]}
    for path in (0,1):
        selected=[row for row in rows if int(row['path'])==path]
        actual=[[int(row[key]) for key in FIELDS] for row in selected]
        if actual!=expected: raise ValueError('path {} result packet mismatch'.format(path))
        for row in selected:
            latency=int(row['cycle'])-eof_cycles[int(row['frame_id'])]
            if latency!=path+1: raise ValueError('EOF-to-result latency mismatch')
            latencies[path].append(latency)
    if len(rows)!=len(expected)*2: raise ValueError('extra output path')
    return len(expected),latencies


def run(command,work,log):
    result=subprocess.run(command,cwd=str(work),stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=300)
    text=result.stdout.decode('utf-8',errors='replace');log.write_text(text,encoding='utf-8')
    if result.returncode: raise RuntimeError('tool failed: '+str(log))
    return text


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--check-only',action='store_true')
    parser.add_argument('--inject-error',action='store_true');args=parser.parse_args()
    cases=json.loads((ROOT/'tests/fixtures/c4/cases.json').read_text(encoding='utf-8'))['cases']
    out=ROOT/'reports/c4/generated';out.mkdir(parents=True,exist_ok=True)
    if args.check_only:
        count,_=check(out,cases,args.inject_error);print('PASS: {} packets per path'.format(count));return
    (out/'summary.json').write_text('{"stage":"C4","result":"FAIL"}',encoding='utf-8')
    tools={t:shutil.which(t) for t in ('vlib','vlog','vsim')}
    if not all(tools.values()): raise RuntimeError('ModelSim not on PATH')
    expected=[expected_packet(c) for c in cases if 'abort_at' not in c]
    with (out/'expected.csv').open('w',newline='',encoding='ascii') as f:
        writer=csv.writer(f);writer.writerow(FIELDS);writer.writerows(expected)
    sources=(ROOT/'rtl/recognition/c4_sources.f').read_text().splitlines()
    with tempfile.TemporaryDirectory(prefix='fpga_c4_') as directory:
        work=Path(directory)
        for rel in sources+['sim/c4/tb_target_result.v','sim/c4/tb_pack_extremes.v']:
            shutil.copy2(str(ROOT/rel),str(work/Path(rel).name))
        with (work/'cases.txt').open('w',encoding='ascii') as f:
            for c in cases:
                f.write('{} {} {:08x} {} {} {} {}\n'.format(c['w'],c['h'],c['id'],c['cfg'],c['color'],c['pattern'],c.get('abort_at',-1)))
        shutil.copy2(str(work/'cases.txt'),str(out/'cases.txt'))
        (work/'run.do').write_text('onerror {quit -f -code 1}\nonbreak {quit -f -code 1}\nrun -all\nquit -f -code 0\n',encoding='ascii')
        version=run([tools['vsim'],'-version'],work,out/'tool_version.log').strip()
        run([tools['vlib'],'work'],work,out/'vlib.log')
        run([tools['vlog'],'-sv']+[Path(s).name for s in sources]+['tb_target_result.v','tb_pack_extremes.v'],work,out/'compile.log')
        log=run([tools['vsim'],'-c','work.tb_pack_extremes','-do','run.do'],work,out/'extremes.log')
        if 'C4_EXTREMES_COMPLETE' not in log: raise RuntimeError('arithmetic core incomplete')
        print('C4: running direct-mask and RGB full-frame paths...',flush=True)
        log=run([tools['vsim'],'-c','work.tb_target_result','-do','run.do'],work,out/'simulation.log')
        for name in ('actual.csv','timing.csv','result_trace.vcd'):
            if (work/name).is_file(): shutil.copy2(str(work/name),str(out/name))
        if 'C4_SIM_COMPLETE' not in log: raise RuntimeError('simulation incomplete')
    count,latencies=check(out,cases,args.inject_error)
    try:check(out,cases,True)
    except ValueError as exc:(out/'checker_selftest.log').write_text('EXPECTED FAILURE: '+str(exc),encoding='utf-8')
    else:raise RuntimeError('checker accepted wrong center')
    summary={'stage':'C4','result':'PASS','interface_version':'c4-draft-1','modelsim':version,
             'frame_cases':len(cases),'packets_per_path':count,'arithmetic_extremes':5,'packet_mismatches':0,
             'timing_errors':0,'L_result_mask_eof_cycles':1,'L_result_rgb_eof_cycles':2,
             'observed_latencies':latencies,'validity':'temporary raw_count > 0',
             'td':'see separate TD report','hardware':'not_tested','team_acceptance':'pending_A_B'}
    (out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n',encoding='utf-8')
    print('PASS: {} frame cases, {} packets per path, 5 arithmetic anchors; L_result=1/2 cycles'.format(len(cases),count))


if __name__=='__main__':
    try:main()
    except Exception as exc:
        print('FAIL: '+str(exc),file=sys.stderr);sys.exit(1)
