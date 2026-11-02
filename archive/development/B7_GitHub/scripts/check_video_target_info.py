"""B1b decimal engine and full-raster dynamic text, compared with Python strings."""
import argparse,hashlib,json,random,shutil,sys
from datetime import datetime
from pathlib import Path
import numpy as np
from PIL import Image
from b1_tools import simulate,command
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'model'))
from target_osd_reference import packet,qualify,logo_array
from target_text_reference import lines,render_text,load_font
from check_video_target_osd import scenarios as base_scenarios

def scenarios():
    script,records=base_scenarios()
    maximum=packet(frame=0xFEDCBA98,cfg=0xFACE,color=2,cx=1279,cy=719,xmin=1200,ymin=680,xmax=1279,ymax=719,
        area=1048575,slots=255,components=4095)
    tests=[('maximum_fields',maximum,0xFEDCBA98,0xFACE,2),
           ('green_target',packet(frame=0xffffffff,cfg=65535,color=1),0xffffffff,65535,1),
           ('wrapped_ids',packet(frame=0,cfg=0,cx=0,cy=0,xmin=0,ymin=0,xmax=15,ymax=15,area=1,slots=0,components=0),0,0,0)]
    for reason in (2,3,5,6,7):
        tests.append((f'reject_{reason}',packet(frame=20+reason,valid=0,area=0,reason=reason,slots=128,components=0),20+reason,1,0))
    for name,data,fid,cfg,color in tests:
        i=len(records)+1;ready,p=qualify(data,True,1,fid,cfg,color)
        script+=f"publish(160'h{data:040x});completed_ready=1;completed_refresh_id=32'h{fid:08x};expected_cfg_id=16'h{cfg:04x};expected_target_id={color};\n"
        script+=f"frame({i},160'h{p:040x},{ready},0,0,160'd0,160'd0);\n"
        records.append(dict(name=name,packet=f'{p:040x}',ready=ready))
    script=script.replace('FULL_FRAMES=9;',f'FULL_FRAMES={len(records)};')
    return script,records

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--modelsim',type=Path,required=True)
    a=p.parse_args();run=ROOT/'build/target_info'/datetime.now().strftime('run_%Y%m%d_%H%M%S')
    run.mkdir(parents=True);print(f'Reports: {run}',flush=True)
    summary=dict(passed=False,profile='h4e-refresh-v1',dimensions=[1280,720],raster=[1650,750],
        latency_registers=4,board_tested=False,seed=0xB1B,source_sha256={})
    try:
        summary['tool_version']=command([a.modelsim/'vsim.exe','-version'],run,run/'version.log').strip()
        names=(ROOT/'b1b_sources.f').read_text().splitlines()+['sim/tb_video_target_info.v','sim/tb_osd_decimal_fields.v']
        for n in names:
            src=ROOT/n;shutil.copy2(src,run/src.name)
            summary['source_sha256'][n]=hashlib.sha256(src.read_bytes()).hexdigest()
        for n in ['scripts/check_video_target_info.py','scripts/b1_tools.py','model/target_text_reference.py','model/target_osd_reference.py','scripts/check_video_target_osd.py','assets/osd/target_font_5x7.json','scripts/build_target_font.py']:
            summary['source_sha256'][n]=hashlib.sha256((ROOT/n).read_bytes()).hexdigest()
        rng=random.Random(0xB1B)
        vectors=[(0,0,0,0,0),(2047,2047,1048575,255,4095),(149,249,10000,7,3)]
        for v in (9,10,99,100,999,1000,9999,10000,99999,100000,999999):
            vectors.append((min(v,2047),min(v,2047),v,min(v,255),min(v,4095)))
        vectors.extend((rng.randrange(2048),rng.randrange(2048),rng.randrange(1048576),rng.randrange(256),rng.randrange(4096)) for _ in range(200))
        (run/'decimal.txt').write_text(''.join(f'{x} {y} {a} {s} {c} {x:04d}{y:04d}{a:07d}{s:03d}{c:04d}\n' for x,y,a,s,c in vectors))
        simulate(a.modelsim,run,['osd_decimal_fields.v','tb_osd_decimal_fields.v'],'tb_osd_decimal_fields','PASS DECIMAL:',timeout=120)
        shutil.copy2(run/'simulation.log',run/'decimal.log');summary['decimal_cases']=len(vectors)
        print(f'PASS: shared decimal conversion ({len(vectors)} cases)',flush=True)
        script,records=scenarios();(run/'scenario.vh').write_text(script)
        sources=[Path(n).name for n in names if not n.endswith('tb_osd_decimal_fields.v')]
        simulate(a.modelsim,run,sources,'tb_video_target_info','PASS B1B:',timeout=1800)
        logo=logo_array(ROOT.parent/'boards/hx1p35a/h4e/assets/logo_reference.hex')
        font=load_font(ROOT/'assets/osd/target_font_5x7.json')
        actual=np.fromfile(run/'actual.rgb',dtype=np.uint8)
        assert actual.size==len(records)*720*1280*3,actual.size
        actual=actual.reshape(len(records),720,1280,3)
        summary['cases']=[]
        for i,c in enumerate(records):
            p=int(c['packet'],16);ref=render_text(p,c['ready'],i+1,logo,font)
            diff=np.any(actual[i]!=ref,axis=2);count=int(diff.sum())
            entry=dict(name=c['name'],pixel_differences=count,text=lines(p,c['ready'],i+1))
            summary['cases'].append(entry)
            for suffix,im in [('actual',actual[i]),('reference',ref),('diff',np.repeat((diff*255).astype(np.uint8)[:,:,None],3,axis=2))]:
                Image.fromarray(im).save(run/f'{i+1:02d}_{c["name"]}_{suffix}.png')
            if count:raise RuntimeError(f'Pixel mismatch: {entry}')
            print(f'PASS: {c["name"]} (921600 pixels, differences=0)',flush=True)
        (run/'cases.json').write_text(json.dumps(records,indent=2)+'\n')
        neg=run/'negative';neg.mkdir()
        for src in sources:shutil.copy2(run/src,neg/src)
        wrong=int(records[0]['packet'],16)^1
        (neg/'scenario.vh').write_text(f"idle();rst_n=0;idle();rst_n=1;FULL_FRAMES=1;completed_ready=1;completed_refresh_id=0;frame(1,160'h{wrong:040x},0,0,0,0,0);\n")
        try:simulate(a.modelsim,neg,sources,'tb_video_target_info','PASS B1B:',timeout=120)
        except RuntimeError:
            if 'Text metadata mismatch' not in (neg/'simulation.log').read_text():raise
        else:raise RuntimeError('Corrupt packet self-test unexpectedly passed')
        summary.update(passed=True,full_frames=len(records),pixels=len(records)*921600,pixel_differences=0,
                       negative_test_detected=True,exit_code=0)
        print('PASS: B1b target text checks completed.',flush=True)
    finally:(run/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
if __name__=='__main__':main()
