"""Standalone B1b synthesis, including a register-loading/probe wrapper."""
import argparse,hashlib,json,re,shutil
from pathlib import Path
from datetime import datetime
from td_runner import run_td
from check_video_display_synthesis import area_count

def main():
    p=argparse.ArgumentParser();p.add_argument('--td',type=Path,required=True);a=p.parse_args()
    root=Path(__file__).resolve().parents[1]
    run=root/'build/target_info_synthesis'/datetime.now().strftime('run_%Y%m%d_%H%M%S')
    (run/'src').mkdir(parents=True);print(f'Reports: {run}',flush=True)
    result=dict(passed=False,board_tested=False,board_timing_verified=False,
        wrapper_included=True,clock_mhz_provisional=75,source_sha256={})
    try:
        files=(root/'b1b_sources.f').read_text().splitlines()+['synthesis/target_info_probe.v']
        for name in files:
            shutil.copy2(root/name,run/'src'/Path(name).name)
            result['source_sha256'][name]=hashlib.sha256((root/name).read_bytes()).hexdigest()
        (run/'timing.sdc').write_text('create_clock -name pixel_clk -period 13.333 [get_ports {clk}]\n'
            'set_input_delay -clock [get_clocks {pixel_clk}] 0.000 [get_ports {in_*}]\n'
            'set_output_delay -clock [get_clocks {pixel_clk}] 0.000 [get_ports {out_*}]\n'
            'set_false_path -from [get_ports {rst_n}]\n')
        (run/'synth.tcl').write_text('create_project target_info_check . -family ph1 -device PH1P35MDG324 -speed -3\n'
            'top_module target_info_probe\nadd_files {'+' '.join('src/'+Path(n).name for n in files)+'}\n'
            'add_files timing.sdc\nset_param -run syn_1 flow syn_ip_flow off\nset_param -run syn_1 gate pack_seq_in_io off\n'
            'launch_runs syn_1\nwait_run -quiet syn_1\nopen_run syn_1\n'
            'report_area -file area.rpt\nreport_timing_summary -file timing.rpt -ep_num 3 -path_num 1\n'
            'write_verilog mapped.v\nclose_project\nputs "B1B_SYNTH_FINISHED"\nexit\n')
        out=run_td(a.td,'source synth.tcl',run,run/'console.log',900)
        syn=run/'target_info_check_Runs/syn_1'
        if 'B1B_SYNTH_FINISHED' not in out or not (syn/'.opt_gate.end.f').exists() or list(syn.glob('*.error.f')):
            raise RuntimeError('Synthesis not confirmed')
        run_log=(syn/'run.log').read_text(errors='replace')
        result['warnings']=[line for line in run_log.splitlines() if re.search(r'\b(?:CRITICAL-)?WARNING:',line)]
        if re.search(r'\bERROR:',run_log):raise RuntimeError('Synthesis log contains errors')
        area=(run/'area.rpt').read_text(errors='replace')
        result['resources']={n:area_count(area,n) for n in ('reg','eram20k','dsp','slice','lut')}
        result['resources']['latch']=area_count((syn/'target_info_check_rtl.area').read_text(errors='replace'),'LATCH')
        timing=(run/'timing.rpt').read_text(errors='replace')
        result['timing_ns']={k:float(re.search(r'\b'+k+r':\s*([-\d.]+)ns',timing)[1]) for k in ('SWNS','STNS','HWNS','HTNS')}
        result['timing_passed']=all(v>=0 for v in result['timing_ns'].values())
        baseline=json.loads((root/'reports/b1a_20261010/synthesis_summary.json').read_text())
        result['resource_delta_from_b1a']={k:v-baseline['resources'][k] for k,v in result['resources'].items()}
        result['passed']=result['resources']['latch']==0 and result['timing_passed'] and result['resources']['eram20k']==0 and result['resources']['dsp']==0
        if not result['passed']:raise RuntimeError('Resource/timing check failed; inspect summary')
        print('PASS: B1b standalone synthesis. '+json.dumps(result['resources']),flush=True)
    finally:(run/'summary.json').write_text(json.dumps(result,indent=2)+'\n')
if __name__=='__main__':main()
