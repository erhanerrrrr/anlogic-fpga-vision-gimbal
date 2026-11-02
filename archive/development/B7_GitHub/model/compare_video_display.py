"""Compare captured source, styled pixels and final OSD to independent models."""
import argparse
import csv
import json
from pathlib import Path
import re
import numpy as np
from PIL import Image,ImageDraw
from edge_csv_to_img import reference_edge
from compare_static_osd import reference as osd_reference


def read_frame(reader,columns,frame,w,h):
    rgb=np.empty((h,w,3),np.uint8)
    extra=np.empty((h,w),np.uint8)
    for pos in range(w*h):
        row=next(reader,None)
        if row is None: raise ValueError('Missing frame pixels')
        if tuple(int(row[k]) for k in ('frame','source_frame_id','x','y'))!=(frame,100+frame,pos%w,pos//w):
            raise ValueError('Frame id/coordinate/order mismatch')
        if not re.fullmatch('[0-9a-fA-F]{6}',row['rgb']): raise ValueError('Invalid RGB')
        y,x=divmod(pos,w); rgb[y,x]=tuple(bytes.fromhex(row['rgb']))
        value=int(row[columns])
        if not 0<=value<=(1 if columns=='mask' else 3): raise ValueError('Invalid mask/mode')
        extra[y,x]=value
    return rgb,extra


def compare(directory,assets,w,h,enable,inject):
    modes=[0,1,1,2,2,3,3,0,3,0]
    _,overlay,layers=osd_reference(w,h,0,enable,assets)
    yy,xx=np.indices((h,w))
    fixture=np.stack(((3*xx+5*yy+102)%256,(7*xx+11*yy+174)%256,(13*xx+19*yy+186)%256),axis=-1).astype(np.uint8)
    outdir=directory/'images'; outdir.mkdir(exist_ok=True)
    results=[]; strips=[]; total_errors=0
    with (directory/'input.csv').open() as sf,(directory/'styled.csv').open() as pf,(directory/'display.csv').open() as df:
        sr,pr,dr=csv.DictReader(sf),csv.DictReader(pf),csv.DictReader(df)
        if sr.fieldnames!=['frame','source_frame_id','x','y','rgb','mask'] or any(r.fieldnames!=['frame','source_frame_id','x','y','mode','rgb'] for r in (pr,dr)):
            raise ValueError('CSV columns mismatch')
        for f,mode in enumerate(modes):
            source,mask=read_frame(sr,'mask',f,w,h)
            styled,styled_mode=read_frame(pr,'mode',f,w,h)
            display,display_mode=read_frame(dr,'mode',f,w,h)
            expected_source=fixture if f%2==0 else 255-fixture
            if not np.array_equal(source,expected_source) or not np.array_equal(mask,(xx//2+yy//2+f)%2):
                raise ValueError('Input fixture differs from documented definition')
            if np.any(styled_mode!=mode) or np.any(display_mode!=mode):
                raise ValueError('Mode differs from independently scheduled frame mode')
            if mode==0: base=expected_source
            elif mode==1:
                v=expected_source.astype(np.int32)
                gray=((77*v[:,:,0]+150*v[:,:,1]+29*v[:,:,2]+128)//256).astype(np.uint8)
                base=np.repeat(gray[:,:,None],3,axis=2)
            elif mode==2: base=reference_edge(expected_source,128)
            else: base=np.repeat((mask*255)[:,:,None],3,axis=2)
            expected=base.copy(); paint=layers[mode]!=0; rgb=overlay[mode]
            colors=np.stack(((rgb>>16)&255,(rgb>>8)&255,rgb&255),axis=-1).astype(np.uint8)
            expected[paint]=colors[paint]
            if inject and f==0: expected[0,0,0]^=1
            pre_errors=int(np.count_nonzero(np.any(styled!=base,axis=2)))
            errors=int(np.count_nonzero(np.any(display!=expected,axis=2)))
            outside=int(np.count_nonzero(np.any(display[~paint]!=base[~paint],axis=1)))
            total_errors+=pre_errors+errors
            diff=np.abs(display.astype(np.int16)-expected.astype(np.int16)).astype(np.uint8)
            pics={'input':source,'styled':styled,'output':display,'reference':expected,'diff':diff}
            if not inject:
                for label,pixels in pics.items(): Image.fromarray(pixels).save(outdir/f'frame_{f:02d}_{label}.png')
                if f in (0,1,3,5):
                    strip=Image.new('RGB',(3*w,h+24),'#17202b'); draw=ImageDraw.Draw(strip)
                    for col,(name,title) in enumerate((('styled','BEFORE OSD'),('output','AFTER OSD / '+['RAW','GRAY','EDGE','TEST MASK'][mode]),('diff','DIFFERENCE'))):
                        draw.text((col*w+5,5),title,fill='white'); strip.paste(Image.fromarray(pics[name]),(col*w,24))
                    strips.append(strip)
            results.append({'frame':f,'id':100+f,'mode':mode,'pixels':w*h,'pre_osd_mismatches':pre_errors,
                            'final_mismatches':errors,'outside_overlay_mismatches':outside})
        if any(next(r,None) is not None for r in (sr,pr,dr)): raise ValueError('Extra pixels after ten frames')
    if total_errors: raise ValueError(f'Integrated display mismatch: {total_errors} pixels')
    canvas=Image.new('RGB',(3*w,sum(s.height for s in strips)))
    top=0
    for s in strips: canvas.paste(s,(0,top)); top+=s.height
    canvas.save(outdir/'video_display_preview.png')
    result={'frames':results,'complete_pixels':10*w*h,'width':w,'height':h,'osd_enabled':enable,
            'mask_is_test_fixture':True,'passed':True}
    (directory/'image_check.json').write_text(json.dumps(result,indent=2)+'\n')


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--directory',type=Path,required=True); p.add_argument('--assets',type=Path,required=True)
    p.add_argument('--width',type=int,default=384); p.add_argument('--height',type=int,default=240)
    p.add_argument('--enable',type=int,choices=(0,1),default=1); p.add_argument('--inject-error',action='store_true')
    a=p.parse_args()
    try:
        compare(a.directory,a.assets,a.width,a.height,a.enable,a.inject_error)
        print('PASS: integrated display pixels match independent mode and OSD references.')
    except (OSError,ValueError,KeyError) as e:
        print(f'FAIL: {e}'); raise SystemExit(1)
