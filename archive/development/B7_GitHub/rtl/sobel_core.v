`timescale 1ns/1ps

// One registered stage, one 3x3 gray patch per valid cycle.
// Same packed byte order as window_3x3: p00,p01,p02,p10,...,p22.
// The caller supplies the threshold (initial project setting: 11'd128).
module sobel_core (
    input wire clk,
    input wire rst_n,
    input wire in_valid,
    input wire [71:0] in_window,
    input wire [10:0] in_threshold,
    output reg out_valid,
    output reg signed [10:0] out_gx,
    output reg signed [10:0] out_gy,
    output reg [10:0] out_magnitude,
    output reg [7:0] out_edge
);
    wire [7:0] p00=in_window[71:64], p01=in_window[63:56], p02=in_window[55:48];
    wire [7:0] p10=in_window[47:40], p12=in_window[31:24];
    wire [7:0] p20=in_window[23:16], p21=in_window[15:8], p22=in_window[7:0];

    // Explicit 10-bit extensions: each weighted side is at most 1020.
    wire [9:0] left_sum   = {2'b0,p00}+{1'b0,p10,1'b0}+{2'b0,p20};
    wire [9:0] right_sum  = {2'b0,p02}+{1'b0,p12,1'b0}+{2'b0,p22};
    wire [9:0] top_sum    = {2'b0,p00}+{1'b0,p01,1'b0}+{2'b0,p02};
    wire [9:0] bottom_sum = {2'b0,p20}+{1'b0,p21,1'b0}+{2'b0,p22};
    wire signed [10:0] gx = $signed({1'b0,right_sum})-$signed({1'b0,left_sum});
    wire signed [10:0] gy = $signed({1'b0,bottom_sum})-$signed({1'b0,top_sum});
    wire [10:0] abs_gx = gx[10] ? -gx : gx;
    wire [10:0] abs_gy = gy[10] ? -gy : gy;
    wire [10:0] magnitude = abs_gx + abs_gy;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_valid <= 1'b0;
            out_gx <= 11'sd0;
            out_gy <= 11'sd0;
            out_magnitude <= 11'd0;
            out_edge <= 8'd0;
        end else begin
            out_valid <= in_valid;
            out_gx <= in_valid ? gx : 11'sd0;
            out_gy <= in_valid ? gy : 11'sd0;
            out_magnitude <= in_valid ? magnitude : 11'd0;
            out_edge <= (in_valid && magnitude >= in_threshold) ? 8'd255 : 8'd0;
        end
    end
endmodule
