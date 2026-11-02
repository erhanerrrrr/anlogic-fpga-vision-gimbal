"""C1-C9 synthesis with an observable word-read harness; no board timing sign-off."""
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT=Path(__file__).resolve().parents[1]


def main():
    td=shutil.which('td_commands_prompt')
    if not td and shutil.which('td'):
        candidate=Path(shutil.which('td')).parent/'td_commands_prompt.exe'
        if candidate.is_file():td=str(candidate)
    if not td:raise RuntimeError('TD command-line executable not found')
    out=ROOT/'reports/c9/generated/td';out.mkdir(parents=True,exist_ok=True)
    (out/'summary.json').write_text('{"result":"FAIL"}\n',encoding='utf-8')
    sources=(ROOT/'rtl/recognition/c9_sources.f').read_text().splitlines()
    with tempfile.TemporaryDirectory(prefix='fpga_c9_td_') as directory:
        work=Path(directory)
        for rel in sources+['scripts/c9_synth.tcl','synth/c9/c9_synth_top.v']:
            shutil.copy2(str(ROOT/rel),str(work/Path(rel).name))
        result=subprocess.run([td,'c9_synth.tcl'],cwd=str(work),stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=180)
        log=result.stdout.decode('utf-8',errors='replace');(out/'synthesis.log').write_text(log,encoding='utf-8')
        for name in ('c9_rtl.area','c9_gate.area','c9_gate.v'):
            if (work/name).is_file():shutil.copy2(str(work/name),str(out/name))
        if result.returncode or 'C9_TD_SYNTH_COMPLETE' not in log:raise RuntimeError('TD failed; see '+str(out/'synthesis.log'))
        for name in ('c9_rtl.area','c9_gate.area','c9_gate.v'):
            if not (work/name).is_file() or (work/name).stat().st_size==0:raise RuntimeError('missing '+name)
    (out/'summary.json').write_text(json.dumps({'stage':'C9','result':'PASS','top':'c9_synth_top',
        'device':'PH1P35MDG324','mode':'synthesis-only full-result word-read harness',
        'timing':'not_constrained_not_signed_off','hardware':'not_tested'},indent=2)+'\n',encoding='utf-8')
    print('PASS: C1-C9 TD synthesis with observable word-read harness. No board timing claim.')


if __name__=='__main__':
    try:main()
    except Exception as exc:
        print('FAIL: '+str(exc),file=sys.stderr);sys.exit(1)
