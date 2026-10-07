"""Check B7 package integrity and reproduce its simulations in the extracted directory."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--modelsim', type=Path)
    p.add_argument('--hash-only', action='store_true')
    p.add_argument('--720p', dest='full_size', action='store_true')
    p.add_argument('--synthesis', action='store_true', help='Append strict 75 MHz synthesis')
    p.add_argument('--synthesis-only', action='store_true')
    p.add_argument('--td', type=Path)
    a = p.parse_args()
    root = Path(__file__).resolve().parent
    manifest = json.loads((root/'reports/source_manifest.json').read_text(encoding='utf-8'))
    for name, expected in manifest['files_sha256'].items():
        path = (root/name).resolve()
        if not path.is_relative_to(root) or not path.is_file():
            raise RuntimeError(f'Missing or invalid package path: {name}')
        if hashlib.sha256(path.read_bytes()).hexdigest() != expected:
            raise RuntimeError(f'Package file changed: {name}')
    print(f"PASS: package hashes ({len(manifest['files_sha256'])} files).", flush=True)
    if a.hash_only:
        return 0
    commands = []
    if not a.synthesis_only:
        candidates = [a.modelsim]
        if os.environ.get('MODELSIM_BIN'):
            candidates.append(Path(os.environ['MODELSIM_BIN']))
        if shutil.which('vsim.exe'):
            candidates.append(Path(shutil.which('vsim.exe')).parent)
        simulator = next((v.resolve() for v in candidates if v and
            all((v/n).is_file() for n in ('vlib.exe', 'vlog.exe', 'vsim.exe'))), None)
        if simulator is None:
            raise RuntimeError('Supply --modelsim <bin-directory> or set MODELSIM_BIN.')
        for name in ('check_osd_assets.py', 'check_video_static_osd.py', 'check_video_display.py'):
            command = [sys.executable, str(root/'scripts'/name), '--modelsim', str(simulator)]
            if a.full_size and name != 'check_osd_assets.py':
                command.append('--720p')
            commands.append(command)
    if a.synthesis or a.synthesis_only:
        command = [sys.executable, str(root/'synthesis/check_video_display_synthesis.py'), '--require-timing']
        if a.td:
            command += ['--td', str(a.td.resolve())]
        commands.append(command)
    for command in commands:
        print(f'Running {Path(command[1]).name}...', flush=True)
        result = subprocess.run(command, cwd=root, timeout=4200)
        if result.returncode:
            raise RuntimeError(f'{Path(command[1]).name} failed: exit {result.returncode}')
    print('PASS: B7 GitHub project checks completed.', flush=True)
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as e:
        print(f'FAIL: {e}', file=sys.stderr)
        raise SystemExit(1)
