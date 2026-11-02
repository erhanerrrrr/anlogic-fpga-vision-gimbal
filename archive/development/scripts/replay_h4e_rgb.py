"""Validate and replay complete RGB888 frames against unchanged H4E capture RTL."""
import argparse,csv,hashlib,json,shutil,subprocess,sys,tempfile,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'model'))
from h4e_c4_reference import validate,masks,geometry,confusion,metrics,digest,GEOM,evaluate_frame

def replay(manifest_path,output,timeout=300):
    manifest_path=Path(manifest_path).resolve();manifest_hash=digest(manifest_path);m=validate(manifest_path);root=manifest_path.parent
    if digest(manifest_path)!=manifest_hash:raise ValueError('manifest changed during validation')
    out=Path(output).resolve()
    if out==root:raise ValueError('output must differ from source dataset directory')
    out.mkdir(parents=True,exist_ok=True);(out/'summary.json').write_text('{"status":"FAIL"}')
    w,h=m['width'],m['height'];commands=[];records=[];start=time.monotonic()
    sources=(ROOT/'rtl/recognition/h4e_c2b_sources.f').read_text().splitlines()
    bench='sim/h4e_c4/tb_h4e_rgb_replay.v'
    def run(cmd,cwd,name):
        commands.append(cmd)
        p=subprocess.run(cmd,cwd=cwd,capture_output=True,text=True,timeout=timeout)
        (out/name).write_text(p.stdout+p.stderr,encoding='utf-8')
        if p.returncode:raise RuntimeError(name+' failed: '+p.stdout+p.stderr)
        return p.stdout+p.stderr
    tools={n:shutil.which(n) for n in ('iverilog','vvp')}
    if not all(tools.values()):raise RuntimeError('Icarus iverilog/vvp must be on PATH')
    versions={n:run([exe,'-V'],ROOT,n+'_version.log').splitlines()[0] for n,exe in tools.items()}
    with tempfile.TemporaryDirectory(prefix='h4e_rgb_') as d:
        work=Path(d)
        for rel in sources+[bench]:shutil.copy2(ROOT/rel,work/Path(rel).name)
        with (work/'frames.txt').open('w') as meta:
            for i,f in enumerate(m['frames']):
                shutil.copy2(root/f['rgb_file'],work/('frame_%d.rgb'%i))
                if digest(work/('frame_%d.rgb'%i))!=f['rgb_sha256'].lower():raise ValueError('input changed during replay setup')
                meta.write(' '.join(map(str,(i,f['frame_id'],f['epoch'],f['cfg_id'],f['target_id'],*f['thresholds'],f['hblank_cycles'])))+'\n')
        run([tools['iverilog'],'-g2012','-s','tb_h4e_rgb_replay','-Ptb_h4e_rgb_replay.W='+str(w),'-Ptb_h4e_rgb_replay.H='+str(h),'-o','replay.vvp']+[Path(s).name for s in sources]+[Path(bench).name],work,'compile.log')
        log=run([tools['vvp'],'replay.vvp'],work,'simulation.log')
        if 'H4E_C4_REPLAY_PASS' not in log:raise RuntimeError('simulation did not complete')
        shutil.copy2(work/'results.csv',out/'results.csv')
        actual=[{k:int(v) for k,v in r.items()} for r in csv.DictReader((work/'results.csv').open())]
        if len(actual)!=len(m['frames']):raise ValueError('missing/extra RTL result')
        previous=None
        for i,(f,a) in enumerate(zip(m['frames'],actual)):
            rgb=(work/('frame_%d.rgb'%i)).read_bytes();cm,fm=masks(rgb,w,h,f['target_id'],f['thresholds']);gold=geometry(fm,w,h)
            observed={}
            for name,expected in [('class',cm),('filter',fm)]:
                data=(work/('%s_%d.bin'%(name,i))).read_bytes()
                if len(data)!=len(expected):raise ValueError('missing/extra '+name+' pixels at frame '+str(i))
                if data!=expected:
                    count=0;first=[]
                    for j,(x,y) in enumerate(zip(data,expected)):
                        if x!=y:
                            count+=1
                            if len(first)<16:first.append(j)
                    (out/'pixel_mismatch.json').write_text(json.dumps(dict(frame=i,stage=name,count=count,first_indices=first),indent=2))
                    raise ValueError('pixel mismatch '+name+' frame '+str(i))
                observed[name]=data
            pair=(f['epoch'],f['frame_id']);fresh=int(previous!=pair);previous=pair
            want=dict(index=i,frame_id=f['frame_id'],capture_epoch=f['epoch'],cfg_id=f['cfg_id'],target_id=f['target_id'],new_observation=fresh)
            structural=f.get('expected_structural_reason')
            if structural is not None:want.update(target_valid=0,reject_reason=structural,**dict.fromkeys(GEOM,0));comparison='expected_synthetic_structural_reject'
            elif a['reject_reason'] in (3,5):
                want.update(target_valid=0,**dict.fromkeys(GEOM,0));comparison='structural_reject_geometry_not_compared'
            else:want.update(gold);comparison='exact_geometry'
            for k,v in want.items():
                if a[k]!=v:raise ValueError('frame %d %s: RTL=%s expected=%s'%(i,k,a[k],v))
            record=dict(index=i,name=f.get('name',str(i)),rgb_sha256=f['rgb_sha256'],rtl=a,ideal_geometry=gold,comparison=comparison,annotation=f.get('annotation'),mask_hashes={key:hashlib.sha256(value).hexdigest() for key,value in observed.items()})
            ann=f.get('annotation')
            if ann and ann.get('mask_file'):
                gt=(root/ann['mask_file']).read_bytes()
                if hashlib.sha256(gt).hexdigest()!=ann['mask_sha256'].lower():raise ValueError('annotation changed during replay')
                record['pixel_metrics']=dict(classified_pixels=confusion(observed['class'],gt),filtered_pixels=confusion(observed['filter'],gt))
            record['evaluation']=evaluate_frame(record)
            records.append(record)
    report=metrics(records)
    faults=sum(r['rtl']['reject_reason'] in (3,5) for r in records)
    unexpected=sum(r['comparison']=='structural_reject_geometry_not_compared' for r in records)
    tracked=sources+[bench,'rtl/recognition/h4e_c2b_sources.f','model/h4e_c4_reference.py','scripts/replay_h4e_rgb.py']
    summary=dict(status='PASS_WITH_STRUCTURAL_FAILURES' if unexpected else 'PASS',source_kind=m['source_kind'],hardware='not_tested_by_replay',width=w,height=h,frames=len(records),
                 classified_pixels_checked=w*h*len(records),filtered_pixels_checked=w*h*len(records),exact_geometry_frames=len(records)-faults,
                 structural_rejects=faults,unexpected_structural_rejects=unexpected,max_post_eof_result_cycles=max(a['rtl']['latency'] for a in records),
                 quiet_clocks_after_last_result_at_least=256,manifest_sha256=manifest_hash,source_hashes={s:digest(ROOT/s) for s in tracked},
                 tools=versions,python=sys.version,commands_exit_codes='all 0',wall_seconds=round(time.monotonic()-start,3),
                 max_runs=64,frame_draining='one complete frame then result+64 quiet clocks; not sensor-rate/CDC/board timing validation',
                 resource_increment='FPGA RTL unchanged: 0 new Slice/ERAM/DSP; no synthesis rerun',
                 temporary_rgb_and_mask_bytes=w*h*len(records)*5)
    for name,data in [('summary.json',summary),('records.json',records),('metrics.json',report),('commands.json',commands),('manifest_snapshot.json',m)]:
        (out/name).write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')
    return summary

def main():
    p=argparse.ArgumentParser();p.add_argument('manifest',type=Path);p.add_argument('--output',type=Path,default=ROOT/'reports/h4e-c4/generated/replay');p.add_argument('--validate-only',action='store_true');p.add_argument('--timeout-seconds',type=int,default=300);args=p.parse_args()
    if args.validate_only:
        m=validate(args.manifest);print(json.dumps(dict(status='PASS',frames=len(m['frames']),source_kind=m['source_kind'],width=m['width'],height=m['height'])));return
    summary=replay(args.manifest,args.output,args.timeout_seconds);print(json.dumps({k:v for k,v in summary.items() if k not in ('source_hashes','python')},indent=2))
    if summary['unexpected_structural_rejects']:sys.exit(2)
if __name__=='__main__':
    try:main()
    except (ValueError,KeyError,OSError,RuntimeError,subprocess.TimeoutExpired) as exc:
        print('FAIL: '+str(exc),file=sys.stderr);sys.exit(1)
