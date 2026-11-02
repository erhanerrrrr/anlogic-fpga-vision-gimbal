"""H4E C1 takeover regression. Frozen files are never edited.
Development mode copies the frozen tests to an isolated directory, then explicitly
replaces ONLY the region selector with rtl/recognition/h4e_region_select.v.
"""
import argparse,ast,hashlib,json,os,re,shutil,subprocess,sys,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
FROZEN=ROOT/'boards/hx1p35a/h4e'
OUT=ROOT/'reports/h4e-c1/generated'

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def run(args,work,log,timeout=2100):
    with log.open('w',encoding='utf-8') as f:
        result=subprocess.run(args,cwd=work,stdout=f,stderr=subprocess.STDOUT,timeout=timeout)
    if result.returncode:raise RuntimeError('command failed: '+str(log))
    return log.read_text(encoding='utf-8',errors='replace')

def collect(work,dest,mode):
    for name in ('region_simulation.log','h4e_simulation.log','simulation/result.json','simulation/cases.json','simulation/pipeline_cases.json'):
        p=dest/Path(name).name;shutil.copy2(work/name,p)
    unit=(dest/'region_simulation.log').read_text(errors='replace')
    pipeline=(dest/'h4e_simulation.log').read_text(errors='replace')
    if 'PASS ROW_REGIONS: 68' not in unit or 'PASS H4E: 13 complete native 720p frames' not in pipeline:
        raise ValueError('missing completion marker')
    rows=re.findall(r'FRAME (\d+) PASS A=(\d+) E=(\d+) peak_slots=(\d+) components=(\d+) max_row_cycles=(\d+) EOF_WAIT=(\d+)',unit)
    if len(rows)!=68:raise ValueError('wrong unit result count')
    cases=json.loads((dest/'cases.json').read_text())
    fields=('frame','area','reason','peak_slots','components','max_row_cycles','EOF_wait')
    records=[dict(name=c['name'],**dict(zip(fields,map(int,r)))) for c,r in zip(cases,rows)]
    (dest/'case_metrics.json').write_text(json.dumps(records,indent=2)+'\n')
    metrics=re.search(r'ROW_ENGINE max_row_cycles=(\d+) max_EOF_wait=(\d+)',pipeline)
    if not metrics:raise ValueError('missing pipeline timing')
    return dict(status='PASS',mode=mode,unit_cases=68,unit_pixels=2506752,pipeline_frames=13,
        pipeline_filtered_pixels=11980800,pipeline_max_row_cycles=int(metrics[1]),pipeline_max_EOF_wait=int(metrics[2]),
        unit_max_row_cycles=max(r['max_row_cycles'] for r in records),unit_max_peak_slots=max(r['peak_slots'] for r in records),
        unit_reason_counts={str(n):sum(r['reason']==n for r in records) for n in (0,1,2,3,5)},
        development_source='rtl/recognition/h4e_region_select.v',development_sha256=sha(ROOT/'rtl/recognition/h4e_region_select.v'),
        frozen_sha256=sha(FROZEN/'user_source/hdl_source/h4e_region_select.v'))

