"""C8 numeric reference, request protocol and full C7-equivalence simulation."""
import argparse
import csv
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'model'))
from c8_reference import rgb,statistics,FIELDS


def commands(group):
    size=group['w']*group['h']
    for c in group['cases']:
        op=c.get('op','frame')
        if op=='reset':yield [1,0,0,-1,-1,-1,0,0,0,0,1,0]
        elif op in ('idle','request'):
            yield [2,0,0,-1,-1,-1,0,0,0,0,c.get('cycles',1),int(op=='request' or c.get('req',False))]
        else:
            requests=([c['req']] if 'req' in c else [])+c.get('extra',[])
            requests=[size-1 if i==-2 else i for i in requests]
            if len(requests)>3:raise ValueError('too many request positions')
            requests+= [-1]*(3-len(requests))
            yield [0,c['id'],c.get('pattern',0)]+requests+[int(c.get('stop',False)),int(c.get('missing',False)),c.get('cfg',0),c.get('color',0),0,0]


def expected(group):
    # Store selected ROI points and reduce the entire array at EOF. No RTL-style sums.
    w,h,rx,ry=[group[k] for k in ('w','h','rx','ry')]
    cycle=0;pending=False;capture=None;last=None;ignored=0;previous=(0,0,0)
    events=[];packets=[]
    def beat(reset=True,valid=False,req=False,x=0,y=0,sof=False,eof=False,fid=0,cfg=0,color=0,pixel=(0,0,0)):
        nonlocal cycle,pending,capture,last,ignored,previous
        cycle+=1;done=0;ignored_pulse=0
        if not reset:pending=False;capture=None;last=None;ignored=0
        else:
            was_busy=pending or capture is not None
            was_pending=pending
            if req and was_busy:ignored=min(65535,ignored+1);ignored_pulse=1
            elif req:pending=True
            new=valid and sof and (last is None or last!=fid)
            if valid and sof:last=fid
            if capture is not None and valid and sof:
                packets.append([cycle]+statistics(*capture[:3],capture[3],ok=False,reason=2))
                capture=None;pending=False;done=1
            else:
                if was_pending and new:
                    capture=[fid,cfg,color,[]];pending=False
                if capture is not None and valid:
                    if rx<=x<rx+16 and ry<=y<ry+16:capture[3].append(pixel)
                    if eof:
                        ok=len(capture[3])==256
                        packets.append([cycle]+statistics(*capture[:3],capture[3],ok=ok,reason=0 if ok else 1))
                        capture=None;done=1
        status=(int(pending or capture is not None),ignored_pulse,ignored)
        if status!=previous or done:events.append([cycle]+list(status)+[done])
        previous=status
    beat(reset=False)
    for op,fid,pattern,r1,r2,r3,stop,missing,cfg,color,cycles,req in commands(group):
        if op==1:beat(reset=False)
        elif op==2:
            for _ in range(cycles):beat(req=bool(req))
        else:
            for y in range(h):
                for x in range(w):
                    if not stop or y<ry+16:
                        i=y*w+x
                        beat(valid=not(missing and x==rx+15 and y==ry+15),req=i in (r1,r2,r3),
                             x=x,y=y,sof=i==0,eof=i==w*h-1,fid=fid,cfg=cfg,color=color,pixel=rgb(pattern,x,y,rx,ry))
                if y<h-1 and (not stop or y<ry+15):
                    for _ in range(1+y%3):beat()
    for _ in range(w+50):beat()
    return events,packets,cycle


def check(group,dest,inject=False):
    events,packets,cycles=expected(group)
    # Literal numeric anchors protect against an accidental shared formula error.
    anchor=statistics(0,0,0,[(144,40,40)]*128+[(160,40,40)]*128)
    if anchor[5:]!=[256,38912,10240,10240,144,40,40,160,40,40,152,40,40]:raise ValueError('anchor mismatch')
    anchors={
        'protocol':[(0,1),(2,1),(4,1),(6,1),(0,0),(3,1),(5,0),(0,1),(11,1)],
        'roi_edges':[(0,1),(1,1),(2,1)],
        'full_720p':[(31,1),(32,1),(33,1)]}
    if [(p[1],p[4]) for p in packets]!=anchors[group['name']]:raise ValueError('frame selection anchor mismatch')
    if inject:packets[0][7]+=1
    for filename,want in [('events.csv',events),('actual.csv',packets)]:
        with (dest/filename).open(newline='') as f:
            rows=list(csv.reader(f));got=[[int(v) for v in row] for row in rows[1:]]
        if got!=want:
            index=next((i for i,(a,b) in enumerate(zip(got,want)) if a!=b),min(len(got),len(want)))
            raise ValueError('{} {} mismatch row {} actual={} expected={}'.format(group['name'],filename,index,got[index:index+1],want[index:index+1]))
    log=(dest/'simulation.log').read_text(encoding='utf-8')
    match=re.search(r'C8_COMPLETE checked_cycles=(\d+) detector_notifications=(\d+)',log)
    if not match or int(match.group(1))!=cycles:raise ValueError('incomplete simulation')
    with (dest/'expected.csv').open('w',newline='',encoding='ascii') as f:
        writer=csv.writer(f);writer.writerow(('cycle',)+FIELDS);writer.writerows(packets)
    return {'name':group['name'],'checked_cycles':cycles,'completed_samples':len(packets),
            'successful_samples':sum(p[4] for p in packets),'detector_notifications':int(match.group(2)),
            'statistics_mismatches':0,'protocol_mismatches':0,'detector_equivalence_mismatches':0}


