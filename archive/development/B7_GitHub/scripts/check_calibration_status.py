"""C control observer, frame snapshots and independent uniform-font pixel oracle."""
import argparse,hashlib,json,shutil
from pathlib import Path
from datetime import datetime
import numpy as np
from PIL import Image
from b1_tools import simulate

ROOT=Path(__file__).resolve().parents[1]
def pack(phase=0,result=0,reason=0,cfg=1,color=0,main=24,d1=16,d2=16,known=1):
    return (known<<50)|(phase<<47)|(result<<45)|(reason<<42)|(cfg<<26)|(color<<24)|(main<<16)|(d1<<8)|d2

def vectors():
    rows=[]
    def add(expected,events=(),active=(1,0,24,16,16),reason=0,rst=1,known=1):
        value=(rst<<53)|(known<<52)
        for event in events:value|=1<<dict(req=51,sample=50,done=49,ok=48,apply=47,pending=46,busy=45)[event]
        cfg,color,main,d1,d2=active
        value|=(reason<<42)|(cfg<<26)|(color<<24)|(main<<16)|(d1<<8)|d2
        rows.append(f'{value:014x} {expected:013x}')
    unknown=pack(known=0,phase=6,cfg=0,main=0,d1=0,d2=0)
    add(unknown,rst=0);add(pack());add(pack(phase=1),['req']);add(pack(phase=1),['busy'])
    add(pack(phase=2),['sample','busy']);add(pack(phase=2),['busy'])
    add(pack(phase=3,result=1),['done','ok','pending','busy']);add(pack(phase=3,result=1),['pending','busy'])
    new=(2,2,192,128,112)
    add(pack(phase=4,result=1,cfg=2,color=2,main=192,d1=128,d2=112),['apply'],new)
    add(pack(phase=4,result=1,cfg=2,color=2,main=192,d1=128,d2=112),active=new)
    for reason in range(8):
        add(pack(phase=1),['req']);add(pack(phase=2),['sample'])
        add(pack(phase=5,result=2,reason=reason),['done'],reason=reason)
        add(pack(phase=5,result=2,reason=reason))
    add(unknown,known=0);add(pack())
    add(pack(phase=3),['pending','busy']);add(pack(phase=4),['apply'])
    add(pack(phase=3,result=1),['sample','done','ok','pending','busy'])
    add(pack(phase=4,result=1),['done','ok','apply'])
    add(pack(phase=1),['req']);add(unknown,rst=0);add(pack())
    add(pack(cfg=65535,color=3,main=255,d1=255,d2=255),active=(65535,3,255,255,255))
    add(pack(phase=4,cfg=0,main=0,d1=0,d2=0),['apply'],(0,0,0,0,0))
    return rows

def cases():
    return [dict(name='unknown',packet=pack(known=0,phase=6,cfg=0,main=0,d1=0,d2=0)),
        dict(name='idle_h4e_values',packet=pack()),dict(name='wait_sample',packet=pack(phase=1)),
        dict(name='sample_done_calculating',packet=pack(phase=2)),dict(name='computed_pending_old_cfg',packet=pack(phase=3,result=1)),
        dict(name='applied_new_cfg',packet=pack(phase=4,result=1,cfg=2,color=2,main=192,d1=128,d2=112)),
        dict(name='failed_keeps_cfg',packet=pack(phase=5,result=2,reason=5,cfg=2,color=2,main=192,d1=128,d2=112)),
        dict(name='manual_pending',packet=pack(phase=3)),dict(name='max_fields',packet=pack(phase=5,result=2,reason=7,cfg=65535,color=3,main=255,d1=255,d2=255)),
        dict(name='zero_fields',packet=pack(phase=4,cfg=0,main=0,d1=0,d2=0))]

def lines(value):
    known=value>>50;phase=(value>>47)&7;result=(value>>45)&3;reason=(value>>42)&7
    cfg=(value>>26)&65535;color=(value>>24)&3;main=(value>>16)&255;d1=(value>>8)&255;d2=value&255
    state=['IDLE','WAIT SAMPLE','CALC','PENDING','APPLIED','FAILED','UNKNOWN','UNKNOWN'][phase] if known else 'UNKNOWN'
    outcome=['NONE','OK','FAIL','NONE'][result] if known else '    '
    first=f"CAL:{state:<11} RESULT:{outcome:<4} WHY:{reason if known else ' '}"
    cfg_s=f'{cfg:04X}' if known else 'NA  '
    second=f"CTRL HEX CFG:{cfg_s} COLOR:{'RGBN'[color] if known else 'N'} MAIN:{main:02X} D1:{d1:02X} D2:{d2:02X}"
    if not known:second=f'CTRL HEX CFG:{cfg_s} COLOR:N MAIN:NA D1:NA D2:NA'
    ink=(255,128,0) if not known else (255,64,64) if phase==5 else (0,255,0) if phase==4 else (255,255,255)
    return [first,second],ink

