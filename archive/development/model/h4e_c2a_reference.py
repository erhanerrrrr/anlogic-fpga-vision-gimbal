"""C2a event contract and independent small-mask 8-connected geometry oracle."""
import random

FIELDS = [('target_valid', 1), ('frame_id', 32), ('capture_epoch', 32),
          ('cfg_id', 16), ('target_id', 2), ('area', 20), ('cx', 11), ('cy', 11),
          ('xmin', 11), ('xmax', 11), ('ymin', 11), ('ymax', 11),
          ('reject_reason', 3), ('peak_slots', 8), ('component_count', 12)]
GEOMETRY = ('area', 'cx', 'cy', 'xmin', 'xmax', 'ymin', 'ymax')
SEED = 20261010


def packet(fid=10, cfg=1, color=0, epoch=0, reason=0, box=(4, 19, 4, 19), area=256):
    left, right, top, bottom = box
    return dict(target_valid=int(reason == 0), frame_id=fid, capture_epoch=epoch,
                cfg_id=cfg, target_id=color, area=area, cx=(left+right)//2,
                cy=(top+bottom)//2, xmin=left, xmax=right, ymin=top, ymax=bottom,
                reject_reason=reason, peak_slots=0 if reason == 1 else 1,
                component_count=0 if reason in (1, 3, 5) else 1)


def unit_vectors():
    poison = {name: (1 << width)-1 for name, width in FIELDS}
    vectors = []

    def add(name, rst=1, strobe=0, data=None):
        vectors.append(dict(cycle=len(vectors), name=name, rst_n=rst,
                            input_strobe=strobe, input=dict(poison if data is None else data)))

    add('reset', rst=0)
    add('idle_poison')
    add('valid_red', strobe=1, data=packet())
    add('hold_despite_live_input_changes')
    add('empty_with_dirty_geometry', strobe=1, data=packet(fid=11, reason=1, area=999))
    add('valid_green', strobe=1, data=packet(fid=12, cfg=2, color=1))
    add('capacity_with_dirty_geometry', strobe=1, data=packet(fid=13, cfg=2, color=1, reason=3))
    add('recovery_blue', strobe=1, data=packet(fid=14, cfg=3, color=2))
    add('consecutive_result', strobe=1, data=packet(fid=15, cfg=4))
    add('same_identity_still_an_event_in_C2a', strobe=1,
        data=packet(fid=15, cfg=4, box=(100, 115, 80, 95)))
    add('hold_after_burst')
    add('identity_width_limits', strobe=1,
        data=packet(fid=0xffffffff, cfg=0xffff, color=2, epoch=0xffffffff,
                    box=(1264, 1279, 704, 719)))
    add('wrap_and_deadline_reason', strobe=1, data=packet(fid=0, cfg=0, reason=5))
    add('async_reset_overrides_input_event', rst=0, strobe=1, data=packet(fid=999))
    add('release_without_event')
    add('epoch_is_preserved_not_interpreted', strobe=1, data=packet(fid=0, cfg=0, epoch=1))
    add('idle_after_epoch')
    add('reset_again', rst=0)
    add('reset_held', rst=0)
    add('release_again')
    full = packet(fid=76, box=(0, 1279, 0, 719), area=921600)
    full.update(peak_slots=128, component_count=4095)
    add('full_frame_and_diagnostic_widths', strobe=1, data=full)
    add('small_with_dirty_geometry', strobe=1, data=packet(fid=77, reason=2, area=255))
    add('idle_after_small')
    add('valid_after_small', strobe=1, data=packet(fid=78, color=1))
    add('demo_final_idle')
    rng = random.Random(SEED)
    for i in range(256):
        x, y = rng.randrange(1200), rng.randrange(640)
        data = packet(fid=rng.getrandbits(32), cfg=rng.getrandbits(16),
                      color=rng.randrange(3), epoch=rng.getrandbits(32),
                      reason=rng.choice((0, 1, 2, 3, 5)),
                      box=(x, x+31, y, y+31), area=rng.randrange(256, 1025))
        data.update(peak_slots=rng.randrange(129), component_count=rng.randrange(4096))
        add('seeded_%03d' % i, rst=int(i % 53 != 0),
            strobe=int(rng.randrange(4) != 0), data=data)
    add('final_idle')
    return vectors


def expected_trace(vectors):
    held = dict.fromkeys((name for name, _ in FIELDS), 0)
    trace = []
    for vector in vectors:
        event = int(bool(vector['rst_n'] and vector['input_strobe']))
        if not vector['rst_n']:
            held = dict.fromkeys(held, 0)
        elif event:
            held = dict(vector['input'])
            if not held['target_valid']:
                held.update(dict.fromkeys(GEOMETRY, 0))
        trace.append(dict(cycle=vector['cycle'], result_strobe=event, **held))
    return trace


def encode(data):
    word = 0
    for name, width in FIELDS:
        value = data[name]
        if not 0 <= value < 1 << width:
            raise ValueError('out-of-range field: ' + name)
        word = (word << width) | value
    return word


def geometry(mask, width, height):
    """Flood fill from input pixels, without observing RTL tables or registers."""
    remaining = {(x, y) for y in range(height) for x in range(width) if mask[y*width+x]}
    regions = []
    while remaining:
        start = remaining.pop()
        stack, points = [start], [start]
        while stack:
            x, y = stack.pop()
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    neighbour = (x+dx, y+dy)
                    if neighbour in remaining:
                        remaining.remove(neighbour)
                        stack.append(neighbour)
                        points.append(neighbour)
        xs, ys = zip(*points)
        regions.append(dict(area=len(points), xmin=min(xs), xmax=max(xs),
                            ymin=min(ys), ymax=max(ys)))
    if not regions:
        return dict(target_valid=0, reject_reason=1, **dict.fromkeys(GEOMETRY, 0))
    best = min(regions, key=lambda r: (-r['area'], r['ymin'], r['xmin']))
    if best['area'] < 256:
        return dict(target_valid=0, reject_reason=2, **dict.fromkeys(GEOMETRY, 0))
    return dict(target_valid=1, reject_reason=0, **best,
                cx=(best['xmin']+best['xmax'])//2, cy=(best['ymin']+best['ymax'])//2)


def chain_vectors():
    width, height = 64, 24
    definitions = [
        ('valid', 10, 1, 0, [(4, 19, 4, 19)]),
        ('empty', 11, 1, 1, []),
        ('largest_of_two', 0xffffffff, 0xffff, 2, [(30, 49, 2, 17), (2, 5, 2, 5)]),
        ('capacity', 0, 0, 0, [(x, x, 5, 5) for x in (0, 4, 8, 12, 16)]),
        ('recovery', 1, 2, 1, [(40, 55, 2, 18)]),
        ('repeated_identity_empty', 1, 2, 1, []),
        ('valid_at_origin', 2, 3, 2, [(0, 15, 0, 15)]),
        ('area_255', 3, 4, 0, [(8, 22, 4, 20)]),
    ]
    frames = []
    for name, fid, cfg, color, boxes in definitions:
        mask = [0] * (width*height)
        for left, right, top, bottom in boxes:
            for y in range(top, bottom+1):
                for x in range(left, right+1):
                    mask[y*width+x] = 1
        expected = geometry(mask, width, height)
        # Capacity contract is independent of geometry: five runs exceed the test's R4.
        if name == 'capacity':
            expected = dict(target_valid=0, reject_reason=3, **dict.fromkeys(GEOMETRY, 0))
        expected.update(frame_id=fid, cfg_id=cfg, target_id=color, capture_epoch=0)
        frames.append(dict(name=name, mask=mask, expected=expected))
    return frames
