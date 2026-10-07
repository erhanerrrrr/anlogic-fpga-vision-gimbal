`timescale 1ns/1ps

// RGB888 grayscale stream, with the same frame contract as video_bypass.
// Gray data, valid and metadata all pass through one register stage.
module video_gray (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        in_valid,
    input  wire [23:0] in_rgb,
    input  wire        in_sof,
    input  wire        in_eol,
    input  wire        in_eof,
    input  wire [10:0] in_x,
    input  wire [10:0] in_y,
    input  wire [31:0] in_source_frame_id,
    output wire        out_valid,
    output wire [23:0] out_rgb,
    output reg         out_sof,
    output reg         out_eol,
    output reg         out_eof,
    output reg  [10:0] out_x,
    output reg  [10:0] out_y,
    output reg  [31:0] out_source_frame_id
);
    reg in_frame;
    wire accept_pixel = in_valid && (in_frame || in_sof);

    rgb_to_gray pixel_pipeline (
        .clk(clk), .rst_n(rst_n),
        .in_valid(accept_pixel), .in_rgb(in_rgb),
        .out_valid(out_valid), .out_rgb(out_rgb)
    );

    // These registers run in parallel with the register inside rgb_to_gray.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            in_frame <= 1'b0;
            out_sof <= 1'b0;
            out_eol <= 1'b0;
            out_eof <= 1'b0;
            out_x <= 11'd0;
            out_y <= 11'd0;
            out_source_frame_id <= 32'd0;
        end
        else begin
            out_sof <= accept_pixel && in_sof;
            out_eol <= accept_pixel && in_eol;
            out_eof <= accept_pixel && in_eof;
            out_x <= accept_pixel ? in_x : 11'd0;
            out_y <= accept_pixel ? in_y : 11'd0;
            out_source_frame_id <= accept_pixel ? in_source_frame_id : 32'd0;
            if (accept_pixel)
                in_frame <= !in_eof;
        end
    end
endmodule
