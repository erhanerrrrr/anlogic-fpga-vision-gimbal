"""Unmodified 57 H4D fixture definitions; H4E uses its own SciPy oracle."""
import numpy as np
W,H=128,80

def fixtures():
    cases=[]
    def add(name,m):cases.append((name,m.astype(bool)))
    def blank():return np.zeros((H,W),bool)
    add('empty',blank())
    for width in (15,16,17):
        m=blank();m[5:22,8:8+width]=1;add('area_'+str(width*17),m)
    m=blank();m[20:36,20:36]=1;add('area_256',m)
    m=blank();m[8:48,12:55]=1;m[58:65,105:115]=1;add('large_plus_remote_small',m)
    m=blank();m[8:28,8:28]=1;m[35:65,80:110]=1;add('two_large',m)
    m=blank();m[8:28,80:100]=1;m[35:55,8:28]=1;add('equal_area_top_wins',m)
    m=blank();m[8:28,8:28]=1;m[8:28,80:100]=1;add('equal_area_left_wins',m)
    yy,xx=np.indices((H,W))
    m=(abs(xx-yy-15)<=5)&(yy>=8)&(yy<70);add('tilted_low_fill',m)
    m=blank();m[8:65,10:20]=1;m[55:65,10:95]=1;add('L_shape',m)
    m=blank();m[10:65,10:110]=1;m[20:55,20:100]=0;add('hole',m)
    m=blank();m[8:50,8:18]=1;m[8:50,80:90]=1;m[45:55,8:90]=1;add('U_merge',m)
    m=blank();m[8:18,8:100]=1;m[18:60,8:18]=1;m[18:60,90:100]=1;add('split_then_merge',m | np.logical_and((yy>=55)&(yy<65),(xx>=8)&(xx<100)))
    m=blank();m[5:50,5:120:4]=1;m[49:60,5:120]=1;add('many_aliases_merge',m)
    m=blank();m[5:25,5:25]=1;m[25:45,25:45]=1;add('diagonal_touch',m)
    m=blank();m[5:25,5:25]=1;m[26:46,26:46]=1;add('one_pixel_separation',m)
    m=blank();m[:30,:40]=1;m[40:,100:]=1;add('frame_edges',m)
    add('full',np.ones((H,W),bool))
    for n in (31,32,33,40):
        m=blank()
        for j in range(n):m[2+(j//16)*4,2+(j%16)*4]=1
        add('label_capacity_'+str(n),m)
    add('overflow_recovery',np.ones((H,W),bool));add('clear_after_full',blank())
    rng=np.random.default_rng(20261010)
    for n in range(24):
        m=blank()
        for j in range(3+n%10):
            x=int(rng.integers(0,W-5));y=int(rng.integers(0,H-5))
            m[y:min(H,y+int(rng.integers(3,35))),x:min(W,x+int(rng.integers(3,45)))]=1
        add('seeded_rectangles_'+str(n),m)
    for n in range(8):add('seeded_noise_'+str(n),rng.random((H,W)) < (.1+.1*n))
    return cases
