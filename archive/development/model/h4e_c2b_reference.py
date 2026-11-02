"""Source event scenarios and independent RGB/majority/8-neighbour reference."""
from h4e_c2a_reference import geometry

WIDTH, HEIGHT, ROW_PERIOD = 64, 32, 240


def classify(rgb, config):
    _, color, minimum, diff1, diff2 = config
    channels = [(rgb >> 16) & 255, (rgb >> 8) & 255, rgb & 255]
    if color not in (0, 1, 2):
        return 0
    others = [channels[i] for i in range(3) if i != color]
    return int(channels[color] >= minimum and channels[color]-others[0] >= diff1 and
               channels[color]-others[1] >= diff2)


def rgb_at(x, y, color):
    if not (10 <= x <= 29 and 6 <= y <= 25):
        return 0
    return (0x280808, 0x082808, 0x080828)[color]


def expected_geometry(color, config):
    raw = [classify(rgb_at(x, y, color), config) if 4 <= y < HEIGHT-4 else 0
           for y in range(HEIGHT) for x in range(WIDTH)]
    filtered = [0]*(WIDTH*HEIGHT)
    for y in range(1, HEIGHT-1):
        for x in range(1, WIDTH-1):
            filtered[y*WIDTH+x] = int(sum(raw[(y+dy)*WIDTH+x+dx]
                for dy in (-1, 0, 1) for dx in (-1, 0, 1)) >= 5)
    return geometry(filtered, WIDTH, HEIGHT)


def scenarios():
    def cfg(n, color=0, threshold=24):
        return [n, color, threshold, 16, 16]
    # Expected active configurations are explicit, not inferred from DUT outputs.
    return [
        dict(name='first_10', fid=10, epoch=7, request=cfg(1), active=cfg(1), color=0, event=1, fresh=1),
        dict(name='repeat_10_threshold_request', fid=10, epoch=7, request=cfg(2, threshold=80), active=cfg(1), color=0, event=1, fresh=0),
        dict(name='new_11_applies_threshold', fid=11, epoch=7, request=cfg(2, threshold=80), active=cfg(2, threshold=80), color=0, event=1, fresh=1),
        dict(name='repeat_empty_11', fid=11, epoch=7, request=cfg(3), active=cfg(2, threshold=80), color=0, event=1, fresh=0),
        dict(name='max_frame_id', fid=0xffffffff, epoch=7, request=cfg(3), active=cfg(3), color=0, event=1, fresh=1),
        dict(name='wrapped_frame_id', fid=0, epoch=7, request=cfg(3), active=cfg(3), color=0, event=1, fresh=1),
        dict(name='revoke_after_eof', fid=1, epoch=7, request=cfg(3), active=cfg(3), color=0, event=0, kind='revoke'),
        dict(name='same_id_new_epoch', fid=0, epoch=8, request=cfg(4,1), active=cfg(4,1), color=1, event=1, fresh=1),
        dict(name='stale_epoch_sof', fid=99, epoch=7, request=cfg(99), active=cfg(4,1), color=0, event=0, kind='stale'),
        dict(name='half_row_interruption', fid=2, epoch=8, request=cfg(5,2), active=cfg(5,2), color=2, event=0, kind='half_row'),
        dict(name='same_id_retry_keeps_config', fid=2, epoch=8, request=cfg(6,2,80), active=cfg(5,2), color=2, event=1, fresh=1),
        dict(name='half_frame_between_rows', fid=3, epoch=8, request=cfg(6), active=cfg(6), color=0, event=0, kind='half_frame'),
        dict(name='new_sof_recovers', fid=4, epoch=8, request=cfg(7), active=cfg(7), color=0, event=1, fresh=1),
        dict(name='early_eof', fid=5, epoch=8, request=cfg(8), active=cfg(8), color=0, event=0, kind='early_eof'),
        dict(name='after_early_eof', fid=6, epoch=8, request=cfg(9), active=cfg(9), color=0, event=1, fresh=1),
        dict(name='missing_sof_ignored', fid=7, epoch=8, request=cfg(10), active=cfg(9), color=0, event=0, kind='missing_sof'),
        dict(name='coordinate_jump', fid=8, epoch=8, request=cfg(10), active=cfg(10), color=0, event=0, kind='bad_coordinate'),
        dict(name='retry_keeps_color', fid=8, epoch=8, request=cfg(11,1), active=cfg(10), color=0, event=1, fresh=1),
        dict(name='reset_during_frame', fid=9, epoch=8, request=cfg(11), active=cfg(11), color=0, event=0, kind='reset'),
        dict(name='after_global_reset', fid=9, epoch=8, request=cfg(12,1), active=cfg(12,1), color=1, event=1, fresh=1),
        dict(name='complete_but_superseded', fid=10, epoch=8, request=cfg(13), active=cfg(13), color=0, event=0, kind='overlap'),
        dict(name='new_sof_during_tail', fid=11, epoch=8, request=cfg(14,2), active=cfg(14,2), color=2, event=1, fresh=1),
        dict(name='epoch_change_without_flush', fid=12, epoch=8, request=cfg(15), active=cfg(15), color=0, event=0, kind='epoch_only'),
        dict(name='same_id_epoch9', fid=11, epoch=9, request=cfg(16), active=cfg(16), color=0, event=1, fresh=1),
        dict(name='final_frame_then_source_stops', fid=12, epoch=9, request=cfg(17), active=cfg(17), color=0, event=1, fresh=1, kind='stop'),
    ]


