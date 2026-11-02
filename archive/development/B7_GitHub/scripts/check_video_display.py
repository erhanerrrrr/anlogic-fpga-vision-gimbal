"""Verify button-controlled video modes followed by static OSD."""
import argparse
from datetime import datetime
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
from project_paths import ROOT, source_path, find_modelsim


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--modelsim',type=Path)
    p.add_argument('--720p',dest='full_size',action='store_true',
                   help='Run ten 1280x720 integrated frames with reset recovery and full pixel comparison.')
    a=p.parse_args(); root=ROOT
    run=root/'build/video_display_sim'/datetime.now().strftime('run_%Y%m%d_%H%M%S_%f')
    (run/'src').mkdir(parents=True); print(f'Reports: {run}',flush=True)
    result={'stage':'B7 buttons + four modes + static OSD integration, '+('720p' if a.full_size else 'small frames'),'passed':False,
            'cases':[],'source_sha256':{},'720p_verified':False,'synthesis_verified':False,'board_verified':False}
    def execute(command,cwd,log,marker,expected=0):
        p=subprocess.run([str(c) for c in command],cwd=cwd,capture_output=True,text=True,
                         encoding='utf-8',errors='replace',timeout=1800 if a.full_size else 600)
        output=p.stdout+p.stderr; log.write_text(output,encoding='utf-8')
        if p.returncode!=expected or marker not in output: raise RuntimeError(f'Unexpected result; see {log}')
        return output
    try:
        a.modelsim=find_modelsim(a.modelsim)
        rtl=['rgb_to_gray.v','video_gray.v','window_3x3.v','sobel_core.v','edge_raster.v','video_edge.v',
             'video_rgb_edge_align.v','frame_mode_ctrl.v','rgb_bypass.v','video_bypass.v','video_modes.v',
             'button_events.v','button_mode_request.v','video_modes_buttons.v','video_static_osd.v','video_display.v','tb_video_display.v']
        assets=root/'assets/osd'
        provenance=json.loads((assets/'provenance.json').read_text())
        for n in ('anlogic_logo_rom.v','osd_char_lib.v'):
            if hashlib.sha256((assets/n).read_bytes()).hexdigest()!=provenance['files'][n]['sha256']:
                raise RuntimeError('Vendor asset hash mismatch')
        if hashlib.sha256((assets/'reference.json').read_bytes()).hexdigest()!=provenance['reference_sha256']:
            raise RuntimeError('Asset reference hash mismatch')
        paths=[source_path(n) for n in rtl]+[assets/n for n in ('anlogic_logo_rom.v','osd_char_lib.v','reference.json','provenance.json')]
        paths += [source_path(n) for n in ('check_video_display.py','project_paths.py','compare_video_display.py','compare_static_osd.py','edge_csv_to_img.py')]
        for path in paths:
            shutil.copy2(path,run/'src'/path.name)
            result['source_sha256'][path.name]=hashlib.sha256(path.read_bytes()).hexdigest()
        execute([a.modelsim/'vlib.exe','lib'],run,run/'vlib.log','')
        execute([a.modelsim/'vlog.exe','-work','lib',*['src/'+n for n in rtl+['anlogic_logo_rom.v','osd_char_lib.v']]],
                run,run/'compile.log','Errors: 0, Warnings: 0')
        cases=([('ten_720p_frames',1280,720,1,1)] if a.full_size else
               [('normal',384,240,1,1),('continuous',384,240,0,1),('disabled',16,12,1,0)])
        for name,w,h,blanks,enabled in cases:
            case=run/name; case.mkdir()
            pred='[examine -radix unsigned /tb_video_display/test_done] == 1 && [examine -radix unsigned /tb_video_display/test_passed] == 1'
            (case/'run.do').write_text('onerror {quit -code 1 -force}\n'+
                f'onbreak {{if {{{pred}}} {{quit -code 0 -force}} else {{quit -code 1 -force}}}}\n'+
                'run -all\n'+f'if {{{pred}}} {{quit -code 0 -force}}\nquit -code 1 -force\n')
            print(f'Running RTL simulation: {name} ({w}x{h}, 10 frames)...',flush=True)
            output=execute([a.modelsim/'vsim.exe','-c','-onfinish','stop','-wlf','display.wlf','-lib',(run/'lib').as_posix(),
                'tb_video_display',f'-gWIDTH={w}',f'-gHEIGHT={h}',f'-gROW_BLANKS={blanks}',f'-gOSD_ENABLE={enabled}',
                '-do','run.do'],case,case/'simulation.log','PASS: buttons, video modes and OSD stream checks completed.')
            command=[sys.executable,run/'src/compare_video_display.py','--directory',case,'--assets',run/'src/reference.json',
                     '--width',w,'--height',h,'--enable',enabled]
            print(f'Comparing captured pixels and generating images: {name}...',flush=True)
            execute(command,case,case/'comparison.log','PASS: integrated display pixels match independent mode and OSD references.')
            data=json.loads((case/'image_check.json').read_text()); data['name']=name
            data['simulation_counters']=re.findall(r'(?:Pixels=|Display pixels=|Buttons:|Detection pixels=|Reset prefix pixels=|FIFO peak=).*',output)
            data['display_sof_latencies']=re.findall(r'Display frame \d+ SOF latency=\d+ cycles',output)
            result['cases'].append(data)
            if name=='normal':
                execute([*command,'--inject-error'],case,case/'checker_selftest.log','Integrated display mismatch: 1 pixels',1)
                result['checker_selftest_passed']=True
            print(f'PASS: {name} (10 frames, {10*w*h} pixels, differences=0)',flush=True)
        result['passed']=True
        result['720p_verified']=a.full_size
        (root/'test_data').mkdir(exist_ok=True)
        case_name='ten_720p_frames' if a.full_size else 'normal'
        preview_name='video_display_720p_preview.png' if a.full_size else 'video_display_preview.png'
        shutil.copy2(run/case_name/'images/video_display_preview.png',root/'test_data'/preview_name)
        print('PASS: button-controlled display with OSD 720p checks completed.' if a.full_size else
              'PASS: button-controlled display with OSD checks completed.',flush=True)
        return 0
    except (OSError,ValueError,RuntimeError,subprocess.TimeoutExpired) as e:
        result['failure']=str(e); print(f'FAIL: {e}',flush=True); return 1
    finally:
        (run/'summary.json').write_text(json.dumps(result,indent=2)+'\n')


if __name__=='__main__':
    raise SystemExit(main())
