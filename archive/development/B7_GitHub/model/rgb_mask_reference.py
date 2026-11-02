"""Independent full-image classifier/majority oracle for B2a."""
import numpy as np
from scipy.ndimage import convolve

def fixtures(w,h):
    y,x=np.indices((h,w));out=[]
    for k in range(6):
        rgb=np.stack(((x*13+y*7+k*31)%256,(x*3+y*19+k*7)%256,(x*11+y*5+k*23)%256),axis=-1).astype(np.uint8)
        if k==0:
            colors=np.array([[0,0,0],[255,255,255],[255,0,0],[0,255,0],[0,0,255],[24,8,8],[23,7,7],[100,85,84]],np.uint8)
            rgb=colors[np.minimum(x*8//w,7)]
        if k in (1,2):
            rgb[:]=0
            region=(x>=w*(k-1)//4)&(x<w*(k+1)//4)&(y>=h//4)&(y<3*h//4)
            rgb[region,k]=230
        if k==4:rgb[:]=96 # Target disappears; all equal channels.
        if k==5:
            rgb[:]=0;rgb[(x<5)|(x>=w-5)|(y<5)|(y>=h-5),0]=255
            rgb[((x*17+y*31)%97)==0,0]=255
        epoch=7 if k<3 else 8
        fid=[0xfffffffe,0xffffffff,0,0,1,2][k]
        cfg=[1,2,65535,0,1,1][k]
        color=[0,1,2,3,0,0][k]
        thresholds=[24,16,16] if k!=1 else [40,12,10]
        out.append((rgb,dict(epoch=epoch,frame=fid,cfg=cfg,color=color,thresholds=thresholds)))
    return out

def reference(rgb,tag,guard):
    h,w,_=rgb.shape;color=tag['color']
    if color==3:return np.zeros((h,w),dtype=np.uint8)
    values=rgb.astype(np.int16);main=values[:,:,color]
    other=[c for c in range(3) if c!=color];t,d1,d2=tag['thresholds']
    raw=(main>=t)&(main-values[:,:,other[0]]>=d1)&(main-values[:,:,other[1]]>=d2)
    if guard:raw[:guard]=False;raw[h-guard:]=False
    result=convolve(raw.astype(np.uint8),np.ones((3,3),np.uint8),mode='constant')>=5
    result[[0,-1],:]=False;result[:,[0,-1]]=False
    return result.astype(np.uint8)

def packed_tag(t):
    value=(t['epoch']<<74)|(t['frame']<<42)|(t['cfg']<<26)|(t['color']<<24)
    a,b,c=t['thresholds'];return value|(a<<16)|(b<<8)|c
