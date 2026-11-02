"""Early C2 synthesis only, not placement/routing or board timing sign-off."""
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT=Path(__file__).resolve().parents[1]


def main():
    td=shutil.which('td_commands_prompt')
    if not td:
        gui=shutil.which('td')
        if gui:
            candidate=Path(gui).parent/'td_commands_prompt.exe'
            if candidate.is_file(): td=str(candidate)
    if not td: raise RuntimeError('TD command-line executable not found on PATH or beside td')
    out=ROOT/'reports/c2/generated/td'; out.mkdir(parents=True,exist_ok=True)
    (out/'summary.json').write_text('{"result":"FAIL"}\n',encoding='utf-8')
    with tempfile.TemporaryDirectory(prefix='fpga_c2_td_') as directory:
        work=Path(directory)
        for rel in ('rtl/recognition/color_classifier.v','rtl/recognition/color_mask_stream.v','scripts/c2_synth.tcl'):
            shutil.copy2(str(ROOT/rel),str(work/Path(rel).name))
        result=subprocess.run([td,'c2_synth.tcl'],cwd=str(work),stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=180)
        log=result.stdout.decode('utf-8',errors='replace')
        (out/'synthesis.log').write_text(log,encoding='utf-8')
        for name in ('c2_rtl.area','c2_gate.area','c2_gate.v'):
            if (work/name).exists(): shutil.copy2(str(work/name),str(out/name))
        if result.returncode or 'C2_TD_SYNTH_COMPLETE' not in log:
            raise RuntimeError('TD synthesis failed; see '+str(out/'synthesis.log'))
        for name in ('c2_rtl.area','c2_gate.area','c2_gate.v'):
            if not (work/name).is_file() or (work/name).stat().st_size==0:
                raise RuntimeError('missing TD output '+name)
    (out/'summary.json').write_text(json.dumps({'result':'PASS','stage':'C2 early synthesis',
        'device':'PH1P35MDG324','speed':'3 (vendor script convention)',
        'timing':'not_constrained_not_signed_off','place_route':'not_run','hardware':'not_tested'},indent=2)+'\n',encoding='utf-8')
    print('PASS: C2 TD synthesis; inspect gate netlist and area report. No board timing claim.')


if __name__=='__main__':
    try: main()
    except Exception as exc:
        print('FAIL: '+str(exc),file=sys.stderr); sys.exit(1)