def modelsim_pipeline(work,dest):
    # Reuse the frozen explicit source list, never glob the repository.
    tree=ast.parse((FROZEN/'run_pipeline_test.py').read_text())
    names=next(ast.literal_eval(n.value) for n in tree.body if isinstance(n,ast.Assign)
               and any(isinstance(t,ast.Name) and t.id=='names' for t in n.targets))
    commands=[['vlib','msim_work'],['vlog','-sv','-work','msim_work','tb_h4e.v']+
              ['user_source/hdl_source/'+n for n in names]]
    (work/'run.do').write_text('onerror {quit -code 1}\nrun -all\nquit -code 0\n')
    commands.append(['vsim','-c','-onfinish','exit','-l','h4e_simulation.log',
                     'msim_work.tb_h4e','-do','do run.do'])
    (dest/'pipeline_commands.json').write_text(json.dumps(commands,indent=2)+'\n')
    for command in commands:
        run(command,work,dest/(command[0]+'_driver.log'),timeout=7200)

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--mode',choices=('frozen','development'),default='development')
    parser.add_argument('--collect-existing',action='store_true',help='Collect a completed frozen run; never claim to rerun it')
    parser.add_argument('--pipeline-simulator',choices=('icarus','modelsim'),default='icarus')
    parser.add_argument('--work-root',type=Path,help='Existing ASCII-only temporary parent directory for old ModelSim')
    args=parser.parse_args();dest=OUT/args.mode;dest.mkdir(parents=True,exist_ok=True)
    (dest/'summary.json').write_text('{"status":"FAIL"}\n')
    for executable in ('iverilog','vvp'):
        if not shutil.which(executable):raise RuntimeError(executable+' is not on PATH')
    import numpy,scipy
    versions=dict(python=sys.version.split()[0],numpy=numpy.__version__,scipy=scipy.__version__)
    for executable in ('iverilog','vvp'):
        versions[executable]=run([executable,'-V'],ROOT,dest/(executable+'_version.log')).splitlines()[0]
    if args.pipeline_simulator=='modelsim':
        if args.collect_existing:raise ValueError('ModelSim requires an isolated fresh run')
        versions['modelsim']=run(['vsim','-version'],ROOT,dest/'modelsim_version.log').strip()
    run([sys.executable,'-X','utf8',str(FROZEN/'run.py'),'check'],ROOT,dest/'source_check.log')
    if args.collect_existing:
        if args.mode!='frozen':raise ValueError('existing results supported only for frozen mode')
        report=collect(FROZEN,dest,args.mode)
    elif args.mode=='frozen' and args.pipeline_simulator=='icarus':
        for action in ('unit','pipeline'):
            print('H4E C1 frozen: '+action,flush=True)
            run([sys.executable,'-X','utf8',str(FROZEN/'run.py'),action],ROOT,dest/(action+'_driver.log'))
        report=collect(FROZEN,dest,args.mode)
    else:
        with tempfile.TemporaryDirectory(prefix='h4e_c1_',dir=args.work_root) as temp:
            work=Path(temp)
            if args.pipeline_simulator=='modelsim' and not str(work).isascii():
                raise ValueError('Old ModelSim needs an ASCII-only path; supply --work-root')
            for name in ('test_regions.py','legacy_fixtures.py','prepare_pipeline_test.py','run_pipeline_test.py','tb_regions.v','tb_h4e.v'):
                shutil.copy2(FROZEN/name,work/name)
            shutil.copytree(FROZEN/'assets',work/'assets')
            shutil.copytree(FROZEN/'user_source/hdl_source',work/'user_source/hdl_source')
            target=work/'user_source/hdl_source/h4e_region_select.v'
            source=(ROOT/'rtl/recognition/h4e_region_select.v' if args.mode=='development'
                    else FROZEN/'user_source/hdl_source/h4e_region_select.v')
            shutil.copy2(source,target)
            if sha(target)!=sha(source):raise ValueError('staging mismatch')
            (dest/'source_selection.json').write_text(json.dumps(dict(region_selector=source.relative_to(ROOT).as_posix(),
                staging_destination='user_source/hdl_source/h4e_region_select.v',sha256=sha(target),
                remaining_sources='frozen H4E explicit source list from run_pipeline_test.py'),indent=2)+'\n')
            for script in ('test_regions.py','prepare_pipeline_test.py','run_pipeline_test.py'):
                print('H4E C1 '+args.mode+': '+script,flush=True)
                if script=='run_pipeline_test.py' and args.pipeline_simulator=='modelsim':
                    modelsim_pipeline(work,dest)
                else:run([sys.executable,'-X','utf8',script],work,dest/(script+'.log'))
            report=collect(work,dest,args.mode)
    report.update(tool_versions=versions,base_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
                  hardware='not_tested_this_run',synthesis='not_run',interface_profile='h4e-refresh-v1',
                  pipeline_simulator=args.pipeline_simulator)
    (dest/'summary.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report))

if __name__=='__main__':
    try:main()
    except Exception as exc:print('FAIL: '+str(exc),file=sys.stderr);sys.exit(1)
