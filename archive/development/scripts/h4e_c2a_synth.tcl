# Isolated packet synthesis; full-width input staging and output read mux stay observable.
if {[catch {
    import_device ph1_35p.db -package PH1P35MDG324 -speed 3
    read_verilog -dir . -top h4e_c2a_synth_top
    optimize_rtl
    report_area -file h4e_c2a_rtl.area
    optimize_gate
    report_area -file h4e_c2a_gate.area
    write_verilog h4e_c2a_gate.v
    puts "H4E_C2A_TD_SYNTH_COMPLETE"
} message]} {
    puts "H4E_C2A_TD_SYNTH_FAILED: $message"
    exit 1
}
exit 0
