"""Native-size RTL ROI images and independent inclusive-rectangle reference."""
import argparse,hashlib,json,re,shutil
from pathlib import Path
from datetime import datetime
import numpy as np
from PIL import Image
from b1_tools import simulate

def main():
    p=argparse.ArgumentParser();p.add_argument('--modelsim',type=Path,required=True);a=p.parse_args()
    root=Path(__file__).resolve().parents[1]
    run=root/'build/calibration_roi'/datetime.now().strftime('run_%Y%m%d_%H%M%S');run.mkdir(parents=True)
    print(f'Reports: {run}',flush=True)
    files=(root/'b3c_sources.f').read_text().splitlines()+['sim/tb_calibration_roi.v']
    logo_file=root.parent/'boards/hx1p35a/h4e/assets/logo_reference.hex'
    logo=np.array([int(s,16) for s in logo_file.read_text().split()],np.uint32).reshape(160,160)
    result=dict(passed=False,board_tested=False,source_sha256={f:hashlib.sha256((root/f).read_bytes()).hexdigest() for f in files},
                reference_logo_sha256=hashlib.sha256(logo_file.read_bytes()).hexdigest(),cases=[])
    try:
        for name,w,h,lx,ly in [('native_720p',1280,720,1104,16),('logo_overlap',160,160,0,0),
                              ('minimum_16',16,16,1024,16),('odd_dimensions',17,19,1024,16)]:
            dest=run/name;dest.mkdir()
            for f in files:shutil.copy2(root/f,dest/Path(f).name)
            shutil.copy2(logo_file,dest/'logo_reference.hex')
            output=simulate(a.modelsim,dest,[Path(f).name for f in files],'tb_calibration_roi','PASS CALIBRATION_ROI:',
                [f'-gWIDTH={w}',f'-gHEIGHT={h}',f'-gLOGO_X={lx}',f'-gLOGO_Y={ly}'])
            actual=np.fromfile(dest/'actual.rgb',np.uint8).reshape(h,w,3)
            yy,xx=np.indices((h,w));ref=np.stack((xx%256,yy%256,np.full((h,w),64)),axis=-1).astype(np.uint8)
            left,top=(w-16)//2,(h-16)//2
            mask=np.zeros((h,w),bool)
            mask[top,left:left+16]=True;mask[top+15,left:left+16]=True
            mask[top:top+16,left]=True;mask[top:top+16,left+15]=True
            assert int(mask.sum())==60
            ref[mask]=[255,255,0]
            opacity=np.zeros((h,w),bool)
            for y in range(160):
                for x in range(160):
                    if lx+x<w and ly+y<h and int(logo[y,x]) & (1<<24):
                        value=int(logo[y,x]);ref[ly+y,lx+x]=[(value>>16)&255,(value>>8)&255,value&255]
                        opacity[ly+y,lx+x]=True
            diff=np.any(actual!=ref,axis=2)
            Image.fromarray(actual).save(dest/'actual.png');Image.fromarray(ref).save(dest/'reference.png')
            Image.fromarray((diff*255).astype(np.uint8)).save(dest/'diff.png')
            crop=actual[max(0,top-8):min(h,top+24),max(0,left-8):min(w,left+24)]
            Image.fromarray(crop).resize((crop.shape[1]*12,crop.shape[0]*12),Image.Resampling.NEAREST).save(dest/'roi_zoom.png')
            overlap=int((mask & opacity).sum())
            assert not diff.any(),f'{name}: {diff.sum()} differences'
            if name=='logo_overlap':assert overlap>0
            result['cases'].append(dict(name=name,dimensions=[w,h],roi=[left,top,left+15,top+15],border_pixels=60,
                logo_overlap_pixels=overlap,pixel_differences=int(diff.sum()),
                checks=int(re.search(r'checks=(\d+)',output)[1]),passed=True))
            print(f'PASS: {name}, {w*h} pixels, zero differences, logo overlap={overlap}',flush=True)
        result['passed']=True
    finally:(run/'summary.json').write_text(json.dumps(result,indent=2)+'\n')
if __name__=='__main__':main()
