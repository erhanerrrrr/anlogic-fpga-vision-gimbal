"""B2b RAW/GRAY real-C full-raster pairing, pixel oracle, metadata assertions and diagnostics."""
import argparse,hashlib,json,re,shutil,sys
from datetime import datetime
from pathlib import Path
import numpy as np
from PIL import Image
from b1_tools import simulate,command
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'model'))
from rgb_mask_reference import reference,packed_tag
from raw_gray_reference import fixtures,gray_reference

def run_case(ms,base,name,w,h,ht,vt,guard):
    run=base/name;run.mkdir();source={}
    files=(ROOT/'b2b_sources.f').read_text().splitlines()+['sim/tb_video_rgb_mask_raw_gray.v']
    for f in files:
        shutil.copy2(ROOT/f,run/Path(f).name);source[f]=hashlib.sha256((ROOT/f).read_bytes()).hexdigest()
    cases=fixtures(w,h);refs=[reference(rgb,t,guard) for rgb,t in cases]
    grays=[gray_reference(rgb) for rgb,_ in cases]
    with (run/'gray.mem').open('w') as fp:
        for gray in grays:
            for row in gray:fp.write(' '.join(f'{int(v):02x}' for v in row)+'\n')
    with (run/'pixels.mem').open('w') as fp:
        for (rgb,_),mask in zip(cases,refs):
            rgb=rgb.astype(np.uint32)
            packed=(((rgb[:,:,0]<<16)|(rgb[:,:,1]<<8)|rgb[:,:,2])<<1)|mask
            for row in packed:fp.write(' '.join(f'{int(v):07x}' for v in row)+'\n')
    (run/'tags.mem').write_text('\n'.join(f'{packed_tag(t):027x}' for _,t in cases)+'\n')
    (run/'cases.json').write_text(json.dumps([t for _,t in cases],indent=2)+'\n')
    output=simulate(ms,run,[Path(f).name for f in files],'tb_video_rgb_mask_raw_gray','PASS RAW_GRAY:',
        [f'-gW={w}',f'-gH={h}',f'-gHT={ht}',f'-gVT={vt}',f'-gN={len(cases)}',f'-gGUARD={guard}'])
    rgb_out=np.fromfile(run/'actual.rgb',np.uint8).reshape(len(cases),h,w,3)
    gray_out=np.fromfile(run/'actual.gray',np.uint8).reshape(len(cases),h,w)
    mask_out=np.fromfile(run/'actual.mask',np.uint8).reshape(len(cases),h,w)
    for i,((rgb,_),mask) in enumerate(zip(cases,refs)):
        diff=np.any(rgb!=rgb_out[i],axis=2)|(mask*255!=mask_out[i])|(grays[i]!=gray_out[i])
        assert not diff.any(),(name,i,int(diff.sum()))
        for label,array in [('rgb_actual',rgb_out[i]),('gray_actual',gray_out[i]),('gray_reference',grays[i]),('mask_actual',mask_out[i]),('mask_reference',mask*255),('diff',diff.astype(np.uint8)*255)]:
            Image.fromarray(array).save(run/f'{i+1:02d}_{label}.png')
    fields=re.search(r'PASS RAW_GRAY: frames=(\d+) pixels=(\d+) peak=(\d+) overlap=(\d+) eof_delay=(\d+)',output)
    assert fields
    result=dict(name=name,passed=True,dimensions=[w,h],raster=[ht,vt],guard_rows=guard,
        frames=int(fields[1]),pixels=int(fields[2]),fifo_peak=int(fields[3]),cross_frame_overlap_pixels=int(fields[4]),
        eof_to_output_cycles=int(fields[5]),pixel_differences=0,source_sha256=source)
    (run/'summary.json').write_text(json.dumps(result,indent=2)+'\n')
    print(f'PASS: {name}: {result["pixels"]} pixels, peak={result["fifo_peak"]}, overlap={result["cross_frame_overlap_pixels"]}',flush=True)
    return result

def main():
    p=argparse.ArgumentParser();p.add_argument('--modelsim',required=True,type=Path)
    p.add_argument('--small-only',action='store_true');a=p.parse_args()
    run=ROOT/'build/raw_gray'/datetime.now().strftime('run_%Y%m%d_%H%M%S')
    run.mkdir(parents=True);print(f'Reports: {run}',flush=True)
    summary=dict(passed=False,board_tested=False,source_ids='synthetic test identities; A must bind real capture buffers',cases=[])
    try:
        summary['tool_version']=command([a.modelsim/'vsim.exe','-version'],run,run/'version.log').strip()
        for params in [('tiny_zero_blank',3,3,3,3,0),('small_zero_blank',16,12,16,12,1),('small_blanking',16,12,23,15,1)]:
            summary['cases'].append(run_case(a.modelsim,run,*params))
        if not a.small_only:summary['cases'].append(run_case(a.modelsim,run,'native_720p',1280,720,1650,750,4))
        # Deliberately corrupt one expected mask bit; require a specific pixel assertion.
        src=run/'small_zero_blank';neg=run/'negative';neg.mkdir()
        for name in ('color_classifier_runtime.v','mask_majority_3x3.v','video_rgb_mask_pair.v','tb_video_rgb_mask_raw_gray.v','pixels.mem','tags.mem','gray.mem','rgb_to_gray_lut.v','video_raw_gray_stage.v','video_rgb_mask_raw_gray.v'):
            shutil.copy2(src/name,neg/name)
        words=(neg/'pixels.mem').read_text().split();words[0]=f'{int(words[0],16)^1:07x}'
        (neg/'pixels.mem').write_text(' '.join(words)+'\n')
        try:simulate(a.modelsim,neg,['color_classifier_runtime.v','mask_majority_3x3.v','video_rgb_mask_pair.v','rgb_to_gray_lut.v','video_raw_gray_stage.v','video_rgb_mask_raw_gray.v','tb_video_rgb_mask_raw_gray.v'],
            'tb_video_rgb_mask_raw_gray','PASS RAW_GRAY:',timeout=120)
        except RuntimeError:
            assert 'Pixel mismatch' in (neg/'simulation.log').read_text()
        else:raise RuntimeError('Negative checker failed to detect corrupt expected pixel')
        summary.update(passed=True,negative_checker_passed=True,source_sha256={f:hashlib.sha256((ROOT/f).read_bytes()).hexdigest()
            for f in ['scripts/check_video_raw_gray.py','model/rgb_mask_reference.py','model/raw_gray_reference.py','b2b_sources.f']})
        print('PASS: B2b RAW/GRAY with real C pairing.',flush=True)
    finally:(run/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
if __name__=='__main__':main()
