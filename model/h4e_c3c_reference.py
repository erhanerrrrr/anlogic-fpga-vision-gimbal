"""Control protocol oracle plus explicitly annotated RGB integration scenarios."""
import random
from h4e_c2b_reference import classify
from h4e_c2a_reference import geometry

def unit_vectors():
    rows=[]
    def add(name,**kw):
        v=dict(rst=1,flush=0,epoch=7,new=0,cal=0,sel=0,color=0,sbusy=0,done=0,ok=1,cepoch=7,ccolor=1,main=168,d1=148,d2=128)
        v.update(kw);v['name']=name;rows.append(v)
    add('reset',rst=0)
    add('select_on_sof',sel=1,color=1,new=1)
    add('repeat_busy',cal=1,sel=1)
    add('apply_and_ignore',new=1,cal=1,sel=1)
    add('manual_blue',sel=1,color=2)
    add('wrap_cfg',new=1)
    add('invalid_color',sel=1,color=3)
    add('calibration_wins',cal=1,sel=1)
    add('waiting_requests',cal=1,sel=1,sbusy=1)
    add('candidate_on_sof',done=1,new=1,cal=1)
    add('repeat_pending',sel=1)
    add('apply_candidate',new=1)
    add('failure_request',cal=1)
    add('failure_completion_ignores',done=1,ok=0,cal=1,sel=1,new=1)
    add('next_cycle_accepts',sel=1,color=0)
    add('flush_beats_apply',flush=1,new=1,cal=1)
    add('drain_after_flush_1')
    add('drain_after_flush_2')
    add('cal_before_epoch',cal=1)
    add('epoch_revokes',epoch=8,new=1,done=1)
    add('late_candidate_ignored',epoch=8,cepoch=8,done=1)
    add('drain_after_epoch',epoch=8)
    add('manual_before_epoch',epoch=8,sel=1,color=2)
    add('epoch_revokes_pending',epoch=9,new=1)
    add('drain_after_pending_1',epoch=9)
    add('drain_after_pending_2',epoch=9)
    add('request_for_stale_candidate',cal=1)
    add('stale_candidate',done=1,cepoch=6)
    add('request_invalid_candidate',cal=1)
    add('invalid_candidate_color',done=1,ccolor=3)
    add('reset_waiting_request',cal=1)
    add('reset_waiting',rst=0,new=1,done=1)
    add('manual_for_reset',sel=1)
    add('reset_pending',rst=0,new=1)
    add('cancel_old_operation',cal=1)
    add('cancel_before_old_result',flush=1,sbusy=1)
    add('drain_1_rejects_new',cal=1)
    add('drain_2_rejects_old_completion',cal=1,done=1)
    add('post_drain_new_request',cal=1)
    add('new_completion',done=1)
    add('apply_new_after_drain',new=1)
    add('sampler_busy_blocks' ,sbusy=1,cal=1,sel=1)
    rng=random.Random(0xC3C)
    for i in range(2500):
        add('random_'+str(i),rst=int(i%73!=0),flush=int(i%61==0),epoch=7+(i//100)%3,new=rng.randrange(2),
            cal=int(rng.randrange(7)==0),sel=int(rng.randrange(7)==0),color=rng.randrange(4),sbusy=int(i%19==0),
            done=int(rng.randrange(4)==0),ok=int(rng.randrange(4)!=0),cepoch=7+(i//100)%3,ccolor=rng.randrange(4),
            main=rng.randrange(256),d1=rng.randrange(256),d2=rng.randrange(256))
    return rows

def unit_expected(rows):
    state='idle';pending=(0,0,0,0);epoch=0;drain=0;active=(65534,0,24,16,16);out=[]
    for i,v in enumerate(rows):
        busy=state!='idle' or v['sbusy'] or drain!=0;cancel=v['flush'] or (state!='idle' and epoch!=v['epoch'])
        sample=int(v['rst'] and v['cal'] and not busy and not cancel)
        apply=int(v['rst'] and state=='ready' and v['new'] and not cancel)
        request=((active[0]+1)&65535,*pending) if apply else active
        ignored=int(v['cal'] and (busy or cancel));si=int(v['sel'] and (busy or cancel or v['cal'] or v['color']==3))
        cancelled=int(cancel and (state!='idle' or v['sbusy']))
        next_drain=max(0,drain-1)
        if cancelled:next_drain=2
        if not v['rst']:
            state='idle';pending=(0,0,0,0);epoch=0;drain=0;active=(65534,0,24,16,16);ignored=si=cancelled=0
        else:
            drain=next_drain
            oldstate=state
            if sample:state='sampling';epoch=v['epoch']
            if v['sel'] and not busy and not cancel and not v['cal'] and v['color']!=3:
                state='ready';epoch=v['epoch'];pending=(v['color'],24,16,16)
            if oldstate=='sampling' and v['done']:
                state='idle'
                if v['ok'] and v['cepoch']==v['epoch'] and v['ccolor']!=3:
                    state='ready';pending=(v['ccolor'],v['main'],v['d1'],v['d2'])
            if apply:state='idle'
            if cancel:state='idle'
            if v['new']:active=request
        out.append(dict(cycle=i,sample=sample,apply=apply,ignored=ignored,select_ignored=si,cancelled=cancelled,
            busy=int(state!='idle' or v['sbusy'] or drain!=0),pending=int(state=='ready'),pc=pending[0],pm=pending[1],pd1=pending[2],pd2=pending[3],
            cfg=active[0],color=active[1],main=active[2],d1=active[3],d2=active[4]))
    return out

WIDTH,HEIGHT,ROW_PERIOD=64,32,240
SCENES={'dim_red':0x280808,'red':0xDC1E0A,'green':0x14C828,'blue':0x0F19D2,'gray':0x646464}
def rgb_at(x,y,scene):return SCENES[scene] if 22<=x<=41 and 6<=y<=25 else 0

def expected_geometry(scene,cfg):
    raw=[classify(rgb_at(x,y,scene),cfg) if 4<=y<HEIGHT-4 else 0 for y in range(HEIGHT) for x in range(WIDTH)]
    filt=[0]*(WIDTH*HEIGHT)
    for y in range(1,HEIGHT-1):
        for x in range(1,WIDTH-1):filt[y*WIDTH+x]=int(sum(raw[(y+dy)*WIDTH+x+dx] for dy in (-1,0,1) for dx in (-1,0,1))>=5)
    return geometry(filt,WIDTH,HEIGHT)

def chain_stimulus():
    rows=[];frames=[]
    state=dict(attempt=-1,rst=0,flush=0,epoch=7,valid=0,sof=0,eof=0,x=0,y=0,rgb=0,fid=0,source_epoch=7,cal=0,sel=0,select=0)
    def add(**kw):state.update(kw);rows.append(dict(cycle=len(rows),**state))
    def idle(n=1,**kw):
        for _ in range(n):add(valid=0,sof=0,eof=0,cal=0,sel=0,**kw)
    def request(cal=0,sel=0,color=0):
        add(valid=0,sof=0,eof=0,cal=cal,sel=sel,select=color);idle()
    def frame(name,fid,scene,cfg,fresh=1,apply=0,new=1,drain=300,mid=None,on_sof=None,partial=False,event=1):
        index=len(frames);frames.append(dict(name=name,fid=fid,epoch=state['epoch'],scene=scene,active=cfg,fresh=fresh,new=new,apply=apply,event=event))
        for y in range(HEIGHT):
            for x in range(WIDTH):
                if partial and y==10 and x==5:idle(6);return
                controls=dict(cal=0,sel=0)
                if on_sof and x==0 and y==0:controls.update(on_sof)
                if mid and x==10 and y==10:controls.update(mid)
                add(attempt=index,valid=1,sof=int(x==0 and y==0),eof=int(x==WIDTH-1 and y==HEIGHT-1),x=x,y=y,rgb=rgb_at(x,y,scene),fid=fid,source_epoch=state['epoch'],**controls)
            if y<HEIGHT-1:idle(ROW_PERIOD-WIDTH)
        idle(drain)
    c1=[1,0,24,16,16];c2=[2,0,188,158,178];c3=[3,1,168,148,128];c4=[4,2,24,16,16]
    idle(3);idle(3,rst=1)
    frame('baseline_red',10,'dim_red',c1)
    request(cal=1,sel=1,color=2)
    frame('sample_red_old_cfg',11,'red',c1,mid=dict(cal=1,sel=1))
    frame('repeat_pending_red_tail_revoked_on_apply',11,'dim_red',c1,fresh=0,new=0,drain=2,event=0)
    frame('apply_red_ignore_requests',12,'dim_red',c2,apply=1,on_sof=dict(cal=1,sel=1))
    frame('sof_request_skips_frame',13,'red',c2,on_sof=dict(cal=1))
    frame('repeat_waiting_sample',13,'red',c2,fresh=0,new=0)
    frame('sample_green_tail_superseded',14,'green',c2,drain=2,event=0)
    frame('candidate_coincides_sof',15,'green',c2)
    frame('apply_green_then_select_blue',16,'green',c3,apply=1,mid=dict(sel=1,select=2))
    frame('repeat_manual_pending',16,'green',c3,fresh=0,new=0)
    frame('apply_manual_blue',17,'blue',c4,apply=1)
    request(cal=1)
    frame('gray_calibration_fails',18,'gray',c4)
    frame('failure_keeps_blue',19,'blue',c4)
    request(sel=1,color=0);idle(flush=1);idle(flush=0)
    frame('flush_keeps_blue',20,'blue',c4)
    request(cal=1);idle(epoch=8);add(valid=0,sof=0,eof=0,cal=1);add(valid=0,sof=0,eof=0,cal=1);idle(3)
    frame('epoch_cancels_waiting',20,'blue',c4)
    request(sel=1,color=1);idle(epoch=9);idle(5)
    frame('epoch_cancels_pending',21,'blue',c4)
    request(cal=1)
    frame('partial_sample',22,'red',c4,partial=True,event=0)
    idle(8)
    frame('same_id_retry_after_failure',22,'blue',c4,new=0)
    request(sel=1,color=1);idle(3,rst=0);idle(3,rst=1)
    frame('reset_restores_baseline',23,'dim_red',c1)
    idle(300)
    return rows,frames
