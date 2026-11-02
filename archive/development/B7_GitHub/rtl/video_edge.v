`timescale 1ns/1ps

// RGB -> gray -> interior windows -> Sobel -> complete binary edge raster.
// WIDTH/HEIGHT >= 3; the input contract is the existing one-pixel raster.
// Output rows are contiguous but inter-row gaps may differ from the input.
module video_edge #(
    parameter integer WIDTH=16,
    parameter integer HEIGHT=12,
    parameter [10:0] THRESHOLD=11'd128
) (
    input wire clk, rst_n,
    input wire in_valid,
    input wire [23:0] in_rgb,
    input wire in_sof, in_eol, in_eof,
    input wire [10:0] in_x, in_y,
    input wire [31:0] in_source_frame_id,
    output wire out_valid,
    output wire [23:0] out_rgb,
    output wire out_sof, out_eol, out_eof,
    output wire [10:0] out_x, out_y,
    output wire [31:0] out_source_frame_id,
    output wire out_error
);
    wire gray_valid, gray_sof, gray_eol, gray_eof;
    wire [23:0] gray_rgb;
    wire [10:0] gray_x, gray_y;
    wire [31:0] gray_id;
    video_gray gray (
        .clk(clk), .rst_n(rst_n), .in_valid(in_valid), .in_rgb(in_rgb),
        .in_sof(in_sof), .in_eol(in_eol), .in_eof(in_eof),
        .in_x(in_x), .in_y(in_y), .in_source_frame_id(in_source_frame_id),
        .out_valid(gray_valid), .out_rgb(gray_rgb),
        .out_sof(gray_sof), .out_eol(gray_eol), .out_eof(gray_eof),
        .out_x(gray_x), .out_y(gray_y), .out_source_frame_id(gray_id)
    );
    wire window_valid, window_eol;
    wire [71:0] neighborhood;
    wire [10:0] center_x, center_y;
    wire [31:0] window_id;
    window_3x3 #(.WIDTH(WIDTH), .HEIGHT(HEIGHT)) windows (
        .clk(clk), .rst_n(rst_n), .in_valid(gray_valid), .in_gray(gray_rgb[7:0]),
        .in_sof(gray_sof), .in_eol(gray_eol), .in_eof(gray_eof),
        .in_x(gray_x), .in_y(gray_y), .in_source_frame_id(gray_id),
        .out_valid(window_valid), .out_window(neighborhood),
        .out_center_x(center_x), .out_center_y(center_y),
        .out_sof(), .out_eol(window_eol), .out_eof(), .out_source_frame_id(window_id)
    );
    wire edge_valid;
    wire [7:0] edge_pixel;
    reg edge_eol;
    reg [10:0] edge_x, edge_y;
    reg [31:0] edge_id;
    sobel_core sobel (
        .clk(clk), .rst_n(rst_n), .in_valid(window_valid),
        .in_window(neighborhood), .in_threshold(THRESHOLD),
        .out_valid(edge_valid), .out_gx(), .out_gy(), .out_magnitude(), .out_edge(edge_pixel)
    );
    // Exactly parallel to Sobel's one output register stage.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            edge_eol <= 1'b0;
            edge_x <= 11'd0; edge_y <= 11'd0; edge_id <= 32'd0;
        end else begin
            edge_eol <= window_valid && window_eol;
            edge_x <= window_valid ? center_x : 11'd0;
            edge_y <= window_valid ? center_y : 11'd0;
            edge_id <= window_valid ? window_id : 32'd0;
        end
    end
    edge_raster #(.WIDTH(WIDTH), .HEIGHT(HEIGHT)) raster (
        .clk(clk), .rst_n(rst_n), .in_valid(edge_valid), .in_edge(edge_pixel),
        .in_eol(edge_eol), .in_x(edge_x), .in_y(edge_y), .in_source_frame_id(edge_id),
        .out_valid(out_valid), .out_rgb(out_rgb),
        .out_sof(out_sof), .out_eol(out_eol), .out_eof(out_eof),
        .out_x(out_x), .out_y(out_y), .out_source_frame_id(out_source_frame_id), .out_error(out_error)
    );
endmodule
