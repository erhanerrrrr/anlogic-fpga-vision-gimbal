# Run in a staging directory containing the two RTL source files.
# Device settings match the provided SC500CS Lab1 example; no board pins assigned.
if {[catch {
    import_device ph1_35p.db -package PH1P35MDG324 -speed 3
    read_verilog -dir . -top color_mask_stream
    optimize_rtl
    report_area -file c2_rtl.area
    optimize_gate
    report_area -file c2_gate.area
    write_verilog c2_gate.v
    puts "C2_TD_SYNTH_COMPLETE"
} message]} {
    puts "C2_TD_SYNTH_FAILED: $message"
    exit 1
}
exit 0
