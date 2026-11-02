"""Independent integer rule reference, deterministic directed/random cases."""
import random
PROFILES=[(80,224,32,40,32),(0,255,255,0,0),(0,255,255,0,255)]
OUTPUTS=['done','ok','reason','fid','epoch','cfg','target','color','main','d1','d2']
INPUTS=['rst','flush','active_epoch','done','ok','count','fid','epoch','cfg','target','mr','mg','mb','lr','lg','lb','hr','hg','hb']

def result(v,profile=PROFILES[0]):
    low,high,spread,dominance,margin=profile
    means=[v['m'+c] for c in 'rgb'];mins=[v['l'+c] for c in 'rgb'];maxs=[v['h'+c] for c in 'rgb']
    color=max(range(3),key=lambda i:means[i])
    main=means[color];others=[means[i] for i in range(3) if i!=color]
    differences=[main-other for other in others]
    checks=[(6,v['flush'] or v['epoch']!=v['active_epoch']),
            (1,not v['ok'] or v['count']!=256),
            (2,any(not l<=m<=h for l,m,h in zip(mins,means,maxs))),
            (3,not low<=main<=high),
            (4,any(h-l>spread for l,h in zip(mins,maxs))),
            (5,min(differences)<dominance)]
    reason=next((code for code,bad in checks if bad),0)
    clamp=lambda n:max(0,min(255,n-margin))
    return dict(done=1,ok=int(reason==0),reason=reason,fid=v['fid'],epoch=v['epoch'],cfg=v['cfg'],target=v['target'],
                color=color if not reason else 0,main=clamp(main) if not reason else 0,
                d1=clamp(differences[0]) if not reason else 0,d2=clamp(differences[1]) if not reason else 0)

def stimulus():
    rows=[]
    def add(name,means=(180,40,20),**changes):
        v=dict(rst=1,flush=0,active_epoch=7,done=1,ok=1,count=256,fid=len(rows),epoch=7,cfg=1,target=0)
        for c,m in zip('rgb',means):v['m'+c]=m;v['l'+c]=m;v['h'+c]=m
        v.update(changes);v['name']=name;rows.append(v)
    add('reset',rst=0)
    for color in range(3):
        for value in (0,79,80,81,223,224,225,255):
            means=[0,0,0];means[color]=value
            add('brightness_%d_%d'%(color,value),means)
        for diff in (0,31,32,33,39,40,41,255):
            for other in [i for i in range(3) if i!=color]:
                means=[0,0,0];means[color]=255 if diff==255 else 180;means[other]=means[color]-diff
                add('dominance_%d_%d_%d'%(color,other,diff),means)
    for c in 'rgb':
        for span in (31,32,33):
            add('spread_'+c+str(span),**{'l'+c: {'r':180,'g':40,'b':20}[c]-min(20,span),'h'+c:{'r':180,'g':40,'b':20}[c]+span-min(20,span)})
        add('bad_min_'+c,**{'l'+c:230})
        add('bad_max_'+c,**{'h'+c:0})
    for count in (0,255,256,257,511):add('count_'+str(count),count=count)
    for means in ((100,100,100),(180,180,20),(20,180,180),(180,20,180),(0,0,0)):
        add('gray_tie_dark',means)
    add('sample_failed',ok=0)
    add('stale',epoch=6)
    add('flush',flush=1)
    add('priority_stale',flush=1,ok=0,count=0,lr=255)
    add('priority_count',ok=0,lr=255)
    add('priority_bounds',(250,40,20),lr=255)
    add('priority_brightness',(250,240,20),lr=0)
    add('priority_spread',(180,170,20),lr=0)
    add('identities',(20,180,40),fid=0xffffffff,epoch=0xffffffff,active_epoch=0xffffffff,cfg=65535,target=2)
    add('no_event_flush',done=0,flush=1)
    add('reset_during_event',rst=0)
    add('idle_after_reset',done=0)
    rng=random.Random(0xC3B)
    for i in range(3000):
        means=tuple(rng.randrange(256) for _ in range(3))
        changes=dict(fid=rng.getrandbits(32),cfg=rng.randrange(65536),target=rng.randrange(3))
        if i%3==0:
            for c,m in zip('rgb',means):changes['l'+c]=max(0,m-rng.randrange(25));changes['h'+c]=min(255,m+rng.randrange(25))
        if i%11==0:changes['count']=rng.randrange(512)
        if i%13==0:changes['epoch']=8
        if i%17==0:changes['done']=0
        if i%23==0:changes['flush']=1
        if i%29==0:changes['rst']=0
        add('random_'+str(i),means,**changes)
    return rows

def cycles(rows,profile):
    held=dict.fromkeys(OUTPUTS,0);out=[]
    for cycle,v in enumerate(rows):
        if not v['rst']:held=dict.fromkeys(OUTPUTS,0)
        elif v['done']:held=result(v,profile)
        else:held=dict(held,done=0)
        out.append(dict(cycle=cycle,**held))
    return out
