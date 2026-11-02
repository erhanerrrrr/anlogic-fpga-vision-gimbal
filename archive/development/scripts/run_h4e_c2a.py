"""Fast C2a packet + actual region-core regression; no full video rerun required."""
import csv
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'model'))
from h4e_c2a_reference import FIELDS, SEED, unit_vectors, expected_trace, encode, chain_vectors


def write_json(path, data):
    path.write_text(json.dumps(data, indent=2)+'\n', encoding='utf-8')


def write_csv(path, rows):
    with path.open('w', newline='', encoding='utf-8') as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def read_csv(path):
    with path.open(newline='', encoding='utf-8') as stream:
        return [{key: int(value) for key, value in row.items()} for row in csv.DictReader(stream)]


def compare(actual, expected):
    if len(actual) != len(expected):
        raise ValueError('wrong observation count')
    for index, (got, want) in enumerate(zip(actual, expected)):
        for key, value in want.items():
            if got[key] != value:
                raise ValueError('row %d %s: got %d, expected %d' % (index, key, got[key], value))


def main():
    out = ROOT/'reports/h4e-c2a/generated'
    out.mkdir(parents=True, exist_ok=True)
    write_json(out/'summary.json', {'status': 'FAIL'})
    tools = {name: shutil.which(name) for name in ('iverilog', 'vvp')}
    if not all(tools.values()):
        raise RuntimeError('iverilog and vvp must be on PATH')
    commands = []

    def run(command, work, log):
        commands.append(command)
        result = subprocess.run(command, cwd=work, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, timeout=180)
        text = result.stdout.decode('utf-8', errors='replace')
        (out/log).write_text(text, encoding='utf-8')
        if result.returncode:
            raise RuntimeError('command failed: '+str(out/log))
        return text

    versions = {name: run([exe, '-V'], ROOT, name+'_version.log').splitlines()[0]
                for name, exe in tools.items()}
    vectors = unit_vectors()
    expected = expected_trace(vectors)
    frames = chain_vectors()
    sources = (ROOT/'rtl/recognition/h4e_c2a_sources.f').read_text().splitlines()
    tb_files = ['sim/h4e_c2a/tb_h4e_target_packet.v', 'sim/h4e_c2a/tb_h4e_target_chain.v']
    with tempfile.TemporaryDirectory(prefix='h4e_c2a_') as directory:
        work = Path(directory)
        for rel in sources+tb_files:
            shutil.copy2(ROOT/rel, work/Path(rel).name)
        with (work/'unit.txt').open('w') as stream:
            for v in vectors:
                stream.write('%d %d %d %048x\n' %
                             (v['cycle'], v['rst_n'], v['input_strobe'], encode(v['input'])))
        (work/'chain_masks.mem').write_text('\n'.join(str(p) for f in frames for p in f['mask'])+'\n')
        (work/'chain_metadata.mem').write_text('\n'.join('%013x' %
            ((f['expected']['frame_id'] << 18) | (f['expected']['cfg_id'] << 2) |
             f['expected']['target_id']) for f in frames)+'\n')
        for kind, tb in [('unit', tb_files[0]), ('chain', tb_files[1])]:
            top = Path(tb).stem
            run([tools['iverilog'], '-g2012', '-s', top, '-o', kind+'.vvp']+
                [Path(s).name for s in sources]+[Path(tb).name], work, kind+'_compile.log')
            log = run([tools['vvp'], kind+'.vvp'], work, kind+'_simulation.log')
            if 'H4E_C2A_'+kind.upper()+'_COMPLETE' not in log:
                raise RuntimeError('missing completion marker: '+kind)
            shutil.copy2(work/(kind+'_actual.csv'), out/(kind+'_actual.csv'))
        shutil.copy2(work/'unit.txt', out/'unit.txt')
    actual = read_csv(out/'unit_actual.csv')
    compare(actual, expected)
    chain = read_csv(out/'chain_actual.csv')
    compare(chain, [frame['expected'] for frame in frames])
    # Deliberately corrupt a correct event: the checker must detect field mixing.
    corrupted = [dict(row) for row in actual]
    corrupted[2]['frame_id'] ^= 1
    try:
        compare(corrupted, expected)
    except ValueError as exc:
        (out/'checker_selftest.log').write_text('EXPECTED_FAILURE: '+str(exc)+'\n')
    else:
        raise RuntimeError('checker accepted corrupted frame identity')
    write_json(out/'unit_vectors.json', vectors)
    write_csv(out/'unit_expected.csv', expected)
    write_json(out/'chain_expected.json', [{'name': f['name'], **f['expected']} for f in frames])
    demo = expected[:25]
    write_csv(out/'ab_demo_cycles.csv', demo)
    write_json(out/'ab_demo.json', dict(profile='packet-only; not physical capture-v1',
        clock_semantics='sample once on each rising edge where result_strobe=1; do not edge-detect',
        input_cycle_vectors=vectors[:25], expected_cycles=demo,
        event_count=sum(row['result_strobe'] for row in demo),
        valid_event_count=sum(row['result_strobe']*row['target_valid'] for row in demo)))
    write_json(out/'commands.json', commands)
    tracked = sources+tb_files+['model/h4e_c2a_reference.py','scripts/run_h4e_c2a.py']
    write_json(out/'source_hashes.json', {rel: hashlib.sha256((ROOT/rel).read_bytes()).hexdigest() for rel in tracked})
    summary = dict(status='PASS',base_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
                   python=sys.version,tools=versions,seed=SEED,unit_cycles=len(vectors),
                   unit_events=sum(row['result_strobe'] for row in expected),
                   chain_frames=len(frames),chain_pixels=len(frames)*64*24,
                   demo_cycles=len(demo),demo_events=sum(row['result_strobe'] for row in demo),
                   payload_bits=sum(width for _,width in FIELDS),register_bits=193,
                   packet_latency_clocks=1,source_binding='C2b pending',hardware='not_tested',
                   synthesis='see separate TD report',checker_selftest='PASS',command_exit_codes='all 0')
    write_json(out/'summary.json', summary)
    print(json.dumps(summary, indent=2))


if __name__ == '__main__':
    try:
        main()
    except Exception as exc:
        print('FAIL: '+str(exc), file=sys.stderr)
        sys.exit(1)
