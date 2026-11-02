from pathlib import Path
import sys,json,subprocess,hashlib
import numpy as np
from scipy import ndimage
ROOT=Path(__file__).resolve().parent
W,H=384,96

def geometry(m):
    y,x=np.nonzero(m)
    return [len(x),int(x.min()),int(x.max()),int(y.min()),int(y.max())] if len(x) else [0]*5
def oracle(m, forced=0):
    lab,n=ndimage.label(m,np.ones((3,3),int))
    areas=np.bincount(lab.ravel());boxes=ndimage.find_objects(lab)
    regions=[]
    for i,b in enumerate(boxes,1):
        if b:regions.append([int(areas[i]),b[1].start,b[1].stop-1,b[0].start,b[0].stop-1])
    regions.sort(key=lambda z:(-z[0],z[3],z[1]))
    starts=m.copy();starts[:,1:] &= ~m[:,:-1]
    why=forced or (3 if starts.sum(1).max()>64 else (1 if not n else (2 if regions[0][0]<256 else 0)))
    a,l,r,t,b=regions[0] if why==0 else [0]*5
    return [int(why==0),why,a,l,r,t,b,(l+r)//2,(t+b)//2,0 if why in (3,5) else min(n,4095)]
def denoise(m):
    f=ndimage.convolve(m.astype(np.uint8),np.ones((3,3),np.uint8),mode='constant')>=5
    f[[0,-1],:]=0;f[:,[0,-1]]=0
    return f
def fixtures():
    import legacy_fixtures as old
    cases=[]
    for name,m in old.fixtures():
        padded=np.zeros((H,W),bool);padded[:m.shape[0],:m.shape[1]]=m
        cases.append((name,padded,1650,0))
    def add(n,m,period=1650,forced=0):cases.append((n,m,period,forced))
    m=np.zeros((H,W),bool);m[24:70,10:345]=1
    for j in range(33):m[10:24,12+j*10:17+j*10]=1
    add('REPAIR_single_component_33_teeth',denoise(m))
    m=np.zeros((H,W),bool);m[10:65,10:160]=1
    for j in range(33):
        x=180+(j%17)*10;y=15+(j//17)*20;m[y:y+5,x:x+5]=1
    add('REPAIR_main_plus_33_blobs',denoise(m))
    m=np.zeros((H,W),bool);m[8:88,8:160]=1
    for y in range(5,90,10):
        for x in range(180,350,10):m[y:y+5,x:x+5]=1
    add('recycle_153_small_blobs_plus_main',denoise(m))
    m=np.zeros((H,W),bool)
    for y in range(3,90,8):
        for x in range(3,375,6):m[y:y+3,x:x+3]=1
    add('682_finished_components',m)
    m=np.zeros((H,W),bool);m[2:80,2:382:6]=1;m[79:90,2:382]=1
    add('64_frontier_branches_merge_to_one',m)
    m=np.zeros((H,W),bool);m[2:15,2:380:6]=1;m[15:30,2:380]=1;m[30:60,2:380:6]=1;m[60:70,2:380]=1
    add('split_merge_split_merge_63_runs',m)
    m=np.zeros((H,W),bool);m[2,2:327:5]=1
    add('65_run_capacity_error',m)
    add('capacity_recovery',np.ones((H,W),bool))
    m=np.zeros((H,W),bool);m[1:90,2:380:6]=1
    add('insufficient_row_cycles',m,W,5)
    add('deadline_recovery',np.ones((H,W),bool))
    add('clear_after_recovery',np.zeros((H,W),bool))
    return cases
def run():
    cases=fixtures();d=ROOT/'simulation';d.mkdir(exist_ok=True)
    with (d/'masks.mem').open('w') as f:
        for _,m,_,_ in cases:
            for row in m:f.write(' '.join('1' if q else '0' for q in row)+'\n')
    expected=[oracle(m,err) for _,m,_,err in cases]
    (d/'expected.txt').write_text('\n'.join(' '.join(map(str,[i+1,period]+exp)) for i,((_,_,period,_),exp) in enumerate(zip(cases,expected)))+'\n')
    (d/'cases.json').write_text(json.dumps([dict(name=n,expected=e,period=p) for (n,_,p,_),e in zip(cases,expected)],indent=2))
    cmds=[['iverilog','-g2012','-Wall','-s','tb_regions',f'-Ptb_regions.N={len(cases)}','-o','simulation/tb_regions.vvp','user_source/hdl_source/h4e_region_select.v','tb_regions.v'],['vvp','simulation/tb_regions.vvp']]
    with (ROOT/'region_simulation.log').open('w') as log:
        for cmd in cmds:
            p=subprocess.run(cmd,cwd=ROOT,text=True,capture_output=True,timeout=240)
            log.write(p.stdout+p.stderr);log.flush()
            if p.returncode:raise RuntimeError(p.stdout+p.stderr)
    report=dict(status='PASS',frames=len(cases),pixels=len(cases)*W*H,rtl_sha256=hashlib.sha256((ROOT/'user_source/hdl_source/h4e_region_select.v').read_bytes()).hexdigest())
    (d/'result.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))
if __name__=='__main__':run()
