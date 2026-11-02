"""Event-history reference and independent array painting (never reads DUT state)."""
import numpy as np

FIELDS=('frame','cfg','color','valid','area','xmin','ymin','xmax','ymax','cx','cy','reason','slots','components')
WIDTHS=(32,16,2,1,20,11,11,11,11,11,11,3,8,12)
def pack(p):
    value=0
    for key,width in zip(FIELDS,WIDTHS):value=(value<<width)|(p.get(key,0)&((1<<width)-1))
    return value
def unpack(v):
    p={}
    for k,w in reversed(list(zip(FIELDS,WIDTHS))):p[k]=v&((1<<w)-1);v>>=w
    return p
def packet(frame=1,cfg=1,color=0,valid=1,area=10000,xmin=100,ymin=200,xmax=199,ymax=299,cx=149,cy=249,reason=0,slots=7,components=3):
    return pack(locals())

def qualify(value,available,completed_ready,completed_id,cfg,color):
    p=unpack(value)
    ready=bool(available and completed_ready and (p['frame'],p['cfg'],p['color'])==(completed_id,cfg,color) and color!=3)
    bad=p['valid'] and (p['reason']!=0 or p['area']==0 or
        not(0<=p['xmin']<=p['xmax']<1280 and 0<=p['ymin']<=p['ymax']<720 and p['cx']<1280 and p['cy']<720))
    if not ready or bad:p['reason']=4
    if not ready or bad or not p['valid']:
        for k in ('valid','area','xmin','ymin','xmax','ymax','cx','cy'):p[k]=0
    if not ready:p['slots']=p['components']=0
    return int(ready),pack(p)

class History:
    def __init__(self):self.time=0;self.events=[];self.active=(0,0);self.opened=False
    def step(self,r,abort,v,s,st,data,cr,cid,cfg,tid):
        self.time+=1
        if not r or abort:
            self.events=[];self.active=(0,0);self.opened=False
        else:
            if v and s:
                eligible=[d for t,d in self.events if t<self.time]
                self.active=qualify(eligible[-1] if eligible else 0,bool(eligible),cr,cid,cfg,tid)
                self.opened=True
            if st:self.events.append((self.time,data))
        return self.opened,self.active

def logo_array(path):
    raw=np.array([int(s,16) for s in path.read_text().split()],dtype=np.uint32)[:25600].reshape(160,160)
    return raw

def pixel(rgb,x,y,value,logo):
    p=unpack(value)
    if p['valid']:
        l,t,r,b=(p[k] for k in ('xmin','ymin','xmax','ymax'))
        if l<=x<=r and t<=y<=b and (x in (l,l+1,r-1,r) or y in (t,t+1,b-1,b)):rgb=0x00ff00
        dx,dy=abs(x-p['cx']),abs(y-p['cy'])
        if (dx<=8 and dy<=1) or (dx<=1 and dy<=8):rgb=0x00ffff
    if 1104<=x<1264 and 16<=y<176:
        q=int(logo[y-16,x-1104])
        if q>>24:rgb=q&0xffffff
    return rgb

def render(value,logo):
    yy,xx=np.indices((720,1280));a=np.zeros((720,1280,3),np.uint8)
    a[:,:,0]=xx%256;a[:,:,1]=yy%256;a[:,:,2]=48
    p=unpack(value)
    def fill(l,t,r,b,rgb):
        a[max(t,0):min(b+1,720),max(l,0):min(r+1,1280)]=rgb
    if p['valid']:
        l,t,r,b=(p[k] for k in ('xmin','ymin','xmax','ymax'))
        for rect in [(l,t,min(l+1,r),b),(max(r-1,l),t,r,b),(l,t,r,min(t+1,b)),(l,max(b-1,t),r,b)]:fill(*rect,(0,255,0))
        x,y=p['cx'],p['cy'];fill(x-8,y-1,x+8,y+1,(0,255,255));fill(x-1,y-8,x+1,y+8,(0,255,255))
    opaque=logo>>24!=0;rgb=np.stack([(logo>>16)&255,(logo>>8)&255,logo&255],axis=-1).astype(np.uint8)
    a[16:176,1104:1264][opaque]=rgb[opaque]
    return a
