// B3b: one shared three-key synchronizer/debouncer, frame-boundary mode selection.
// Key bits: 0 mode, 1 calibrate, 2 track. Events are in the pixel clock domain.
module video_button_stream #(
    parameter integer WIDTH=1280,HEIGHT=720,GUARD_ROWS=4,
    parameter integer DEBOUNCE_CYCLES=750000,ACTIVE_LOW=1,
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
    input wire [2:0] buttons_async,
    output wire [2:0] pressed,press_event,
    output wire [1:0] requested_mode,
    output wire mode_next_evt,calibrate_evt,track_toggle_evt,
    output wire invalid_request,
    output wire invalid_request_seen,
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
    wire mode_req_valid;
    wire [2:0] mode_req;
    button_mode_request #(.DEBOUNCE_CYCLES(DEBOUNCE_CYCLES),.ACTIVE_LOW(ACTIVE_LOW)) controls(
        .clk(clk),.rst_n(rst_n),.buttons_async(buttons_async),
        .pressed(pressed),.press_event(press_event),.requested_mode(requested_mode),
        .mode_req_valid(mode_req_valid),.mode_req(mode_req));
    assign mode_next_evt=press_event[0];
    assign calibrate_evt=press_event[1];
    assign track_toggle_evt=press_event[2];
    video_frame_mode_stream #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.GUARD_ROWS(GUARD_ROWS),
        .FIFO_DEPTH(FIFO_DEPTH),.MAX_IDLE_CYCLES(MAX_IDLE_CYCLES),.THRESHOLD(THRESHOLD)) video(
        .clk(clk),.rst_n(rst_n),.stream_abort(stream_abort),
        .in_valid(in_valid),.in_sof(in_sof),.in_eol(in_eol),.in_eof(in_eof),.in_rgb(in_rgb),
        .in_x(in_x),.in_y(in_y),.in_epoch(in_epoch),.in_frame_id(in_frame_id),
        .in_cfg_id(in_cfg_id),.in_target_id(in_target_id),.mode_req_valid(mode_req_valid),.mode_req(mode_req),
        .invalid_request(invalid_request),.invalid_request_seen(invalid_request_seen),
        .active_input_mode(active_input_mode),.next_frame_mode(next_frame_mode),
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
