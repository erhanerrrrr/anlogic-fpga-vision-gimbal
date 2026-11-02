create_clock -name {sys_clk_50m} -period 20.000 -waveform {0.000 10.000} [get_ports {I_sys_clk}]
create_clock -name {mipi_rx_ck_pad} -period 4.167 -waveform {0.000 2.083} [get_nets {IO_rx_clk_pad_p}]

derive_clocks

rename_clock -name {pll_clk_100m} [get_clocks {u_PLL/ph1p_phy_pll_wrapper_25a56e5ce2f9_Inst/u_PH1P_PHY_PLL.clkc[0]}]
rename_clock -name {pll_clk_24m} [get_clocks {u_PLL/ph1p_phy_pll_wrapper_25a56e5ce2f9_Inst/u_PH1P_PHY_PLL.clkc[1]}]
rename_clock -name {HDMI_PIXEL_CLK} [get_clocks {u_PLL/ph1p_phy_pll_wrapper_25a56e5ce2f9_Inst/u_PH1P_PHY_PLL.clkc[4]}]
rename_clock -name {HDMI_SERIAL_CLK} [get_clocks {u_PLL/ph1p_phy_pll_wrapper_25a56e5ce2f9_Inst/u_PH1P_PHY_PLL.clkc[5]}]

rename_clock -name {MIPI_RX_BYTE_CLK} [get_clocks {u_mipi_dphy_rx_ph1p_mipiio_wrapper/u_ph1p_mipiio_rx_wrapper/u_PH1P_LOGIC_DPHY_MIPI_RX.o_fabric_div4_8_clk}]


set_clock_groups -asynchronous \
    -group [get_clocks {mipi_rx_ck_pad MIPI_RX_BYTE_CLK}] \
    -group [get_clocks {sys_clk_50m pll_clk_100m pll_clk_24m HDMI_PIXEL_CLK HDMI_SERIAL_CLK}] \
    -group [get_clocks {u_ph1p35_324_ddr_wrapper/u_ddr2/ddr_clk u_ph1p35_324_ddr_wrapper/u_ddr2/usr_clk}]
# asynchronous keys, asynchronous servo receivers.
set_false_path -from [get_ports {I_key_n[*]}]
# Servo inputs do not sample on the FPGA's 100MHz clock. Bound clock-to-pin
# propagation to 100ns (10% of the 1us PWM resolution), rather than claiming
# an external 5ns synchronous setup requirement. This is a design budget,
# not a servo VIH/VIL or input setup-time specification.
set_output_delay -clock pll_clk_100m -max 0.000 [get_ports {O_pan_pwm O_tilt_pwm}]
set_output_delay -clock pll_clk_100m -min 0.000 [get_ports {O_pan_pwm O_tilt_pwm}]
set_max_delay -datapath_only 100.000 -from [get_clocks {pll_clk_100m}] -to [get_ports {O_pan_pwm O_tilt_pwm}]

# switch inputs are asynchronous and pass two synchronizer stages.
set_false_path -from [get_ports {I_sw[*]}]
# Local display/buzzer are asynchronous loads, not synchronous receivers.
# 100ns propagation budget is small relative to the 1us display blanking.
set_output_delay -clock pll_clk_100m -max 0.000 [get_ports {O_led[*] O_dig[*] O_sel[*] O_buzzer_n O_source_mark O_result_mark}]
set_output_delay -clock pll_clk_100m -min 0.000 [get_ports {O_led[*] O_dig[*] O_sel[*] O_buzzer_n O_source_mark O_result_mark}]
set_max_delay -datapath_only 100.000 -from [get_clocks {pll_clk_100m}] -to [get_ports {O_led[*] O_dig[*] O_sel[*] O_buzzer_n O_source_mark O_result_mark}]

# UART receiver is asynchronous. Preserve original outputs' budgets.
set_output_delay -clock pll_clk_100m -max 0.000 [get_ports {O_uart_tx}]
set_output_delay -clock pll_clk_100m -min 0.000 [get_ports {O_uart_tx}]
set_max_delay -datapath_only 100.000 -from [get_clocks {pll_clk_100m}] -to [get_ports {O_uart_tx}]

# the ONLY 24 MHz <-> pixel crossings are bundled two-phase mailboxes
# (meter_cdc and ae_status_cdc). Their data remains fixed through the ack;
# destination capture waits for two request synchronizer stages. Bound all
# these transfer paths to 10 ns, less than one 13.333 ns pixel period, rather
# than the unrelated fractional-PLL edge coincidence (0.653/0.674 ns).
# All same-domain timing checks and every original clock remain unchanged.
set_max_delay -datapath_only 10.000 -from [get_clocks {pll_clk_24m}] -to [get_clocks {HDMI_PIXEL_CLK}]
set_max_delay -datapath_only 10.000 -from [get_clocks {HDMI_PIXEL_CLK}] -to [get_clocks {pll_clk_24m}]
