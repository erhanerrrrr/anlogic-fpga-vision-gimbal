// B3a: synchronous mode requests -> stable source-frame mode -> B2d stream.
// Button synchronization/debounce and cross-clock event transport are upstream.
module video_frame_mode_stream #(
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
    input wire mode_req_valid,
    input wire [2:0] mode_req,
    output wire invalid_request,
    output reg invalid_request_seen,
    output wire [1:0] active_input_mode,next_frame_mode,
    output wire out_valid,out_sof,out_eol,out_eof,
    output wire [23:0] out_rgb,out_raw_rgb,out_gray_rgb,out_edge_rgb,out_mask_rgb,
    output wire [1:0] out_mode,
    output wire [10:0] out_x,out_y,
    output wire [31:0] out_epoch,out_frame_id,
    output wire [15:0] out_cfg_id,
    output wire [1:0] out_target_id,
    output wire out_abort,
    output wire detect_valid,detect_mask,detect_sof,detect_eol,detect_eof,
    output wire [10:0] detect_x,detect_y,
    output wire [31:0] detect_epoch,detect_frame_id,
    output wire [15:0] detect_cfg_id,
    output wire [1:0] detect_target_id,
    output wire [15:0] error_flags,fifo_used,fifo_peak
);
    reg input_active;
    wire admitted_sof=rst_n && !out_abort && !input_active && in_valid && in_sof &&
        in_x==0 && in_y==0 && !in_eol && !in_eof;
    wire [1:0] pixel_mode=admitted_sof?next_frame_mode:active_input_mode;
    // Retain applied/pending mode across a video abort. A pending request is
    // consumed only at a new source SOF, never by remnants or a malformed SOF.
    frame_mode_ctrl modes(
        .clk(clk),.rst_n(rst_n),.in_valid(admitted_sof),.in_sof(1'b1),
        .mode_req_valid(mode_req_valid),.mode_req(mode_req),
        .active_mode(active_input_mode),.mode_for_sof(next_frame_mode),.invalid_request(invalid_request));
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin input_active<=0;invalid_request_seen<=0;end
        else begin
            if(out_abort)input_active<=0;
            else if(in_valid && (input_active || admitted_sof))input_active<=!in_eof;
            if(mode_req_valid && mode_req[2])invalid_request_seen<=1;
        end
    end
    video_four_mode_stream #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.GUARD_ROWS(GUARD_ROWS),
        .FIFO_DEPTH(FIFO_DEPTH),.MAX_IDLE_CYCLES(MAX_IDLE_CYCLES),.THRESHOLD(THRESHOLD)) video(
        .clk(clk),.rst_n(rst_n),.stream_abort(stream_abort),
        .in_valid(in_valid),.in_sof(in_sof),.in_eol(in_eol),.in_eof(in_eof),.in_rgb(in_rgb),
        .in_x(in_x),.in_y(in_y),.in_epoch(in_epoch),.in_frame_id(in_frame_id),
        .in_cfg_id(in_cfg_id),.in_target_id(in_target_id),.in_mode(pixel_mode),
        .min_main(min_main),.min_diff_1(min_diff_1),.min_diff_2(min_diff_2),
        .out_valid(out_valid),.out_sof(out_sof),.out_eol(out_eol),.out_eof(out_eof),
        .out_rgb(out_rgb),.out_raw_rgb(out_raw_rgb),.out_gray_rgb(out_gray_rgb),
        .out_edge_rgb(out_edge_rgb),.out_mask_rgb(out_mask_rgb),.out_mode(out_mode),
        .out_x(out_x),.out_y(out_y),.out_epoch(out_epoch),.out_frame_id(out_frame_id),
        .out_cfg_id(out_cfg_id),.out_target_id(out_target_id),.out_abort(out_abort),
        .detect_valid(detect_valid),.detect_mask(detect_mask),
        .detect_sof(detect_sof),.detect_eol(detect_eol),.detect_eof(detect_eof),
        .detect_x(detect_x),.detect_y(detect_y),
        .detect_epoch(detect_epoch),.detect_frame_id(detect_frame_id),
        .detect_cfg_id(detect_cfg_id),.detect_target_id(detect_target_id),
        .error_flags(error_flags),.fifo_used(fifo_used),.fifo_peak(fifo_peak));
endmodule
