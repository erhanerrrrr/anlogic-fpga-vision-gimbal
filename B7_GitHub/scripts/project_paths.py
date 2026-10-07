"""Repository paths and tool discovery; never depend on the caller's cwd."""
import os
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[1]


def source_path(name):
    if name.startswith('tb_') and name.endswith('.v'):
        return ROOT/'sim'/name
    if name.endswith('.v'):
        return ROOT/'rtl'/name
    if name.startswith('check_') or name == 'project_paths.py':
        return ROOT/'scripts'/name
    return ROOT/'model'/name


def find_modelsim(explicit):
    if explicit:
        candidates = [explicit]
    else:
        candidates = []
        if os.environ.get('MODELSIM_BIN'):
            candidates.append(Path(os.environ['MODELSIM_BIN']))
        if shutil.which('vsim.exe'):
            candidates.append(Path(shutil.which('vsim.exe')).parent)
    for path in candidates:
        if all((path/n).is_file() for n in ('vlib.exe', 'vlog.exe', 'vsim.exe')):
            return path.resolve()
    raise RuntimeError('Supply --modelsim <bin-directory>, set MODELSIM_BIN, or add ModelSim to PATH.')
