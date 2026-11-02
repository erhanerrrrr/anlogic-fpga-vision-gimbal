`timescale 1ns/1ps

// Complete interior windows only; no padding and no Sobel arithmetic.
// Parameters: 3 <= WIDTH, HEIGHT <= 2048. Input is a legal raster stream.
// A pixel captured at edge N can produce its window at edge N+1.
module window_3x3 #(
    parameter integer WIDTH = 16,
    parameter integer HEIGHT = 12
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        in_valid,
    input  wire [7:0]  in_gray,
    input  wire        in_sof,
    input  wire        in_eol,
    input  wire        in_eof,
    input  wire [10:0] in_x,
    input  wire [10:0] in_y,
    input  wire [31:0] in_source_frame_id,
    output reg         out_valid,
    output reg  [71:0] out_window,
    output reg  [10:0] out_center_x,
    output reg  [10:0] out_center_y,
    output reg         out_sof,
    output reg         out_eol,
    output reg         out_eof,
    output reg  [31:0] out_source_frame_id
);
    reg in_frame;
    wire accept_pixel = rst_n && in_valid && (in_frame || in_sof)
                        && (in_x < WIDTH) && (in_y < HEIGHT);

    // Do not reset either memory. Rows 0 and 1 refill history every frame.
    reg [7:0] previous_row [0:WIDTH-1];
    reg [7:0] two_rows_back [0:WIDTH-1];
    reg [7:0] previous_q, older_q;
    reg stage_valid, stage_eol, stage_eof;
    reg [7:0] stage_gray;
    reg [10:0] stage_x, stage_y;
    reg [31:0] stage_id;

    // Synchronous reads at the current x; writes use the preceding pixel.
    // For a legal raster (WIDTH >= 3), used reads do not collide with writes.
    // This avoids relying on a vendor-specific same-address read/write mode.
    always @(posedge clk) begin
        if (accept_pixel) begin
            previous_q <= previous_row[in_x];
            older_q <= two_rows_back[in_x];
        end
        if (rst_n && stage_valid) begin
            previous_row[stage_x] <= stage_gray;
            if (stage_y != 0)
                two_rows_back[stage_x] <= previous_q;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            in_frame <= 1'b0;
            stage_valid <= 1'b0;
            stage_eol <= 1'b0;
            stage_eof <= 1'b0;
            stage_gray <= 8'd0;
            stage_x <= 11'd0;
            stage_y <= 11'd0;
            stage_id <= 32'd0;
        end else begin
            stage_valid <= accept_pixel;
            stage_eol <= accept_pixel && in_eol;
            stage_eof <= accept_pixel && in_eof;
            stage_gray <= accept_pixel ? in_gray : 8'd0;
            stage_x <= accept_pixel ? in_x : 11'd0;
            stage_y <= accept_pixel ? in_y : 11'd0;
            stage_id <= accept_pixel ? in_source_frame_id : 32'd0;
            if (accept_pixel)
                in_frame <= !in_eof;
        end
    end

    reg [7:0] top_left2, top_left1;
    reg [7:0] mid_left2, mid_left1;
    reg [7:0] bot_left2, bot_left1;
    wire [7:0] top_pixel = (stage_y >= 2) ? older_q : 8'd0;
    wire [7:0] mid_pixel = (stage_y >= 1) ? previous_q : 8'd0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            top_left2 <= 8'd0; top_left1 <= 8'd0;
            mid_left2 <= 8'd0; mid_left1 <= 8'd0;
            bot_left2 <= 8'd0; bot_left1 <= 8'd0;
            out_valid <= 1'b0;
            out_window <= 72'd0;
            out_center_x <= 11'd0; out_center_y <= 11'd0;
            out_sof <= 1'b0; out_eol <= 1'b0; out_eof <= 1'b0;
            out_source_frame_id <= 32'd0;
        end else begin
            out_valid <= 1'b0;
            out_window <= 72'd0;
            out_center_x <= 11'd0; out_center_y <= 11'd0;
            out_sof <= 1'b0; out_eol <= 1'b0; out_eof <= 1'b0;
            out_source_frame_id <= 32'd0;

            if (stage_valid) begin
                // Start each row afresh; blank cycles never shift history.
                top_left2 <= (stage_x == 0) ? 8'd0 : top_left1;
                mid_left2 <= (stage_x == 0) ? 8'd0 : mid_left1;
                bot_left2 <= (stage_x == 0) ? 8'd0 : bot_left1;
                top_left1 <= top_pixel;
                mid_left1 <= mid_pixel;
                bot_left1 <= stage_gray;

                if (stage_x >= 2 && stage_y >= 2) begin
                    out_valid <= 1'b1;
                    // High to low bytes: p00,p01,p02,p10,p11,p12,p20,p21,p22.
                    out_window <= {top_left2, top_left1, top_pixel,
                                   mid_left2, mid_left1, mid_pixel,
                                   bot_left2, bot_left1, stage_gray};
                    out_center_x <= stage_x - 11'd1;
                    out_center_y <= stage_y - 11'd1;
                    // Markers describe the smaller stream of valid windows.
                    out_sof <= (stage_x == 2 && stage_y == 2);
                    out_eol <= stage_eol;
                    out_eof <= stage_eof;
                    out_source_frame_id <= stage_id;
                end
            end
        end
    end
endmodule
