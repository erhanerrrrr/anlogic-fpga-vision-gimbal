`timescale 1ns/1ps

// Raw buttons and video share this clock. No cross-clock event transfer.
module video_modes_buttons #(
    parameter integer WIDTH=16, HEIGHT=12,
    parameter [10:0] THRESHOLD=11'd128,
    parameter integer DEBOUNCE_CYCLES=750000, ACTIVE_LOW=1
) (
    input wire clk, rst_n, in_valid,
    input wire [23:0] in_rgb,
    input wire in_mask, in_sof, in_eol, in_eof,
    input wire [10:0] in_x, in_y,
    input wire [31:0] in_source_frame_id,
    input wire [2:0] buttons_async,
    output wire [2:0] pressed, press_event,
    output wire [1:0] requested_mode,
    output wire invalid_request,
    output wire out_valid,
    output wire [23:0] out_rgb,
    output wire [1:0] out_mode,
    output wire out_sof, out_eol, out_eof,
    output wire [10:0] out_x, out_y,
    output wire [31:0] out_source_frame_id,
    output wire out_error,
    // Independent, one-register base RGB tap for recognition. Always active.
    output wire detect_valid,
    output wire [23:0] detect_rgb,
    output wire detect_sof, detect_eol, detect_eof,
    output wire [10:0] detect_x, detect_y,
    output wire [31:0] detect_source_frame_id
);
    wire mode_req_valid;
    wire [2:0] mode_req;
    button_mode_request #(.DEBOUNCE_CYCLES(DEBOUNCE_CYCLES),.ACTIVE_LOW(ACTIVE_LOW)) controls (
        .clk(clk),.rst_n(rst_n),.buttons_async(buttons_async),
        .pressed(pressed),.press_event(press_event),.requested_mode(requested_mode),
        .mode_req_valid(mode_req_valid),.mode_req(mode_req)
    );
    video_modes #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.THRESHOLD(THRESHOLD)) video (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(in_valid),
        .in_rgb(in_rgb),
        .in_mask(in_mask),
        .in_sof(in_sof),
        .in_eol(in_eol),
        .in_eof(in_eof),
        .in_x(in_x),
        .in_y(in_y),
        .in_source_frame_id(in_source_frame_id),
        .mode_req_valid(mode_req_valid),
        .mode_req(mode_req),
        .invalid_request(invalid_request),
        .out_valid(out_valid),
        .out_rgb(out_rgb),
        .out_mode(out_mode),
        .out_sof(out_sof),
        .out_eol(out_eol),
        .out_eof(out_eof),
        .out_x(out_x),
        .out_y(out_y),
        .out_source_frame_id(out_source_frame_id),
        .out_error(out_error),
        .detect_valid(detect_valid),
        .detect_rgb(detect_rgb),
        .detect_sof(detect_sof),
        .detect_eol(detect_eol),
        .detect_eof(detect_eof),
        .detect_x(detect_x),
        .detect_y(detect_y),
        .detect_source_frame_id(detect_source_frame_id)
    );
endmodule
