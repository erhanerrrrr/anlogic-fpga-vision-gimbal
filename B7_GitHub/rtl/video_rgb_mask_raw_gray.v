// B2b integration: exactly one B2a queue/classifier/filter, plus one RAW/GRAY stage.
module video_rgb_mask_raw_gray #(
    parameter integer WIDTH=1280,HEIGHT=720,GUARD_ROWS=4,
    parameter integer FIFO_DEPTH=(1 << $clog2(WIDTH+8)),
    parameter integer MAX_IDLE_CYCLES=4096
)(
    input wire clk,rst_n,stream_abort,
    input wire in_valid,in_sof,in_eol,in_eof,
    input wire [23:0] in_rgb,
    input wire [10:0] in_x,in_y,
    input wire [31:0] in_epoch,in_frame_id,
    input wire [15:0] in_cfg_id,
    input wire [1:0] in_target_id,
    input wire [7:0] min_main,min_diff_1,min_diff_2,
    output wire out_valid,
    output wire [23:0] out_raw_rgb,out_gray_rgb,
    output wire out_mask,out_sof,out_eol,out_eof,
    output wire [10:0] out_x,out_y,
    output wire [31:0] out_epoch,out_frame_id,
    output wire [15:0] out_cfg_id,
    output wire [1:0] out_target_id,
    output wire out_abort,
    output wire [7:0] error_flags,
    output wire [15:0] fifo_used,fifo_peak
);
    wire pv,pm,ps,pl,pe,pa,sa;
    wire [23:0] prgb;
    wire [10:0] px,py;
    wire [81:0] pt;
    video_rgb_mask_pair #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.GUARD_ROWS(GUARD_ROWS),
        .FIFO_DEPTH(FIFO_DEPTH),.MAX_IDLE_CYCLES(MAX_IDLE_CYCLES)) pair(
        .clk(clk),.rst_n(rst_n),.stream_abort(stream_abort),
        .in_valid(in_valid),.in_sof(in_sof),.in_eol(in_eol),.in_eof(in_eof),
        .in_rgb(in_rgb),.in_x(in_x),.in_y(in_y),.in_epoch(in_epoch),.in_frame_id(in_frame_id),
        .in_cfg_id(in_cfg_id),.in_target_id(in_target_id),
        .min_main(min_main),.min_diff_1(min_diff_1),.min_diff_2(min_diff_2),
        .out_valid(pv),.out_rgb(prgb),.out_mask(pm),.out_sof(ps),.out_eol(pl),.out_eof(pe),
        .out_x(px),.out_y(py),.out_epoch(pt[81:50]),.out_frame_id(pt[49:18]),
        .out_cfg_id(pt[17:2]),.out_target_id(pt[1:0]),.out_abort(pa),
        .error_flags(error_flags),.fifo_used(fifo_used),.fifo_peak(fifo_peak));
    video_raw_gray_stage display_stage(
        .clk(clk),.rst_n(rst_n),.stream_abort(stream_abort || pa),
        .in_valid(pv),.in_rgb(prgb),.in_mask(pm),.in_sof(ps),.in_eol(pl),.in_eof(pe),
        .in_x(px),.in_y(py),.in_epoch(pt[81:50]),.in_frame_id(pt[49:18]),
        .in_cfg_id(pt[17:2]),.in_target_id(pt[1:0]),
        .out_valid(out_valid),.out_raw_rgb(out_raw_rgb),.out_gray_rgb(out_gray_rgb),
        .out_mask(out_mask),.out_sof(out_sof),.out_eol(out_eol),.out_eof(out_eof),
        .out_x(out_x),.out_y(out_y),.out_epoch(out_epoch),.out_frame_id(out_frame_id),
        .out_cfg_id(out_cfg_id),.out_target_id(out_target_id),.out_abort(sa));
    // Abort remains asserted until the added pipeline stage is also flushed.
    assign out_abort=stream_abort || pa || sa;
endmodule
