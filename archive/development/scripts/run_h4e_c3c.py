"""C3c: request protocol and independent full-chain configuration/geometry checks."""
import hashlib,json,shutil,subprocess,sys,tempfile
from pathlib import Path
from collections import Counter
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'model'))
from h4e_c3c_reference import unit_vectors,unit_expected,chain_stimulus,rgb_at,expected_geometry,WIDTH,HEIGHT
from h4e_c2b_reference import classify
from run_h4e_c2a import compare,read_csv

def main():
    out=ROOT/'reports/h4e-c3c/generated';out.mkdir(parents=True,exist_ok=True)
    (out/'summary.json').write_text('{"status":"FAIL"}')
    sources=(ROOT/'rtl/recognition/h4e_c3c_sources.f').read_text().splitlines()
    benches=['sim/h4e_c3c/tb_h4e_control.v','sim/h4e_c3c/tb_h4e_calibrated_chain.v'];commands=[]
    def run(cmd,work,log):
        commands.append(cmd);p=subprocess.run(cmd,cwd=work,capture_output=True,text=True,timeout=120)
        (out/log).write_text(p.stdout+p.stderr)
        if p.returncode:raise RuntimeError(p.stdout+p.stderr)
        return p.stdout+p.stderr
    versions={name:run([shutil.which(name),'-V'],ROOT,name+'_version.log').splitlines()[0] for name in ('iverilog','vvp')}
    unit=unit_vectors();rows,frames=chain_stimulus()
    with tempfile.TemporaryDirectory(prefix='h4e_c3c_') as d:
        work=Path(d)
        for rel in sources+benches:shutil.copy2(ROOT/rel,work/Path(rel).name)
        fields=json.loads((ROOT/'sim/h4e_c3c/control_fields.json').read_text())
        (work/'control.txt').write_text(''.join(' '.join(str(v[k]) for k in fields)+'\n' for v in unit))
        with (work/'stimulus.txt').open('w') as f:
            for v in rows:
                f.write('%d %d %d %d %08x %d %d %d %d %d %06x %08x %08x %d %d %d\n'%tuple(v[k] for k in ('cycle','attempt','rst','flush','epoch','valid','sof','eof','x','y','rgb','fid','source_epoch','cal','sel','select')))
        ih={n:hashlib.sha256((work/n).read_bytes()).hexdigest() for n in ('control.txt','stimulus.txt')}
        for kind,bench in zip(('control','chain'),benches):
            run([shutil.which('iverilog'),'-g2012','-s',Path(bench).stem,'-o',kind+'.vvp']+[Path(s).name for s in sources]+[Path(bench).name],work,kind+'_compile.log')
            log=run([shutil.which('vvp'),kind+'.vvp'],work,kind+'_simulation.log')
            if ('C3C_CONTROL_PASS' if kind=='control' else 'H4E_C3C_CHAIN_COMPLETE') not in log:raise RuntimeError('incomplete '+kind)
        for name in ('control_actual.csv','results.csv','pixels.csv','configs.csv','errors.csv','controls.csv','candidates.csv'):shutil.copy2(work/name,out/name)
    ua=read_csv(out/'control_actual.csv');compare(ua,unit_expected(unit))
    named={v['name']:ua[i] for i,v in enumerate(unit)}
    assert named['wrap_cfg']['cfg']==0 and named['wrap_cfg']['apply']==1
    assert named['candidate_on_sof']['pending']==1 and named['candidate_on_sof']['apply']==0
    for key in ('cal_before_epoch','request_for_stale_candidate','request_invalid_candidate','cancel_old_operation','post_drain_new_request'):
        assert named[key]['sample']==1,key
    for key in ('epoch_revokes','epoch_revokes_pending','cancel_before_old_result'):
        assert named[key]['cancelled']==1,key
    for key in ('drain_1_rejects_new','drain_2_rejects_old_completion'):
        assert named[key]['sample']==0 and named[key]['ignored']==1,key
    result=read_csv(out/'results.csv');expected=[]
    for i,f in enumerate(frames):
        if f['event']:expected.append(dict(attempt=i,new_observation=f['fresh'],frame_id=f['fid'],capture_epoch=f['epoch'],cfg_id=f['active'][0],target_id=f['active'][1],**expected_geometry(f['scene'],f['active'])))
    compare(result,expected)
    configs=read_csv(out/'configs.csv')
    compare(configs,[dict(attempt=i,new_source_sof=f['new'],**dict(zip(('cfg','color','minimum','d1','d2'),f['active']))) for i,f in enumerate(frames)])
    pixels=read_csv(out/'pixels.csv');counts=Counter()
    for p in pixels:
        f=frames[p['attempt']];counts[p['attempt']]+=1
        compare([p],[dict(frame_id=f['fid'],epoch=f['epoch'],processing_rst_n=1,mask=classify(rgb_at(p['x'],p['y'],f['scene']),f['active']),**dict(zip(('cfg','color','minimum','d1','d2'),f['active'])))])
    for i,f in enumerate(frames):
        if f['event']:assert counts[i]==WIDTH*HEIGHT,(i,counts[i])
    controls=read_csv(out/'controls.csv')
    compare([v for v in controls if v['applied']],[dict(attempt=i,cfg=f['active'][0]) for i,f in enumerate(frames) if f['apply']])
    assert sum(v['ignored'] for v in controls)==4
    assert sum(v['select_ignored'] for v in controls)==3
    assert sum(v['cancelled'] for v in controls)==3
    candidates=read_csv(out/'candidates.csv')
    compare(candidates,[dict(fid=11,epoch=7,cfg=1,ok=1,reason=0,color=0,main=188,d1=158,d2=178,new_sof=0),
                        dict(fid=14,epoch=7,cfg=2,ok=1,reason=0,color=1,main=168,d1=148,d2=128,new_sof=1),
                        dict(fid=18,epoch=7,cfg=4,ok=0,reason=5,color=0,main=0,d1=0,d2=0,new_sof=0),
                        dict(fid=0,epoch=0,cfg=0,ok=0,reason=6,color=0,main=0,d1=0,d2=0,new_sof=0),
                        dict(fid=22,epoch=9,cfg=4,ok=0,reason=1,color=0,main=0,d1=0,d2=0,new_sof=0)])
    damaged=[dict(v) for v in result];damaged[0]['cfg_id']^=1
    try:compare(damaged,expected)
    except ValueError as exc:(out/'checker_selftest.log').write_text('EXPECTED_FAILURE: '+str(exc)+'\n')
    else:raise RuntimeError('checker missed cfg mismatch')
    tracked=sources+benches+['rtl/recognition/h4e_c3c_sources.f','sim/h4e_c3c/control_fields.json','model/h4e_c3c_reference.py','model/h4e_c2b_reference.py','model/h4e_c2a_reference.py','scripts/run_h4e_c3c.py','scripts/run_h4e_c2a.py']
    summary=dict(status='PASS',base_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        control_cycles=len(unit),chain_cycles=len(rows),frames=len(frames),results=len(result),classified_pixels=len(pixels),
        applications=sum(v['applied'] for v in controls),cancellations=sum(v['cancelled'] for v in controls),candidate_events=len(candidates),
        unit_cfg_wrap='65534 -> 65535 -> 0',candidate_sof_collision='PASS',checker_selftest='PASS',source='synthetic',hardware='not_tested',
        input_hashes=ih,tools=versions,python=sys.version,command_exit_codes='all 0',source_hashes={s:hashlib.sha256((ROOT/s).read_bytes()).hexdigest() for s in tracked})
    for name,data in [('summary.json',summary),('commands.json',commands),('frames.json',frames),('expected_results.json',expected),('directed_control.json',[v for v in unit if not v['name'].startswith('random_')])]:
        (out/name).write_text(json.dumps(data,indent=2)+'\n')
    print(json.dumps({k:v for k,v in summary.items() if k!='source_hashes'},indent=2))
if __name__=='__main__':main()
