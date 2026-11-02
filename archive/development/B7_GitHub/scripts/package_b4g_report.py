"""Audit the confirmed B4g runs and write a small Git-friendly handoff report."""
import hashlib
import json
import shutil
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
SIM=ROOT/'build/b4g_native720_performance/run_20261020_132405'
SYN=ROOT/'build/b4g_closed_loop_synthesis/run_20261020_141614_211663'
DEST=ROOT/'reports/b4g_20261020'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    source_names=(ROOT/'b4g_sources.f').read_text().splitlines()
    if len(source_names)!=len(set(source_names)) or not source_names:
        raise RuntimeError('Duplicate or missing explicit source')
    sim=json.loads((SIM/'summary.json').read_text())
    syn=json.loads((SYN/'summary.json').read_text())
    if not sim['passed'] or not syn['passed']:
        raise RuntimeError('Simulation or synthesis did not pass')
    if set(source_names)!=(set(sim['source_sha256'])-{'run_b4g.py'}):
        raise RuntimeError('Explicit source list differs from the simulated list')
    for name in source_names:
        if not (ROOT/name).is_file() or digest(ROOT/name)!=sim['source_sha256'][name]:
            raise RuntimeError(f'Changed or missing simulated source: {name}')
    for name,expected in syn['source_sha256'].items():
        if not (ROOT/name).is_file() or digest(ROOT/name)!=expected:
            raise RuntimeError(f'Changed or missing synthesized source: {name}')
    if digest(ROOT/'run_b4g.py')!=sim['source_sha256']['run_b4g.py']:
        raise RuntimeError('Changed simulation runner')
    sim_log=(SIM/'simulation.log').read_text(errors='replace')
    compile_log=(SIM/'compile.log').read_text(errors='replace')
    if ('PASS B4G_NATIVE720_PERFORMANCE:' not in sim_log or
        'Errors: 0, Warnings: 0' not in sim_log or
        'Errors: 0, Warnings: 0' not in compile_log):
        raise RuntimeError('Simulation log does not confirm clean PASS')
    if any(item['pixel_differences']!=0 for item in sim['cases']):
        raise RuntimeError('Pixel mismatch in simulation summary')
    if len(sim['cases'])!=2 or sum(item['pixels'] for item in sim['cases'])!=1843200:
        raise RuntimeError('Wrong native-resolution frame count')
    if (syn['resources']['slice']!=9339 or syn['resources']['eram20k']!=10 or
        syn['resources']['dsp']!=0 or syn['resources']['latch']!=0 or
        min(syn['timing_ns'].values())<0):
        raise RuntimeError('Unexpected synthesis resources or timing')
    if 'B4G_SYNTH_FINISHED' not in (SYN/'console.log').read_text(errors='replace'):
        raise RuntimeError('Synthesis finish marker missing')
    DEST.mkdir(parents=True,exist_ok=True)
    for name in ('01_actual.png','01_reference.png','01_diff.png'):
        shutil.copy2(SIM/name,DEST/name)
    manifest={
        'stage':'B4g','date':'2026-10-20',
        'user_simulation_confirmed':True,'user_synthesis_confirmed':True,
        'simulation_run':str(SIM.relative_to(ROOT)).replace('\\','/'),
        'synthesis_run':str(SYN.relative_to(ROOT)).replace('\\','/'),
        'resolution':[1280,720],'frames':2,'pixels':1843200,
        'pixel_differences':0,'modelsim_errors':0,'modelsim_warnings':0,
        'peak_fifo_used':1284,
        'resources':syn['resources'],'provisional_75mhz_timing_ns':syn['timing_ns'],
        'approx_delta_from_b4c_comparable_wrapper':syn['approx_delta_from_b4c_comparable_wrapper'],
        'synthetic_capture_identity':True,'synthetic_latency':True,'synthetic_rates':True,
        'full_board_timing_verified':False,'bit_generated':False,'board_tested':False,
        'source_sha256':{name:sim['source_sha256'][name] for name in source_names},
        'additional_sha256':{
            name:digest(ROOT/name) for name in
            ('b4g_sources.f','run_b4g.py','B4g_README.md','docs/B4g_to_A_handoff.md',
             'docs/B4g_GitHub_upload_checklist.md',
             'synthesis/check_b4g_closed_loop_synthesis.py')},
        'sample_image_sha256':{name:digest(DEST/name) for name in
                               ('01_actual.png','01_reference.png','01_diff.png')},
    }
    (DEST/'delivery_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    (DEST/'verification.txt').write_text(
        'B4g user-confirmed verification, 2026-10-20\n'
        'ModelSim ALTERA vlog 10.3c: PASS B4G_NATIVE720_PERFORMANCE; '
        '2 x 1280 x 720, 1,843,200 pixels, 0 differences; '
        'compile/simulation errors 0 warnings 0; FIFO peak 1284.\n'
        'Tang Dynasty 6.2.168116: PASS B4g closed-loop standalone synthesis; '
        '8904 reg, 13694 LUT, 9339 Slice, 10 ERAM, 0 DSP, 0 latch; '
        'provisional 75 MHz SWNS +1.071 ns, HWNS +0.292 ns.\n'
        'Inputs for capture identity, latency and rates were synthetic. '
        'No full-board timing, bit or board test.\n',encoding='utf-8')
    print('PASS: B4g handoff package audited:',DEST)


if __name__=='__main__':
    main()
