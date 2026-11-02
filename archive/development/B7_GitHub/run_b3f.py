"""B3f combined four-mode and status display, with synthetic A/C status."""
import argparse,subprocess,sys
from pathlib import Path
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--modelsim',type=Path,required=True)
    p.add_argument('--synthesis',action='store_true');p.add_argument('--td',type=Path)
    a=p.parse_args();root=Path(__file__).resolve().parent
    if a.synthesis and not a.td:p.error('--synthesis requires --td')
    subprocess.run([sys.executable,'-X','utf8',str(root/'scripts/check_b3_status_stream.py'),'--modelsim',str(a.modelsim)],cwd=root,check=True)
    if a.synthesis:subprocess.run([sys.executable,'-X','utf8',str(root/'synthesis/check_b3_status_synthesis.py'),'--td',str(a.td)],cwd=root,check=True)
    print('PASS: B3f checks completed.')
if __name__=='__main__':main()
