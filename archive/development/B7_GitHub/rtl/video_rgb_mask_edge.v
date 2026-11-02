// B2c integration. base_* and out_* have DIFFERENT timing; do not mux directly.
// One existing B2b instance + one two-line gray edge stage. No second RGB FIFO.
module video_rgb_mask_edge #(
    parameter integer WIDTH=1280,HEIGHT=720,GUARD_ROWS=4,
    parameter integer FIFO_DEPTH=(1 << $clog2(WIDTH+8)),MAX_IDLE_CYCLES=4096,
    parameter [10:0] THRESHOLD=11'd128
)(
    input wire clk,rst_n,stream_abort,
    input wire in_valid,in_sof,in_eol,in_eof,
    input wire [23:0] in_rgb,
    input wire [10:0] in_x,in_y,
    input wire [31:0] in_epoch,in_frame_id,
    input wire [15:0] in_cfg_id,
    input wire [1:0] in_target_id,
    input wire [7:0] min_main,min_diff_1,min_diff_2,
    output wire out_valid,out_sof,out_eol,out_eof,
    output wire [23:0] out_rgb,
    output wire [10:0] out_x,out_y,
    output wire [31:0] out_epoch,out_frame_id,
    output wire [15:0] out_cfg_id,
    output wire [1:0] out_target_id,
    output wire out_abort,
    output wire [12:0] error_flags,
    output wire [15:0] fifo_used,fifo_peak,
    output wire base_valid,base_mask,base_sof,base_eol,base_eof,
    output wire [23:0] base_raw_rgb,base_gray_rgb,
    output wire [10:0] base_x,base_y,
    output wire [31:0] base_epoch,base_frame_id,
    output wire [15:0] base_cfg_id,
    output wire [1:0] base_target_id
);
    wire ba,ea;
    video_rgb_mask_raw_gray #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.GUARD_ROWS(GUARD_ROWS),
        .FIFO_DEPTH(FIFO_DEPTH),.MAX_IDLE_CYCLES(MAX_IDLE_CYCLES)) base(
        .clk(clk),.rst_n(rst_n),.stream_abort(stream_abort),
        .in_valid(in_valid),.in_sof(in_sof),.in_eol(in_eol),.in_eof(in_eof),.in_rgb(in_rgb),
        .in_x(in_x),.in_y(in_y),.in_epoch(in_epoch),.in_frame_id(in_frame_id),
        .in_cfg_id(in_cfg_id),.in_target_id(in_target_id),
        .min_main(min_main),.min_diff_1(min_diff_1),.min_diff_2(min_diff_2),
        .out_valid(base_valid),.out_raw_rgb(base_raw_rgb),.out_gray_rgb(base_gray_rgb),
        .out_mask(base_mask),.out_sof(base_sof),.out_eol(base_eol),.out_eof(base_eof),
        .out_x(base_x),.out_y(base_y),.out_epoch(base_epoch),.out_frame_id(base_frame_id),
        .out_cfg_id(base_cfg_id),.out_target_id(base_target_id),.out_abort(ba),
        .error_flags(error_flags[7:0]),.fifo_used(fifo_used),.fifo_peak(fifo_peak));
    video_gray_edge_stream #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.MAX_IDLE_CYCLES(MAX_IDLE_CYCLES),.THRESHOLD(THRESHOLD)) edges(
        .clk(clk),.rst_n(rst_n),.stream_abort(stream_abort || ba),
        .in_valid(base_valid),.in_gray(base_gray_rgb[7:0]),.in_sof(base_sof),.in_eol(base_eol),.in_eof(base_eof),
        .in_x(base_x),.in_y(base_y),.in_epoch(base_epoch),.in_frame_id(base_frame_id),
        .in_cfg_id(base_cfg_id),.in_target_id(base_target_id),
        .out_valid(out_valid),.out_rgb(out_rgb),.out_sof(out_sof),.out_eol(out_eol),.out_eof(out_eof),
        .out_x(out_x),.out_y(out_y),.out_epoch(out_epoch),.out_frame_id(out_frame_id),
        .out_cfg_id(out_cfg_id),.out_target_id(out_target_id),.out_abort(ea),.error_flags(error_flags[12:8]));
    assign out_abort=stream_abort || ba || ea;
endmodule
