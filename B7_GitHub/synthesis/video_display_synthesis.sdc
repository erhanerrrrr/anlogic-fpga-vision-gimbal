# Standalone provisional 75 MHz budget; not a board-level timing contract.
# The runner replaces the period in the build copy when --clock-mhz is given.
create_clock -name pixel_clk -period 13.333 [get_ports {clk}]
set_input_delay -clock [get_clocks {pixel_clk}] 0.000 [get_ports {in_*}]
set_output_delay -clock [get_clocks {pixel_clk}] 0.000 [get_ports {out_*}]
# Reset release synchronization belongs to eventual board-level integration.
set_false_path -from [get_ports {rst_n}]

# Raw asynchronous pins: exclude only paths launched by these ports.
# The first-to-second synchronizer stage remains timed by pixel_clk.
set_false_path -from [get_ports {buttons_async[*]}]
