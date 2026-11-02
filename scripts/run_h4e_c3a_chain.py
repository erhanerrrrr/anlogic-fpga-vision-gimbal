"""C2b synthetic-source integration: RGB -> H4E T -> atomic packet -> freshness."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
from collections import Counter

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'model'))
from h4e_c2b_reference import stimulus,observer_vectors,expected_geometry,classify,rgb_at,WIDTH,HEIGHT
from run_h4e_c2a import read_csv,write_json,compare


def main():
    out=ROOT/'reports/h4e-c3a/generated/chain';out.mkdir(parents=True,exist_ok=True)
    write_json(out/'summary.json',{'status':'FAIL'})
    tools={n:shutil.which(n) for n in ('iverilog','vvp')}
    if not all(tools.values()):raise RuntimeError('Icarus must be on PATH')
    commands=[]
    def run(cmd,work,name):
        commands.append(cmd)
        p=subprocess.run(cmd,cwd=work,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=240)
        text=p.stdout.decode('utf-8',errors='replace');(out/name).write_text(text,encoding='utf-8')
        if p.returncode:raise RuntimeError('command failed: '+str(out/name))
        return text
    versions={n:run([exe,'-V'],ROOT,n+'_version.log').splitlines()[0] for n,exe in tools.items()}
    rows,frames=stimulus();ov,oe=observer_vectors()
    sources=(ROOT/'rtl/recognition/h4e_c3a_sources.f').read_text().splitlines()
    tb=['sim/h4e_c2b/tb_capture_observer.v','sim/h4e_c3a/tb_h4e_sampling_chain.v']
    with tempfile.TemporaryDirectory(prefix='h4e_c2b_') as directory:
        work=Path(directory)
        for rel in sources+tb:shutil.copy2(ROOT/rel,work/Path(rel).name)
        with (work/'stimulus.txt').open('w') as f:
            for r in rows:
                f.write('%d %d %d %d %08x %d %d %d %d %d %06x %08x %08x %04x %d %d %d %d\n' %
                    tuple(r[n] for n in ('cycle','attempt','rst','flush','epoch','valid','sof','eof','x','y','rgb','fid','source_epoch','cfg','color','minimum','d1','d2')))
        with (work/'observer.txt').open('w') as f:
            for i,v in enumerate(ov):f.write('%d %d %d %d %08x %08x %08x\n' % ((i,)+v))
        input_hash=hashlib.sha256((work/'stimulus.txt').read_bytes()).hexdigest()
        for kind,bench in zip(('observer','chain'),tb):
            run([tools['iverilog'],'-g2012','-s',('tb_h4e_capture_tracker' if kind=='chain' else Path(bench).stem),'-o',kind+'.vvp']+
                [Path(s).name for s in sources]+[Path(bench).name],work,kind+'_compile.log')
            log=run([tools['vvp'],kind+'.vvp'],work,kind+'_simulation.log')
            if 'H4E_C2B_'+kind.upper()+'_COMPLETE' not in log:raise RuntimeError('incomplete '+kind)
        for name in ('observer_actual.csv','results.csv','pixels.csv','configs.csv','errors.csv'):
            shutil.copy2(work/name,out/name)
    compare(read_csv(out/'observer_actual.csv'),oe)
    actual=read_csv(out/'results.csv')
    expected=[]
    for index,f in enumerate(frames):
        if f['event']:
            expected.append(dict(attempt=index,new_observation=f['fresh'],frame_id=f['fid'],capture_epoch=f['epoch'],
                                 cfg_id=f['active'][0],target_id=f['active'][1],**expected_geometry(f['color'],f['active'])))
    compare(actual,expected)
    configs=read_csv(out/'configs.csv')
    wanted_configs=[]
    for index,f in enumerate(frames):
        if f.get('kind') not in ('stale','missing_sof'):
            wanted_configs.append(dict(attempt=index,new_source_sof=int(index not in (1,3,10,17)),
                **dict(zip(('cfg','color','minimum','d1','d2'),f['active']))))
    compare(configs,wanted_configs)
    pixels=read_csv(out/'pixels.csv');counts=Counter()
    for p in pixels:
        f=frames[p['attempt']];counts[p['attempt']]+=1
        wanted=dict(frame_id=f['fid'],epoch=f['epoch'],processing_rst_n=1,
                    **dict(zip(('cfg','color','minimum','d1','d2'),f['active'])))
        wanted['mask']=classify(rgb_at(p['x'],p['y'],f['color']),f['active'])
        compare([p],[wanted])
    for index,f in enumerate(frames):
        if f['event'] and counts[index]!=WIDTH*HEIGHT:raise ValueError('missing/extra classified pixels '+f['name'])
        if f.get('kind') in ('stale','missing_sof') and counts[index]:raise ValueError('rejected stream entered classifier')
    errors=read_csv(out/'errors.csv')
    compare(errors,[dict(attempt=6,frame_abort=1,stream_error=0),dict(attempt=8,frame_abort=0,stream_error=1),
                    dict(attempt=9,frame_abort=1,stream_error=1),dict(attempt=12,frame_abort=1,stream_error=0),
                    dict(attempt=13,frame_abort=1,stream_error=1),dict(attempt=16,frame_abort=1,stream_error=1),
                    dict(attempt=21,frame_abort=1,stream_error=0),dict(attempt=22,frame_abort=1,stream_error=0)])
    stop_delay=actual[-1]['cycle']-frames[-1]['input_eof_cycle']
    if not 0<stop_delay<=WIDTH+256:raise ValueError('last complete frame did not drain within test bound')
    damaged=[dict(r) for r in actual];damaged[0]['capture_epoch']^=1
    try:compare(damaged,expected)
    except ValueError as exc:(out/'checker_selftest.log').write_text('EXPECTED_FAILURE: '+str(exc)+'\n')
    else:raise RuntimeError('checker missed corrupted epoch')
    write_json(out/'scenarios.json',frames);write_json(out/'expected_results.json',expected)
    write_json(out/'observer_expected.json',oe);write_json(out/'commands.json',commands)
    tracked=sources+tb+['model/h4e_c2b_reference.py','model/h4e_c2a_reference.py','scripts/run_h4e_c3a_chain.py']
    write_json(out/'source_hashes.json',{n:hashlib.sha256((ROOT/n).read_bytes()).hexdigest() for n in tracked})
    summary=dict(status='PASS',base_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        python=sys.version,tools=versions,source='synthetic; not camera capture',observer_cycles=len(ov),
        input_cycles=len(rows),attempts=len(frames),result_events=len(actual),new_observations=sum(r['new_observation'] for r in actual),
        accepted_sofs=len(configs),new_source_sofs=sum(r['new_source_sof'] for r in configs),
        classified_pixels_checked=len(pixels),frame_aborts=sum(r['frame_abort'] for r in errors),
        stream_errors=sum(r['stream_error'] for r in errors),last_frame_drain_cycles=stop_delay,
        quiet_clocks_after_last_result=len(rows)-1-actual[-1]['cycle'],stimulus_sha256=input_hash,
        checker_selftest='PASS',hardware='not_tested',synthesis='separate TD report',command_exit_codes='all 0')
    write_json(out/'summary.json',summary);print(json.dumps(summary,indent=2))


if __name__=='__main__':
    try:main()
    except Exception as exc:print('FAIL: '+str(exc),file=sys.stderr);sys.exit(1)
