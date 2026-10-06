"""C5 complete mask and geometry comparison, including line-buffer flushing."""
import argparse
import csv
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'model'))
from c5_reference import input_mask,majority,geometry
from run_c2 import png


def check(out,group,inject=False):
    w,h=group['w'],group['h'];cases=group['cases']
    refs={};expected=[];stats=[]
    for case in cases:
        raw=input_mask(w,h,case);filtered=majority(w,h,raw);geo=geometry(w,filtered)
        if 'ones' in case and geo[1]!=case['ones']:raise ValueError('reference anchor mismatch '+case['name'])
        refs[case['id']]=(filtered,case)
        if not case.get('abort'):
            expected.append([case['id'],case.get('cfg',0),case.get('color',0)]+geo)
            png(out/(case['name']+'_input.png'),w,h,bytearray(v*255 for v in raw))
        stats.append({'case':case['name'],'input_ones':sum(raw),'filtered_geometry':geo,'aborted':case.get('abort',False)})
    pixels_per_path=[]
    for path in (0,1):
        with (out/('mask{}.hex'.format(path))).open() as f:
            total=0
            for case in cases:
                # Reset before input (x=7,y=2); delayed read stage leaves a valid prefix.
                count=(w+5-path) if case.get('abort') else w*h
                filtered,_=refs[case['id']];actual=bytearray()
                for index in range(count):
                    line=f.readline()
                    if not line:raise ValueError('missing filtered pixel')
                    word=int(line,16)
                    color=word&3;cfg=(word>>2)&65535;fid=(word>>18)&0xffffffff
                    y=(word>>50)&2047;x=(word>>61)&2047
                    eof=(word>>72)&1;eol=(word>>73)&1;sof=(word>>74)&1;mask=(word>>75)&1
                    ey,ex=divmod(index,w)
                    if (fid,cfg,color,x,y,sof,eol,eof)!=(case['id'],case.get('cfg',0),case.get('color',0),ex,ey,int(index==0),int(ex==w-1),int(index==w*h-1)):
                        raise ValueError('path {} metadata mismatch {} pixel {}'.format(path,case['name'],index))
                    want=filtered[index]
                    if inject and total==0:want^=1
                    if mask!=want:raise ValueError('path {} mask mismatch {} pixel {}'.format(path,case['name'],index))
                    actual.append(mask*255);total+=1
                if not case.get('abort'):
                    png(out/(case['name']+'_rtl_path{}.png'.format(path)),w,h,actual)
                    if path==0:png(out/(case['name']+'_diff.png'),w,h,bytearray(w*h))
            if f.read().strip():raise ValueError('unexpected filtered pixels')
        pixels_per_path.append(total)
    with (out/'actual.csv').open(newline='') as f:results=list(csv.DictReader(f))
    with (out/'timing.csv').open(newline='') as f:events=list(csv.DictReader(f))
    times={(r['kind'],int(r['path']),int(r['frame_id'])):int(r['cycle']) for r in events}
    keys=('frame_id','cfg_id','target_id','valid','area','xmin','ymin','xmax','ymax','cx','cy')
    latency=[]
    for path in (0,1):
        actual=[[int(r[k]) for k in keys] for r in results if int(r['path'])==path]
        if actual!=expected:raise ValueError('filtered geometry mismatch path '+str(path))
        for row in expected:
            fid=row[0];start=times['input',-1,fid];end=times['filtered',path,fid];done=times['result',path,fid]
            if end-start!=w+2+path or done-end!=2:raise ValueError('flush/result latency mismatch')
            latency.append({'path':path,'frame_id':fid,'input_eof_to_filtered_eof':end-start,'input_eof_to_result':done-start})
    if len(results)!=2*len(expected):raise ValueError('extra results')
    return {'dimensions':[w,h],'pixels_per_path':pixels_per_path,'complete_frames':len(expected),'cases':stats,'latency':latency}


