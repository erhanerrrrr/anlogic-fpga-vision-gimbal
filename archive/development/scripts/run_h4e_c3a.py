"""Fast state tests plus real complete 720p rasters; no wave/pixel dump."""
import csv,hashlib,json,shutil,subprocess,sys,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'model'))
from h4e_c3a_reference import expected

def main():
    out=ROOT/'reports/h4e-c3a/generated';out.mkdir(parents=True,exist_ok=True)
    (out/'summary.json').write_text('{"status":"FAIL"}')
    sources=['rtl/recognition/capture_frame_guard.v','rtl/recognition/h4e_roi_sampler.v','sim/h4e_c3a/tb_h4e_roi_sampler.v']
    commands=[];counts={}
    with tempfile.TemporaryDirectory(prefix='h4e_c3a_') as d:
        work=Path(d)
        for rel in sources:shutil.copy2(ROOT/rel,work/Path(rel).name)
        for name,w,h in [('state',32,32),('720p',1280,720)]:
            cmd=[shutil.which('iverilog'),'-g2012','-s','tb_h4e_roi_sampler','-Ptb_h4e_roi_sampler.W='+str(w),'-Ptb_h4e_roi_sampler.H='+str(h),'-o','sim.vvp']+[Path(s).name for s in sources]
            for cmd in [cmd,[shutil.which('vvp'),'sim.vvp']]:
                commands.append(cmd)
                p=subprocess.run(cmd,cwd=work,capture_output=True,text=True,timeout=180)
                (out/(name+('_compile.log' if Path(cmd[0]).stem.lower()=='iverilog' else '_simulation.log'))).write_text(p.stdout+p.stderr)
                if p.returncode:raise RuntimeError(p.stdout+p.stderr)
            if 'C3A_PASS' not in p.stdout:raise RuntimeError('missing completion')
            means={int(line.split()[1]):int(line.split()[2]) for line in p.stdout.splitlines() if line.startswith('BMEAN')}
            rows=[{k:int(v) for k,v in r.items()} for r in csv.DictReader((work/'samples.csv').open())]
            assert len(rows)==(14 if name=='state' else 6),rows
            for i,row in enumerate(rows,1):
                assert row['tag']==i
                row['mb']=means[i]
                if i in (7,9,10,12,13):
                    assert row['ok']==0 and row['reason']==2
                    assert all(row[k]==0 for k in ('count','sr','sg','sb','lr','lg','lb','hr','hg','hb','mr','mg','mb'))
                else:
                    pat=i-1 if i<=6 else {8:1,11:2,14:0}[i]
                    want=expected(pat)
                    want.update(ok=1,reason=0,fid=i+10 if i<=6 else {8:18,11:19,14:24}[i],epoch=7 if i<=8 else 8,cfg=1,color=0)
                    for k,v in want.items():assert row[k]==v,(name,i,k,row[k],v)
            (out/(name+'_actual.json')).write_text(json.dumps(rows,indent=2)+'\n')
            counts[name]=len(rows)
    tracked=sources+['model/h4e_c3a_reference.py','scripts/run_h4e_c3a.py']
    summary=dict(status='PASS',events=counts,source='synthetic',hardware='not_tested',mean='floor(sum/256)',full_720p_rasters=8,command_exit_codes='all 0',python=sys.version,source_hashes={s:hashlib.sha256((ROOT/s).read_bytes()).hexdigest() for s in tracked})
    (out/'commands.json').write_text(json.dumps(commands,indent=2))
    (out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary,indent=2))
if __name__=='__main__':main()
