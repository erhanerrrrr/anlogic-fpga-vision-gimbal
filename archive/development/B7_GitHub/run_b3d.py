"""B3d calibration status observer and uniform-font display."""
import argparse,subprocess,sys
from pathlib import Path
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--modelsim',type=Path,required=True)
    p.add_argument('--synthesis',action='store_true');p.add_argument('--td',type=Path)
    a=p.parse_args();root=Path(__file__).resolve().parent
    if a.synthesis and not a.td:p.error('--synthesis requires --td')
    subprocess.run([sys.executable,'-X','utf8',str(root/'scripts/check_calibration_status.py'),'--modelsim',str(a.modelsim)],cwd=root,check=True)
    if a.synthesis:subprocess.run([sys.executable,'-X','utf8',str(root/'synthesis/check_calibration_status_synthesis.py'),'--td',str(a.td)],cwd=root,check=True)
    print('PASS: B3d checks completed.')
if __name__=='__main__':main()
