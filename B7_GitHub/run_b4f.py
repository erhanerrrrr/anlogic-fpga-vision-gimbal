"""Compare the B4f ModelSim panel with an independent text/image reference."""
import argparse
import hashlib
import json
import shutil
import sys
from datetime import datetime
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / 'scripts'))
from b1_tools import simulate

FONT = json.loads((ROOT / 'assets/osd/target_font_5x7.json').read_text())
WIDTH, HEIGHT = 304, 112
CASES = [
    (None, None, None, None, False),
    (6000, 5994, 2997, 0x1A2B3C4D, True),
    (65535, 0, 1, 0xFFFFFFFF, True),
    ('OVER', None, 1234, 0, False),
    (1234, 4567, 890, 7, False),
]


def glyph(image, top, col, char, color):
    x0 = col * 16
    if char == '/':
        for y in range(1, 15):
            x = 14 - (y - 1)
            image[top+y, x0+x:x0+x+2] = color
    elif char == '.':
        image[top+12:top+15, x0+6:x0+10] = color
    else:
        for gy, row in enumerate(FONT.get(char, ['00000'] * 7)):
            for gx, on in enumerate(row):
                if on == '1':
                    image[top+1+gy*2:top+3+gy*2,
                          x0+3+gx*2:x0+5+gx*2] = color


def rate(value):
    if value is None:
        return 'N/A   '
    if value == 'OVER':
        return 'OVER  '
    return f'{value // 100:03d}.{value % 100:02d}'


def reference(case):
    source, display, result, fault, simulated = case
    image = np.full((HEIGHT, WIDTH, 3), 16, dtype=np.uint8)
    lines = [
        'SRC FPS:' + rate(source),
        'DSP FPS:' + rate(display),
        'RES FPS:' + rate(result),
        'ERR HEX:' + ('N/A     ' if fault is None else f'{fault:08X}'),
        'SIM INPUT' if simulated else '',
    ]
    for top, line in zip((0, 24, 48, 72, 96), lines):
        if not line:
            continue
        image[top:top+16] = 32
        for col, char in enumerate(line):
            glyph(image, top, col, char, (255, 255, 0) if top == 96 else (0, 255, 255))
    return image


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--modelsim', type=Path, required=True)
    args = parser.parse_args()
    sources = (ROOT / 'b4f_sources.f').read_text().splitlines()
    run = ROOT / 'build/b4f_performance_text' / datetime.now().strftime('run_%Y%m%d_%H%M%S')
    run.mkdir(parents=True, exist_ok=True)
    summary = {
        'stage': 'B4f', 'passed': False, 'synthetic_input': True,
        'provisional_rate_interface': True, 'board_tested': False,
        'cases': [], 'source_sha256': {
            name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
            for name in [*sources, 'run_b4f.py']
        },
    }
    print('Reports:', run, flush=True)
    try:
        for name in sources:
            shutil.copy2(ROOT / name, run / Path(name).name)
        log = simulate(args.modelsim, run, [Path(name).name for name in sources],
                       'tb_b4f_performance_text', 'PASS B4F_PERFORMANCE_TEXT:', timeout=1200)
        if 'Errors: 0, Warnings: 0' not in (run / 'compile.log').read_text():
            raise RuntimeError('ModelSim compile errors or warnings')
        if 'Errors: 0, Warnings: 0' not in log:
            raise RuntimeError('ModelSim errors or warnings')
        raw = np.fromfile(run / 'actual.rgb', dtype=np.uint8)
        expected_size = len(CASES) * HEIGHT * WIDTH * 3
        if raw.size != expected_size:
            raise RuntimeError(f'Actual bytes {raw.size}, expected {expected_size}')
        actual = raw.reshape(len(CASES), HEIGHT, WIDTH, 3)
        for index, case in enumerate(CASES):
            expected = reference(case)
            diff = np.any(actual[index] != expected, axis=2)
            mismatch = int(diff.sum())
            Image.fromarray(actual[index]).save(run / f'{index:02d}_actual.png')
            Image.fromarray(expected).save(run / f'{index:02d}_reference.png')
            Image.fromarray((diff * 255).astype(np.uint8)).save(run / f'{index:02d}_diff.png')
            summary['cases'].append({'frame': index, 'pixels': WIDTH * HEIGHT,
                                     'pixel_differences': mismatch})
            if mismatch:
                raise RuntimeError(f'frame {index}: {mismatch} pixels differ; '
                                   f'first {np.argwhere(diff)[:10].tolist()}')
        summary['passed'] = True
        print('PASS: B4f performance OSD image, frame snapshot and pixel metadata checks completed.',
              flush=True)
    finally:
        (run / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
