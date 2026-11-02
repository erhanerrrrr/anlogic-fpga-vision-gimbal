"""B1a: H4E profile, directed event tests and complete 720p RTL image comparison."""
import argparse,hashlib,json,random,shutil,sys
from datetime import datetime
from pathlib import Path
import numpy as np
from PIL import Image
from b1_tools import simulate,command
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'model'))
from target_osd_reference import History,packet,pack,unpack,qualify,logo_array,pixel,render

def directed(logo):
    h=History();rows=[]
    state=dict(r=1,abort=0,v=1,s=0,l=0,e=0,x=149,y=249,rgb=0x203040,id=1,
        cr=1,cid=1,cfg=1,tid=0,st=0,data=0)
    def add(**kw):
        z=state.copy();z.update(kw)
        opened,(ready,p)=h.step(z['r'],z['abort'],z['v'],z['s'],z['st'],z['data'],z['cr'],z['cid'],z['cfg'],z['tid'])
        valid=int(opened and z['v'] and z['x']<1280 and z['y']<720)
        rgb=pixel(z['rgb'],z['x'],z['y'],p,logo) if valid else 0
        vals=[z[k] for k in state]+[ready,p,valid,rgb]
        rows.append(vals)
    add(r=0);add();add(s=1,x=0,y=0)
    add(st=1,data=packet());add();add(v=0,s=1);add(s=1);add()
    add(s=1,st=1,data=packet(valid=0,area=0,reason=1));add();add(s=1);add()
    add(st=1,data=packet(frame=2));add(s=1);add(s=1,cid=2);add()
    for p in [packet(cfg=2),packet(color=1),packet(color=3),packet(xmax=2047),packet(xmin=200,xmax=199),
              packet(cx=2047),packet(area=0),packet(reason=3),packet(valid=0,reason=5)]:
        add(st=1,data=p);add(s=1);add()
    for x,y in [(0,0),(1279,0),(0,719),(1279,719)]:
        add(st=1,data=packet(xmin=0,ymin=0,xmax=1279,ymax=719,cx=x,cy=y));add(s=1)
        for a,b in [(x,y),(1279-x,719-y),(1280,y),(x,720),(2047,2047)]:add(x=a,y=b)
    add(abort=1,st=1,data=packet());add();add(s=1);add(st=1,data=packet());add(s=1)
    add(r=0);add();add(st=1,data=packet(frame=0xffffffff,cfg=65535));add(s=1,cid=0xffffffff,cfg=65535)
    add(st=1,data=packet(frame=0,cfg=0));add(s=1,cid=0,cfg=0)
    rng=random.Random(0xB1A)
    for i in range(650):
        add(r=int(i%101!=0),abort=int(i%137==4),v=int(rng.random()<.8),s=int(rng.random()<.2),
            st=int(rng.random()<.4),data=packet(frame=rng.randrange(4),cfg=rng.randrange(3),color=rng.randrange(4),
            valid=rng.randrange(2),reason=rng.randrange(6),slots=rng.randrange(256),components=rng.randrange(4096)),
            cid=rng.randrange(4),cfg=rng.randrange(3),tid=rng.randrange(4),cr=int(rng.random()<.8),
            x=rng.choice([0,99,100,149,199,200,1104,1150,1180,1263,1279,1280,2047]),
            y=rng.choice([0,16,80,100,200,249,299,719,720,2047]))
    add(r=0);add(v=0)
    # Columns with hex formatting match the fixed fscanf format in the TB.
    return [' '.join(format(v,'x') if i in (8,11,12,15,17,19) else str(v) for i,v in enumerate(row)) for row in rows]

