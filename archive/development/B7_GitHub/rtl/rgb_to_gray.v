`timescale 1ns/1ps

// One registered RGB888 grayscale stage; accepts one pixel per clock.
// Y = floor((77*R + 150*G + 29*B + 128) / 256).
module rgb_to_gray (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        in_valid,
    input  wire [23:0] in_rgb,
    output reg         out_valid,
    output reg  [23:0] out_rgb
);
    // Explicit unsigned 16-bit operands prevent truncating the products.
    wire [15:0] red_weighted   = {8'd0, in_rgb[23:16]} * 16'd77;
    wire [15:0] green_weighted = {8'd0, in_rgb[15:8]}  * 16'd150;
    wire [15:0] blue_weighted  = {8'd0, in_rgb[7:0]}   * 16'd29;
    // Maximum: (77+150+29)*255 + 128 = 65408, which fits in 16 bits.
    wire [15:0] rounded_sum = red_weighted + green_weighted + blue_weighted + 16'd128;
    wire [7:0] gray = rounded_sum[15:8];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_valid <= 1'b0;
            out_rgb <= 24'd0;
        end
        else begin
            out_valid <= in_valid;
            out_rgb <= in_valid ? {gray, gray, gray} : 24'd0;
        end
    end
endmodule
