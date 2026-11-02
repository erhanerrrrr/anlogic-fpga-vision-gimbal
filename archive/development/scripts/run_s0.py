"""S0 software fixtures and interface checker; Python 3.7+, standard library only.

This is NOT an RTL simulation or a C1 classifier verification.
"""
import argparse
import csv
import json
import platform
import random
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COLORS = {'red': (200, 40, 40), 'green': (40, 200, 40), 'blue': (40, 40, 200)}


def pixels(case):
    for y in range(case['height']):
        for x in range(case['width']):
            rgb = (0, 0, 0)
            for left, top, right, bottom, r, g, b in case['rectangles']:
                if left <= x <= right and top <= y <= bottom:
                    rgb = (r, g, b)
            yield x, y, rgb


def stream(cases, seed, blanking=True):
    rng = random.Random(seed)
    for case in cases:
        for x, y, rgb in pixels(case):
            yield (1, x, y, *rgb, int(x == 0 and y == 0),
                   int(x == case['width'] - 1),
                   int(x == case['width'] - 1 and y == case['height'] - 1), case['frame_id'])
            if blanking and x == case['width'] - 1:
                for _ in range(rng.randint(1, 4)):
                    yield (0, 0, 0, 0, 0, 0, 0, 0, 0, case['frame_id'])
        if blanking:
            for _ in range(rng.randint(2, 8)):
                yield (0, 0, 0, 0, 0, 0, 0, 0, 0, case['frame_id'])


def check(records, cases):
    """Independent raster arithmetic and fixed expected statistics, not generator output."""
    frame = index = cycles = valid_count = 0
    stats = {}
    results = []
    bound = sum(c['width'] * c['height'] + 4 * c['height'] + 8 for c in cases)
    for rec in records:
        cycles += 1
        if cycles > bound:
            raise ValueError('stream exceeded bounded cycle count')
        valid, x, y, r, g, b, sof, eol, eof, fid = rec
        if valid not in (0, 1) or any(v not in (0, 1) for v in (sof, eol, eof)):
            raise ValueError('invalid control bit')
        if not valid:
            if sof or eol or eof:
                raise ValueError('marker during blanking')
            continue
        if frame >= len(cases):
            raise ValueError('unexpected extra pixel')
        c = cases[frame]
        w, h = c['width'], c['height']
        ey, ex = divmod(index, w)
        expected_control = (ex, ey, int(index == 0), int(index % w == w-1), int(index == w*h-1), c['frame_id'])
        if (x, y, sof, eol, eof, fid) != expected_control:
            raise ValueError('coordinate/frame/marker mismatch at {}'.format(index))
        if any(v < 0 or v > 255 for v in (r, g, b)):
            raise ValueError('RGB out of range')
        # Independently address a rectangle by half-open intervals.
        expected_rgb = (0, 0, 0)
        for box in c['rectangles']:
            if x in range(box[0], box[2]+1) and y in range(box[1], box[3]+1):
                expected_rgb = tuple(box[4:7])
        if (r, g, b) != expected_rgb:
            raise ValueError('RGB mismatch')
        for color, value in COLORS.items():
            if (r, g, b) == value:
                if color not in stats:
                    stats[color] = [0, x, y, x, y]
                s = stats[color]
                s[:] = [s[0]+1, min(s[1], x), min(s[2], y), max(s[3], x), max(s[4], y)]
        index += 1
        valid_count += 1
        if index == w*h:
            actual = {}
            for color in COLORS:
                s = stats.get(color)
                actual[color] = s + [(s[1]+s[3])//2, (s[2]+s[4])//2] if s else None
            if actual != c['expected']:
                raise ValueError('independent geometry mismatch: ' + c['name'])
            results.append({'case': c['name'], 'source_frame_id': fid, 'pixels': index, 'geometry': actual})
            frame += 1
            index = 0
            stats = {}
    if frame != len(cases) or index:
        raise ValueError('incomplete/missing frame')
    return {'cycles': cycles, 'valid_pixels': valid_count, 'frames': results}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--inject-error', choices=['rgb', 'coordinate', 'marker', 'frame_id', 'truncated'])
    args = parser.parse_args()
    fixture = json.loads((ROOT/'tests/fixtures/s0/cases.json').read_text(encoding='utf-8'))
    cases = fixture['cases']
    seed = fixture['seed']
    if args.inject_error:
        records = list(stream([cases[3]], seed))
        if args.inject_error == 'truncated':
            records = records[:20]
        else:
            field = {'rgb':3, 'coordinate':1, 'marker':6, 'frame_id':9}[args.inject_error]
            row = list(records[0])
            row[field] = 1-row[field] if field == 6 else row[field]+1
            records[0] = tuple(row)
        check(records, [cases[3]])
        raise RuntimeError('injected error was not rejected')
    out = ROOT/'reports/s0/generated'
    out.mkdir(parents=True, exist_ok=True)
    result = check(stream(cases, seed), cases)
    # Repeat the two 720p frames with another legal blanking configuration.
    alternate = check(stream(cases[-2:], seed+1), cases[-2:])
    for c in cases:
        with (out/(c['name']+'.ppm')).open('wb') as f:
            f.write('P6\n{} {}\n255\n'.format(c['width'], c['height']).encode('ascii'))
            f.write(bytearray(v for _, _, rgb in pixels(c) for v in rgb))
    with (out/'small_rgb_stream.csv').open('w', newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        writer.writerow(['pixel_valid','x','y','r','g','b','sof','eol','eof','source_frame_id'])
        writer.writerows(stream([cases[3]], seed))
    summary = {'stage':'S0-C', 'result':'software_fixture_checks_passed',
               'interface_version':fixture['interface_version'], 'python':platform.python_version(),
               'seed':seed, 'primary':result, 'alternate_720p':alternate,
               'rtl_simulation':'not_run_no_rtl_in_S0_C', 'td':'not_run',
               'team_acceptance':'pending_A_B', 'hardware':'not_tested'}
    (out/'summary.json').write_text(json.dumps(summary, indent=2, ensure_ascii=False)+'\n', encoding='utf-8')
    print('PASS: {} cases; {} primary valid pixels; alternate two 720p frames checked'.format(len(cases), result['valid_pixels']))
    print('Outputs: ' + str(out))


if __name__ == '__main__':
    try:
        main()
    except Exception as exc:
        print('FAIL: ' + str(exc), file=sys.stderr)
        sys.exit(1)