def scenarios():
    normal=packet(); overlap=packet(frame=2,xmin=1120,ymin=50,xmax=1240,ymax=155,cx=1180,cy=102)
    empty=packet(frame=3,valid=0,area=0,xmin=0,ymin=0,xmax=0,ymax=0,cx=0,cy=0,reason=1)
    edge=packet(frame=4,xmin=0,ymin=0,xmax=1279,ymax=719,cx=0,cy=0,area=921600)
    corner=packet(frame=5,xmin=1240,ymin=680,xmax=1279,ymax=719,cx=1279,cy=719)
    # name, result before SOF, expected completed identity, ready, SOF event, mid-frame event
    plans=[('waiting',None,0,1,None,None),('normal_mid_update',normal,1,1,None,overlap),
        ('logo_overlap',None,2,1,None,empty),('invalid_clear',None,3,1,None,None),
        ('edge_and_sof_event',edge,4,1,corner,None),('next_sof_corner',None,5,1,None,None),
        ('id_mismatch',None,6,1,None,None),('busy_wait',None,5,0,None,None),
        ('recovered',None,5,1,None,None)]
    lines=['idle();rst_n=0;idle();rst_n=1;stream_abort=0;','FULL_FRAMES=%d;'%len(plans)]
    latest=None;records=[]
    for i,(name,before,cid,cr,sof,mid) in enumerate(plans,1):
        if before is not None:latest=before;lines.append(f"publish(160'h{before:040x});")
        ready,p=qualify(latest or 0,latest is not None,cr,cid,1,0)
        lines.append(f"completed_ready={cr};completed_refresh_id=32'd{cid};expected_cfg_id=1;expected_target_id=0;")
        lines.append(f"frame({i},160'h{p:040x},{ready},{int(sof is not None)},{int(mid is not None)},160'h{sof or 0:040x},160'h{mid or 0:040x});")
        records.append(dict(name=name,packet=f'{p:040x}',ready=ready,completed_id=cid,
            before=None if before is None else f'{before:040x}',sof_event=None if sof is None else f'{sof:040x}',
            mid_event=None if mid is None else f'{mid:040x}'))
        if sof is not None:latest=sof
        if mid is not None:latest=mid
    return '\n'.join(lines)+'\n',records

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--modelsim',type=Path,required=True)
    a=p.parse_args();run=ROOT/'build/target_osd'/datetime.now().strftime('run_%Y%m%d_%H%M%S')
    run.mkdir(parents=True);print(f'Reports: {run}',flush=True)
    summary=dict(passed=False,profile='h4e-refresh-v1',dimensions=[1280,720],raster=[1650,750],
        synthesis_passed=False,board_tested=False,seed=0xB1A,source_sha256={})
    try:
        summary['tool_version']=command([a.modelsim/'vsim.exe','-version'],run,run/'version.log').strip()
        names=(ROOT/'b1a_sources.f').read_text().splitlines()+['sim/tb_video_target_osd.v']
        sources=[]
        for n in names:
            src=ROOT/n;shutil.copy2(src,run/src.name);sources.append(src.name)
            summary['source_sha256'][n]=hashlib.sha256(src.read_bytes()).hexdigest()
        logo_path=ROOT.parent/'boards/hx1p35a/h4e/assets/logo_reference.hex'
        logo=logo_array(logo_path)
        summary['reference_logo_sha256']=hashlib.sha256(logo_path.read_bytes()).hexdigest()
        rows=directed(logo);(run/'directed.txt').write_text('\n'.join(rows)+'\n')
        scenario,records=scenarios();(run/'scenario.vh').write_text(scenario)
        (run/'cases.json').write_text(json.dumps(records,indent=2)+'\n')
        simulate(a.modelsim,run,sources,'tb_video_target_osd','PASS B1A:',timeout=1800)
        actual=np.fromfile(run/'actual.rgb',dtype=np.uint8)
        assert actual.size==len(records)*720*1280*3,actual.size
        actual=actual.reshape(len(records),720,1280,3)
        summary['cases']=[]
        for i,c in enumerate(records):
            ref=render(int(c['packet'],16),logo);diff=np.any(actual[i]!=ref,axis=2)
            count=int(diff.sum());entry=dict(name=c['name'],pixel_differences=count)
            summary['cases'].append(entry)
            for suffix,im in [('actual',actual[i]),('reference',ref),('diff',np.repeat((diff*255).astype(np.uint8)[:,:,None],3,axis=2))]:
                Image.fromarray(im).save(run/f'{i+1:02d}_{c["name"]}_{suffix}.png')
            if count:raise RuntimeError(f'Pixel mismatch: {entry}')
            print(f'PASS: {c["name"]} (921600 pixels, differences=0)',flush=True)
        # Prove a bad pixel expectation is caught, with the same compiled DUT/TB.
        neg=run/'negative';neg.mkdir()
        short=rows[:12];cols=short[6].split();cols[19]=format(int(cols[19],16)^1,'x');short[6]=' '.join(cols)
        (neg/'directed.txt').write_text('\n'.join(short)+'\n');(neg/'scenario.vh').write_text('FULL_FRAMES=0;\n')
        for src in sources:shutil.copy2(run/src,neg/src)
        try:simulate(a.modelsim,neg,sources,'tb_video_target_osd','PASS B1A:',timeout=120)
        except RuntimeError:
            if 'Sparse pixel mismatch' not in (neg/'simulation.log').read_text():raise
        else:raise RuntimeError('Negative pixel self-test unexpectedly passed')
        summary.update(passed=True,directed_vectors=len(rows),full_frames=len(records),pixels=len(records)*921600,
                       pixel_differences=0,negative_test_detected=True,exit_code=0)
        print('PASS: B1a target overlay checks completed.',flush=True)
    finally:
        (run/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
if __name__=='__main__':main()
