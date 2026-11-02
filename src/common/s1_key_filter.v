`timescale 1ns/1ps
module s1_key_filter #(
    parameter integer DEBOUNCE_US = 20000
) (
    input wire clk,
    input wire reset,
    input wire us_tick,
    input wire key_n,
    output reg down = 1'b0,
    output reg pressed = 1'b0
);
    // Synchronize before debounce; only the port -> first stage is excepted in SDC.
    (* async_reg = "true" *) reg sync_meta = 1'b1;
    (* async_reg = "true" *) reg sync_safe = 1'b1;
    localparam integer COUNT_BITS = (DEBOUNCE_US > 1) ? $clog2(DEBOUNCE_US) : 1;
    reg [COUNT_BITS-1:0] count = 0;
    always @(posedge clk) begin
        sync_meta <= key_n;
        sync_safe <= sync_meta;
        pressed <= 1'b0;
        if (reset) begin
            down <= 1'b0;
            count <= 0;
        end else if (us_tick) begin
            if ((!sync_safe) == down) count <= 0;
            else if (count == DEBOUNCE_US-1) begin
                down <= !sync_safe;
                pressed <= !sync_safe;
                count <= 0;
            end else count <= count + 1'b1;
        end
    end
endmodule
