"""Isolated ModelSim runs; a zero exit alone is never proof of a passing TB."""
from pathlib import Path
import subprocess

def command(args, cwd, log, timeout=1800, marker=None):
    p = subprocess.run(list(map(str,args)), cwd=cwd, capture_output=True,
                       text=True, encoding='utf-8', errors='replace', timeout=timeout)
    output = p.stdout + p.stderr
    Path(log).write_text(output, encoding='utf-8')
    if p.returncode or (marker and marker not in output):
        raise RuntimeError(f'Command failed or PASS missing: {log} (exit {p.returncode})')
    return output

def simulate(ms, directory, sources, top, marker, generics=(), timeout=1800):
    directory = Path(directory)
    command([ms/'vlib.exe','lib'], directory, directory/'vlib.log')
    command([ms/'vlog.exe','-sv','-work','lib',*sources], directory, directory/'compile.log')
    (directory/'run.do').write_text('onerror {quit -code 1 -force}\n'
        'onbreak {quit -code 1 -force}\nrun -all\nquit -code 0 -force\n')
    output = command([ms/'vsim.exe','-c','-onfinish','exit','-lib','lib',top,
        *generics,'-wlf','simulation.wlf','-do','run.do'], directory,
        directory/'simulation.log',timeout,marker)
    if '** Fatal:' in output or '** Error:' in output:
        raise RuntimeError(f'Simulator diagnostic: {directory}/simulation.log')
    return output
