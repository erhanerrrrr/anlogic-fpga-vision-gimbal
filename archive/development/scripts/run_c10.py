"""C10 final C-only deterministic video acceptance; no B or hardware claims."""
import argparse,csv,hashlib,json,re,shutil,subprocess,sys,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'model'))
from c10_reference import rgb
from c9_reference import classify
from c5_reference import majority,geometry
from c6_reference import packet
from run_c2 import png
from run_c9 import compare


def reference(g,c):
    w,h=g['w'],g['h']
    data=bytearray(classify(rgb(c['pattern'],x,y,w,h),c['color'],*c['limits']) for y in range(h) for x in range(w))
    filtered=majority(w,h,data);geom=geometry(w,filtered);a=c['expected']
    p=packet(c['id'],c['cfg'],c['color'],geom[1],geom[2:6],w*h)
    if sum(data)!=a['raw_count'] or geom[1]!=a['filtered_count'] or geom[2:6]!=a['bbox'] or p[3]!=a['valid'] or p[11]!=a['reason']:
        raise ValueError('independent fixture anchor mismatch: '+str(c['id']))
    return data,filtered,p


def expectations(g):
    w,h=g['w'],g['h'];cycle=1;last=None;configs=[];raws=[];results=[];eofs=[];table=[]
    for c in g['cases']:
        if c.get('op'):
            cycle+=1 if c['op']=='reset' else c['cycles']
            if c['op']=='reset':last=None
            continue
        configs.append([cycle+1,c['id'],c['cfg'],c['color']]+c['limits'])
        count=c.get('stop_after',w*h)
        cycle+=count+sum(1+y%3 for y in range(h-1) if (y+1)*w<count)
        a=c['expected'];p=packet(c['id'],c['cfg'],c['color'],a['filtered_count'],a['bbox'],w*h)
        table.append([len(table),c['id'],c['cfg'],c['color'],c['limits'][0],c['limits'][1],c['limits'][2],int(c['publish'])]+p[3:])
        if 'stop_after' in c:continue
        eofs.append([c['id'],cycle]);raws.append([c['id'],c['cfg'],c['color'],a['raw_count']])
        is_new=last is None or c['id']!=last
        if is_new!=c['publish']:raise ValueError('fixture notification policy inconsistent')
        if is_new:results.append([cycle+w+7]+p);last=c['id']
    return configs,raws,results,eofs,table,cycle+w+50


def prepare(g,work,dest):
    metas=[];commands=[];fi=0
    for c in g['cases']:
        if c.get('op')=='reset':commands.append([1]+[0]*14);continue
        if c.get('op')=='idle':commands.append([2]+[0]*7+[c['cycles']]+[0]*5+[c['busy']]);continue
        data,filtered,p=reference(g,c)
        ascii_mask=bytes(49 if b else 48 for b in filtered)
        (work/('mask_%d.txt'%fi)).write_bytes(b'\n'.join(ascii_mask[y*g['w']:(y+1)*g['w']] for y in range(g['h']))+b'\n')
        (dest/('expected_mask_%d.bin'%fi)).write_bytes(bytes(255 if v else 0 for v in filtered))
        metas.append([c['id'],c['cfg'],c['color']]);fi+=1
        commands.append([0,c['id'],c['pattern'],c.get('req',-1),c.get('extra',-1),-1,0,c.get('stop_after',0),0,c['cfg'],c['color']]+c['limits']+[0])
    (work/'frames.txt').write_text(''.join(' '.join(map(str,r))+'\n' for r in metas))
    (work/'cases.txt').write_text(''.join(' '.join(map(str,r))+'\n' for r in commands))
    shutil.copy2(str(work/'cases.txt'),str(dest/'cases.txt'))
    expected=expectations(g)
    with (dest/'expected_frames.csv').open('w',newline='') as f:
        writer=csv.writer(f);writer.writerow('index frame_id cfg_id color main d1 d2 publish valid area xmin ymin xmax ymax cx cy reason debug_count debug_xmin debug_ymin debug_xmax debug_ymax'.split());writer.writerows(expected[4])


