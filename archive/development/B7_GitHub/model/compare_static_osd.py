"""Independent coordinate compositor versus actual registered RTL pixels."""
import argparse
import csv
import json
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw


def reference(width,height,layout,enable,assets):
    tables=json.loads(assets.read_text())
    y,x=np.indices((height,width))
    gray=((x+3*y)&255).astype(np.uint32)
    backgrounds=[np.full((height,width),v,np.uint32) for v in (0xb02020,0x208020,0x2030b0,0xffffff)]
    backgrounds.append(gray*0x010101)
    frames=[a.copy() for a in backgrounds]
    layers=[]
    if layout==1:
        lx,ly,tx,ty,mx,my,cx,cy=width-80,height-90,width-40,height-24,width-20,height-8,0,0
    elif layout==2:
        lx,ly,tx,ty,mx,my,cx,cy=0,0,45,40,45,40,60,45
    else:
        lx,ly,tx,ty,mx,my,cx,cy=0,0,168,16,168,48,width//2,height//2
    for f,frame in enumerate(frames):
        layer=np.zeros((height,width),np.uint8)
        def put(px,py,color,kind):
            if 0<=px<width and 0<=py<height:
                frame[py,px]=color; layer[py,px]=kind
        def text(s,px,py,color,kind):
            for i,c in enumerate(s):
                rows=tables['font'].get(str(ord(c)),[0]*16)
                for gy,bits in enumerate(rows):
                    for gx in range(16):
                        if bits&(1<<(15-gx)):
                            put(px+i*16+gx,py+gy,color,kind)
        if enable:
            for addr,value in tables['logo'].items():
                addr=int(addr)
                if value&(1<<24): put(lx+addr%160,ly+addr//160,value&0xffffff,1)
            for py in range(ty,ty+16):
                for px in range(tx,tx+160): put(px,py,0x17202b,2)
            text('FPGA VIDEO',tx,ty,0x00e6ff,3)
            for py in range(my,my+16):
                for px in range(mx,mx+160): put(px,py,0x17202b,4)
            text(['MODE: RAW ','MODE: GRAY','MODE: EDGE','MODE: MASK'][f%4],mx,my,0xfff200,5)
            for d in range(-8,9):
                put(cx+d,cy,0xff00ff,6); put(cx,cy+d,0xff00ff,6)
        layers.append(layer)
    return backgrounds,frames,layers


def compare(directory,assets,width,height,layout,enable,inject=False):
    backgrounds,expected,layers=reference(width,height,layout,enable,assets)
    if inject: expected[0][0,0]^=1
    outputs=[np.zeros_like(a) for a in expected]
    count=prefix=errors=0; previous_cycle=-1
    with (directory/'pixels.csv').open() as stream:
        for row in csv.DictReader(stream):
            cycle,source,x,y,mode=[int(row[k]) for k in ('cycle','id','x','y','mode')]
            if cycle<=previous_cycle: raise ValueError('Cycle order mismatch')
            previous_cycle=cycle
            if source==90:
                if count or prefix>=200 or (x,y,mode)!=(prefix%width,prefix//width,0):
                    raise ValueError('Interrupted prefix mismatch')
                # Prefix uses the same layout/mode as complete frame 0.
                wanted=int(expected[0][y,x])
                if inject and x==0 and y==0: wanted^=1
                prefix+=1
            else:
                f,offset=divmod(count,width*height)
                if f>=5 or source!=100+f or (x,y,mode)!=(offset%width,offset//width,f%4):
                    raise ValueError('Full frame coordinate/id/mode mismatch')
                wanted=int(expected[f][y,x]); outputs[f][y,x]=int(row['output'],16); count+=1
            background_index=0 if source==90 else source-100
            if int(row['input'],16)!=int(backgrounds[background_index][y,x]):
                raise ValueError('Stimulus differs from documented background')
            if int(row['output'],16)!=wanted: errors+=1
    if count!=5*width*height or prefix!=200: raise ValueError('Incomplete output frames or reset prefix')
    if errors: raise ValueError(f'Static OSD mismatch: {errors} pixels')
    def image(a):
        return Image.fromarray(np.stack(((a>>16)&255,(a>>8)&255,a&255),axis=-1).astype(np.uint8))
    images=directory/'images'; images.mkdir(exist_ok=True)
    montage=Image.new('RGB',(3*width,2*(height+24)), '#17202b'); draw=ImageDraw.Draw(montage)
    coverage=[]
    for f in range(5):
        out=image(outputs[f]); out.save(images/f'frame_{f}_output.png')
        image(expected[f]).save(images/f'frame_{f}_reference.png')
        image(outputs[f]^expected[f]).save(images/f'frame_{f}_diff.png')
        image(backgrounds[f]).save(images/f'frame_{f}_input.png')
        px,py=(f%3)*width,(f//3)*(height+24)
        draw.text((px+8,py+5),f'Frame {100+f} | label: '+['RAW','GRAY','EDGE','MASK','RAW'][f],fill='white')
        montage.paste(out,(px,py+24))
        coverage.append({str(k):int(np.count_nonzero(layers[f]==k)) for k in range(7)})
    montage.save(images/'static_osd_preview.png')
    result={'width':width,'height':height,'layout':layout,'enable':enable,
            'complete_frames':5,'complete_pixels':count,'reset_prefix_pixels':prefix,'pixel_mismatches':0,
            'layer_counts_per_frame':coverage,'layers':'0 background,1 logo,2 title panel,3 title glyph,4 label panel,5 label glyph,6 cross',
            'real_four_mode_pipeline_connected':False,'passed':True}
    (directory/'image_check.json').write_text(json.dumps(result,indent=2)+'\n')
    return result


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--directory',type=Path,required=True); p.add_argument('--assets',type=Path,required=True)
    p.add_argument('--width',type=int,default=384); p.add_argument('--height',type=int,default=240)
    p.add_argument('--layout',type=int,choices=(0,1,2),default=0); p.add_argument('--enable',type=int,choices=(0,1),default=1)
    p.add_argument('--inject-error',action='store_true'); a=p.parse_args()
    try:
        compare(a.directory,a.assets,a.width,a.height,a.layout,a.enable,a.inject_error)
        print('PASS: static OSD RTL pixels match the independent compositor.')
    except (OSError,ValueError,KeyError) as e:
        print(f'FAIL: {e}'); raise SystemExit(1)
