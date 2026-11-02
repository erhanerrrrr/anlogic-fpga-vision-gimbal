# Run by check_video_display_synthesis.py in a fresh source snapshot directory.
if {[catch {
    create_project video_display_check . -family ph1 -device PH1P35MDG324 -speed -3
    top_module video_display_720p_probe_top
    add_files {src/rgb_to_gray.v src/video_gray.v src/window_3x3.v src/sobel_core.v src/edge_raster.v src/video_edge.v src/video_rgb_edge_align.v src/frame_mode_ctrl.v src/rgb_bypass.v src/video_bypass.v src/video_modes.v src/button_events.v src/button_mode_request.v src/video_modes_buttons.v src/video_static_osd.v src/video_display.v src/anlogic_logo_rom.v src/osd_char_lib.v src/video_display_720p_probe_top.v}
    add_files video_display_synthesis.sdc
    # Normal synthesis maps logical RAMs to physical ERAM resources.
    # The observation wrapper fits the package IO count without dropping data.
    set_param -run syn_1 flow syn_ip_flow off
    set_param -run syn_1 gate pack_seq_in_io off
    launch_runs syn_1
    wait_run -quiet syn_1

    if {[llength [glob -nocomplain -directory video_display_check_Runs/syn_1 *.error.f]] > 0} {
        error "TD reported a failed synthesis step"
    }
    foreach artifact {.opt_gate.end.f video_display_check_gate.db} {
        if {![file exists video_display_check_Runs/syn_1/$artifact]} {
            error "Missing synthesis result: $artifact"
        }
    }
    open_run syn_1
    report_area -file video_display_area.rpt
    report_timing_summary -file video_display_timing.rpt -ep_num 3 -path_num 1
    write_verilog video_display_mapped.v
    close_project
} failure]} {
    puts stderr "FAIL: button-controlled four-mode and OSD synthesis failed: $failure"
    exit 1
}
puts "PASS: button-controlled four-mode and OSD video synthesis completed."
exit 0