def run(command,work,log):
    result=subprocess.run(command,cwd=str(work),stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=600)
    output=result.stdout.decode('utf-8',errors='replace');log.write_text(output,encoding='utf-8')
    if result.returncode:raise RuntimeError('tool failed: '+str(log))
    return output


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--check-only',action='store_true');parser.add_argument('--inject-error',action='store_true')
    args=parser.parse_args()
    groups=json.loads((ROOT/'tests/fixtures/c8/cases.json').read_text())['groups']
    out=ROOT/'reports/c8/generated';out.mkdir(parents=True,exist_ok=True)
    for g in groups:
        if not (16<=g['w']<=1280 and 16<=g['h']<=720 and 0<=g['rx']<=g['w']-16 and 0<=g['ry']<=g['h']-16):
            raise ValueError('ROI must be fully inside supported frame')
    if args.check_only:
        for g in groups:check(g,out/g['name'],args.inject_error)
        print('PASS: C8 saved outputs verified');return
    (out/'summary.json').write_text('{"stage":"C8","result":"FAIL"}',encoding='ascii')
    tools={t:shutil.which(t) for t in ('vlib','vlog','vsim')}
    if not all(tools.values()):raise RuntimeError('ModelSim not on PATH')
    sources=(ROOT/'rtl/recognition/c8_sources.f').read_text().splitlines()
    summaries=[]
    with tempfile.TemporaryDirectory(prefix='fpga_c8_') as directory:
        work=Path(directory)
        for rel in sources+['sim/c8/tb_roi_rgb.v']:shutil.copy2(str(ROOT/rel),str(work/Path(rel).name))
        (work/'run.do').write_text('onerror {quit -f -code 1}\nonbreak {quit -f -code 1}\nrun -all\nquit -f -code 0\n',encoding='ascii')
        run([tools['vlib'],'work'],work,out/'vlib.log')
        run([tools['vlog'],'-sv']+[Path(s).name for s in sources]+['tb_roi_rgb.v'],work,out/'compile.log')
        for g in groups:
            dest=out/g['name'];dest.mkdir(exist_ok=True)
            with (work/'cases.txt').open('w',encoding='ascii') as f:
                for values in commands(g):
                    f.write(str(values[0])+' '+format(values[1],'08x')+' '+' '.join(str(v) for v in values[2:])+'\n')
            shutil.copy2(str(work/'cases.txt'),str(dest/'cases.txt'))
            print('C8: running '+g['name'],flush=True)
            run([tools['vsim'],'-c','-gWIDTH='+str(g['w']),'-gHEIGHT='+str(g['h']),'-gROI_X='+str(g['rx']),'-gROI_Y='+str(g['ry']),
                 'work.tb_roi_rgb','-do','run.do'],work,dest/'simulation.log')
            for name in ('actual.csv','events.csv','sampling_trace.vcd'):
                if (work/name).is_file():shutil.copy2(str(work/name),str(dest/name))
            summaries.append(check(g,dest,args.inject_error))
    try:check(groups[0],out/groups[0]['name'],True)
    except ValueError as exc:(out/'checker_selftest.log').write_text('EXPECTED FAILURE: '+str(exc),encoding='utf-8')
    else:raise ValueError('checker accepted incorrect sum')
    (out/'summary.json').write_text(json.dumps({'stage':'C8','result':'PASS','groups':summaries,
        'interface_version':'c8-draft-1','hardware':'not_tested','team_acceptance':'pending_A_B'},indent=2)+'\n',encoding='ascii')
    print('PASS: C8 ROI statistics, request protocol, reset and unchanged C7 detector')


if __name__=='__main__':
    try:main()
    except Exception as exc:print('FAIL: '+str(exc),file=sys.stderr);sys.exit(1)
