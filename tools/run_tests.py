"""Run the HDL regression suite with Icarus Verilog."""
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]


def find_tool(name, override):
    resolved = override or shutil.which(name)
    if not resolved or not Path(resolved).is_file():
        raise FileNotFoundError(f'{name}: add it to PATH or specify --{name}')
    return str(Path(resolved).resolve())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--test', nargs='+', help='Run only the named testbenches')
    parser.add_argument('--jobs', type=int, default=3)
    parser.add_argument('--timeout', type=int, default=3600, help='Seconds per simulation')
    parser.add_argument('--iverilog')
    parser.add_argument('--vvp')
    args = parser.parse_args()
    if args.jobs < 1 or args.timeout < 1:
        parser.error('--jobs and --timeout must be positive')
    iv = find_tool('iverilog', args.iverilog)
    vvp = find_tool('vvp', args.vvp)
    suite = json.loads((ROOT / 'tb/suite.json').read_text())
    tests = args.test or suite
    if len(tests) != len(set(tests)) or not set(tests) <= set(suite):
        parser.error('Test names must be unique entries in tb/suite.json')
    sources = [ROOT / p for p in json.loads((ROOT / 'tb/sources.json').read_text())]
    output = ROOT / 'sim'
    output.mkdir(exist_ok=True)

    def run_one(name):
        start = time.monotonic()
        exe = output / f'{name}.vvp'
        command = [iv, '-g2012', '-Wall', '-I', str(ROOT / 'src/include'),
                   '-s', name, '-o', str(exe), str(ROOT / 'tb' / f'{name}.sv')]
        command += [str(p) for p in sources]
        compile_result = subprocess.run(command, cwd=ROOT, capture_output=True,
                                        text=True, encoding='utf-8', errors='replace')
        (output / f'{name}.compile.log').write_text(
            compile_result.stdout + compile_result.stderr, encoding='utf-8')
        if compile_result.returncode:
            return dict(name=name, status='FAIL', phase='compile')
        try:
            with (output / f'{name}.log').open('w', encoding='utf-8') as log:
                result = subprocess.run([vvp, str(exe)], cwd=ROOT, stdout=log,
                                        stderr=subprocess.STDOUT, timeout=args.timeout)
        except subprocess.TimeoutExpired:
            return dict(name=name, status='FAIL', phase='timeout')
        text = (output / f'{name}.log').read_text(encoding='utf-8', errors='replace')
        passed = (result.returncode == 0 and re.search(r'^PASS\b', text, re.M)
                  and not re.search(r'\b(?:FATAL|ERROR)\b', text))
        return dict(name=name, status='PASS' if passed else 'FAIL',
                    seconds=round(time.monotonic() - start, 2))

    results = []
    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        futures = [pool.submit(run_one, name) for name in tests]
        for future in as_completed(futures):
            item = future.result()
            results.append(item)
            print(item['status'], item['name'], item.get('seconds', item.get('phase')), flush=True)
    if any(item['name'] == 'tb_f2n_uart' and item['status'] == 'PASS' for item in results):
        decoder = subprocess.run([sys.executable, str(ROOT / 'tools/verify_telemetry.py')], cwd=ROOT)
        results.append(dict(name='telemetry_decoder', status='PASS' if decoder.returncode == 0 else 'FAIL'))
    passed = all(item['status'] == 'PASS' for item in results)
    report = dict(status='PASS' if passed else 'FAIL', results=sorted(results, key=lambda x: x['name']))
    (output / 'results.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(f"{report['status']}: {len(results)} checks; logs in {output}", flush=True)
    return 0 if passed else 1


if __name__ == '__main__':
    sys.exit(main())
