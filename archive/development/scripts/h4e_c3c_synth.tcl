# Isolated controller synthesis; full-width input staging and output read mux stay observable.
if {[catch {
    import_device ph1_35p.db -package PH1P35MDG324 -speed 3
    read_verilog -dir . -top h4e_c3c_synth_top
    optimize_rtl
    report_area -file h4e_c3c_rtl.area
    optimize_gate
    report_area -file h4e_c3c_gate.area
    write_verilog h4e_c3c_gate.v
    puts "H4E_C3C_TD_SYNTH_COMPLETE"
} message]} {
    puts "H4E_C3C_TD_SYNTH_FAILED: $message"
    exit 1
}
exit 0
