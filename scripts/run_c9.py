"""C9 arithmetic/control unit tests and complete runtime-calibrated RGB pipeline."""
import argparse,csv,json,random,re,shutil,subprocess,sys,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'model'))
from c9_reference import parameters,classify,frame_rgb
from c5_reference import majority,geometry
from c6_reference import packet

def unit_vectors():
    anchors=[]
    for means in [(152,40,40),(40,152,40),(40,40,152),(80,40,40),(79,0,0),(224,0,0),(225,0,0),(80,41,40),(80,40,41),(128,128,128),(16,16,16),(255,255,255)]:
        anchors.append([1,256]+list(means)*3)
    anchors+=[[1,256,152,40,40,136,40,40,168,40,40],
              [1,256,152,40,40,135,40,40,168,40,40],
              [0,256,152,40,40,152,40,40,152,40,40],
              [1,255,152,40,40,152,40,40,152,40,40],
              [1,256,152,40,40,153,40,40,160,40,40]]
    rng=random.Random(20261006)
    samples=anchors[:]
    for i in range(4096):
        if i%2:
            c=rng.randrange(3);means=[rng.randrange(81) for _ in range(3)];means[c]=rng.randrange(70,235)
            lows=[max(0,v-rng.randrange(20)) for v in means];highs=[min(255,v+rng.randrange(20)) for v in means]
        else:means=[rng.randrange(256) for _ in range(3)];lows=[rng.randrange(256) for _ in range(3)];highs=[rng.randrange(256) for _ in range(3)]
        samples.append([1,256]+means+lows+highs)
    vectors=[]
    for i,s in enumerate(samples):
        pix=[rng.randrange(256) for _ in range(3)];c=rng.randrange(4);limits=[rng.randrange(256) for _ in range(3)]
        vectors.append([int(i!=0),int(i%7!=0)]+s+[(i%1024)-512,(pix[0]<<16)|(pix[1]<<8)|pix[2],c]+limits)
    for pix in [(130,50,50),(130,51,50),(119,39,39),(120,40,40),(20,200,20)]:
        vectors.append([1,1]+anchors[0]+[0,(pix[0]<<16)|(pix[1]<<8)|pix[2],0,120,80,80])
    return vectors

def check_units(out,inject=False):
    expected=[]
    for i,v in enumerate(unit_vectors()):
        rst,pv,ok,count=v[:4];mr=v[4:7];lo=v[7:10];hi=v[10:13];sat,rgb,c,m,d1,d2=v[13:]
        expected.append([i]+parameters(ok,count,mr,lo,hi)+[max(0,min(255,sat-32)),rst*pv,rst*pv*classify((rgb>>16,(rgb>>8)&255,rgb&255),c,m,d1,d2)])
    if [r[-1] for r in expected[-5:]]!=[1,0,0,1,0]:raise ValueError('pixel anchors wrong')
    if expected[1][1:7]!=[1,0,1,120,80,80]:raise ValueError('green anchor wrong')
    if inject:expected[-5][-1]=0
    compare(out/'params_actual.csv',expected)
    compare(out/'control_actual.csv',control_expected())
    return len(expected),len(control_vectors())

def control_vectors():
    # rst,pv,sof,fid,req,select_req,select,done,valid,reason,sampleid,color,main,d1,d2
    def row(**kw):
        d=dict(rst=1,pv=0,sof=0,fid=0,req=0,selreq=0,sel=0,done=0,valid=0,reason=0,sid=0,color=0,main=120,d1=80,d2=80);d.update(kw)
        return [d[n] for n in ('rst','pv','sof','fid','req','selreq','sel','done','valid','reason','sid','color','main','d1','d2')]
    v=[row(rst=0),row(req=1),row(pv=1,sof=1,fid=10),row(req=1),
       row(pv=1,sof=1,fid=11,done=1,valid=1,sid=10),row(pv=1,sof=1,fid=11),
       row(pv=1,sof=1,fid=12,req=1),row(req=1),row(done=1,valid=0,reason=5,sid=12),
       row(selreq=1,sel=1),row(pv=1,sof=1,fid=12),row(pv=1,sof=1,fid=0xffffffff),
       row(req=1,selreq=1,sel=2),row(done=1,valid=1,sid=0xffffffff,color=2),row(pv=1,sof=1,fid=0),
       row(selreq=1,sel=3),row(rst=0),row(req=1)]
    v.extend(row(req=1) for _ in range(65540))
    v.extend([row(rst=0),row(done=1,valid=1),row(selreq=1,sel=0),row(rst=0),row(pv=1,sof=1,fid=0)])
    return v