def stimulus():
    frames = scenarios()
    rows = []
    authoritative_epoch = 7
    state = dict(attempt=-1, rst=0, flush=0, epoch=7, valid=0, sof=0, eof=0,
                 x=0, y=0, rgb=0, fid=0, source_epoch=7, cfg=1, color=0, minimum=24, d1=16, d2=16)

    def add(**changes):
        state.update(changes)
        rows.append(dict(cycle=len(rows), **state))

    def idle(count, **changes):
        for _ in range(count):
            add(valid=0, sof=0, eof=0, **changes)

    idle(3)
    idle(3, rst=1)
    for index, frame in enumerate(frames):
        kind = frame.get('kind', 'normal')
        state.update(attempt=index, fid=frame['fid'], source_epoch=frame['epoch'],
                     epoch=authoritative_epoch)
        state.update(dict(zip(('cfg','color','minimum','d1','d2'),frame['request'])))
        count = {'stale':1,'half_row':WIDTH*8+10,'half_frame':WIDTH*8,
                 'early_eof':10,'missing_sof':WIDTH,'bad_coordinate':10,'reset':10}.get(kind, WIDTH*HEIGHT)
        for pixel in range(count):
            if index==0 and pixel==100:
                state.update(cfg=999, color=2, minimum=250, d1=200, d2=200)
            x, y = pixel % WIDTH, pixel // WIDTH
            actual_x = x+1 if kind=='bad_coordinate' and pixel==3 else x
            is_eof = pixel==WIDTH*HEIGHT-1 or (kind=='early_eof' and pixel==count-1)
            add(valid=1, sof=int(pixel==0 and kind!='missing_sof'), eof=int(is_eof),
                x=actual_x, y=y, rgb=rgb_at(x,y,frame['color']))
            if is_eof:
                frame['input_eof_cycle'] = rows[-1]['cycle']
            if x==WIDTH-1 and not (pixel==count-1 and kind in ('revoke','stop','overlap','epoch_only')):
                idle(ROW_PERIOD-WIDTH)
        if kind=='revoke':
            authoritative_epoch=8
            idle(2, epoch=8, flush=1)
            idle(10, flush=0)
        elif kind=='epoch_only':
            authoritative_epoch=9
            idle(10, epoch=9, flush=0)
        elif kind=='overlap':
            pass
        elif kind=='reset':
            idle(2, rst=0)
            idle(5, rst=1)
        elif kind=='stop':
            idle(2048)
        else:
            idle(25)
    return rows, frames


def observer_vectors():
    # rst, strobe, flush, authoritative epoch, packet epoch, packet frame
    vectors = [(0,0,0,7,0,0),(1,1,0,7,7,10),(1,0,0,7,7,10),
               (1,1,0,7,7,10),(1,1,0,7,7,11),(1,1,0,7,7,0xffffffff),
               (1,1,0,7,7,0),(1,1,0,8,7,1),(1,1,0,8,8,0),
               (1,1,1,8,8,1),(1,1,0,8,8,1),(1,1,0,8,8,1),
               (1,0,1,8,8,1),(1,1,0,8,8,1),(1,1,0,8,8,2),
               (0,1,0,8,8,2),(1,1,0,8,8,2)]
    vectors += [(1,0,0,8,8,2)]*32
    expected, last = [], None
    for cycle, (rst, strobe, flush, active, epoch, fid) in enumerate(vectors):
        if not rst:
            last = None
        publish = int(bool(rst and strobe and not flush and epoch==active))
        fresh = int(bool(publish and last != (epoch,fid)))
        if fresh:
            last = (epoch,fid)
        expected.append(dict(cycle=cycle,result_strobe=publish,new_observation=fresh))
    return vectors, expected
