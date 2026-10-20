"""B0: replay frozen H4E TBs with installed ModelSim, leaving the snapshot intact."""
import argparse, hashlib, importlib.util, json, shutil, sys
from datetime import datetime
from pathlib import Path
from b1_tools import command, simulate

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--modelsim',type=Path,required=True)
    a=p.parse_args(); b=Path(__file__).resolve().parents[1]
    h=b.parent/'boards/hx1p35a/h4e'
    run=b/'build/h4e_baseline'/datetime.now().strftime('run_%Y%m%d_%H%M%S')
    run.mkdir(parents=True); print(f'Reports: {run}',flush=True)
    report={'passed':False,'simulator':'ModelSim (original TBs and reference unchanged)',
            'baseline_declared_sha':'7eb4a90','git_sha_verified':False,
            'board_tested_by_this_run':False,'commands':[]}
    try:
        report['tool_version']=command([a.modelsim/'vsim.exe','-version'],run,run/'version.log').strip()
        report['check']=command([sys.executable,'-X','utf8',h/'run.py','check'],run,run/'check.log').strip()
        # Only copy the explicit test inputs. Generated files stay in build/.
        work=run/'h4e';work.mkdir()
        shutil.copytree(h/'user_source/hdl_source',work/'user_source/hdl_source')
        shutil.copytree(h/'assets',work/'assets')
        for name in ('test_regions.py','legacy_fixtures.py','prepare_pipeline_test.py','tb_regions.v','tb_h4e.v'):
            shutil.copy2(h/name,work/name)
        sys.path.insert(0,str(work))
        spec=importlib.util.spec_from_file_location('test_regions',work/'test_regions.py')
        ref=importlib.util.module_from_spec(spec);sys.modules['test_regions']=ref;spec.loader.exec_module(ref)
        cases=ref.fixtures();data=work/'simulation';data.mkdir()
        with (data/'masks.mem').open('w') as f:
            for _,m,_,_ in cases:
                for row in m:f.write(' '.join('1' if q else '0' for q in row)+'\n')
        expected=[ref.oracle(m,err) for _,m,_,err in cases]
        (data/'expected.txt').write_text('\n'.join(' '.join(map(str,[i+1,period]+e))
            for i,((_,_,period,_),e) in enumerate(zip(cases,expected)))+'\n')
        (data/'cases.json').write_text(json.dumps([{'name':c[0],'expected':e} for c,e in zip(cases,expected)],indent=2))
        src=work/'user_source/hdl_source'
        simulate(a.modelsim,work,[src/'h4e_region_select.v',work/'tb_regions.v'],
                 'tb_regions','PASS ROW_REGIONS: 68', ['-gN=68'])
        shutil.copy2(work/'simulation.log',run/'unit.log')
        report['unit']={'frames':len(cases),'pixels':len(cases)*384*96,'exit_code':0}
        print('PASS: H4E unit, 68 cases',flush=True)
        command([sys.executable,'-X','utf8',work/'prepare_pipeline_test.py'],work,run/'prepare.log')
        names=['h3d3_display_path.v','h3d2_mixer.v','h4e_region_select.v','h4c_fill_metrics.v',
            'anlogic_logo_rom.v','display_raster_adapter.v','color_classifier_runtime.v','mask_frame_stats.v',
            'mask_target_result.v','target_result_pack.v','mask_majority_3x3.v','mask_denoised_result.v','vtc/uivtc.v']
        simulate(a.modelsim,work,[work/'tb_h4e.v']+[src/n for n in names],
                 'tb_h4e','PASS H4E: 13 complete native 720p frames')
        shutil.copy2(work/'simulation.log',run/'pipeline.log')
        report['pipeline']={'frames':13,'filtered_pixels':11980800,'exit_code':0}
        report['frozen_test_sha256']={n:hashlib.sha256((h/n).read_bytes()).hexdigest()
            for n in ('tb_regions.v','tb_h4e.v','test_regions.py','prepare_pipeline_test.py')}
        report['passed']=True; print('PASS: H4E baseline reproduced with ModelSim.',flush=True)
    finally:
        (run/'summary.json').write_text(json.dumps(report,indent=2)+'\n')

if __name__=='__main__': main()
