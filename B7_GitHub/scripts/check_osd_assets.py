"""Compile and exhaustively read the contest Logo/font assets with ModelSim."""
import argparse
from datetime import datetime
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
from project_paths import ROOT, source_path, find_modelsim


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--modelsim',type=Path)
    a=p.parse_args()
    root=ROOT
    assets=root/'assets/osd'
    run=root/'build/osd_assets_sim'/datetime.now().strftime('run_%Y%m%d_%H%M%S_%f')
    (run/'src').mkdir(parents=True)
    result={'stage':'B7 asset readback only','passed':False,'video_overlay_verified':False,
            'synthesis_verified':False,'board_verified':False,'source_sha256':{}}
    print(f'Reports: {run}',flush=True)
    def execute(command,label,expected=0,marker=None):
        process=subprocess.run([str(s) for s in command],cwd=run,capture_output=True,
                               text=True,encoding='utf-8',errors='replace',timeout=120)
        output=process.stdout+process.stderr
        (run/f'{label}.log').write_text(output,encoding='utf-8')
        if process.returncode != expected or (marker and marker not in output):
            raise RuntimeError(f'{label}: unexpected result; inspect {run / (label+".log")}')
        return output
    try:
        a.modelsim=find_modelsim(a.modelsim)
        provenance=json.loads((assets/'provenance.json').read_text())
        for name,info in provenance['files'].items():
            if hashlib.sha256((assets/name).read_bytes()).hexdigest()!=info['sha256']:
                raise RuntimeError(f'Original vendor asset changed: {name}')
        if hashlib.sha256((assets/'reference.json').read_bytes()).hexdigest()!=provenance['reference_sha256']:
            raise RuntimeError('Frozen reference table changed')
        for path in [assets/'anlogic_logo_rom.v',assets/'osd_char_lib.v',assets/'reference.json',
                     assets/'provenance.json',source_path('tb_osd_assets.v'),source_path('compare_osd_assets.py'),Path(__file__),source_path('project_paths.py')]:
            shutil.copy2(path,run/'src'/path.name)
            result['source_sha256'][path.name]=hashlib.sha256(path.read_bytes()).hexdigest()
        execute([a.modelsim/'vlib.exe','lib'],'create_library')
        execute([a.modelsim/'vlog.exe','-work','lib','src/anlogic_logo_rom.v','src/osd_char_lib.v',
                 'src/tb_osd_assets.v'],'compile',marker='Errors: 0, Warnings: 0')
        predicate='[examine -radix unsigned /tb_osd_assets/test_done] == 1 && [examine -radix unsigned /tb_osd_assets/test_passed] == 1'
        (run/'run.do').write_text('onerror {quit -code 1 -force}\n'
            f'onbreak {{if {{{predicate}}} {{quit -code 0 -force}} else {{quit -code 1 -force}}}}\n'
            'run -all\n'+f'if {{{predicate}}} {{quit -code 0 -force}}\nquit -code 1 -force\n')
        execute([a.modelsim/'vsim.exe','-c','-onfinish','stop','-wlf','assets.wlf','-lib','lib',
                 'tb_osd_assets','-do','run.do'],'simulation',marker='PASS: OSD asset RTL dump completed.')
        command=[sys.executable,run/'src/compare_osd_assets.py','--directory',run,'--reference',run/'src/reference.json']
        execute(command,'comparison',marker='PASS: OSD asset tables match RTL readback.')
        execute([*command,'--inject-error'],'checker_selftest',expected=1,marker='OSD asset mismatch: 1 entries')
        result.update(json.loads((run/'image_check.json').read_text()))
        result['checker_selftest_passed']=True
        result['passed']=True
        (root/'test_data').mkdir(exist_ok=True)
        shutil.copy2(run/'osd_assets_preview.png',root/'test_data/osd_assets_preview.png')
        print('Logo: 32768 addresses checked; Font: 4096 rows checked; Differences: 0.',flush=True)
        print(f'Preview: {root / "test_data/osd_assets_preview.png"}',flush=True)
        print('PASS: OSD asset checks completed.',flush=True)
        return 0
    except (OSError,ValueError,RuntimeError,subprocess.TimeoutExpired) as e:
        result['failure']=str(e); print(f'FAIL: {e}',flush=True); return 1
    finally:
        (run/'summary.json').write_text(json.dumps(result,indent=2)+'\n')


if __name__=='__main__':
    raise SystemExit(main())
