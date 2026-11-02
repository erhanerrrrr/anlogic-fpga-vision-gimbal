"""B2c EDGE real-C full-raster pairing, pixel oracle, metadata assertions and diagnostics."""
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
from edge_stream_reference import edge_reference

def run_case(ms,base,name,w,h,ht,vt,guard,threshold=128):
    run=base/name;run.mkdir();source={}
    files=(ROOT/'b2c_sources.f').read_text().splitlines()+['sim/tb_video_rgb_mask_edge.v']
    for f in files:
        shutil.copy2(ROOT/f,run/Path(f).name);source[f]=hashlib.sha256((ROOT/f).read_bytes()).hexdigest()
    cases=fixtures(w,h);refs=[reference(rgb,t,guard) for rgb,t in cases]
    grays=[gray_reference(rgb) for rgb,_ in cases]
    edges=[edge_reference(rgb,threshold) for rgb,_ in cases]
    with (run/'edge.mem').open('w') as fp:
        for edge in edges:
            for row in edge:fp.write(' '.join(f'{int(v):02x}' for v in row)+'\n')
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
    output=simulate(ms,run,[Path(f).name for f in files],'tb_video_rgb_mask_edge','PASS EDGE_STREAM:',
        [f'-gW={w}',f'-gH={h}',f'-gHT={ht}',f'-gVT={vt}',f'-gN={len(cases)}',f'-gGUARD={guard}',f'-gTH={threshold}'])
    rgb_out=np.fromfile(run/'actual.rgb',np.uint8).reshape(len(cases),h,w,3)
    edge_out=np.fromfile(run/'actual.edge',np.uint8).reshape(len(cases),h,w)
    gray_out=np.fromfile(run/'actual.gray',np.uint8).reshape(len(cases),h,w)
    mask_out=np.fromfile(run/'actual.mask',np.uint8).reshape(len(cases),h,w)
    for i,((rgb,_),mask) in enumerate(zip(cases,refs)):
        diff=np.any(rgb!=rgb_out[i],axis=2)|(mask*255!=mask_out[i])|(grays[i]!=gray_out[i])|(edges[i]!=edge_out[i])
        assert not diff.any(),(name,i,int(diff.sum()))
        for label,array in [('rgb_actual',rgb_out[i]),('edge_actual',edge_out[i]),('edge_reference',edges[i]),('gray_actual',gray_out[i]),('gray_reference',grays[i]),('mask_actual',mask_out[i]),('mask_reference',mask*255),('diff',diff.astype(np.uint8)*255)]:
            Image.fromarray(array).save(run/f'{i+1:02d}_{label}.png')
    fields=re.search(r'PASS EDGE_STREAM: frames=(\d+) pixels=(\d+) peak=(\d+) overlap=(\d+) eof_delay=(\d+)',output)
    assert fields
    result=dict(name=name,passed=True,dimensions=[w,h],raster=[ht,vt],guard_rows=guard,threshold=threshold,
        frames=int(fields[1]),pixels=int(fields[2]),fifo_peak=int(fields[3]),cross_frame_overlap_pixels=int(fields[4]),
        eof_to_output_cycles=int(fields[5]),pixel_differences=0,source_sha256=source)
    (run/'summary.json').write_text(json.dumps(result,indent=2)+'\n')
    print(f'PASS: {name}: {result["pixels"]} pixels, peak={result["fifo_peak"]}, overlap={result["cross_frame_overlap_pixels"]}',flush=True)
    return result

def main():
    p=argparse.ArgumentParser();p.add_argument('--modelsim',required=True,type=Path)
    p.add_argument('--small-only',action='store_true');a=p.parse_args()
    run=ROOT/'build/edge_stream'/datetime.now().strftime('run_%Y%m%d_%H%M%S')
    run.mkdir(parents=True);print(f'Reports: {run}',flush=True)
    summary=dict(passed=False,board_tested=False,source_ids='synthetic test identities; A must bind real capture buffers',cases=[])
    try:
        summary['tool_version']=command([a.modelsim/'vsim.exe','-version'],run,run/'version.log').strip()
        for params in [('tiny_zero_blank',3,3,3,3,0),('small_zero_blank',16,12,16,12,1),('small_blanking',16,12,23,15,1),('threshold_zero',16,12,16,12,1,0),('threshold_max',16,12,16,12,1,2047)]:
            summary['cases'].append(run_case(a.modelsim,run,*params))
        if not a.small_only:summary['cases'].append(run_case(a.modelsim,run,'native_720p',1280,720,1650,750,4))
        # Flip an expected EDGE pixel; confirm the edge-specific assertion fires.
        src=run/'small_zero_blank';neg=run/'negative';neg.mkdir()
        sources=[Path(f).name for f in (ROOT/'b2c_sources.f').read_text().splitlines()]+['tb_video_rgb_mask_edge.v']
        for name in sources+['pixels.mem','tags.mem','gray.mem','edge.mem']:shutil.copy2(src/name,neg/name)
        words=(neg/'edge.mem').read_text().split();words[0]='ff'
        (neg/'edge.mem').write_text(' '.join(words)+'\n')
        try:simulate(a.modelsim,neg,sources,'tb_video_rgb_mask_edge','PASS EDGE_STREAM:',timeout=120)
        except RuntimeError:assert 'EDGE pixel mismatch' in (neg/'simulation.log').read_text()
        else:raise RuntimeError('Negative checker failed to detect corrupt expected EDGE')
        summary.update(passed=True,negative_checker_passed=True,source_sha256={f:hashlib.sha256((ROOT/f).read_bytes()).hexdigest()
            for f in ['scripts/check_video_edge_stream.py','model/rgb_mask_reference.py','model/raw_gray_reference.py','model/edge_stream_reference.py','b2c_sources.f']})
        print('PASS: B2c EDGE with real C pairing.',flush=True)
    finally:(run/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
if __name__=='__main__':main()
