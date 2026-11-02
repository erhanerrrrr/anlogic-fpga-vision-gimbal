"""C7 source-frame freshness, trajectory and continuity verification."""
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
from c6_reference import packet
from run_c6 import FIELDS


def unit_vectors():
    # Initial ID zero, repeated payload changes, wrap 15->0, reset and idle.
    vectors=[(0,0,0,0),(1,1,0,100),(1,1,0,999),(1,0,1,888),
             (1,1,1,101),(1,1,1,102),(1,1,15,115),(1,1,0,116),
             (1,1,0,117),(0,1,0,118),(1,1,0,119)]
    rng=random.Random(20261006);fid=0
    for i in range(4096):
        if rng.randrange(3)==0:fid=(fid+1)%16
        vectors.append((1,int(rng.randrange(5)!=0),fid,rng.getrandbits(32)))
        if i==2048:vectors.append((0,1,fid,0))
    vectors.extend([(1,0,fid,0)]*100)
    return vectors


def check_unit(out,inject=False):
    expected=[];last=None;value=0
    for i,(rst,s,fid,data) in enumerate(unit_vectors()):
        accepted=0
        if not rst:last=None;value=0
        elif s and (last is None or fid!=last):accepted=1;last=fid;value=data
        expected.append([i,accepted,0 if last is None else last,value])
    # Known prefix explicitly requires zero-ID first acceptance and wrap acceptance.
    if [r[1] for r in expected[:11]]!=[0,1,0,0,1,0,1,1,0,0,1]:raise ValueError('unit anchor mismatch')
    if inject:expected[2][1]=1
    with (out/'unit_actual.csv').open(newline='') as f:
        reader=csv.reader(f);next(reader);actual=[[int(v) for v in row] for row in reader]
    if actual!=expected:raise ValueError('unit freshness/hold/reset mismatch')
    return len(expected),sum(r[1] for r in expected)


def expected_packet(c,w,h):
    left=(100 if w>=640 else 10)+({1:10,2:20}.get(c['pattern'],0))
    top=80 if h>=360 else 8
    if c['pattern']==3:count=0;box=[0,0,0,0]
    elif c['pattern']==4:count=2534;box=[100,80,340,110]
    else:count=1267;box=[left,top,left+40,top+30]
    result=packet(c['id'],c.get('cfg',0),c.get('color',0),count,box,w*h)
    if 'cx' in c and result[9]!=c['cx']:raise ValueError('trajectory anchor mismatch')
    return result


def trajectory(out,rows):
    # Plot actual published positions only; empty frames are marked without inventing a position.
    svg=['<svg xmlns="http://www.w3.org/2000/svg" width="720" height="260" viewBox="0 0 720 260">',
         '<rect width="720" height="260" fill="white"/>',
         '<text x="20" y="24" font-size="16">C7 actual published centers (blue=cx, green=cy)</text>',
         '<path d="M50 45 V205 H680" stroke="#888" fill="none"/>']
    for i,row in enumerate(rows):
        x=70+i*580/max(1,len(rows)-1)
        svg.append('<text x="{}" y="228" text-anchor="middle" font-size="13">{}</text>'.format(x,row['frame_id']))
        if row['valid']=='1':
            for field,color in [('cx','#2463c4'),('cy','#23834b')]:
                value=int(row[field]);y=200-value
                svg.append('<circle cx="{}" cy="{}" r="4" fill="{}"/>'.format(x,y,color))
                svg.append('<text x="{}" y="{}" text-anchor="middle" font-size="11" fill="{}">{}</text>'.format(x,y-8,color,value))
        else:svg.append('<text x="{}" y="190" text-anchor="middle" font-size="12" fill="#b33">invalid</text>'.format(x))
    svg.append('<text x="330" y="250" font-size="12">source_frame_id (duplicate 15 has no new point)</text></svg>')
    (out/'trajectory.svg').write_text('\n'.join(svg),encoding='utf-8')


def check_chain(out,g):
    w,h=g['w'],g['h'];complete=[];published=[];publish_indices=[];last=None
    for c in g['cases']:
        if c.get('abort') or c.get('stop'):
            last=None;continue
        expected=expected_packet(c,w,h);complete.append(expected)
        is_new=last is None or c['id']!=last
        if is_new!=c['publish']:raise ValueError('fixture publication policy inconsistent')
        if is_new:published.append(expected);publish_indices.append(len(complete)-1);last=c['id']
    def read(name):
        with (out/name).open(newline='') as f:return list(csv.DictReader(f))
    candidates=read('candidates.csv');results=read('actual.csv');counts=read('filtered_counts.csv');events=read('timing.csv')
    if [[int(r[k]) for k in FIELDS] for r in candidates]!=complete:raise ValueError('candidate content/count mismatch')
    if [[int(r[k]) for k in FIELDS] for r in results]!=published:raise ValueError('published sequence mismatch')
    expected_counts=[[r[0],r[1],r[2],w*h,r[12]] for r in complete]
    if [[int(r[k]) for k in ('frame_id','cfg_id','target_id','pixels','ones')] for r in counts]!=expected_counts:
        raise ValueError('display-mask repetition or metadata mismatch')
    inputs=[e for e in events if e['kind']=='input'];filtered=[e for e in events if e['kind']=='filtered']
    if len(inputs)!=len(complete) or len(filtered)!=len(complete):raise ValueError('EOF count mismatch')
    for i,candidate in enumerate(candidates):
        if int(candidate['cycle'])-int(inputs[i]['cycle'])!=w+6:raise ValueError('C6 latency changed')
        if int(filtered[i]['cycle'])-int(inputs[i]['cycle'])!=w+3:raise ValueError('filter latency changed')
    for row,index in zip(results,publish_indices):
        if int(row['cycle'])-int(candidates[index]['cycle'])!=1:raise ValueError('freshness latency mismatch')
    if g['name']=='specified_sequence':
        if len(results)!=7:raise ValueError('specified sequence must publish exactly 7 observations')
        trajectory(out,results)
    with (out/'expected.csv').open('w',newline='',encoding='ascii') as f:
        writer=csv.writer(f);writer.writerow(FIELDS);writer.writerows(published)
    return {'name':g['name'],'dimensions':[w,h],'complete_display_frames':len(complete),
            'new_observations':len(results),'suppressed_duplicates':len(complete)-len(results),
            'valid_observations':sum(r[3] for r in published),'L_result':w+7}


