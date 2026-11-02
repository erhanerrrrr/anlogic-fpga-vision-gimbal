"""C6 boundary/random unit verification and full RGB->C5->validity integration."""
import argparse
import csv
import json
from pathlib import Path
import random
import shutil
import subprocess
import sys
import tempfile

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'model'))
from c6_reference import decide,packet
from c5_reference import majority,geometry
from run_c2 import png

FIELDS=('frame_id','cfg_id','target_id','valid','area','xmin','ymin','xmax','ymax','cx','cy','reason',
        'debug_count','debug_xmin','debug_ymin','debug_xmax','debug_ymax')


def unit_vectors():
    # Literal reason anchors for default area ceiling; independent of RTL.
    anchors=[(0,[0,0,0,0],1),(9,[0,0,2,2],0),(8,[0,0,2,2],2),
        (20,[0,0,1,9],3),(12,[0,0,3,3],0),(11,[0,0,3,3],5),
        (1271,[100,80,140,110],0),(1267,[100,80,140,110],0),
        (2542,[100,80,340,110],5),(2534,[100,80,340,110],5),
        (100,[0,0,9,9],0),(101,[0,0,9,10],0),
        (921600,[0,0,1279,719],0),(921601,[0,0,1279,720],4),
        (921600,[0,0,2047,2047],5),(1048575,[0,0,2047,2047],4),
        (9,[10,10,8,12],6),(10,[0,0,2,2],6),(2542,[100,80,182,110],0)]
    vectors=[(0,0,0,[0,0,0,0])]
    for count,box,reason in anchors:
        if decide(count,box)!=reason:raise ValueError('literal unit anchor mismatch')
        vectors.append((1,1,count,box))
    rng=random.Random(20261005)
    for i in range(4096):
        l,t=rng.randrange(2048),rng.randrange(2048)
        r,b=rng.randrange(l,2048),rng.randrange(t,2048)
        size=(r-l+1)*(b-t+1)
        ceiling=min(size,1048575)
        count=rng.choice([rng.randrange(ceiling+1),min(ceiling,3*size//4),min(ceiling,(3*size+3)//4)])
        vectors.append((1,1,count,[l,t,r,b]))
        if i%127==0:vectors.append((1,0,count,[l,t,r,b]))
        if i==2048:vectors.append((0,1,count,[l,t,r,b]))
    return vectors


def check_unit(out,inject=False):
    rows=unit_vectors();expected=[];last=[[0]*17 for _ in range(2)]
    reasons=set()
    for i,(rst,s,count,box) in enumerate(rows):
        for profile,limit in enumerate((921600,100)):
            if not rst:last[profile]=[0]*17
            elif s:
                last[profile]=packet(i,i%65536,i%3,count,box,limit)
                reasons.add(last[profile][11])
            expected.append([i,profile,int(bool(rst and s))]+last[profile])
    if inject:expected[2][14]^=1
    with (out/'unit_actual.csv').open(newline='') as f:
        reader=csv.reader(f);next(reader);actual=[[int(v) for v in row] for row in reader]
    if actual!=expected:raise ValueError('unit packet/validity/reason/debug mismatch')
    if reasons!=set(range(7)):raise ValueError('reason coverage incomplete')
    return len(rows),len(expected)


def scene(w,h,c):
    p=c['pattern'];data=bytearray(w*h)
    for y in range(h):
        for x in range(w):
            if p==0:bit=100<=x<=140 and 80<=y<=110
            elif p==1:bit=(100<=x<=140 or 300<=x<=340) and 80<=y<=110
            elif p==2:bit=(100<=x<=140 or 142<=x<=182) and 80<=y<=110
            elif p==3:bit=False
            elif p==4:bit=10<=x<=12 and 10<=y<=12
            elif p==5:bit=10<=x<=13 and 10<=y<=13
            elif p==6:bit=10<=x<=11 and 10<=y<=19
            elif p==7:bit=True
            else:raise ValueError('unknown scene')
            data[y*w+x]=bit
    return data


def check_chain(out,group):
    w,h=group['w'],group['h'];expected=[];expected_counts=[];details=[]
    for c in group['cases']:
        if c.get('abort'):continue
        raw=scene(w,h,c);filtered=majority(w,h,raw);geo=geometry(w,filtered)
        count=geo[1];box=geo[2:6]
        want=packet(c['id'],c.get('cfg',0),c.get('color',0),count,box,group['max_area'])
        if want[11]!=c['reason'] or ('count' in c and count!=c['count']):raise ValueError('chain literal anchor mismatch')
        expected.append(want);expected_counts.append([c['id'],c.get('cfg',0),c.get('color',0),w*h,count])
        png(out/(c['name']+'_reference_mask.png'),w,h,bytearray(v*255 for v in filtered))
        details.append({'name':c['name'],'raw_geometry':geo,'reason':want[11],'target_valid':want[3]})
    with (out/'actual.csv').open(newline='') as f:rows=list(csv.DictReader(f))
    actual=[[int(row[k]) for k in FIELDS] for row in rows]
    if actual!=expected:raise ValueError('chain public/debug/reason fields mismatch')
    with (out/'filtered_counts.csv').open(newline='') as f:
        reader=csv.reader(f);next(reader);observed=[[int(v) for v in row] for row in reader]
    if observed!=expected_counts:raise ValueError('filtered output count/metadata mismatch')
    with (out/'timing.csv').open(newline='') as f:events=list(csv.DictReader(f))
    times={(e['kind'],int(e['frame_id'])):int(e['cycle']) for e in events}
    for row in rows:
        fid=int(row['frame_id']);done=int(row['cycle'])
        if done-times['input',fid]!=w+6 or done-times['filtered',fid]!=3:
            raise ValueError('C6 result latency mismatch')
    with (out/'expected.csv').open('w',newline='',encoding='ascii') as f:
        writer=csv.writer(f);writer.writerow(FIELDS);writer.writerows(expected)
    return {'dimensions':[w,h],'max_area':group['max_area'],'results':len(expected),
            'valid':sum(row[3] for row in expected),'invalid':sum(1-row[3] for row in expected),
            'L_result':w+6,'cases':details}


def run(command,work,log):
    result=subprocess.run(command,cwd=str(work),stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=360)
    text=result.stdout.decode('utf-8',errors='replace');log.write_text(text,encoding='utf-8')
    if result.returncode:raise RuntimeError('tool failed: '+str(log))
    return text


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--check-only',action='store_true')
    parser.add_argument('--inject-error',action='store_true');args=parser.parse_args()
    fixture=json.loads((ROOT/'tests/fixtures/c6/cases.json').read_text(encoding='utf-8'))
    out=ROOT/'reports/c6/generated';out.mkdir(parents=True,exist_ok=True)
    if args.check_only:
        check_unit(out,args.inject_error)
        for g in fixture['groups']:check_chain(out/('{}x{}'.format(g['w'],g['h'])),g)
        print('PASS: C6 saved outputs verified');return
    (out/'summary.json').write_text('{"stage":"C6","result":"FAIL"}',encoding='utf-8')
    tools={t:shutil.which(t) for t in ('vlib','vlog','vsim')}
    if not all(tools.values()):raise RuntimeError('ModelSim not on PATH')
    sources=(ROOT/'rtl/recognition/c6_sources.f').read_text().splitlines()
    with tempfile.TemporaryDirectory(prefix='fpga_c6_') as directory:
        work=Path(directory)
        for rel in sources+['sim/c6/tb_validity_unit.v','sim/c6/tb_validated_rgb.v']:
            shutil.copy2(str(ROOT/rel),str(work/Path(rel).name))
        (work/'run.do').write_text('onerror {quit -f -code 1}\nonbreak {quit -f -code 1}\nrun -all\nquit -f -code 0\n',encoding='ascii')
        run([tools['vlib'],'work'],work,out/'vlib.log')
        run([tools['vlog'],'-sv']+[Path(s).name for s in sources]+['tb_validity_unit.v','tb_validated_rgb.v'],work,out/'compile.log')
        with (work/'unit.txt').open('w',encoding='ascii') as f:
            for i,(rst,s,count,box) in enumerate(unit_vectors()):f.write(' '.join(map(str,[i,rst,s,count]+box))+'\n')
        shutil.copy2(str(work/'unit.txt'),str(out/'unit.txt'))
        log=run([tools['vsim'],'-c','work.tb_validity_unit','-do','run.do'],work,out/'unit_simulation.log')
        if 'C6_UNIT_COMPLETE' not in log:raise RuntimeError('unit simulation incomplete')
        shutil.copy2(str(work/'unit_actual.csv'),str(out/'unit_actual.csv'))
        cycles,comparisons=check_unit(out,args.inject_error)
        print('C6: {} unit cycles, {} packet comparisons passed'.format(cycles,comparisons),flush=True)
        summaries=[]
        for g in fixture['groups']:
            w,h=g['w'],g['h'];dest=out/('{}x{}'.format(w,h));dest.mkdir(exist_ok=True)
            with (work/'cases.txt').open('w',encoding='ascii') as f:
                for c in g['cases']:f.write('{:08x} {} {} {} {}\n'.format(c['id'],c['pattern'],int(c.get('abort',False)),c.get('cfg',0),c.get('color',0)))
            shutil.copy2(str(work/'cases.txt'),str(dest/'cases.txt'))
            print('C6: full RGB chain {}x{}...'.format(w,h),flush=True)
            log=run([tools['vsim'],'-c','-gWIDTH='+str(w),'-gHEIGHT='+str(h),'-gMAX_AREA='+str(g['max_area']),
                     'work.tb_validated_rgb','-do','run.do'],work,dest/'simulation.log')
            for name in ('actual.csv','filtered_counts.csv','timing.csv','validity_trace.vcd'):
                if (work/name).is_file():shutil.copy2(str(work/name),str(dest/name))
            if 'C6_CHAIN_COMPLETE' not in log:raise RuntimeError('chain simulation incomplete')
            summaries.append(check_chain(dest,g))
    try:check_unit(out,True)
    except ValueError as exc:(out/'checker_selftest.log').write_text('EXPECTED FAILURE: '+str(exc),encoding='utf-8')
    else:raise RuntimeError('checker accepted altered reason')
    (out/'summary.json').write_text(json.dumps({'stage':'C6','result':'PASS','interface_version':'c6-draft-1',
        'seed':20261005,'unit_cycles':cycles,'unit_comparisons':comparisons,'reason_codes_covered':list(range(7)),
        'groups':summaries,'packet_mismatches':0,'timing_errors':0,'td':'see separate report','hardware':'not_tested',
        'team_acceptance':'pending_A_B','limitation':'nearby same-color objects may still pass'},indent=2)+'\n',encoding='utf-8')
    print('PASS: C6 boundary/random rules, accepted/rejected examples, debug fields and timing')


if __name__=='__main__':
    try:main()
    except Exception as exc:
        print('FAIL: '+str(exc),file=sys.stderr);sys.exit(1)