def control_expected():
    active=[0,80,40,40];cfg=65535;pending=None;held_pending=[0,0,0,0];waiting=False;last=None;ignored=0;calib=[0,0,0]
    rows=[]
    for i,(rst,pv,sof,fid,req,sreq,sel,done,valid,reason,sid,color,main,d1,d2) in enumerate(control_vectors()):
        if not rst:active=[0,80,40,40];cfg=65535;pending=None;held_pending=[0,0,0,0];waiting=False;last=None;ignored=0;calib=[0,0,0]
        busy=waiting or pending is not None
        apply=pending is not None and pv and sof and (last is None or last!=fid)
        effective=pending[:] if apply else active[:];effective_cfg=(cfg+1)%65536 if apply else cfg
        pre=[int(req and not busy)]+effective+[effective_cfg]
        ri=si=cd=ap=0
        if rst:
            was_waiting=waiting
            if pv and sof:last=fid
            if req:
                if busy:ri=1;ignored=min(65535,ignored+1)
                else:waiting=True
            if sreq:
                if busy or req or sel==3:si=1
                else:pending=[sel,80,40,40];held_pending=pending[:]
            if was_waiting and done:
                waiting=False;cd=1;calib=[valid,reason,sid]
                if valid:pending=[color,main,d1,d2];held_pending=pending[:]
            if apply:active=effective;cfg=effective_cfg;pending=None;ap=1
        # Ordered exactly as independently observed output column names.
        rows.append([i]+pre+[int(waiting or pending is not None),ri,si,ignored,cd]+calib+
                    [ap,int(pending is not None),held_pending[0],active[0]]+held_pending[1:]+active[1:]+[cfg])
    if rows[6][-1]!=0:raise ValueError('cfg wrap anchor failed')
    return rows

def compare(path,want):
    with path.open(newline='') as f:rows=list(csv.reader(f));got=[[int(v) for v in r] for r in rows[1:]]
    if got!=want:
        i=next((i for i,(a,b) in enumerate(zip(got,want)) if a!=b),min(len(got),len(want)))
        raise ValueError('{} row {} actual={} expected={}'.format(path.name,i,got[i:i+1],want[i:i+1]))
    return got

def commands(g):
    for c in g['cases']:
        if c.get('op')=='reset':yield [1]+[0]*14
        elif c.get('op')=='idle':yield [2]+[0]*7+[c['cycles']]+[0]*6
        else:yield [0,c['id'],c['pattern'],c.get('req',-1),c.get('extra',-1),c.get('select_at',-1),c.get('select',0),int(c.get('stop',False)),0,c['cfg'],c['color']]+c['limits']+[0]

def prepare(g,work,dest):
    w,h=g['w'],g['h'];fi=0;expected_packets=[];raws=[];configs=[];last=None
    cycles=1;input_events=[]
    with (work/'frames.txt').open('w') as meta:
        for c in g['cases']:
            if c.get('op'):
                cycles+=1 if c['op']=='reset' else c['cycles']
                if c['op']=='reset':last=None
                continue
            configs.append([cycles+1,c['id'],c['cfg'],c['color']]+c['limits'])
            data=bytearray(classify(frame_rgb(c['pattern'],x,y,w,h),c['color'],*c['limits']) for y in range(h) for x in range(w))
            filtered=majority(w,h,data)
            (work/('mask_%d.txt'%fi)).write_bytes(b''.join(b'1\n' if v else b'0\n' for v in filtered))
            meta.write('{} {} {}\n'.format(c['id'],c['cfg'],c['color']));fi+=1
            rows=(h-16)//2+16 if c.get('stop') else h
            cycles+=rows*w+sum(1+y%3 for y in range(rows-1))
            if not c.get('stop'):
                raws.append([c['id'],c['cfg'],c['color'],sum(data)])
                input_events.append((c['id'],cycles))
                if not c.get('discard') and (last is None or c['id']!=last):
                    geom=geometry(w,filtered);count=geom[1];box=geom[2:6]
                    expected_packets.append([cycles+w+7]+packet(c['id'],c['cfg'],c['color'],count,box,w*h));last=c['id']
    for name,rows in [('expected_packets.json',expected_packets),('expected_raws.json',raws),('expected_configs.json',configs),('input_events.json',input_events)]:
        (dest/name).write_text(json.dumps(rows))
    (work/'cases.txt').write_text(''.join(' '.join(str(v) for v in r)+'\n' for r in commands(g)))
    shutil.copy2(str(work/'cases.txt'),str(dest/'cases.txt'))

