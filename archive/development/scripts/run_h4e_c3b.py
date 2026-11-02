"""C3b rule, saturation, event and real sampler integration tests."""
import csv,hashlib,json,shutil,subprocess,sys,tempfile
from collections import Counter
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'model'))
from h4e_c3b_reference import stimulus,cycles,result,PROFILES
from run_h4e_c2a import compare,read_csv

def main():
    out=ROOT/'reports/h4e-c3b/generated';out.mkdir(parents=True,exist_ok=True)
    (out/'summary.json').write_text('{"status":"FAIL"}')
    sources=['rtl/recognition/h4e_calibration_candidate.v','rtl/recognition/h4e_roi_sampler.v','rtl/recognition/capture_frame_guard.v',
             'sim/h4e_c3b/tb_h4e_candidate.v','sim/h4e_c3b/tb_h4e_candidate_sample.v']
    commands=[]
    def run(cmd,work,log):
        commands.append(cmd)
        p=subprocess.run(cmd,cwd=work,capture_output=True,text=True,timeout=90)
        (out/log).write_text(p.stdout+p.stderr)
        if p.returncode:raise RuntimeError(p.stdout+p.stderr)
        return p.stdout
    rows=stimulus();order=json.loads((ROOT/'sim/h4e_c3b/vector_fields.json').read_text())
    with tempfile.TemporaryDirectory(prefix='h4e_c3b_') as d:
        work=Path(d)
        for rel in sources:shutil.copy2(ROOT/rel,work/Path(rel).name)
        (work/'vectors.txt').write_text(''.join(' '.join(str(v[k]) for k in order)+'\n' for v in rows))
        input_hash=hashlib.sha256((work/'vectors.txt').read_bytes()).hexdigest()
        for kind,top,bench in [('rules','tb_h4e_candidate','tb_h4e_candidate.v'),('sample','tb_h4e_roi_sampler','tb_h4e_candidate_sample.v')]:
            run([shutil.which('iverilog'),'-g2012','-s',top,'-o',kind+'.vvp']+[Path(s).name for s in sources if s.startswith('rtl/')]+[bench],work,kind+'_compile.log')
            log=run([shutil.which('vvp'),kind+'.vvp'],work,kind+'_simulation.log')
            if ('C3B_PASS' if kind=='rules' else 'C3A_PASS') not in log:raise RuntimeError('missing completion')
        for name in ('actual.csv','clamps.csv','samples.csv','candidate_samples.csv'):shutil.copy2(work/name,out/name)
    actual=read_csv(out/'actual.csv');reason_counts={}
    for i,profile in enumerate(PROFILES):
        subset=[v for v in actual if v['profile']==i];wanted=cycles(rows,profile)
        compare(subset,wanted)
        reason_counts[i]=dict(Counter(v['reason'] for v in wanted if v['done']))
    clamps=read_csv(out/'clamps.csv');assert len(clamps)==1024
    for v in clamps:
        for i,p in enumerate(PROFILES):assert v['p'+str(i)]==max(0,min(255,v['value']-p[-1]))
    sample_rows=read_csv(out/'samples.csv');candidates=read_csv(out/'candidate_samples.csv')
    assert len(sample_rows)==len(candidates)==14
    expected=[]
    for sample in sample_rows:
        # mean B is independently floor(sum/256) for valid 256-pixel samples.
        v=dict(sample,done=1,mb=sample['sb']//256 if sample['ok'] else 0,target=sample['color'],flush=int(sample['tag']==9),active_epoch=7 if sample['tag']<=9 else 8)
        expected.append(dict(tag=sample['tag'],**{k:w for k,w in result(v).items() if k!='done'}))
    compare(candidates,expected)
    # Mutation check proves candidate arithmetic differences are detected.
    damaged=[dict(v) for v in candidates];damaged[0]['d1']^=1
    try:compare(damaged,expected)
    except ValueError as exc:(out/'checker_selftest.log').write_text('EXPECTED_FAILURE: '+str(exc)+'\n')
    else:raise RuntimeError('checker missed damaged candidate')
    tracked=sources+['sim/h4e_c3b/vector_fields.json','model/h4e_c3b_reference.py','scripts/run_h4e_c3b.py','scripts/run_h4e_c2a.py']
    summary=dict(status='PASS',cycles_per_profile=len(rows),profiles=PROFILES,reason_counts=reason_counts,saturation_values=1024,saturation_profiles=3,
        sampler_events=len(candidates),sampler_valid_candidates=sum(v['ok'] for v in candidates),checker_selftest='PASS',
        source='synthetic',hardware='not_tested',active_configuration='not written by candidate module',command_exit_codes='all 0',python=sys.version,
        vector_sha256=input_hash,source_hashes={s:hashlib.sha256((ROOT/s).read_bytes()).hexdigest() for s in tracked})
    for name,value in [('summary.json',summary),('commands.json',commands),('expected_samples.json',expected),('directed_vectors.json',[r for r in rows if not r['name'].startswith('random_')])]:
        (out/name).write_text(json.dumps(value,indent=2)+'\n')
    print(json.dumps(summary,indent=2))
if __name__=='__main__':main()
