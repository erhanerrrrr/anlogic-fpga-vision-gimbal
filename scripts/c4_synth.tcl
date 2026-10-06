# Synthesis-only harness exposes all result fields through a word selector.
if {[catch {
    import_device ph1_35p.db -package PH1P35MDG324 -speed 3
    read_verilog -dir . -top c4_synth_top
    optimize_rtl
    report_area -file c4_rtl.area
    optimize_gate
    report_area -file c4_gate.area
    write_verilog c4_gate.v
    puts "C4_TD_SYNTH_COMPLETE"
} message]} {
    puts "C4_TD_SYNTH_FAILED: $message"
    exit 1
}
exit 0