def check(g,dest,inject=False):
    configs,raws,results,eofs,table,cycles=expectations(g)
    if inject:results[0][10]+=1
    compare(dest/'configs.csv',configs);compare(dest/'raw_counts.csv',raws);compare(dest/'actual.csv',results)
    with (dest/'calibrations.csv').open() as f:calibs=[[int(v) for v in r] for r in list(csv.reader(f))[1:]]
    if [r[1:] for r in calibs]!=g['calibrations']:raise ValueError('calibration events mismatch')
    for r in calibs:
        eof=next(t for fid,t in eofs if fid==r[1])
        if r[0]!=eof+1:raise ValueError('calibration latency mismatch')
    with (dest/'timing.csv').open() as f:events=list(csv.DictReader(f))
    if [[int(r['frame_id']),int(r['cycle'])] for r in events if r['kind']=='input']!=eofs:raise ValueError('input EOF mismatch')
    if [[int(r['frame_id']),int(r['cycle'])] for r in events if r['kind']=='filtered']!=[[fid,t+g['w']+3] for fid,t in eofs]:raise ValueError('filtered EOF mismatch')
    complete=0;actual_pixels=0;frames=[c for c in g['cases'] if 'id' in c]
    for i,c in enumerate(frames):
        actual=(dest/('actual_mask_%d.bin'%i)).read_bytes();want=(dest/('expected_mask_%d.bin'%i)).read_bytes()
        if not actual or actual!=want[:len(actual)] or len(actual)>len(want):raise ValueError('saved RTL mask mismatch index '+str(i))
        if 'stop_after' not in c:
            if len(actual)!=g['w']*g['h']:raise ValueError('incomplete displayed frame')
            complete+=1;png(dest/('mask_%02d_id%d.png'%(i,c['id'])),g['w'],g['h'],actual)
        actual_pixels+=len(actual)
    log=(dest/'simulation.log').read_text(encoding='utf-8')
    m=re.search(r'C10_CHAIN_COMPLETE cycles=(\d+) raw_pixels=(\d+) filtered_pixels=(\d+) complete_frames=(\d+)',log)
    expected_raw=sum(c.get('stop_after',g['w']*g['h']) for c in frames)
    if not m or [int(v) for v in m.groups()]!=[cycles,expected_raw,actual_pixels,complete]:raise ValueError('completion/count mismatch')
    valid=sum(r[4] for r in results);rejected=len(results)-valid
    summary=dict(name=g['name'],input_complete_frames=complete,partial_input_frames=len(frames)-complete,
        input_pixels=expected_raw,filtered_pixels=actual_pixels,new_observations=len(results),valid_observations=valid,
        rejected_observations=rejected,suppressed_duplicates=complete-len(results),calibrations=len(calibs),
        successful_calibrations=sum(r[2] for r in calibs),L_result_cycles=g['w']+7,L_filtered_cycles=g['w']+3,
        pixel_mismatches=0,packet_mismatches=0,timing_errors=0,cycles=cycles)
    return summary


def run(cmd,work,log):
    p=subprocess.run(cmd,cwd=str(work),stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=1200)
    text=p.stdout.decode('utf-8',errors='replace');log.write_text(text,encoding='utf-8')
    if p.returncode:raise RuntimeError('tool failed: '+str(log))
    return text


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--check-only',action='store_true');ap.add_argument('--inject-error',action='store_true');args=ap.parse_args()
    groups=json.loads((ROOT/'tests/fixtures/c10/cases.json').read_text())['groups']
    out=ROOT/'reports/c10/generated';out.mkdir(parents=True,exist_ok=True)
    if args.check_only:
        for g in groups:check(g,out/g['name'],args.inject_error)
        print('PASS: C10 saved masks, packets and timing verified');return
    (out/'summary.json').write_text('{"stage":"C10","result":"FAIL"}')
    tools={n:shutil.which(n) for n in ('vlib','vlog','vsim')}
    if not all(tools.values()):raise RuntimeError('ModelSim not on PATH')
    sources=(ROOT/'rtl/recognition/c10_sources.f').read_text().splitlines();summaries=[]
    with tempfile.TemporaryDirectory(prefix='fpga_c10_') as d:
        work=Path(d)
        for rel in sources+['sim/c10/tb_final_chain.v']:shutil.copy2(str(ROOT/rel),str(work/Path(rel).name))
        (work/'run.do').write_text('onerror {quit -f -code 1}\nonbreak {quit -f -code 1}\nrun -all\nquit -f -code 0\n')
        run([tools['vlib'],'work'],work,out/'vlib.log')
        run([tools['vlog'],'-sv']+[Path(s).name for s in sources]+['tb_final_chain.v'],work,out/'compile.log')
        for g in groups:
            dest=out/g['name'];dest.mkdir(exist_ok=True)
            print('C10: preparing independent reference '+g['name'],flush=True);prepare(g,work,dest)
            print('C10: simulating '+g['name'],flush=True)
            run([tools['vsim'],'-c','-gWIDTH='+str(g['w']),'-gHEIGHT='+str(g['h']),'work.tb_final_chain','-do','run.do'],work,dest/'simulation.log')
            for name in ('actual.csv','configs.csv','calibrations.csv','raw_counts.csv','timing.csv','states.csv','calibration_trace.vcd'):
                shutil.copy2(str(work/name),str(dest/name))
            for i,c in enumerate(c for c in g['cases'] if 'id' in c):
                raw=(work/('actual_mask_%d.txt'%i)).read_bytes().replace(b'\r',b'').replace(b'\n',b'')
                if any(b not in (48,49) for b in raw):raise ValueError('invalid captured mask byte')
                (dest/('actual_mask_%d.bin'%i)).write_bytes(bytes(255 if b==49 else 0 for b in raw))
            summaries.append(check(g,dest,args.inject_error))
    try:check(groups[0],out/groups[0]['name'],True)
    except ValueError as exc:(out/'checker_selftest.log').write_text('EXPECTED FAILURE: '+str(exc))
    else:raise ValueError('checker accepted wrong center')
    hashes={s:hashlib.sha256((ROOT/s).read_bytes()).hexdigest() for s in sources}
    (out/'source_manifest.json').write_text(json.dumps(hashes,indent=2)+'\n')
    (out/'summary.json').write_text(json.dumps(dict(stage='C10',result='PASS',interface_version='c9-draft-1',seed=20261006,
        groups=summaries,tool_versions=dict(python=sys.version.split()[0],modelsim='10.3c'),
        board_measurements='pending_H3_H4',B_integration='pending_B_RTL',real_input_replay='no_capture_available',
        throughput='one_valid_pixel_per_clock_in_simulation',hardware_fps=None,timing_signoff=False),indent=2)+'\n')
    print('PASS: C10 C-only masks, observations, calibration, reset and stop recovery')

if __name__=='__main__':
    try:main()
    except Exception as exc:print('FAIL: '+str(exc),file=sys.stderr);sys.exit(1)