def run(command,work,log):
    result=subprocess.run(command,cwd=str(work),stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=360)
    text=result.stdout.decode('utf-8',errors='replace');log.write_text(text,encoding='utf-8')
    if result.returncode:raise RuntimeError('tool failed: '+str(log))
    return text


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--check-only',action='store_true')
    parser.add_argument('--inject-error',action='store_true');args=parser.parse_args()
    fixture=json.loads((ROOT/'tests/fixtures/c7/cases.json').read_text(encoding='utf-8'))
    out=ROOT/'reports/c7/generated';out.mkdir(parents=True,exist_ok=True)
    if args.check_only:
        check_unit(out,args.inject_error)
        for g in fixture['groups']:check_chain(out/g['name'],g)
        print('PASS: C7 saved outputs verified');return
    (out/'summary.json').write_text('{"stage":"C7","result":"FAIL"}',encoding='utf-8')
    tools={t:shutil.which(t) for t in ('vlib','vlog','vsim')}
    if not all(tools.values()):raise RuntimeError('ModelSim not on PATH')
    sources=(ROOT/'rtl/recognition/c7_sources.f').read_text().splitlines()
    with tempfile.TemporaryDirectory(prefix='fpga_c7_') as directory:
        work=Path(directory)
        for rel in sources+['sim/c7/tb_new_frame_unit.v','sim/c7/tb_fresh_rgb.v']:
            shutil.copy2(str(ROOT/rel),str(work/Path(rel).name))
        (work/'run.do').write_text('onerror {quit -f -code 1}\nonbreak {quit -f -code 1}\nrun -all\nquit -f -code 0\n',encoding='ascii')
        run([tools['vlib'],'work'],work,out/'vlib.log')
        run([tools['vlog'],'-sv']+[Path(s).name for s in sources]+['tb_new_frame_unit.v','tb_fresh_rgb.v'],work,out/'compile.log')
        with (work/'unit.txt').open('w',encoding='ascii') as f:
            for i,(rst,s,fid,payload) in enumerate(unit_vectors()):f.write('{} {} {} {} {:08x}\n'.format(i,rst,s,fid,payload))
        shutil.copy2(str(work/'unit.txt'),str(out/'unit.txt'))
        log=run([tools['vsim'],'-c','work.tb_new_frame_unit','-do','run.do'],work,out/'unit_simulation.log')
        if 'C7_UNIT_COMPLETE' not in log:raise ValueError('unit simulation incomplete')
        shutil.copy2(str(work/'unit_actual.csv'),str(out/'unit_actual.csv'))
        cycles,unit_notices=check_unit(out,args.inject_error)
        print('C7: {} unit cycles passed'.format(cycles),flush=True)
        summaries=[]
        for g in fixture['groups']:
            dest=out/g['name'];dest.mkdir(exist_ok=True)
            with (work/'cases.txt').open('w',encoding='ascii') as f:
                for c in g['cases']:
                    f.write('{:08x} {} {} {} {} {}\n'.format(c['id'],c['pattern'],int(c.get('abort',False)),int(c.get('stop',False)),c.get('cfg',0),c.get('color',0)))
            shutil.copy2(str(work/'cases.txt'),str(dest/'cases.txt'))
            print('C7: running '+g['name'],flush=True)
            log=run([tools['vsim'],'-c','-gWIDTH='+str(g['w']),'-gHEIGHT='+str(g['h']),'-gDRAIN='+str(int(g['drain'])),
                     'work.tb_fresh_rgb','-do','run.do'],work,dest/'simulation.log')
            for name in ('actual.csv','candidates.csv','filtered_counts.csv','timing.csv','freshness_trace.vcd'):
                if (work/name).is_file():shutil.copy2(str(work/name),str(dest/name))
            if 'C7_CHAIN_COMPLETE' not in log:raise ValueError('chain incomplete: '+g['name'])
            summaries.append(check_chain(dest,g))
    try:check_unit(out,True)
    except ValueError as exc:(out/'checker_selftest.log').write_text('EXPECTED FAILURE: '+str(exc),encoding='utf-8')
    else:raise ValueError('checker accepted false duplicate observation')
    (out/'summary.json').write_text(json.dumps({'stage':'C7','result':'PASS','interface_version':'c7-draft-1',
        'seed':20261006,'unit_cycles':cycles,'unit_observations':unit_notices,'groups':summaries,
        'packet_mismatches':0,'timing_errors':0,'dedup_scope':'consecutive source-frame equality',
        'td':'see separate report','hardware':'not_tested','team_acceptance':'pending_A_B'},indent=2)+'\n',encoding='utf-8')
    print('PASS: C7 motion, loss/reappearance, duplicate suppression, wrap, stop and reset')


if __name__=='__main__':
    try:main()
    except Exception as exc:
        print('FAIL: '+str(exc),file=sys.stderr);sys.exit(1)
