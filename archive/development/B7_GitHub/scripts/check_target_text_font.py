"""Exhaustive glyph outputs and uniform letter/digit size checks."""
import argparse,hashlib,json,shutil,sys
from pathlib import Path
from datetime import datetime
from b1_tools import simulate
from build_target_font import generated
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'model'))
from target_text_reference import load_font

def main():
    p=argparse.ArgumentParser();p.add_argument('--modelsim',type=Path,required=True);a=p.parse_args()
    assert (ROOT/'assets/osd/target_text_font.v').read_text()==generated()
    font=load_font(ROOT/'assets/osd/target_font_5x7.json')
    for ch in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789':
        rows=font[str(ord(ch))]
        assert rows[0]==rows[15]==0 and rows[1] and rows[14], ch
        for y in range(1,15,2):
            assert rows[y]==rows[y+1],ch
            bits=f'{rows[y]:016b}'
            assert bits[:3]==bits[13:]=='000',ch
            assert all(bits[x]==bits[x+1] for x in range(3,13,2)),ch
    assert font[str(ord('A'))][1]==int('0000011111100000',2)
    run=ROOT/'build/target_text_font'/datetime.now().strftime('run_%Y%m%d_%H%M%S')
    run.mkdir(parents=True)
    expected=[v for ch in range(256) for v in font.get(str(ch),[0]*16)]
    (run/'font_expected.mem').write_text(''.join(f'{v:04x}\n' for v in expected))
    files=['assets/osd/target_text_font.v','sim/tb_target_text_font.v']
    for f in files:shutil.copy2(ROOT/f,run/Path(f).name)
    simulate(a.modelsim,run,[Path(f).name for f in files],'tb_target_text_font','PASS FONT:',timeout=120)
    tracked=files+['assets/osd/target_font_5x7.json','scripts/build_target_font.py','scripts/check_target_text_font.py','model/target_text_reference.py']
    (run/'summary.json').write_text(json.dumps(dict(passed=True,rows_checked=4096,letter_digit_height=14,
        source_sha256={f:hashlib.sha256((ROOT/f).read_bytes()).hexdigest() for f in tracked}),indent=2)+'\n')
    print(f'PASS: uniform text font. Reports: {run}',flush=True)
if __name__=='__main__':main()
