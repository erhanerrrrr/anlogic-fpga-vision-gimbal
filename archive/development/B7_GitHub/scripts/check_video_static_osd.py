"""Verify the standalone static OSD stream, pixel reference and boundary layouts."""
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
    p.add_argument('--720p',dest='full_size',action='store_true',
                   help='Run five full 1280x720 frames, including reset recovery and actual PNG output.')
    a=p.parse_args(); root=ROOT
    width,height=(1280,720) if a.full_size else (384,240)
    run=root/'build/static_osd_sim'/datetime.now().strftime('run_%Y%m%d_%H%M%S_%f')
    (run/'src').mkdir(parents=True)
    print(f'Reports: {run}',flush=True)
    result={'stage':f'B7 standalone static OSD, {width}x{height}','passed':False,'cases':[],
            'synthesis_verified':False,'720p_verified':False,'four_mode_integration_verified':False,
            'board_verified':False,'source_sha256':{}}
    def execute(cmd,cwd,log,marker,expected=0):
        r=subprocess.run([str(s) for s in cmd],cwd=cwd,capture_output=True,text=True,
                         encoding='utf-8',errors='replace',timeout=1200 if a.full_size else 180)
        text=r.stdout+r.stderr; log.write_text(text,encoding='utf-8')
        if r.returncode!=expected or marker not in text:
            raise RuntimeError(f'Unexpected result; see {log}')
    try:
        a.modelsim=find_modelsim(a.modelsim)
        assets=root/'assets/osd'
        provenance=json.loads((assets/'provenance.json').read_text())
        for name in ('anlogic_logo_rom.v','osd_char_lib.v'):
            if hashlib.sha256((assets/name).read_bytes()).hexdigest()!=provenance['files'][name]['sha256']:
                raise RuntimeError('Vendor asset hash mismatch')
        if hashlib.sha256((assets/'reference.json').read_bytes()).hexdigest()!=provenance['reference_sha256']:
            raise RuntimeError('Reference asset hash mismatch')
        for path in [assets/'anlogic_logo_rom.v',assets/'osd_char_lib.v',assets/'reference.json',assets/'provenance.json',
                     source_path('video_static_osd.v'),source_path('tb_video_static_osd.v'),source_path('compare_static_osd.py'),Path(__file__),source_path('project_paths.py')]:
            shutil.copy2(path,run/'src'/path.name)
            result['source_sha256'][path.name]=hashlib.sha256(path.read_bytes()).hexdigest()
        execute([a.modelsim/'vlib.exe','lib'],run,run/'vlib.log','')
        execute([a.modelsim/'vlog.exe','-work','lib',*['src/'+n for n in
                 ('anlogic_logo_rom.v','osd_char_lib.v','video_static_osd.v','tb_video_static_osd.v')]],run,
                run/'compile.log','Errors: 0, Warnings: 0')
        cases=([('five_720p_frames',0,1,1)] if a.full_size else
               [('normal',0,1,1),('continuous',0,1,0),('clipped',1,1,1),('overlap',2,1,1),('disabled',0,0,1)])
        for name,layout,enable,blanks in cases:
            case=run/name; case.mkdir()
            predicate='[examine -radix unsigned /tb_video_static_osd/test_done] == 1 && [examine -radix unsigned /tb_video_static_osd/test_passed] == 1'
            (case/'run.do').write_text('onerror {quit -code 1 -force}\n'
                f'onbreak {{if {{{predicate}}} {{quit -code 0 -force}} else {{quit -code 1 -force}}}}\n'
                'run -all\n'+f'if {{{predicate}}} {{quit -code 0 -force}}\nquit -code 1 -force\n')
            execute([a.modelsim/'vsim.exe','-c','-onfinish','stop','-wlf','osd.wlf','-lib',(run/'lib').as_posix(),
                     'tb_video_static_osd',f'-gLAYOUT={layout}',f'-gENABLE={enable}',f'-gROW_BLANKS={blanks}',
                     f'-gWIDTH={width}',f'-gHEIGHT={height}',
                     '-do','run.do'],case,case/'simulation.log','PASS: static OSD stream timing checks completed.')
            command=[sys.executable,run/'src/compare_static_osd.py','--directory',case,'--assets',run/'src/reference.json',
                     '--layout',str(layout),'--enable',str(enable),'--width',str(width),'--height',str(height)]
            execute(command,case,case/'comparison.log','PASS: static OSD RTL pixels match the independent compositor.')
            item=json.loads((case/'image_check.json').read_text()); item['name']=name
            result['cases'].append(item)
            if name=='normal':
                execute([*command,'--inject-error'],case,case/'checker_selftest.log','Static OSD mismatch: 1 pixels',1)
                result['checker_selftest_passed']=True
            print(f'PASS: {name} (5 frames, {5*width*height} pixels, differences=0)',flush=True)
        result['passed']=True
        result['720p_verified']=a.full_size
        (root/'test_data').mkdir(exist_ok=True)
        case_name='five_720p_frames' if a.full_size else 'normal'
        preview_name='static_osd_720p_preview.png' if a.full_size else 'static_osd_preview.png'
        shutil.copy2(run/case_name/'images/static_osd_preview.png',root/'test_data'/preview_name)
        print('PASS: static OSD 720p checks completed.' if a.full_size else
              'PASS: static OSD small-frame checks completed.',flush=True)
        return 0
    except (OSError,ValueError,RuntimeError,subprocess.TimeoutExpired) as e:
        result['failure']=str(e); print(f'FAIL: {e}',flush=True); return 1
    finally:
        (run/'summary.json').write_text(json.dumps(result,indent=2)+'\n')


if __name__=='__main__':
    raise SystemExit(main())
