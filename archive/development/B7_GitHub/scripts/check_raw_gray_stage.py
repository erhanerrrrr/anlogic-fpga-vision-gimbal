"""Standalone RAW/GRAY stage: rounding, full gray ramp, bubbles and abort/reset."""
import argparse,hashlib,json,random,shutil
from datetime import datetime
from pathlib import Path
from b1_tools import simulate

def main():
    p=argparse.ArgumentParser();p.add_argument('--modelsim',type=Path,required=True);a=p.parse_args()
    root=Path(__file__).resolve().parents[1]
    run=root/'build/raw_gray_stage'/datetime.now().strftime('run_%Y%m%d_%H%M%S');run.mkdir(parents=True)
    rng=random.Random(0xB2B)
    colors=[(v,v,v) for v in range(256)]
    colors += [(v,0,0) for v in range(256)]+[(0,v,0) for v in range(256)]+[(0,0,v) for v in range(256)]
    colors += [(rng.randrange(256),rng.randrange(256),rng.randrange(256)) for _ in range(4096)]
    # Exercise both sides of half-LSB rounding with independent modular search.
    for residue in (0,127,128,129,255):
        found=0
        for r in range(256):
            for g in range(256):
                b=(residue-77*r-150*g)*pow(29,-1,256)%256
                colors.append((r,g,b));found+=1
                if found==32:break
            if found==32:break
    vectors=['0 0 0 0 00']
    for i,(r,g,b) in enumerate(colors):
        data=(rng.getrandbits(108)<<24)|(r<<16)|(g<<8)|b
        gray=(77*r+150*g+29*b+128)//256
        vectors.append(f'1 0 1 {data:033x} {gray:02x}')
        if i%37==0:
            vectors += [f'1 0 0 {data:033x} {gray:02x}',f'1 1 1 {data:033x} {gray:02x}',f'1 1 0 {data:033x} {gray:02x}',f'0 0 1 {data:033x} {gray:02x}']
    (run/'stage_vectors.txt').write_text('\n'.join(vectors)+'\n')
    files=['rtl/rgb_to_gray_lut.v','rtl/video_raw_gray_stage.v','sim/tb_raw_gray_stage.v']
    for f in files:shutil.copy2(root/f,run/Path(f).name)
    simulate(a.modelsim,run,[Path(f).name for f in files],'tb_raw_gray_stage','PASS RAW_GRAY_STAGE:')
    files+=['scripts/check_raw_gray_stage.py']
    (run/'summary.json').write_text(json.dumps(dict(passed=True,vectors=len(vectors),valid_colors=len(colors),source_sha256={f:hashlib.sha256((root/f).read_bytes()).hexdigest() for f in files}),indent=2)+'\n')
    print(f'PASS: RAW/GRAY stage {len(vectors)} vectors. Reports: {run}',flush=True)
if __name__=='__main__':main()
