from pathlib import Path
import json,re
import numpy as np
from scipy import ndimage
from test_regions import oracle,geometry
r=Path(__file__).resolve().parent
W,H=1280,720;yy,xx=np.indices((H,W));cases=[]
def rect(l,t,w,h):return (xx>=l)&(xx<l+w)&(yy>=t)&(yy<t+h)
noise=(xx==50)&(yy==200) | rect(1100,650,2,2);edge=(yy<3)|(yy>=717)
cases += [rect(600,300,100,100)|noise|edge,rect(800,400,16,16)|noise|edge,
          noise|edge|((xx==100)&(yy>=200)&(yy<300)),rect(800,400,17,17),np.ones((H,W),bool),
          rect(400,300,150,100)|rect(950,550,40,40),
          (abs(xx-yy-100)<=18)&(yy>=250)&(yy<610)]
m=rect(300,300,150,100)
for j in range(33):m |= rect(600+(j%17)*20,300+(j//17)*30,5,5)
cases.append(m)
m=rect(300,240,335,180)
for j in range(33):m |= rect(302+j*10,210,5,30)
cases.append(m)
m=rect(450,300,180,150)
for y in range(30,700,25):
    for x in range(20,1200,25):
        if not(420<=x<=650 and 270<=y<=470):m |= rect(x,y,5,5)
cases.append(m)
m=np.zeros((H,W),bool)
for j in range(65):m |= rect(200+j*10,250,5,15)
cases.append(m);cases.append(rect(200,300,100,100));cases.append(np.zeros((H,W),bool))
N=len(cases)

def peak_working_slots(mask):
    # Independent unbounded software labels for *capacity accounting only*.
    # Geometry/component reference remains SciPy's full-image 8-neighbour label.
    parent={};serial=0;previous=[];peak=0
    def root(k):
        while parent[k]!=k:k=parent[k]
        return k
    for row in mask:
        a=np.flatnonzero(np.diff(np.r_[False,row,False].astype(np.int8)))
        spans=list(zip(a[::2],a[1::2]-1))
        if len(spans)>64:return peak
        live=len({root(p[2]) for p in previous});born=0;current=[]
        for l,h in spans:
            touching={root(p[2]) for p in previous if p[1]+1>=l and p[0]<=h+1}
            if not touching:
                serial+=1;parent[serial]=serial;k=serial;born+=1
            else:
                k=min(touching)
                for q in touching:parent[q]=k
            current.append((int(l),int(h),k))
        peak=max(peak,live+born);previous=current
    return peak

d=r/'simulation';d.mkdir(exist_ok=True)
filtered=[];fs=[[0]*5];rs=[[0]*5];ts=[[0]*11]
for mask in cases:
    g=mask&(yy>=4)&(yy<716)
    fm=ndimage.convolve(g.astype(np.uint8),np.ones((3,3),np.uint8),mode='constant')>=5
    fm[[0,-1],:]=0;fm[:,[0,-1]]=0
    e=oracle(fm);e.insert(9,peak_working_slots(fm))
    filtered.append(fm);fs.append(geometry(fm));rs.append(geometry(mask));ts.append(e)
for name,seq in [('pipeline_raw',cases),('pipeline_filtered',filtered)]:
    with (d/(name+'.mem')).open('w') as f:
        for mask in seq:
            for row in mask:f.write(' '.join('1' if q else '0' for q in row)+'\n')
for name,seq in [('f_stats',fs),('r_stats',rs),('t_stats',ts)]:
    (d/(name+'.mem')).write_text('\n'.join(''.join(f'{v:08x}' for v in row) for row in seq)+'\n')
(d/'pipeline_cases.json').write_text(json.dumps(dict(frames=N,F=fs,R=rs,T=ts),indent=2))
print(json.dumps(dict(frames=N,T=ts[1:])))
