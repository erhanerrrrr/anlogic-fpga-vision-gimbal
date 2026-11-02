"""Run B2a real C RGB/mask pairing and fault recovery checks."""
import argparse,os,shutil,subprocess,sys
from pathlib import Path

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--modelsim',type=Path);p.add_argument('--small-only',action='store_true')
    p.add_argument('--synthesis',action='store_true');p.add_argument('--td',type=Path)
    a=p.parse_args();root=Path(__file__).resolve().parent
    candidates=[a.modelsim,os.environ.get('MODELSIM_BIN')]
    if shutil.which('vsim.exe'):candidates.append(Path(shutil.which('vsim.exe')).parent)
    ms=next((Path(c) for c in candidates if c and all((Path(c)/n).is_file()
        for n in ('vlib.exe','vlog.exe','vsim.exe'))),None)
    if ms is None:p.error('Supply --modelsim <ModelSim bin> or MODELSIM_BIN')
    extra=['--small-only'] if a.small_only else []
    jobs=[[root/'scripts/check_rgb_mask_faults.py','--modelsim',ms,*extra],
          [root/'scripts/check_video_rgb_mask_pair.py','--modelsim',ms,*extra]]
    if a.synthesis:
        td=a.td or os.environ.get('TD_EXECUTABLE') or shutil.which('td_commands_prompt.exe')
        if not td:p.error('Supply --td or TD_EXECUTABLE')
        jobs.append([root/'synthesis/check_rgb_mask_pair_synthesis.py','--td',td])
    for job in jobs:subprocess.run([sys.executable,'-X','utf8',*map(str,job)],cwd=root,check=True)
    print('PASS: B2a checks completed.')
if __name__=='__main__':main()
