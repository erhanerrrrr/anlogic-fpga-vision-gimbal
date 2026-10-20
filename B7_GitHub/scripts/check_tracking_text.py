"""A tracking-state OSD: RTL frames vs independent string/font reference."""
import argparse,hashlib,json,shutil
from pathlib import Path
from datetime import datetime
import numpy as np
from PIL import Image
from b1_tools import simulate

ROOT=Path(__file__).resolve().parents[1]
def packet(valid=1,state=0,pan_limit=0,tilt_limit=0,pan_us=1500,tilt_us=1500):
    return (valid<<37)|(state<<34)|(pan_limit<<33)|(tilt_limit<<32)|(pan_us<<16)|tilt_us
def cases():
    return [dict(name='unknown',packet=packet(valid=0,state=2,pan_us=65535,tilt_us=65535)),
        dict(name='off',packet=packet(state=0)),dict(name='reacquire',packet=packet(state=1)),
        dict(name='follow',packet=packet(state=2,pan_us=1200,tilt_us=1800)),
        dict(name='lost_hold',packet=packet(state=3,pan_limit=1,pan_us=500)),
        dict(name='timeout_hold',packet=packet(state=4,tilt_limit=1,tilt_us=2500)),
        dict(name='fault',packet=packet(state=5,pan_limit=1,tilt_limit=1,pan_us=0,tilt_us=65535)),
        dict(name='reserved6',packet=packet(state=6)),dict(name='reserved7',packet=packet(state=7)),
        dict(name='zero_commands',packet=packet(state=2,pan_us=0,tilt_us=0)),
        dict(name='max_commands',packet=packet(state=2,pan_us=65535,tilt_us=65535))]
def lines(value):
    valid=(value>>37)&1;state=(value>>34)&7;pl=(value>>33)&1;tl=(value>>32)&1;pan=(value>>16)&65535;tilt=value&65535
    name=['OFF','REACQUIRE','FOLLOW','LOST HOLD','TIMEOUT HLD','FAULT','RESERVED','RESERVED'][state] if valid else 'UNKNOWN'
    # Put dynamic fields at their documented column positions.
    chars=list('TRACK:            PAN LIM:  TILT LIM:  ')
    for i,c in enumerate(f'{name:<11}'):chars[7+i]=c
    for pos,lim in [(26,pl),(37,tl)]:
        chars[pos]='Y' if lim else 'N' if valid else 'N'
        if not valid:chars[pos+1]='A'
    first=''.join(chars).rstrip()
    chars=list('PAN CMD US HEX:       TILT CMD US HEX:    ')
    for pos,cmd in [(16,pan),(38,tilt)]:
        for i,c in enumerate(f'{cmd:04X}' if valid else 'NA  '):chars[pos+i]=c
    second=''.join(chars).rstrip()
    ink=(255,128,0) if not valid else (255,64,64) if state==5 else (0,255,0) if state==2 else (255,255,0) if state in (3,4) else (255,255,255)
    return [first,second],ink
def render(value,w,h,font):
    image=np.full((h,w,3),[32,48,64],np.uint8)
    strings,ink=lines(value)
    for index,(y,text) in enumerate(zip((160,184),strings)):
        image[y:y+16,16:976]=32
        for col,ch in enumerate(text):
            for gy,row in enumerate(font.get(ch,['00000']*7)):
                for gx,on in enumerate(row):
                    if on=='1':image[y+1+gy*2:y+3+gy*2,16+col*16+3+gx*2:16+col*16+5+gx*2]=ink if index==0 else (255,255,255)
    return image
def main():
    p=argparse.ArgumentParser();p.add_argument('--modelsim',type=Path,required=True);a=p.parse_args()
    run=ROOT/'build/tracking_text'/datetime.now().strftime('run_%Y%m%d_%H%M%S');run.mkdir(parents=True)
    print(f'Reports: {run}',flush=True)
    files=(ROOT/'b3e_sources.f').read_text().splitlines()+['sim/tb_tracking_text.v']
    logo_file=ROOT.parent/'boards/hx1p35a/h4e/assets/logo_reference.hex'
    logo=np.array([int(v,16) for v in logo_file.read_text().split()],np.uint32).reshape(160,160)
    summary=dict(passed=False,board_tested=False,source_sha256={n:hashlib.sha256((ROOT/n).read_bytes()).hexdigest() for n in files},
        logo_sha256=hashlib.sha256(logo_file.read_bytes()).hexdigest(),cases=[])
    font=json.loads((ROOT/'assets/osd/target_font_5x7.json').read_text())
    try:
        for name,w,h,plans in [('panels',976,208,cases()),('native_720p',1280,720,[cases()[3]])]:
            dest=run/name;dest.mkdir()
            for f in files:shutil.copy2(ROOT/f,dest/Path(f).name)
            (dest/'tracking_scenarios.vh').write_text('\n'.join(f"frame(38'h{c['packet']:010x},38'h{cases()[(i+4)%11]['packet']:010x});" for i,c in enumerate(plans)))
            simulate(a.modelsim,dest,[Path(f).name for f in files],'tb_tracking_text','PASS TRACKING_TEXT:',[f'-gWIDTH={w}',f'-gHEIGHT={h}'])
            actual=np.fromfile(dest/'actual.rgb',np.uint8).reshape(len(plans),h,w,3)
            final=np.fromfile(dest/'with_logo.rgb',np.uint8).reshape(len(plans),h,w,3)
            strips=[]
            for i,c in enumerate(plans):
                ref=render(c['packet'],w,h,font);diff=np.any(actual[i]!=ref,axis=2)
                stem=f'{i:02d}_{c["name"]}'
                Image.fromarray(actual[i]).save(dest/f'{stem}_actual.png')
                Image.fromarray(ref).save(dest/f'{stem}_reference.png')
                Image.fromarray((diff*255).astype(np.uint8)).save(dest/f'{stem}_diff.png')
                assert not diff.any(),(name,c['name'],int(diff.sum()))
                final_ref=ref.copy()
                if w==1280:
                    patch=final_ref[16:176,1104:1264];opaque=(logo>>24)!=0
                    patch[opaque]=np.stack(((logo>>16)&255,(logo>>8)&255,logo&255),axis=-1).astype(np.uint8)[opaque]
                assert np.array_equal(final[i],final_ref),(name,c['name'],'Logo')
                Image.fromarray(final[i]).save(dest/f'{stem}_with_logo.png')
                summary['cases'].append(dict(group=name,name=c['name'],packet=f'{c["packet"]:010x}',dimensions=[w,h],pixel_differences=0,logo_differences=0))
                strips.append(actual[i][156:204])
            Image.fromarray(np.concatenate(strips,axis=0)).save(dest/'tracking_panels.png')
            print(f'PASS: {name}, {len(plans)} frames, zero pixel differences',flush=True)
        summary['passed']=True
    finally:(run/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
if __name__=='__main__':main()
