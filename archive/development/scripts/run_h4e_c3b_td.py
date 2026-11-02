"""Isolated TD synthesis with observable candidate fields; not full-board timing."""
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    td = shutil.which('td_commands_prompt')
    if not td:
        raise RuntimeError('td_commands_prompt must be on PATH')
    out = ROOT/'reports/h4e-c3b/generated/td'
    out.mkdir(parents=True, exist_ok=True)
    (out/'summary.json').write_text('{"status":"FAIL"}\n')
    sources = ['rtl/recognition/h4e_calibration_candidate.v',
               'synth/h4e_c3b/h4e_c3b_synth_top.v', 'scripts/h4e_c3b_synth.tcl']
    with tempfile.TemporaryDirectory(prefix='h4e_c3b_td_') as directory:
        work = Path(directory)
        for rel in sources:
            shutil.copy2(ROOT/rel, work/Path(rel).name)
        result = subprocess.run([td, 'h4e_c3b_synth.tcl'], cwd=work,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=180)
        log = result.stdout.decode('utf-8', errors='replace')
        (out/'synthesis.log').write_text(log, encoding='utf-8')
        for name in ('h4e_c3b_rtl.area', 'h4e_c3b_gate.area', 'h4e_c3b_gate.v'):
            if (work/name).is_file():
                shutil.copy2(work/name, out/name)
        if result.returncode or 'H4E_C3B_TD_SYNTH_COMPLETE' not in log:
            raise RuntimeError('TD failed: '+str(out/'synthesis.log'))
    area = (out/'h4e_c3b_gate.area').read_text()
    row = next(line for line in area.splitlines() if '|h4e_calibration_candidate' in line.replace(' ', ''))
    values = [part.strip() for part in row.split('|')[3:-1]]
    keys = ('logic_lut','ripple','seq','eram','dsp','dram_lut','shifter_lut','f7mux','f8mux','pll','ddr')
    resources = dict(zip(keys, map(int, values)))
    if resources['eram'] or resources['dsp']:
        raise RuntimeError('unexpected candidate retention or memory/DSP resources')
    top_slice = int(re.search(r'^#slice\*?\s+(\d+)', area, re.MULTILINE)[1])
    summary = dict(status='PASS',device='PH1P35MDG324',top='h4e_c3b_synth_top',
                   candidate_hierarchy=resources,whole_harness_synthesis_slice_estimate=top_slice,
                   timing='not_constrained_not_signed_off',hardware='not_tested',
                   full_board_increment='requires A integration and place/route; harness is excluded',
                   command=[td,'h4e_c3b_synth.tcl'],exit_code=result.returncode,
                   source_hashes={rel: hashlib.sha256((ROOT/rel).read_bytes()).hexdigest() for rel in sources})
    (out/'summary.json').write_text(json.dumps(summary, indent=2)+'\n')
    print(json.dumps(summary, indent=2))


if __name__ == '__main__':
    try:
        main()
    except Exception as exc:
        print('FAIL: '+str(exc), file=sys.stderr)
        sys.exit(1)
