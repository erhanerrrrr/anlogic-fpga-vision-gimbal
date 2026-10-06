"""Generate independent vectors, run ModelSim and compare actual registered outputs."""
import argparse
import csv
import json
from pathlib import Path
import random
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'model'))
from c1_reference import classify

SEED = 20261005
PROFILES = [(80,40,40), (0,0,0), (255,255,255), (120,30,90)]


def vectors():
    rows = [(0,0,0,(0,0,0),'reset')]
    # Literal known-answer anchors, rotated into R/G/B configurations.
    anchors = [((200,40,40),1), ((80,40,40),1), ((79,0,0),0),
               ((80,41,40),0), ((80,40,41),0), ((20,200,20),0),
               ((0,0,0),0), ((255,255,255),0), ((128,128,128),0),
               ((255,0,0),1), ((0,255,0),0)]
    for color in range(3):
        for (main,a,b), expected in anchors:
            rgb = [a,b]
            rgb.insert(color, main)
            if classify(rgb,color) != expected:
                raise ValueError('reference disagrees with literal anchor')
            rows.append((1,1,color,tuple(rgb),'anchor'))
        for main in (0,39,40,79,80,81,120,254,255):
            for diff1 in (39,40,41):
                for diff2 in (39,40,41):
                    a,b=main-diff1,main-diff2
                    if min(a,b) >= 0:
                        rgb=[a,b]; rgb.insert(color,main)
                        rows.append((1,1,color,tuple(rgb),'boundary'))
    rng=random.Random(SEED)
    for color in range(3):
        for index in range(4096):
            rgb=tuple(rng.randrange(256) for _ in range(3))
            rows.append((1,1,color,rgb,'random'))
            if index % 97 == 0:
                rows.append((1,0,color,(200,40,40),'valid_gap'))
            if index == 2048:
                rows.extend([(0,1,color,rgb,'midstream_reset'),(1,1,color,rgb,'reset_recovery')])
    rows.extend([(1,1,3,(255,0,0),'illegal_color'),(1,0,0,(0,0,0),'flush')])
    return rows


def run(command, cwd, log):
    result=subprocess.run(command,cwd=str(cwd),stdout=subprocess.PIPE,
                          stderr=subprocess.STDOUT,timeout=90)
    text=result.stdout.decode('utf-8',errors='replace')
    log.write_text(text,encoding='utf-8')
    if result.returncode:
        raise RuntimeError('{} returned {}: see {}'.format(command[0],result.returncode,log))
    return text


def compare(actual, expected):
    if len(actual) != len(expected):
        raise ValueError('output row count mismatch')
    for i,(got,want) in enumerate(zip(actual,expected)):
        if got != want:
            raise ValueError('cycle {}: actual {} expected {}'.format(i,got,want))


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--inject-error',action='store_true',help='flip one expected mask; must exit 1')
    args=parser.parse_args()
    out=ROOT/'reports/c1/generated'
    out.mkdir(parents=True,exist_ok=True)
    summary={'stage':'C1','result':'FAIL','seed':SEED,'interface_version':'c1-draft-1',
             'td':'not_run_C2_checkpoint','team_interface_acceptance':'pending_A_B'}
    (out/'summary.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
    tools={name:shutil.which(name) for name in ('vlib','vlog','vsim')}
    if not all(tools.values()):
        raise RuntimeError('ModelSim vlib/vlog/vsim must be on PATH')
    rows=vectors()
    expected=[]
    with (out/'vectors.txt').open('w',encoding='ascii') as f:
        for i,(rst,valid,color,rgb,kind) in enumerate(rows):
            packed=(rgb[0]<<16)|(rgb[1]<<8)|rgb[2]
            f.write('{} {} {} {} {:06x}\n'.format(i,rst,valid,color,packed))
            packet=[i]
            for limits in PROFILES:
                packet.extend([int(bool(rst and valid)),classify(rgb,color,limits) if rst and valid else 0])
            expected.append(packet)
    with (out/'expected.csv').open('w',newline='',encoding='ascii') as f:
        csv.writer(f).writerows(expected)
    # Isolate the old simulator from non-ASCII workspace paths and user library mappings.
    with tempfile.TemporaryDirectory(prefix='fpga_c1_') as directory:
        work=Path(directory)
        for source in (ROOT/'rtl/recognition/color_classifier.v', ROOT/'sim/c1/tb_color_classifier.v',out/'vectors.txt'):
            shutil.copy2(str(source),str(work/source.name))
        version=run([tools['vsim'],'-version'],work,out/'tool_version.log').strip()
        run([tools['vlib'],'work'],work,out/'vlib.log')
        run([tools['vlog'],'-sv','color_classifier.v','tb_color_classifier.v'],work,out/'compile.log')
        log=run([tools['vsim'],'-c','work.tb_color_classifier','-do',
                 'onerror {quit -f -code 1}; onbreak {quit -f -code 1}; run -all; quit -f -code 0'],work,out/'simulation.log')
        if 'C1_SIM_COMPLETE' not in log:
            raise RuntimeError('simulation did not reach completion')
        shutil.copy2(str(work/'actual.csv'),str(out/'actual.csv'))
    with (out/'actual.csv').open(newline='') as f:
        reader=csv.reader(f); next(reader)
        actual=[[int(value) for value in row] for row in reader]
    if args.inject_error:
        expected[1][2] ^= 1
        compare(actual,expected)
        raise RuntimeError('checker accepted corrupted expectation')
    compare(actual,expected)
    corrupted=[row[:] for row in expected]
    corrupted[1][2] ^= 1
    try:
        compare(actual,corrupted)
    except ValueError as exc:
        (out/'checker_selftest.log').write_text('EXPECTED FAILURE: '+str(exc)+'\n',encoding='utf-8')
    else:
        raise RuntimeError('checker self-test failed')
    coverage={kind:sum(row[4]==kind for row in rows) for kind in sorted(set(row[4] for row in rows))}
    summary.update(result='PASS',cycles=len(rows),profiles=PROFILES,coverage=coverage,
                   comparisons=len(rows)*len(PROFILES),mask_mismatches=0,valid_mismatches=0,
                   latency='one output register; checked after sampling edge and held until next edge',
                   modelsim=version,checker_selftest='expected mask bit flip rejected',
                   hardware='not_tested')
    (out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n',encoding='utf-8')
    print('PASS: {} cycles x {} profiles; 12288 random RGB; valid/reset/hold checks passed'.format(len(rows),len(PROFILES)))


if __name__ == '__main__':
    try:
        main()
    except Exception as exc:
        print('FAIL: '+str(exc),file=sys.stderr)
        sys.exit(1)
