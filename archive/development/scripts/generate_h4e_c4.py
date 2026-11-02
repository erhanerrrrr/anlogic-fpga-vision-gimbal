"""Reproducible small RGB888 files, annotations independent of detector output."""
import argparse,hashlib,json,random,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'model'))
from h4e_c4_reference import ENTRY,digest
SEED=20261010

def generate(root):
    root=Path(root);root.mkdir(parents=True,exist_ok=True);paths=[]
    for group,w,h in [('scenes',64,48),('capacity',512,32),('deadline',64,48)]:
        dest=root/group;dest.mkdir(exist_ok=True)
        manifest=dict(schema='h4e-rgb-replay-v1',source_kind='synthetic',seed=SEED,width=w,height=h,entry=ENTRY,identity_profile='capture-v1',
                      bit_sha256=None,exposure='synthetic byte values; no camera exposure',lighting='synthetic; no physical light measurement',frames=[])
        rng=random.Random(SEED);index=0
        def new():return bytearray(w*h*3),bytearray(w*h)
        def rect(rgb,label,box,color,annotated=True):
            for y in range(box[1],box[3]+1):
                for x in range(box[0],box[2]+1):
                    j=y*w+x;rgb[j*3:j*3+3]=bytes(color)
                    if annotated:label[j]=1
        def save(name,rgb,label,box,target=0,hblank=176,structural=None,repeat=False):
            nonlocal index
            rgb_path=dest/(name+'.rgb');mask_path=dest/(name+'.mask');rgb_path.write_bytes(rgb);mask_path.write_bytes(label)
            previous=manifest['frames'][-1] if manifest['frames'] else None
            cfg=previous['cfg_id'] if previous and previous['target_id']==target else (previous['cfg_id']+1 if previous else 1)
            frame=dict(name=name,rgb_file=rgb_path.name,rgb_sha256=digest(rgb_path),frame_id=previous['frame_id'] if repeat else index+100,epoch=7,cfg_id=cfg,target_id=target,thresholds=[24,16,16],hblank_cycles=hblank,
                annotation=dict(origin='synthetic_geometry',target_present=bool(any(label)),primary_bbox=box,mask_file=mask_path.name,mask_sha256=digest(mask_path)))
            if structural:frame['expected_structural_reason']=structural
            manifest['frames'].append(frame);index+=1
        if group=='scenes':
            rgb,gt=new();save('empty',rgb,gt,None)
            for name,color,target in [('red',(220,30,10),0),('green',(20,200,40),1),('blue',(15,25,210),2)]:
                rgb,gt=new();box=[10,10,33,33];rect(rgb,gt,box,color);save(name,rgb,gt,box,target)
            rgb,gt=new()
            for y in range(8,32):rect(rgb,gt,[8+(y-8)//2,y,27+(y-8)//2,y],(180,30,20))
            save('tilted',rgb,gt,[8,8,38,31])
            rgb,gt=new();box=[10,10,33,33];rect(rgb,gt,box,(200,30,20));rect(rgb,gt,[16,10,33,33],(255,255,255),False);save('glare',rgb,gt,box)
            for name,color in [('dark',(20,8,8)),('bright_before_change',(50,10,10)),('dark_after_change',(20,8,8))]:
                rgb,gt=new();box=[10,10,33,33];rect(rgb,gt,box,color);save(name,rgb,gt,box)
            rgb,gt=new();box=[0,0,21,21];rect(rgb,gt,box,(220,30,10));save('edge',rgb,gt,box)
            rgb,gt=new();box=[2,8,25,27];rect(rgb,gt,box,(220,30,10));rect(rgb,gt,[42,10,57,25],(220,30,10));save('same_color_largest',rgb,gt,box)
            rgb,gt=new();box=[2,10,21,29];rect(rgb,gt,box,(220,30,10));rect(rgb,gt,[42,10,61,29],(220,30,10));save('same_color_tie',rgb,gt,box)
            rgb,gt=new();box=[6,10,25,29];rect(rgb,gt,box,(220,30,10));rect(rgb,gt,[26,10,45,29],(220,30,10));save('touching_cards',rgb,gt,box)
            rgb,gt=new();box=[20,8,43,35];rect(rgb,gt,box,(220,30,10));rect(rgb,gt,[29,8,34,35],(0,0,0),False);save('occluded',rgb,gt,box)
            rgb,gt=new()
            for j in range(w*h):
                if rng.random()<0.03:rgb[j*3:j*3+3]=bytes((200,20,10))
            save('background_noise',rgb,gt,None)
            rgb,gt=new();box=[36,10,55,29];rect(rgb,gt,box,(20,200,40));rect(rgb,gt,[6,10,25,29],(220,30,10),False);save('selected_green_red_distractor',rgb,gt,box,1)
            save('stopped_source_repeat',rgb,gt,box,1,repeat=True)
        else:
            rgb,gt=new();runs=65 if group=='capacity' else 8;bottom=h-7
            for i in range(runs):rect(rgb,gt,[4+i*7,6,6+i*7,bottom],(220,30,10))
            save(group+'_stress',rgb,gt,[4,6,6,bottom],hblank=4096 if group=='capacity' else 0,structural=3 if group=='capacity' else 5)
            rgb,gt=new();box=[10,6,41,h-7];rect(rgb,gt,box,(220,30,10));save('recovery',rgb,gt,box,hblank=4096)
        path=dest/'manifest.json';path.write_text(json.dumps(manifest,indent=2)+'\n');paths.append(path)
    return paths
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,default=ROOT/'reports/h4e-c4/generated/datasets');args=p.parse_args()
    for path in generate(args.output):print(path)
