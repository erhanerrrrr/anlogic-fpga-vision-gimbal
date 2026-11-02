from pathlib import Path
import subprocess
r=Path(__file__).resolve().parent
names=['h3d3_display_path.v','h3d2_mixer.v','h4e_region_select.v','h4c_fill_metrics.v','anlogic_logo_rom.v','display_raster_adapter.v','color_classifier_runtime.v','mask_frame_stats.v','mask_target_result.v','target_result_pack.v','mask_majority_3x3.v','mask_denoised_result.v','vtc/uivtc.v']
cmds=[['iverilog','-g2012','-s','tb_h4e','-o','tb_h4e.vvp','tb_h4e.v']+['user_source/hdl_source/'+n for n in names],['vvp','tb_h4e.vvp']]
with (r/'h4e_simulation.log').open('w') as log:
    for cmd in cmds:
        p=subprocess.run(cmd,cwd=r,stdout=log,stderr=subprocess.STDOUT,timeout=1800)
        log.flush()
        if p.returncode:raise RuntimeError('Pipeline failed: inspect h4e_simulation.log')
print('H4E pipeline completed; inspect h4e_simulation.log')