def run(command,work,log):
    result=subprocess.run(command,cwd=str(work),stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=360)
    text=result.stdout.decode('utf-8',errors='replace');log.write_text(text,encoding='utf-8')
    if result.returncode:raise RuntimeError('tool failure: '+str(log))
    return text


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--check-only',action='store_true')
    parser.add_argument('--inject-error',action='store_true');args=parser.parse_args()
    fixture=json.loads((ROOT/'tests/fixtures/c5/cases.json').read_text(encoding='utf-8'))
    out=ROOT/'reports/c5/generated';out.mkdir(parents=True,exist_ok=True)
    if args.check_only:
        for group in fixture['groups']:check(out/('{}x{}'.format(group['w'],group['h'])),group,args.inject_error)
        print('PASS: existing C5 outputs verified');return
    (out/'summary.json').write_text('{"stage":"C5","result":"FAIL"}',encoding='utf-8')
    tools={t:shutil.which(t) for t in ('vlib','vlog','vsim')}
    if not all(tools.values()):raise RuntimeError('ModelSim not on PATH')
    sources=(ROOT/'rtl/recognition/c5_sources.f').read_text().splitlines()
    summaries=[]
    for group in fixture['groups']:
        w,h=group['w'],group['h'];dest=out/('{}x{}'.format(w,h));dest.mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(prefix='fpga_c5_') as directory:
            work=Path(directory)
            for rel in sources+['sim/c5/tb_denoised_result.v']:
                shutil.copy2(str(ROOT/rel),str(work/Path(rel).name))
            with (work/'cases.txt').open('w',encoding='ascii') as f:
                for c in group['cases']:f.write('{:08x} {} {} {} {}\n'.format(c['id'],c['pattern'],int(c.get('abort',False)),c.get('cfg',0),c.get('color',0)))
            shutil.copy2(str(work/'cases.txt'),str(dest/'cases.txt'))
            (work/'run.do').write_text('onerror {quit -f -code 1}\nonbreak {quit -f -code 1}\nrun -all\nquit -f -code 0\n',encoding='ascii')
            run([tools['vlib'],'work'],work,dest/'vlib.log')
            run([tools['vlog'],'-sv']+[Path(s).name for s in sources]+['tb_denoised_result.v'],work,dest/'compile.log')
            print('C5: simulating {}x{}, {} cases...'.format(w,h,len(group['cases'])),flush=True)
            log=run([tools['vsim'],'-c','-gWIDTH='+str(w),'-gHEIGHT='+str(h),
                     '-gLINE_GAPS='+str(group.get('line_gaps',1)),'work.tb_denoised_result','-do','run.do'],work,dest/'simulation.log')
            for name in ('mask0.hex','mask1.hex','actual.csv','timing.csv','filter_trace.vcd'):
                if (work/name).is_file():shutil.copy2(str(work/name),str(dest/name))
            if 'C5_SIM_COMPLETE' not in log:raise RuntimeError('simulation incomplete: '+str(dest))
        summaries.append(check(dest,group,args.inject_error))
    first=fixture['groups'][0]
    try:check(out/('{}x{}'.format(first['w'],first['h'])),first,True)
    except ValueError as exc:(out/'checker_selftest.log').write_text('EXPECTED FAILURE: '+str(exc),encoding='utf-8')
    else:raise RuntimeError('checker accepted wrong mask')
    summary={'stage':'C5','result':'PASS','interface_version':'c5-draft-1','groups':summaries,
        'pixel_mismatches':0,'packet_mismatches':0,'timing_errors':0,'rule':'5 of 9; outer border zero',
        'td':'see separate TD report','hardware':'not_tested','team_acceptance':'pending_A_B'}
    (out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n',encoding='utf-8')
    print('PASS: C5 full masks, geometry, boundary and flush timing verified for both paths')


if __name__=='__main__':
    try:main()
    except Exception as exc:
        print('FAIL: '+str(exc),file=sys.stderr);sys.exit(1)