def check_chain(g,dest):
    for filename,expected in [('actual.csv','expected_packets.json'),('raw_counts.csv','expected_raws.json'),('configs.csv','expected_configs.json')]:
        compare(dest/filename,json.loads((dest/expected).read_text()))
    with (dest/'calibrations.csv').open() as f:rows=list(csv.reader(f))[1:]
    rows=[[int(v) for v in row] for row in rows]
    wanted=[(1,1,0),(5,0,5),(7,0,3),(9,0,3),(11,0,4),(13,1,0),(17,1,0)] if g['name']=='protocol' else [(101,1,0)]
    if [(r[1],r[2],r[3]) for r in rows]!=wanted:raise ValueError('calibration sequence mismatch: '+str(rows))
    events=json.loads((dest/'input_events.json').read_text())
    for r in rows:
        eof=next(t for fid,t in events if fid==r[1])
        if r[0]!=eof+1:raise ValueError('calibration generation latency mismatch')
        if r[2]:
            color={1:0,13:1,17:2,101:0}[r[1]]
            if r[4:]!=[color,120,80,80]:raise ValueError('generated parameters wrong')
    log=(dest/'simulation.log').read_text(encoding='utf-8')
    match=re.search(r'C9_CHAIN_COMPLETE cycles=(\d+) raw_pixels=(\d+) filtered_pixels=(\d+)',log)
    if not match:raise ValueError('incomplete simulation')
    return dict(name=g['name'],cycles=int(match.group(1)),raw_pixels=int(match.group(2)),filtered_pixels=int(match.group(3)),
                calibration_events=len(rows),successful_calibrations=sum(r[2] for r in rows),packet_mismatches=0,pixel_mismatches=0,timing_errors=0)

def run(cmd,work,log):
    p=subprocess.run(cmd,cwd=str(work),stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=600)
    s=p.stdout.decode('utf-8',errors='replace');log.write_text(s,encoding='utf-8')
    if p.returncode:raise RuntimeError('tool failed: '+str(log))
    return s

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--check-only',action='store_true');ap.add_argument('--inject-error',action='store_true');args=ap.parse_args()
    out=ROOT/'reports/c9/generated';out.mkdir(parents=True,exist_ok=True)
    groups=json.loads((ROOT/'tests/fixtures/c9/cases.json').read_text())['groups']
    if args.check_only:
        check_units(out,args.inject_error)
        for g in groups:check_chain(g,out/g['name'])
        print('PASS: C9 saved results verified');return
    (out/'summary.json').write_text('{"result":"FAIL"}')
    tools={n:shutil.which(n) for n in ('vlib','vlog','vsim')}
    if not all(tools.values()):raise RuntimeError('ModelSim not on PATH')
    sources=(ROOT/'rtl/recognition/c9_sources.f').read_text().splitlines();summaries=[]
    with tempfile.TemporaryDirectory(prefix='fpga_c9_') as d:
        work=Path(d)
        for rel in sources+['sim/c9/tb_params.v','sim/c9/tb_control.v','sim/c9/tb_calibrated.v']:shutil.copy2(str(ROOT/rel),str(work/Path(rel).name))
        (work/'run.do').write_text('onerror {quit -f -code 1}\nonbreak {quit -f -code 1}\nrun -all\nquit -f -code 0\n')
        run([tools['vlib'],'work'],work,out/'vlib.log')
        run([tools['vlog'],'-sv']+[Path(s).name for s in sources]+['tb_params.v','tb_control.v','tb_calibrated.v'],work,out/'compile.log')
        with (work/'params.txt').open('w') as f:
            for v in unit_vectors():f.write(' '.join(str(x) for x in v[:14])+' '+format(v[14],'06x')+' '+' '.join(str(x) for x in v[15:])+'\n')
        (work/'control.txt').write_text(''.join(' '.join(str(v) for v in row)+'\n' for row in control_vectors()))
        for name in ('params','control'):
            s=run([tools['vsim'],'-c','work.tb_'+name,'-do','run.do'],work,out/(name+'_simulation.log'))
            if 'C9_'+name.upper()+'_COMPLETE' not in s:raise ValueError('unit incomplete')
            shutil.copy2(str(work/(name+'_actual.csv')),str(out/(name+'_actual.csv')))
        counts=check_units(out,args.inject_error);print('C9: params/classifier {} cycles, control {} cycles passed'.format(*counts),flush=True)
        for g in groups:
            dest=out/g['name'];dest.mkdir(exist_ok=True);prepare(g,work,dest)
            print('C9: running '+g['name'],flush=True)
            run([tools['vsim'],'-c','-gWIDTH='+str(g['w']),'-gHEIGHT='+str(g['h']),'work.tb_calibrated','-do','run.do'],work,dest/'simulation.log')
            for name in ('actual.csv','configs.csv','calibrations.csv','raw_counts.csv','calibration_trace.vcd'):
                shutil.copy2(str(work/name),str(dest/name))
            summaries.append(check_chain(g,dest))
    try:check_units(out,True)
    except ValueError as exc:(out/'checker_selftest.log').write_text('EXPECTED FAILURE: '+str(exc))
    else:raise ValueError('checker accepted false pixel')
    (out/'summary.json').write_text(json.dumps(dict(stage='C9',result='PASS',interface_version='c9-draft-1',seed=20261006,
        unit_cycles=counts[0],control_cycles=counts[1],groups=summaries,hardware='not_tested',team_acceptance='pending_A_B'),indent=2)+'\n')
    print('PASS: C9 calibration arithmetic, atomic application and complete RGB pipeline')

if __name__=='__main__':
    try:main()
    except Exception as exc:print('FAIL: '+str(exc),file=sys.stderr);sys.exit(1)
