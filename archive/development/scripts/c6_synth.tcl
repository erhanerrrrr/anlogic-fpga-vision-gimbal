# Synthesis-only harness exposes all result fields through a word selector.
if {[catch {
    import_device ph1_35p.db -package PH1P35MDG324 -speed 3
    read_verilog -dir . -top c6_synth_top
    optimize_rtl
    report_area -file c6_rtl.area
    optimize_gate
    report_area -file c6_gate.area
    write_verilog c6_gate.v
    puts "C6_TD_SYNTH_COMPLETE"
} message]} {
    puts "C6_TD_SYNTH_FAILED: $message"
    exit 1
}
exit 0
