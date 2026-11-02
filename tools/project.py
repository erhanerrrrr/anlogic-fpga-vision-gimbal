"""Check, prepare, or build the TangDynasty project in an isolated directory."""
import argparse
from datetime import datetime
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
PROJECT = Path('project/camera_to_dsi_display.al')


def checked_path(base, relative):
    path = (base / relative).resolve()
    if not path.is_relative_to(ROOT) or not path.is_file():
        raise FileNotFoundError(f'Missing or external dependency: {base} / {relative}')
    return path


def check():
    text = (ROOT / PROJECT).read_text(encoding='utf-8')
    paths = re.findall(r'<File Path="([^"]+)"', text)
    expected = json.loads((ROOT / 'project/sources.json').read_text())
    actual = []
    ip_files = 0
    for name in paths:
        path = checked_path((ROOT / PROJECT).parent, name)
        actual.append(path.relative_to(ROOT).as_posix())
        if path.suffix == '.xml':
            tree = ET.parse(path)
            for element in tree.iter():
                if element.tag.rsplit('}', 1)[-1] != 'file':
                    continue
                for child in element:
                    if child.tag.rsplit('}', 1)[-1] == 'name' and child.text:
                        checked_path(path.parent, child.text.strip())
                        ip_files += 1
        elif path.suffix == '.ipc':
            for element in ET.parse(path).find('GeneratedFiles'):
                if element.text:
                    checked_path(path.parent, element.text.strip())
                    ip_files += 1
    if actual != expected:
        raise ValueError('Project file order differs from project/sources.json')
    if len(actual) != len(set(actual)):
        raise ValueError('Duplicate project entries')
    for name in json.loads((ROOT / 'tb/sources.json').read_text()):
        checked_path(ROOT, name)
    for name in json.loads((ROOT / 'tb/suite.json').read_text()):
        checked_path(ROOT, f'tb/{name}.sv')
    print(f'PASS: {len(actual)} project entries; {ip_files} generated IP dependencies', flush=True)


def prepare(label):
    workspace = ROOT / 'build' / (label + '_' + datetime.now().strftime('%Y%m%d_%H%M%S_%f'))
    workspace.mkdir(parents=True, exist_ok=False)
    for name in ['src', 'platform', 'constraints', 'project']:
        shutil.copytree(ROOT / name, workspace / name)
    project = workspace / PROJECT
    text = project.read_text(encoding='utf-8')
    text = re.sub(r'(<Project\b[^>]*\bPath=")[^"]*',
                  lambda m: m[1] + project.parent.as_posix(), text, count=1)
    project.write_text(text, encoding='utf-8', newline='\n')
    print(f'Project: {project}', flush=True)
    return workspace


def run_td(workspace, action, executable):
    td = executable or os.environ.get('TD_BIN') or shutil.which('td_commands_prompt.exe')
    if not td or not Path(td).is_file():
        raise FileNotFoundError('Specify --td with the path to td_commands_prompt.exe, or set TD_BIN')
    project = workspace / PROJECT
    lines = [
        'import_device ph1_35p.db -package PH1P35MDG324 -speed 3',
        'open_project {' + project.as_posix() + '}',
    ]
    if action in ['synth', 'build']:
        lines += ['launch_runs {syn_1} -jobs 1', 'wait_run syn_1 -quiet']
    if action == 'build':
        lines += ['launch_runs {phy_1} -jobs 1', 'wait_run phy_1 -quiet', 'save_best_bits',
                  'open_run phy_1',
                  'check_timing -file {' + (workspace / 'timing_checks.rpt').as_posix() + '} -verbose']
    lines += ['close_project', 'puts "PROJECT_COMMAND_COMPLETE"']
    script = workspace / 'run.tcl'
    script.write_text('if {[catch {\n' + '\n'.join(lines)
                      + '\n} message]} {puts stderr $message; exit 1}\nexit\n', encoding='utf-8')
    flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
    with (workspace / 'run.log').open('w', encoding='utf-8') as log:
        result = subprocess.run([str(Path(td).resolve())],
                                input='source {' + script.as_posix() + '}\n',
                                cwd=project.parent, stdout=log, stderr=subprocess.STDOUT,
                                text=True, encoding='utf-8', errors='replace',
                                creationflags=flags)
    text = (workspace / 'run.log').read_text(encoding='utf-8', errors='replace')
    success = result.returncode == 0 and 'PROJECT_COMMAND_COMPLETE' in text
    if action in ['synth', 'build']:
        success = success and 'Run syn_1 success.' in text
    if action == 'build':
        success = success and 'Run phy_1 success.' in text
    if not success:
        print(text[-4000:])
        raise RuntimeError(f'TangDynasty did not complete; see {workspace / "run.log"}')
    print(f'PASS: TangDynasty {action}; log: {workspace / "run.log"}', flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['check', 'prepare', 'inspect', 'synth', 'build'])
    parser.add_argument('--td', help='Full path to td_commands_prompt.exe')
    args = parser.parse_args()
    check()
    if args.action != 'check':
        workspace = prepare(args.action)
        if args.action != 'prepare':
            run_td(workspace, args.action, args.td)
    return 0


if __name__ == '__main__':
    sys.exit(main())