def render(value,w,h,font):
    image=np.full((h,w,3),[32,48,64],np.uint8)
    strings,ink=lines(value)
    for index,(y,text) in enumerate(zip((112,136),strings)):
        image[y:y+16,16:976]=32
        for col,ch in enumerate(text):
            for gy,row in enumerate(font.get(ch,['00000']*7)):
                for gx,on in enumerate(row):
                    if on=='1':image[y+1+gy*2:y+3+gy*2,16+col*16+3+gx*2:16+col*16+5+gx*2]=ink if index==0 else (255,255,255)
    return image

def main():
    p=argparse.ArgumentParser();p.add_argument('--modelsim',type=Path,required=True);a=p.parse_args()
    run=ROOT/'build/calibration_status'/datetime.now().strftime('run_%Y%m%d_%H%M%S');run.mkdir(parents=True)
    print(f'Reports: {run}',flush=True)
    sources=(ROOT/'b3d_sources.f').read_text().splitlines()
    display_sources=(ROOT/'b3d_display_sources.f').read_text().splitlines()
    extras=['sim/tb_calibration_status_view.v','sim/tb_calibration_text.v','sim/tb_calibration_c_control.v','../rtl/recognition/calibration_control.v']
    summary=dict(passed=False,board_tested=False,source_sha256={n:hashlib.sha256((ROOT/n).read_bytes()).hexdigest() for n in display_sources+extras},cases=[])
    def prepare(name,files):
        dest=run/name;dest.mkdir()
        for f in files:shutil.copy2(ROOT/f,dest/Path(f).name)
        return dest,[Path(f).name for f in files]
    try:
        dest,fs=prepare('observer',[sources[0],extras[0]])
        rows=vectors();(dest/'status_vectors.txt').write_text('\n'.join(rows)+'\n')
        simulate(a.modelsim,dest,fs,'tb_calibration_status_view','PASS CALIBRATION_STATUS:')
        summary['observer_vectors']=len(rows);print(f'PASS: {len(rows)} observer vectors',flush=True)
        dest,fs=prepare('real_c_control',sources+[extras[2],extras[3]])
        simulate(a.modelsim,dest,fs,'tb_calibration_c_control','PASS C_CONTROL_STATUS:')
        summary['real_c_control_passed']=True;print('PASS: real C control + observer + display snapshot',flush=True)
        font=json.loads((ROOT/'assets/osd/target_font_5x7.json').read_text())
        logo_file=ROOT.parent/'boards/hx1p35a/h4e/assets/logo_reference.hex'
        logo=np.array([int(v,16) for v in logo_file.read_text().split()],np.uint32).reshape(160,160)
        summary['reference_logo_sha256']=hashlib.sha256(logo_file.read_bytes()).hexdigest()
        for name,w,h,plans in [('panels',976,160,cases()),('native_720p',1280,720,[cases()[5]])]:
            dest,fs=prepare(name,display_sources+[extras[1]])
            (dest/'text_scenarios.vh').write_text('\n'.join(f"frame(51'h{c['packet']:013x},51'h{cases()[(i+3)%10]['packet']:013x});" for i,c in enumerate(plans)))
            simulate(a.modelsim,dest,fs,'tb_calibration_text','PASS CALIBRATION_TEXT:',[f'-gWIDTH={w}',f'-gHEIGHT={h}'])
            actual=np.fromfile(dest/'actual.rgb',np.uint8).reshape(len(plans),h,w,3)
            final=np.fromfile(dest/'with_logo.rgb',np.uint8).reshape(len(plans),h,w,3)
            strips=[]
            for i,c in enumerate(plans):
                ref=render(c['packet'],w,h,font);diff=np.any(actual[i]!=ref,axis=2)
                stem=f'{i:02d}_{c["name"]}'
                Image.fromarray(actual[i]).save(dest/f'{stem}_actual.png');Image.fromarray(ref).save(dest/f'{stem}_reference.png')
                Image.fromarray((diff*255).astype(np.uint8)).save(dest/f'{stem}_diff.png')
                assert not diff.any(),(name,c['name'],int(diff.sum()))
                final_ref=ref.copy()
                if w==1280:
                    patch=final_ref[16:176,1104:1264];opaque=(logo>>24)!=0
                    patch[opaque]=np.stack(((logo>>16)&255,(logo>>8)&255,logo&255),axis=-1).astype(np.uint8)[opaque]
                assert np.array_equal(final[i],final_ref),(name,c['name'],'Logo composition')
                Image.fromarray(final[i]).save(dest/f'{stem}_with_logo.png')
                summary['cases'].append(dict(group=name,name=c['name'],packet=f'{c["packet"]:013x}',dimensions=[w,h],pixel_differences=0,logo_composition_differences=0))
                strips.append(actual[i][108:156])
            Image.fromarray(np.concatenate(strips,axis=0)).save(dest/'status_panels.png')
            print(f'PASS: {name}, {len(plans)} frames, zero pixel differences',flush=True)
        summary['passed']=True
    finally:(run/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
if __name__=='__main__':main()
