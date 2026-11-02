"""Portable H4E checks. Rebuilds are isolated and never replace accepted evidence."""
from pathlib import Path
import argparse, hashlib, json, os, re, shutil, subprocess, sys
from verify_package import verify

ROOT = Path(__file__).resolve().parent

def build(td):
    if not td or not Path(td).is_file():
        raise SystemExit('Supply --td <td_commands_prompt.exe> or set ANLOGIC_TD_COMMAND')
    work = ROOT/'build'
    work.mkdir(exist_ok=True)
    if (work/'td_project').exists():
        raise SystemExit('build/td_project already exists; archive this run before rebuilding.')
    shutil.copytree(ROOT/'user_source', work/'user_source')
    shutil.copytree(ROOT/'td_project', work/'td_project')
    shutil.copy2(ROOT/'gamma_lut.hex', work/'gamma_lut.hex')
    project = work/'td_project/camera_to_dsi_display.al'
    s = project.read_text(encoding='utf-8')
    s = re.sub(r'(<Project\b[^>]*\bPath=")[^"]*',
               lambda m: m[1]+project.parent.as_posix(), s, count=1)
    project.write_text(s, encoding='utf-8')
    tcl = work/'td_project/build.tcl'
    tcl.write_text('import_device ph1_35p.db -package PH1P35MDG324 -speed 3\n'
        +'open_project {'+project.as_posix()+'}\n'
        +'launch_runs {syn_1 phy_1} -jobs 1\nwait_run syn_1 -quiet\nwait_run phy_1 -quiet\n'
        +'save_best_bits\nclose_project\nputs "H4E_PORTABLE_BUILD_FINISHED"\nexit\n', encoding='utf-8')
    with (work/'build.log').open('w', encoding='utf-8') as log:
        subprocess.run([str(Path(td).resolve())], cwd=project.parent,
            input='source {'+tcl.as_posix()+'}\n', text=True, encoding='utf-8', errors='replace',
            stdout=log, stderr=subprocess.STDOUT, timeout=1800, check=True,
            creationflags=subprocess.CREATE_NO_WINDOW if os.name=='nt' else 0)
    log = (work/'build.log').read_text(encoding='utf-8', errors='replace')
    for marker in ('Run syn_1 success.', 'Run phy_1 success.', 'H4E_PORTABLE_BUILD_FINISHED'):
        assert marker in log, marker
    runs = project.parent/'camera_to_dsi_display_Runs'
    phy = runs/'phy_1'
    timing = (phy/'final_timing.rpt').read_text(errors='replace')
    assert 'Confidence          : Routed' in timing
    metrics = {k:float(re.search(r'\b'+k+r':\s*([-\d.]+)ns',timing)[1])
               for k in ('SWNS','STNS','HWNS','HTNS')}
    assert all(v>=0 for v in metrics.values()), metrics
    metrics['coverage_percent'] = float(re.search(r'STA coverage\s*:\s*([\d.]+)%',timing)[1])
    area = (phy/'camera_to_dsi_display_phy.area').read_text(errors='replace')
    resources = {k:int(re.search(r'^#'+k+r'\s+(\d+)',area,re.M)[1]) for k in ('slice','eram','dsp')}
    assert resources['slice']<=14000 and resources['eram']<=60 and resources['dsp']==8, resources
    bit = runs/'best_result/camera_to_dsi_display.bit'
    assert bit.stat().st_size>0 and bit.read_bytes()==(phy/'camera_to_dsi_display.bit').read_bytes()
    report = dict(status='PASS',timing=metrics,resources=resources,
                  bit_sha256=hashlib.sha256(bit.read_bytes()).hexdigest(),
                  board_status='not_board_tested',timing_scope='existing SDC only')
    (work/'summary.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report))

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['check','unit','pipeline','build'])
    parser.add_argument('--td', default=os.environ.get('ANLOGIC_TD_COMMAND'))
    args = parser.parse_args()
    verify()
    if args.action=='unit':
        subprocess.run([sys.executable,'-X','utf8','test_regions.py'],cwd=ROOT,check=True)
    elif args.action=='pipeline':
        for s in ('prepare_pipeline_test.py','run_pipeline_test.py'):
            subprocess.run([sys.executable,'-X','utf8',s],cwd=ROOT,check=True)
    elif args.action=='build':
        build(args.td)

if __name__=='__main__':
    main()
