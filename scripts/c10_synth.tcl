# Synthesis-only harness exposes all result fields through a word selector.
if {[catch {
    import_device ph1_35p.db -package PH1P35MDG324 -speed 3
    read_verilog -dir . -top c10_synth_top
    optimize_rtl
    report_area -file c10_rtl.area
    optimize_gate
    report_area -file c10_gate.area
    write_verilog c10_gate.v
    puts "C10_TD_SYNTH_COMPLETE"
} message]} {
    puts "C10_TD_SYNTH_FAILED: $message"
    exit 1
}
exit 0
