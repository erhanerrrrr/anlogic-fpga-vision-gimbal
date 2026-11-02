"""Synthesize new observer + text + font, all metadata ports observable."""
import argparse,hashlib,json,re,shutil
from pathlib import Path
from datetime import datetime
from td_runner import run_td
from check_video_display_synthesis import area_count

def main():
    p=argparse.ArgumentParser();p.add_argument('--td',type=Path,required=True);a=p.parse_args()
    root=Path(__file__).resolve().parents[1]
    run=root/'build/calibration_status_synthesis'/datetime.now().strftime('run_%Y%m%d_%H%M%S');run.mkdir(parents=True)
    print(f'Reports: {run}',flush=True)
    files=(root/'b3d_sources.f').read_text().splitlines()+['synthesis/calibration_status_probe.v']
    for name in files:shutil.copy2(root/name,run/Path(name).name)
    result=dict(passed=False,scope='new observer + status text + font + banked observation wrapper, all metadata observed',wrapper_included=True,
        board_tested=False,board_timing_verified=False,provisional_clock_mhz=75,
        source_sha256={name:hashlib.sha256((root/name).read_bytes()).hexdigest() for name in files})
    try:
        (run/'timing.sdc').write_text('create_clock -name pixel_clk -period 13.333 [get_ports {clk}]\n'
            'set_input_delay -clock [get_clocks {pixel_clk}] 0.000 [get_ports {in_* stream_abort c_status_valid sample_* calibration_done calibration_ok cfg_applied pending_valid busy}]\n'
            'set_output_delay -clock [get_clocks {pixel_clk}] 0.000 [get_ports {out_*}]\n'
            'set_false_path -from [get_ports {rst_n}]\n')
        (run/'synth.tcl').write_text('create_project status_check . -family ph1 -device PH1P35MDG324 -speed -3\n'
            'top_module calibration_status_probe\nadd_files {'+' '.join(Path(n).name for n in files)+' timing.sdc}\n'
            'set_param -run syn_1 flow syn_ip_flow off\nset_param -run syn_1 gate pack_seq_in_io off\n'
            'launch_runs syn_1\nwait_run -quiet syn_1\nopen_run syn_1\n'
            'report_area -file area.rpt\nreport_timing_summary -file timing.rpt -ep_num 3 -path_num 1\n'
            'close_project\nputs "B3D_SYNTH_FINISHED"\nexit\n')
        output=run_td(a.td,'source synth.tcl',run,run/'console.log',900)
        syn=run/'status_check_Runs/syn_1'
        assert 'B3D_SYNTH_FINISHED' in output and (syn/'.opt_gate.end.f').exists() and not list(syn.glob('*.error.f'))
        log=(syn/'run.log').read_text(errors='replace');assert not re.search(r'\bERROR:',log)
        result['warnings']=[s for s in log.splitlines() if 'WARNING:' in s]
        area=(run/'area.rpt').read_text(errors='replace')
        result['resources']={n:area_count(area,n) for n in ['reg','lut','slice','eram20k','dsp']}
        result['resources']['latch']=area_count((syn/'status_check_rtl.area').read_text(errors='replace'),'LATCH')
        timing=(run/'timing.rpt').read_text(errors='replace')
        result['timing_ns']={k:float(re.search(r'\b'+k+r':\s*([-\d.]+)ns',timing)[1]) for k in ['SWNS','STNS','HWNS','HTNS']}
        assert all(v>=0 for v in result['timing_ns'].values())
        assert all(result['resources'][k]==0 for k in ['eram20k','dsp','latch'])
        result['passed']=True
        print('PASS: B3d standalone synthesis. '+json.dumps(result['resources']),flush=True)
    finally:(run/'summary.json').write_text(json.dumps(result,indent=2)+'\n')
if __name__=='__main__':main()
