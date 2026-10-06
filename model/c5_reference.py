"""Offline complete-array majority reference; independent of streaming RAM scheduling."""
def input_mask(w,h,case,seed=20261005):
    p=case['pattern'];left=100 if w>=640 else 10;top=80 if h>=360 else 8
    result=bytearray(w*h)
    for y in range(h):
        for x in range(w):
            if p in (0,1):
                bit=(left<=x<=left+40 and top<=y<=top+30)
                if p==1:bit=(bit and (x,y)!=(left+20,top+15)) or (x,y)==(2,2)
            elif p==2:bit=(x,y)==(10,10)
            elif p==3:bit=x%8==3 and y%8==3
            elif p==4:bit=x==w//2 and 2<=y<h-2
            elif p==5:bit=x<9 and y<7
            elif p in (6,7):bit=(x,y) in ([(5,5),(7,5),(5,7),(7,7)]+([(6,6)] if p==6 else []))
            elif p==8:bit=True
            elif p==9:bit=False
            elif p==10:bit=(((y*w+x+seed)*1664525+1013904223)%(2**32))//(2**24)<96
            else:raise ValueError('unknown scene')
            result[y*w+x]=int(bit)
    return result


def majority(w,h,data):
    result=bytearray(w*h)
    for y in range(1,h-1):
        for x in range(1,w-1):
            # Full-image neighbourhood indexing, not line-buffer or RTL state logic.
            n=sum(data[(y+dy)*w+x+dx] for dy in (-1,0,1) for dx in (-1,0,1))
            result[y*w+x]=int(n>=5)
    return result


def geometry(w,data):
    positions=[i for i,bit in enumerate(data) if bit]
    if not positions:return [0,0,0,0,0,0,0,0]
    xs=[i%w for i in positions];ys=[i//w for i in positions]
    l,r,t,b=min(xs),max(xs),min(ys),max(ys)
    return [1,len(positions),l,t,r,b,(l+r)//2,(t+b)//2]
